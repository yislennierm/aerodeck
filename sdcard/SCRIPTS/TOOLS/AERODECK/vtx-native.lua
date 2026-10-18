-- Native TBS Crossfire/Tracer VTX adapter. The shared dispatcher owns pop().
-- Original wire evidence: deep-parity-20261017/evidence/LIB-VTX-VTXTBS.txt,
-- main/1 PCs43–190 (reports),194–252 (writes); main/0 (eight manual maps).
-- A successful push is not an acknowledgement. Only later status is observable
-- confirmation. No polling requests, persistence commands or automatic writes.
local M={}
local hardware={
 {'Sixty9',{0,14,20,26,30}}, {'Uni Pro32 HV',{0,14,20,26,30}},
 {'Uni Pro32 Nano',{0,14,20,26}}, {'Uni EVO',{0,14,20,26}},
 {'Uni Pro',{0,14,23,27,29,30}}, {'Uni Pro HV',{0,14,23,27,29}},
 {'Uni Pro HV Race',{0,14,23}}, {'Uni Pro Nano',{0,14,17}}
}
-- Nominal hardware labels from original VTXINIT, not a guessed dBm conversion.
local milliwatts={[0]=0,[14]=25,[17]=50,[20]=100,[23]=200,[26]=400,[27]=500,[29]=800,[30]=1000,[33]=2000}
local presets={
 {'A',{5865,5845,5825,5805,5785,5765,5745,5725}},
 {'B',{5733,5752,5771,5790,5809,5828,5847,5866}},
 {'E',{5705,5685,5665,5645,5885,5905,5925,5945}},
 {'F',{5740,5760,5780,5800,5820,5840,5860,5880}},
 {'R',{5658,5695,5732,5769,5806,5843,5880,5917}},
 {'L',{5333,5373,5413,5453,5493,5533,5573,5613}}
}
local function finite(v)return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function integer(v,lo,hi)return finite(v) and v%1==0.0 and v>=lo and v<=hi end
local function bounded(v,default,lo,hi)return integer(v,lo,hi) and v or default end
function M.hardwareList()
 local names={[0]='Unknown / select hardware'}
 for i,h in ipairs(hardware)do names[i]=h[1]end
 return names
