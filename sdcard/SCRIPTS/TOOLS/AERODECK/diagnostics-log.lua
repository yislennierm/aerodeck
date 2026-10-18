-- Opt-in bounded error/event log. record() and beginFlush() are RAM-only;
-- explicit flush()/stepFlush() access files. Native static io takes a handle.
-- One inert log with per-event model identity avoids per-model path collisions.
-- Never execute/load a log. Native rename/del are required for safe promotion.
local M={}
local capacity,maxBytes,recordInterval,flushInterval=8,4096,25,3000
local function integer(v,lo,hi)return type(v)=='number' and v==v and v%1==0.0 and v>=lo and v<=hi end
local function checksum(raw)
 local a,b=0,0;local i,n=1,#raw;local byte=string.byte
 -- Same persisted Fletcher checksum,16-byte blocks; intermediates<=38998.
 while i+15<=n do
  local x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16=byte(raw,i,i+15)
  a=a+x1;b=b+a;a=a+x2;b=b+a;a=a+x3;b=b+a;a=a+x4;b=b+a
  a=a+x5;b=b+a;a=a+x6;b=b+a;a=a+x7;b=b+a;a=a+x8;b=b+a
  a=a+x9;b=b+a;a=a+x10;b=b+a;a=a+x11;b=b+a;a=a+x12;b=b+a
  a=a+x13;b=b+a;a=a+x14;b=b+a;a=a+x15;b=b+a;a=a+x16;b=b+a
  a=a%255;b=b%255;i=i+16
 end
 for j=i,n do a=(a+byte(raw,j))%255;b=(b+a)%255 end
 return string.format('%02X%02X',a,b)
end
local function safe(raw,limit)
 return (string.gsub(string.sub(raw,1,limit),'[%c|]',' '))
end
local function validModel(id)
 return type(id)=='string' and #id>0 and #id<=96 and not string.find(id,'[%c|]')
end
local function validLog(raw)
 if type(raw)~='string' or #raw>maxBytes or string.sub(raw,1,7)~='ADLOG1\n' then return false end
 local body,sum=string.match(raw,'^(.*)C|([0-9A-F][0-9A-F][0-9A-F][0-9A-F])\n$')
 return body~=nil and string.sub(body,-1)=='\n' and checksum(body)==sum
