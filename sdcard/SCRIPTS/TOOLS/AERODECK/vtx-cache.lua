-- Inert per-FC VTX tables. Never load/execute a cache as Lua; never authorizes
-- readiness, freshness or writes. The caller must match a fresh UID and VTX88.
-- EdgeTX2.12.4: io.read/write/close take the file handle as their first argument;
-- global del()/rename() return FRESULT0 on success (api_filesystem.cpp147–234).
local M={}
local maxBytes=4096
local function integer(v,lo,hi)return type(v)=='number' and v%1==0.0 and v>=lo and v<=hi end
local function uidKey(uid)
 if type(uid)~='string' or #uid~=24 or string.find(uid,'[^%x]') or uid==string.rep('0',24) then return nil end
 return string.upper(uid)
end
local function signature(h,b,c,p)return string.format('%d:%d:%d:%d',h,b,c,p)end
local function metadata(t)
 if type(t)~='table' then return nil,'INVALID METADATA' end
 local h,b,c,p
 if t.signature~=nil then
  if type(t.signature)~='string' or #t.signature>20 then return nil,'INVALID SIGNATURE' end
  local a,bb,cc,dd=string.match(t.signature,'^(%d+):(%d+):(%d+):(%d+)$')
  h,b,c,p=tonumber(a),tonumber(bb),tonumber(cc),tonumber(dd)
 else
  local r=t.reported or t
  if type(r)~='table' then return nil,'INVALID METADATA' end
  h,b,c,p=r.hardware,r.bandCount,r.channelCount,r.powerCount
 end
 if not integer(h,1,254) or not integer(b,1,8) or not integer(c,1,8) or not integer(p,1,8) then return nil,'INVALID DIMENSIONS' end
 local sig=signature(h,b,c,p)
 if t.signature~=nil and t.signature~=sig then return nil,'NONCANONICAL SIGNATURE' end
 if t.hardware~=nil and t.hardware~=h or t.bandCount~=nil and t.bandCount~=b or t.channelCount~=nil and t.channelCount~=c or t.powerCount~=nil and t.powerCount~=p then return nil,'METADATA MISMATCH' end
 local r=t.reported
 if r and (type(r)~='table' or r.hardware~=h or r.bandCount~=b or r.channelCount~=c or r.powerCount~=p or r.tableAvailable==false) then return nil,'METADATA MISMATCH' end
 if t.tableAvailable==false then return nil,'TABLE NOT AVAILABLE' end
 return {hardware=h,bandCount=b,channelCount=c,powerCount=p,signature=sig}
end
local function text(v,limit)
 return type(v)=='string' and #v<=limit and not string.find(v,'[^ -~]')
end
local function array(t,count)
 if type(t)~='table' then return false end
 local found=0
 for k in pairs(t)do if not integer(k,1,count)then return false end;found=found+1 end
 if found~=count then return false end
 for i=1,count do if t[i]==nil then return false end end
 return true
end
local function validate(uid,t)
 uid=uidKey(uid);if not uid then return nil,'INVALID UID' end
 local md,err=metadata(t);if not md then return nil,err end
 if t.uid~=nil and uidKey(t.uid)~=uid then return nil,'UID MISMATCH' end
 if not array(t.bands,md.bandCount) or not array(t.powers,md.powerCount)then return nil,'TABLE COUNT MISMATCH' end
 local record={uid=uid,signature=md.signature,hardware=md.hardware,bandCount=md.bandCount,channelCount=md.channelCount,powerCount=md.powerCount,bands={},powers={},cached=true,provenance='SD CACHE / FRESH UID AND VTX METADATA REQUIRED'}
 for i=1,md.bandCount do
  local b=t.bands[i]
  if type(b)~='table' or b.index~=i or not text(b.name,64) or not text(b.letter,1) or type(b.factory)~='boolean' or not array(b.frequencies,md.channelCount)then return nil,'INVALID BAND' end
  local frequencies={}
  for j=1,md.channelCount do
   local f=b.frequencies[j];if not integer(f,0,65535)then return nil,'INVALID FREQUENCY' end
   frequencies[j]=f
  end
  record.bands[i]={index=i,name=b.name,letter=b.letter,factory=b.factory,frequencies=frequencies}
 end
 for i=1,md.powerCount do
  local p=t.powers[i]
  if type(p)~='table' or p.index~=i or not integer(p.value,0,65535) or not text(p.label,64)then return nil,'INVALID POWER' end
  record.powers[i]={index=i,value=p.value,label=p.label}
 end
 return record
end
local hexEncode,hexDecode={},{}
for byte=0,255 do
 local c,h=string.char(byte),string.format('%02X',byte)
 hexEncode[c]=h;hexDecode[h]=c