end
function M.new(opts)
 opts=opts or {}
 local freshness=bounded(opts.freshness,800,100,6000)
 local reportTimeout=bounded(opts.reportTimeout,800,100,6000)
 local sendTimeout=bounded(opts.sendTimeout,300,100,6000)
 local spacing=bounded(opts.backpressure,25,10,100)
 local vtx={status='OFF',hardwareId=0,configuredHardware='Unknown',bands={},powers={},tablesReady=false,
  tablesStatus='SELECT HARDWARE',operation={state='IDLE'},tableSource='DEFAULT PRESETS / MANUAL HARDWARE',type='TBS NATIVE'}
 local s={status='OFF',active=false,ready=false,writable=false,requests=0,responses=0,rejected=0,ignored=0,busy=0,timeouts=0,vtx=vtx}
 local c,lastTick,guardDisarmed,operation,operationId,restorePower,source,holdUntil={},nil,false,nil,0,nil,nil,0
 for i,b in ipairs(presets)do
  local band={index=i,name=b[1],letter=b[1],frequencies={},source='DEFAULT PRESET'}
  for j,f in ipairs(b[2])do band.frequencies[j]=f end
  vtx.bands[i]=band
 end
 local function activeOperation()
  return operation and (operation.state=='QUEUED' or operation.state=='WRITING' or operation.state=='VERIFYING')
 end
 local function finish(state,now,err)
  operation.state=state;operation.changedAt=now;operation.finishedAt=now;operation.error=err
  if state=='FAILED' or state=='CANCELLED' then
   operation.uncertain=operation.writeSent==true
   if operation.uncertain then holdUntil=now+reportTimeout;vtx.reportedAt=nil;vtx.status='READBACK REQUIRED';s.ready=false end
  elseif state=='SUCCEEDED' then operation.uncertain=false;operation.confirmation='OBSERVED REPORT' end
 end
 local function decodePower(report)
  report.power=nil;report.powerMw=nil
  for i,p in ipairs(vtx.powers)do
   if p.dbm==report.powerDbm then report.power=i;report.powerMw=p.mw;break end
  end
  if report.powerDbm==0 then report.powerMw=0 end
  if report.power and report.powerDbm>0 and not report.pit and not (activeOperation() and operation.requested.pit) then restorePower=report.power end
 end
 local function configure(id)
  vtx.hardwareId=id;vtx.configuredHardware=hardware[id] and hardware[id][1] or 'Unknown'
  vtx.powers={};restorePower=nil
  if hardware[id] then
   for i,dbm in ipairs(hardware[id][2])do
    vtx.powers[i]={index=i,value=dbm,dbm=dbm,mw=milliwatts[dbm],label=dbm==0 and 'PIT' or tostring(milliwatts[dbm]),pit=dbm==0}
   end
  end
  vtx.tablesReady=hardware[id]~=nil;vtx.tablesStatus=vtx.tablesReady and 'MANUAL HARDWARE / DEFAULT CHANNELS' or 'SELECT HARDWARE'
  if vtx.reported then decodePower(vtx.reported) end
 end
 local function clearStatus()
  source=nil;restorePower=nil;vtx.source=nil;vtx.reported=nil;vtx.reportedAt=nil
  s.ready=false
 end
 local function disable(reason,now)
  if activeOperation()then finish('CANCELLED',now,reason)end
  s.active=false;s.ready=false;s.writable=false;s.status=reason;vtx.status=reason
  clearStatus()
 end
 function c:setHardware(id)
  if not integer(id,0,8)then return false,'INVALID HARDWARE'end
  if activeOperation()then return false,'TRANSACTION ACTIVE'end
  if id~=vtx.hardwareId then configure(id)end
  return true
 end
 function c:tick(now,enabled,current,disarmed)
  if not finite(now)then disable('INVALID CLOCK',lastTick or 0);return s end
  if not enabled then disable('OFF',now);lastTick=now;return s end
  if current~=true then disable('NO CURRENT LINK',now);lastTick=now;return s end
  if lastTick and now<lastTick then disable('CLOCK RESET',now);holdUntil=now+reportTimeout end
  lastTick=now;s.active=true;guardDisarmed=disarmed==true
  s.writable=guardDisarmed and type(opts.push)=='function'
  if not guardDisarmed and activeOperation()then finish('CANCELLED',now,'ARMED / UNKNOWN')end
  local fresh=vtx.reportedAt~=nil and now>=vtx.reportedAt and now-vtx.reportedAt<=freshness
  s.ready=fresh
  vtx.status=fresh and 'LIVE' or vtx.reported and 'STATUS OLD' or 'WAITING'
  s.status=not guardDisarmed and 'ARMED / READ ONLY' or not s.writable and 'READ ONLY / NO TRANSPORT' or vtx.status
  if not activeOperation()then return s end
  if operation.state=='VERIFYING' then
   if now>=operation.verifyDeadline then s.timeouts=s.timeouts+1;finish('FAILED',now,operation.readbackMismatch and 'READBACK MISMATCH' or 'READBACK TIMEOUT')end
   return s
  end
  if now>=operation.sendDeadline then s.timeouts=s.timeouts+1;finish('FAILED',now,'SEND TIMEOUT');return s end
  if now<operation.nextAt then return s end
  local packet=operation.packets[operation.nextPacket]
  local ok,accepted=pcall(opts.push,0x32,packet)
  if not ok then finish('FAILED',now,'PUSH ERROR: '..tostring(accepted));return s end
  operation.attempts=operation.attempts+1
  if accepted~=true then s.busy=s.busy+1;operation.nextAt=now+spacing;return s end
  s.requests=s.requests+1;operation.writeSent=true;operation.lastSentAt=now
  operation.state='WRITING';operation.changedAt=now;operation.nextPacket=operation.nextPacket+1;operation.nextAt=now+spacing
  if operation.nextPacket>#operation.packets then
   operation.state='VERIFYING';operation.verifyDeadline=now+reportTimeout;operation.minimumReport=s.responses+1
  end
  return s
 end
 function c:ingest(kind,data,now)
  if kind~=0x10 then return false,'OTHER FRAME'end
  if not s.active then return false,'INACTIVE'end
  if not finite(now) or not lastTick or now<lastTick then return false,'INVALID CLOCK'end
  if type(data)~='table' or #data~=5 then s.rejected=s.rejected+1;return false,'INVALID LENGTH'end
  for i=1,5 do if not integer(data[i],0,255)then s.rejected=s.rejected+1;return false,'INVALID BYTE'end end
  local src=data[1]
  if src~=0xEC and src~=0xCE then s.ignored=s.ignored+1;return false,'UNSUPPORTED SOURCE'end
  if source==0xEC and src==0xCE then s.ignored=s.ignored+1;return false,'LOWER PRIORITY SOURCE'end
  local frequency=data[3]*256+data[4]
  if not integer(frequency,5300,5950)then s.rejected=s.rejected+1;return false,'INVALID FREQUENCY'end
  -- The dispatcher may deliver before our next tick; an expired operation must
  -- not be revived by a late matching report in that ordering.
  if activeOperation() then
   if operation.state=='VERIFYING' and now>=operation.verifyDeadline then
    s.timeouts=s.timeouts+1;finish('FAILED',now,operation.readbackMismatch and 'READBACK MISMATCH' or 'READBACK TIMEOUT')
   elseif operation.state~='VERIFYING' and now>=operation.sendDeadline then s.timeouts=s.timeouts+1;finish('FAILED',now,'SEND TIMEOUT')end
  end
  if activeOperation() and source and src~=source then finish('CANCELLED',now,'VTX SOURCE CHANGED')end
  source=src;vtx.source=src
  local report={frequency=frequency,powerDbm=data[2],pit=data[5]%2==1,flags=data[5],source=src,sourceName=src==0xEC and 'VTX' or 'RECEIVER',
   ready=true,supported=true,tableAvailable=false,hardwareReported=false}
  decodePower(report)
  vtx.reported=report;vtx.reportedAt=now;vtx.status='LIVE';s.ready=true;s.responses=s.responses+1
  s.status=not guardDisarmed and 'ARMED / READ ONLY' or not s.writable and 'READ ONLY / NO TRANSPORT' or 'LIVE'
  if activeOperation() and operation.state=='VERIFYING' and now>=operation.lastSentAt and s.responses>=operation.minimumReport then
   local requested=operation.requested
   local matches=report.source==operation.observed.source and report.frequency==requested.frequency
   if requested.checkPit then matches=matches and report.pit==requested.pit end
   if requested.checkPower then matches=matches and report.powerDbm==requested.powerDbm end
   if matches then finish('SUCCEEDED',now)
   else operation.readbackMismatch=true end
  end
  return true
 end
 function c:applyVtx(wanted)
  if activeOperation()then return false,'TRANSACTION ACTIVE'end
  if not s.active then return false,'NO CURRENT LINK'end
  if not guardDisarmed then return false,'ARMED / UNKNOWN'end
  if type(opts.push)~='function'then return false,'TRANSPORT UNAVAILABLE'end
  if not lastTick or lastTick<holdUntil then return false,'WAIT FOR LINK TO SETTLE'end
  local r=vtx.reported
  if not r or not vtx.reportedAt or lastTick<vtx.reportedAt or lastTick-vtx.reportedAt>freshness then return false,'VTX STATUS OLD'end
  if type(wanted)~='table'then return false,'INVALID REQUEST'end
  for k in pairs(wanted)do if k~='frequency' and k~='band' and k~='channel' and k~='power' and k~='pit' then return false,'UNSUPPORTED FIELD'end end
  local frequency=wanted.frequency
  if frequency==nil then frequency=r.frequency end
  if wanted.band~=nil or wanted.channel~=nil then
   if not integer(wanted.band,1,6) or not integer(wanted.channel,1,8)then return false,'INVALID CHANNEL'end
   local f=vtx.bands[wanted.band].frequencies[wanted.channel]
   if wanted.frequency~=nil and f~=wanted.frequency then return false,'CHANNEL FREQUENCY MISMATCH'end
   frequency=f
  end
  if not integer(frequency,5300,5950)then return false,'INVALID FREQUENCY'end
  local pit=wanted.pit
  if pit==nil then pit=r.pit elseif type(pit)~='boolean'then return false,'INVALID PIT'end
  local power=wanted.power
  if power~=nil and (not integer(power,1,#vtx.powers) or not vtx.powers[power])then return false,'POWER NOT AVAILABLE'end
  if power==nil then power=r.powerDbm>0 and r.power or restorePower end
  local dbm=power and vtx.powers[power] and vtx.powers[power].dbm or nil
  if wanted.power~=nil and not pit and (not dbm or dbm==0)then return false,'NONZERO POWER REQUIRED'end
  local powerChange=wanted.power~=nil and dbm~=r.powerDbm
  local pitChange=pit~=r.pit
  if pit and powerChange and dbm~=0 and power~=restorePower then return false,'EXIT PIT TO CHANGE POWER'end
  if pit and r.pit and power==restorePower then powerChange=false end
  if not pit and (pitChange or powerChange) and (not dbm or dbm==0)then return false,'SELECT RESTORE POWER'end
  local frequencyChange=frequency~=r.frequency
  if not frequencyChange and not powerChange and not pitChange then return false,'NO CHANGES'end
  local packets={}
  if frequencyChange then packets[#packets+1]={0xCE,0xEA,0x08,0x02,math.floor(frequency/256),frequency%256}end
  local sendPower=pitChange or powerChange
  if sendPower then packets[#packets+1]={0xCE,0xEA,0x08,0x08,pit and 0 or dbm}end
  operationId=operationId+1
  operation={id=operationId,state='QUEUED',startedAt=lastTick,changedAt=lastTick,sendDeadline=lastTick+sendTimeout,nextAt=lastTick,nextPacket=1,attempts=0,
   requested={frequency=frequency,power=power,powerDbm=dbm,pit=pit,checkPit=sendPower,checkPower=sendPower and not pit},
   observed={source=source,frequency=r.frequency,power=r.power,powerDbm=r.powerDbm,pit=r.pit},packets=packets,uncertain=false}
  vtx.operation=operation
  -- Remember a real known non-PIT selection. Turning PIT off always sends it.
  if dbm and dbm>0 then restorePower=power end
  return true
 end
 function c:cancelVtx()
  if not activeOperation()then return false,'NO TRANSACTION'end
  finish('CANCELLED',lastTick or 0,'CANCELLED BY USER');return true
 end
 function c:snapshot()return s end -- Borrowed read-only view, aligned with MSP client.
 function c:stop()disable('OFF',lastTick or 0)end
 configure(integer(opts.hardwareId,0,8) and opts.hardwareId or 0)
 return c
end
return M