end
function M.new(opts)
 opts=opts or {}
 local fs=opts.io or io
 local removeFile,renameFile=opts.remove or del,opts.rename or rename
 local statFile=opts.stat or fstat
 local root=opts.root or '/SCRIPTS/TOOLS/AERODECK'
 local validRoot=type(root)=='string' and #root<=128 and string.sub(root,1,1)=='/' and not string.find(root,'[%c\\]')
 if validRoot then
  for part in string.gmatch(root,'[^/]+')do if part=='.' or part=='..'then validRoot=false end end
  root=string.gsub(root,'/+$','');validRoot=validRoot and #root>0
 end
 local path=validRoot and root..'/errors.log' or nil
 local events={}
 local s={enabled=false,state='OFF',events=events,pending=false,dropped=0,repeated=0,recorded=0,clockEpoch=0,revision=0,path=path,
  capacity=capacity,maxBytes=maxBytes,recordIntervalTicks=recordInterval,flushIntervalTicks=flushInterval,flushing=false}
 local api,lastNow,lastRecord,lastAttempt={},nil,nil,nil
 local verifiedRaw,flushJob
 local function clearFlush()
  flushJob=nil;s.flushing=false;s.flushPhase=nil;s.flushModelId=nil
 end
 function api.cancelFlush(reason)
  if not flushJob then return true,'IDLE'end
  clearFlush();s.error=reason or'CANCELLED';s.state=not s.enabled and'OFF'or(s.pending and'PENDING'or'READY')
  return true,s.error
 end
 local function changed()
  s.pending=true;s.revision=s.revision+1;s.state='PENDING'
 end
 local function now()
  if type(opts.clock)~='function'then return nil,'CLOCK UNAVAILABLE'end
  local ok,t=pcall(opts.clock)
  if not ok or not integer(t,0,4294967295)then return nil,'CLOCK UNAVAILABLE'end
  if lastNow and t<lastNow then
   s.clockEpoch=s.clockEpoch+1;lastRecord=nil;lastAttempt=nil;s.nextFlushAt=nil
  end
  lastNow=t;return t
 end
 local function date()
  if type(opts.getDateTime)~='function'then return '--'end
  local ok,d=pcall(opts.getDateTime)
  if not ok or type(d)~='table' or not integer(d.year,1970,9999) or not integer(d.mon,1,12) or not integer(d.day,1,31)
   or not integer(d.hour,0,23) or not integer(d.min,0,59) or not integer(d.sec,0,60)then return '--'end
  return string.format('%04d-%02d-%02dT%02d:%02d:%02d',d.year,d.mon,d.day,d.hour,d.min,d.sec)
 end
 function api.snapshot()return s end -- Stable borrowed read-only view.
 function api.configure(enabled,modelId)
  if type(enabled)~='boolean'then return false,'INVALID ENABLE FLAG'end
  if enabled and not validModel(modelId)then return false,'INVALID MODEL ID'end
  if flushJob and(not enabled or modelId~=flushJob.modelId)then api.cancelFlush(not enabled and'OFF'or'MODEL CHANGED')end
  s.enabled=enabled;if validModel(modelId)then s.modelId=modelId end
  s.error=nil;s.state=not enabled and 'OFF' or(s.pending and 'PENDING' or 'READY')
  return true
 end
 function api.record(kind,message)
  if not s.enabled then return false,'OFF'end
  if type(kind)~='string' or #kind==0 or type(message)~='string' or #message==0 then return false,'INVALID EVENT'end
  local tick,err=now();if not tick then s.error=err;s.state='ERROR';return false,err end
  kind=safe(kind,32);message=safe(message,192)
  for _,event in ipairs(events)do
   if event.modelId==s.modelId and event.kind==kind and event.message==message then
    event.repeats=math.min(9999,event.repeats+1);event.lastTick=tick;event.lastEpoch=s.clockEpoch
    s.repeated=math.min(999999,s.repeated+1);changed();return true,'REPEATED'
   end
  end
  if lastRecord and tick-lastRecord<recordInterval then
   s.dropped=math.min(999999,s.dropped+1);changed();return false,'RATE LIMITED'
  end
  lastRecord=tick
  local event
  if #events==capacity then event=table.remove(events,1)else event={}end
  event.modelId=s.modelId;event.kind=kind;event.message=message;event.tick=tick;event.lastTick=tick;event.epoch=s.clockEpoch;event.lastEpoch=s.clockEpoch
  event.repeats=1;event.date=date();events[#events+1]=event
  s.recorded=math.min(999999,s.recorded+1);changed();s.error=nil
  return true,'RECORDED'
 end
 local function encode()
  local lines={'ADLOG1','events='..#events..' dropped='..s.dropped..' repeated='..s.repeated..' recorded='..s.recorded..' clockEpoch='..s.clockEpoch}
  for _,e in ipairs(events)do
   lines[#lines+1]='at='..e.date..' tick='..e.tick..' last='..e.lastTick..' epoch='..e.epoch..'/'..e.lastEpoch..' repeats='..e.repeats
    ..' model='..e.modelId..' kind='..e.kind..' message='..e.message
  end
  local body=table.concat(lines,'\n')..'\n'
  return body..'C|'..checksum(body)..'\n'
 end
 local function ioReady()
  return type(fs)=='table' and type(fs.open)=='function' and type(fs.read)=='function' and type(fs.write)=='function' and type(fs.close)=='function'
   and type(removeFile)=='function' and type(renameFile)=='function'
 end
 local function read(file)
  local ok,f=pcall(fs.open,file,'r');if not ok then return nil,'OPEN ERROR',false end
  if not f then return nil,'NOT FOUND',false end
  local good,raw=pcall(fs.read,f,maxBytes+1);local closed,v=pcall(fs.close,f)
  if not good or not closed or v==false or type(raw)~='string'then return nil,'READ ERROR',true end
  if #raw>maxBytes then return nil,'OVERSIZE LOG',true end
  return raw,nil,true
 end
 local function remove(file)
  -- Simulator FatFS uses6 even for absent files;6 is never delete success.
  if type(statFile)=='function'then
   local ok,info=pcall(statFile,file)
   if not ok or(info~=nil and type(info)~='table')then return false end
   if info==nil then return true end
  end
  local ok,v=pcall(removeFile,file);return ok and(v==0 or v==true or v==4 or v==5)
 end
 local function move(from,to)
  local ok,v=pcall(renameFile,from,to);return ok and(v==0 or v==true)
 end
 local function write(file,raw)
  local ok,f=pcall(fs.open,file,'w');if not ok or not f then return false,'OPEN WRITE FAILED'end
  local good,v=pcall(fs.write,f,raw);local closed,result=pcall(fs.close,f)
  if not good or v==false or not closed or result==false then return false,'WRITE ERROR'end
  local actual=read(file)
  if actual~=raw then return false,'READBACK MISMATCH'end
  return true
 end
 local function errorState(err)clearFlush();s.state='ERROR';s.error=err;return false,err end
 local function complete(job,result)
  verifiedRaw=job.raw
  s.pending=s.revision~=job.revision;s.state=s.pending and'PENDING'or'SAVED';s.error=nil;s.lastFlushAt=job.tick
  if result=='SAVED'then s.flushedRevision=job.revision end
  clearFlush();return true,result
 end
 function api.beginFlush()
  if flushJob then return false,'SAVE IN PROGRESS'end
  if not s.enabled then return false,'OFF'end
  if not s.pending then return true,'UNCHANGED'end
  if not path then return errorState('INVALID LOG ROOT')end
  if not ioReady()then return errorState('ATOMIC IO UNAVAILABLE')end
  local tick,err=now();if not tick then return errorState(err)end
  if lastAttempt and tick-lastAttempt<flushInterval then s.nextFlushAt=lastAttempt+flushInterval;return false,'RATE LIMITED'end
  flushJob={phase=1,modelId=s.modelId,epoch=s.clockEpoch};s.flushing=true;s.flushPhase=1;s.flushModelId=s.modelId;s.state='SAVING';s.error=nil
  return true,'PENDING'
 end
 function api.stepFlush(currentModelId)
  local job=flushJob;if not job then return false,'NO SAVE IN PROGRESS'end
  if not s.enabled then return errorState('OFF')end
  if s.modelId~=job.modelId or currentModelId~=job.modelId then return errorState('MODEL CHANGED')end
  local tick,err=now();if not tick then return errorState(err)end
  if s.clockEpoch~=job.epoch then return errorState('CLOCK CHANGED')end
  if job.phase==1 then
   job.revision=s.revision;job.raw=encode();if #job.raw>maxBytes then return errorState('OVERSIZE LOG')end
   job.tick=tick;lastAttempt=tick;s.nextFlushAt=tick+flushInterval
   job.old,job.oldError,job.exists=read(path)
   if job.oldError=='OPEN ERROR'or job.oldError=='READ ERROR'then return errorState('PRIMARY READ ERROR')end
   if job.old==job.raw then return complete(job,'UNCHANGED')end
   job.phase=2;s.flushPhase=2;return true,'PENDING'
  end
  local oldValid=job.old and(job.old==verifiedRaw or validLog(job.old))
  -- A callback boundary is an actual race window: never rotate or replace a
  -- primary that changed after phase1, even if the captured old file was valid.
  local current,currentError,currentExists=read(path)
  if currentError=='OPEN ERROR'or currentError=='READ ERROR'then return errorState('PRIMARY READ ERROR')end
  if current~=job.old or currentError~=job.oldError or currentExists~=job.exists then return errorState('PRIMARY CHANGED')end
  local ok;ok,err=write(path..'.tmp',job.raw);if not ok then return errorState(err)end
  if oldValid then
   if not remove(path..'.bak')then return errorState('BACKUP DELETE FAILED')end
   if not move(path,path..'.bak')then return errorState('BACKUP RENAME FAILED')end
  elseif job.exists then
   if not remove(path)then return errorState('CORRUPT PRIMARY DELETE FAILED')end
  end
  if not move(path..'.tmp',path)then return errorState('PROMOTION FAILED')end
  local actual=read(path)
  -- encode() generated this canonical checksum-bearing snapshot. Exact temp
  -- and final byte equality verifies its entire content without rechecksumming.
  if actual~=job.raw then return errorState('FINAL VERIFY FAILED')end
  return complete(job,'SAVED')
 end
 function api.flush()
  local ok,result=api.beginFlush();if not ok or not flushJob then return ok,result end
  -- Legacy standalone callers keep the synchronous contract. Widgets must
  -- explicitly begin, then invoke one step per dedicated saving callback.
  while flushJob do ok,result=api.stepFlush(s.modelId);if not ok then return false,result end end
  return ok,result
 end
 return api
end
return M