end
local function hex(value)
 -- Native gsub table replacement avoids one Lua callback per text byte.
 return (string.gsub(value,'.',hexEncode))
end
local function unhex(value,limit)
 if #value>limit*2 or #value%2~=0 or string.find(value,'[^0-9A-F]')then return nil end
 return (string.gsub(value,'..',hexDecode))
end
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
local function encode(record,verifiedSum)
 local lines={'ADVT1','U|'..record.uid,'S|'..record.signature}
 for i,b in ipairs(record.bands)do
  local frequencies={};for j,f in ipairs(b.frequencies)do frequencies[j]=tostring(f)end
  lines[#lines+1]='B|'..i..'|'..(b.factory and '1' or '0')..'|'..hex(b.name)..'|'..hex(b.letter)..'|'..table.concat(frequencies,',')
 end
 for i,p in ipairs(record.powers)do lines[#lines+1]='P|'..i..'|'..p.value..'|'..hex(p.label)end
 local body=table.concat(lines,'\n')..'\n'
 return body..'C|'..(verifiedSum or checksum(body))..'\n'
end
local function decode(uid,raw)
 if type(raw)~='string' or #raw>maxBytes then return nil,'OVERSIZE OR INVALID FILE' end
 local body,sum=string.match(raw,'^(.*)C|([0-9A-F][0-9A-F][0-9A-F][0-9A-F])\n$')
 if not body or string.sub(body,-1)~='\n' or checksum(body)~=sum then return nil,'CHECKSUM OR TRUNCATED FILE' end
 local lines={};for line in string.gmatch(body,'([^\n]*)\n')do lines[#lines+1]=line;if #lines>19 then return nil,'TOO MANY RECORDS' end end
 if lines[1]~='ADVT1' or lines[2]~='U|'..uid or not lines[3]then return nil,'FORMAT OR UID MISMATCH' end
 local sig=string.match(lines[3],'^S|(.+)$');local md=metadata({signature=sig})
 if not md or #lines~=3+md.bandCount+md.powerCount then return nil,'INVALID RECORD COUNT' end
 local record={uid=uid,signature=sig,bands={},powers={}}
 for n=1,md.bandCount do
  local i,factory,name,letter,freq=string.match(lines[3+n],'^B|(%d+)|([01])|([0-9A-F]*)|([0-9A-F]*)|([%d,]+)$')
  i=tonumber(i)
  if not i or record.bands[i]then return nil,'INVALID BAND RECORD' end
  local frequencies={}
  for value in string.gmatch(freq,'[^,]+')do frequencies[#frequencies+1]=tonumber(value);if #frequencies>8 then return nil,'TOO MANY FREQUENCIES' end end
  record.bands[i]={index=i,name=unhex(name,64),letter=unhex(letter,1),factory=factory=='1',frequencies=frequencies}
 end
 for n=1,md.powerCount do
  local i,value,label=string.match(lines[3+md.bandCount+n],'^P|(%d+)|(%d+)|([0-9A-F]*)$')
  i=tonumber(i)
  if not i or record.powers[i]then return nil,'INVALID POWER RECORD' end
  record.powers[i]={index=i,value=tonumber(value),label=unhex(label,64)}
 end
 local valid,err=validate(uid,record)
 if not valid then return nil,err end
 if encode(valid,sum)~=raw then return nil,'NONCANONICAL FILE' end
 return valid
end
local function matchesValidated(record,fresh88)
 local md,err=metadata(fresh88);if not md then return false,err end
 if md.signature~=record.signature then return false,'METADATA MISMATCH' end
 return true
end
function M.matches(record,uid,fresh88)
 local valid,err=validate(uid,record);if not valid then return false,err end
 return matchesValidated(valid,fresh88)
end
function M.new(opts)
 opts=opts or {}
 local fs=opts.io or io
 local removeFile,renameFile=opts.remove or del,opts.rename or rename
 local statFile=opts.stat or fstat
 local root=opts.root or '/SCRIPTS/TOOLS/AERODECK'
 local validRoot=type(root)=='string' and #root<=128 and string.sub(root,1,1)=='/' and not string.find(root,'[%c\\]')
 if validRoot then for part in string.gmatch(root,'[^/]+')do if part=='.' or part=='..' then validRoot=false end end;root=string.gsub(root,'/+$','');validRoot=validRoot and #root>0 end
 local c={}
 local verifiedFile,verifiedRaw
 local function path(uid)
  if not validRoot then return nil,'INVALID CACHE ROOT' end
  local key=uidKey(uid);if not key then return nil,'INVALID UID' end
  return root..'/vtx-'..key..'.cache',key
 end
 local function ioReady()
  return type(fs)=='table' and type(fs.open)=='function' and type(fs.read)=='function' and type(fs.write)=='function' and type(fs.close)=='function'
 end
 local function read(file)
  local ok,f=pcall(fs.open,file,'r')
  if not ok then return nil,'OPEN ERROR',false end
  if not f then return nil,'NOT FOUND',false end
  local good,raw=pcall(fs.read,f,maxBytes+1);local closed,closeResult=pcall(fs.close,f)
  if not good or not closed or closeResult==false or type(raw)~='string' then return nil,'READ ERROR',true end
  if #raw>maxBytes then return nil,'OVERSIZE FILE',true end
  return raw,nil,true
 end
 local function write(file,raw)
  local ok,f=pcall(fs.open,file,'w');if not ok or not f then return false,'OPEN WRITE FAILED' end
  local good,result=pcall(fs.write,f,raw);local closed,closeResult=pcall(fs.close,f)
  if not good or result==false or not closed or closeResult==false then return false,'WRITE ERROR' end
  local actual=read(file)
  if actual~=raw then return false,'READBACK MISMATCH' end
  return true
 end
 local function remove(file)
  -- Simulator FatFS uses6 even for absent files;6 is never delete success.
  if type(statFile)=='function'then
   local ok,info=pcall(statFile,file)
   if not ok or(info~=nil and type(info)~='table')then return false,'DELETE STAT FAILED'end
   if info==nil then return true end
  end
  local ok,result=pcall(removeFile,file)
  if ok and (result==true or result==0 or result==4 or result==5)then return true end
  return false,'DELETE FAILED'
 end
 local function move(from,to)
  local ok,result=pcall(renameFile,from,to)
  if ok and (result==true or result==0)then return true end
  return false,'RENAME FAILED'
 end
 function c:load(uid,fresh88)
  local file,key=path(uid);if not file then return nil,key end
  if not ioReady()then return nil,'IO UNAVAILABLE' end
  local raw,readError=read(file);local record,parseError
  if raw then record,parseError=decode(key,raw) end
  if record then
   -- Envelope validity for backup rotation is separate from fresh hardware /
   -- dimension matching. A mismatch still returns no usable cached tables.
   verifiedFile,verifiedRaw=file,raw
   -- decode already validated/owns this record. Rechecking its entire table
   -- would duplicate bounded parsing work inside the native widget callback.
   if fresh88 then local ok,err=matchesValidated(record,fresh88);if not ok then return nil,err end end
   return record,nil,{source='PRIMARY'}
  end
  local primaryError=readError or parseError
  local backup,backupError=read(file..'.bak')
  if backup then record,parseError=decode(key,backup) end
  if not record then return nil,parseError or readError or backupError end
  if fresh88 then local ok,err=matchesValidated(record,fresh88);if not ok then return nil,err end end
  return record,nil,{source='BACKUP',recovered=true,primaryError=primaryError}
 end
 function c:save(uid,tables)
  local file,key=path(uid);if not file then return false,key end
  local record,err=validate(key,tables);if not record then return false,err end
  if not ioReady()then return false,'IO UNAVAILABLE' end
  if type(removeFile)~='function' or type(renameFile)~='function'then return false,'ATOMIC FILE API UNAVAILABLE' end
  local raw=encode(record);if #raw>maxBytes then return false,'OVERSIZE TABLES' end
  local old,oldError,exists=read(file)
  if oldError=='OPEN ERROR' or oldError=='READ ERROR' then return false,'PRIMARY READ ERROR' end
  if old==raw then verifiedFile,verifiedRaw=file,raw;return true,'UNCHANGED' end
  local oldValid=old and((verifiedFile==file and verifiedRaw==old)or decode(key,old))
  local ok;ok,err=write(file..'.tmp',raw);if not ok then return false,err end
  if oldValid then
   ok,err=remove(file..'.bak');if not ok then return false,err end
   ok,err=move(file,file..'.bak');if not ok then return false,err end
  elseif exists then
   ok,err=remove(file);if not ok then return false,err end
  end
  ok,err=move(file..'.tmp',file)
  if not ok then return false,err end -- Valid old backup remains recoverable.
  -- Input tables passed validate() before canonical encode(). Exact temporary
  -- and final byte equality verifies every byte of that known-valid record.
  local actual=read(file)
  if actual~=raw then return false,'FINAL VERIFY FAILED' end
  verifiedFile,verifiedRaw=file,raw
  return true,'SAVED'
 end
 function c:remove(uid)
  local file,key=path(uid);if not file then return false,key end
  if type(removeFile)~='function'then return false,'DELETE API UNAVAILABLE' end
  -- Delete backup first. Partial failure must not remove the primary then leave
  -- a recoverable backup that silently resurrects a supposedly removed cache.
  for _,suffix in ipairs({'.bak','.tmp',''})do local ok,err=remove(file..suffix);if not ok then return false,err end end
  return true
 end
 return c
end
return M
