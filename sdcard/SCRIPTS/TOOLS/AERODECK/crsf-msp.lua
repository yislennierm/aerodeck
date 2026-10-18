-- Bounded BF/INAV MSPv2 client over normalized CRSF/S.Port adapters. No serial MSP checksum:
-- EdgeTX owns the outer CRSF CRC. Only explicit applyVtx() can enqueue writes.
-- Wire layouts: official Betaflight 4.5.2 / 2026.6.2 src/main/msp/msp.c
-- (VTX_CONFIG, VTXTABLE_BAND/POWERLEVEL, SET_VTX_CONFIG, EEPROM_WRITE).
-- INAV8.0.0/8.0.1/9.0.0/9.0.1/9.1.0 fc_msp.c verifies8192/151/board layouts. Native TBS VTX
-- uses distinct11/12-byte VTX status and channel-only writes, not BF offsets.
local M={}
local identity={2,1,3}
local startDelay,responseWait,backpressure=100,500,25 -- getTime ticks
local maxPayload,maxPops,maxQueue=256,4,24
local hardware={[1]='RTC6705',[3]='SmartAudio',[4]='Tramp',[5]='MSP'}
local inavHardware={[3]='SmartAudio',[4]='Tramp',[6]='MSP'}
-- INAV8.0.0/8.0.1/9.0.0/9.0.1/9.1.0 io/vtx_string.c. These are firmware mappings,
-- not a claim that MSP88 measures RF frequency or reports a custom table.
local inav58={{5865,5845,5825,5805,5785,5765,5745,5725},{5733,5752,5771,5790,5809,5828,5847,5866},{5705,5685,5665,5645,5885,5905,5925,5945},{5740,5760,5780,5800,5820,5840,5860,5880},{5658,5695,5732,5769,5806,5843,5880,5917}}
local inav13={{1080,1120,1160,1200,1240,1280,1320,1360},{1080,1120,1160,1200,1258,1280,1320,1360}}
local groupRequest={};for i=1,#'vtx_frequency_group'do groupRequest[i]=string.byte('vtx_frequency_group',i)end;groupRequest[#groupRequest+1]=0
local function verifiedInav(s)return(s.fcMajor==8 and s.fcMinor==0 and(s.fcPatch==0 or s.fcPatch==1))or(s.fcMajor==9 and s.fcMinor==0 and(s.fcPatch==0 or s.fcPatch==1))or(s.fcMajor==9 and s.fcMinor==1 and s.fcPatch==0)end
local function byte(v)return type(v)=='number'and v>=0 and v<=255 and v%1==0.0 end
local function integer(v,lo,hi)return type(v)=='number'and v>=lo and v<=hi and v%1==0.0 end
local function u16(d,p)return d[p]+d[p+1]*256 end
local function bit(v,n)return math.floor(v/2^n)%2==1 end
local function text(d,p,n)
 if not integer(n,0,64)or p+n-1>#d then return nil end
 local t={}
 for i=p,p+n-1 do
  local b=d[i];if b~=0 and(b<32 or b>126)then return nil end
  t[#t+1]=string.char(b)
 end
 return (string.gsub(table.concat(t),'[%z ]+$',''))
end
local function sizedText(d,p)
 local n=d[p];if not n then return nil end
 local v=text(d,p+1,n);if not v then return nil end
 return v,p+1+n
end
function M.new(transport,options)
 options=options or{}
 transport=options.adapter or transport
 local family=options.family or'BF'
 local supportedFamily=family=='BF'or family=='INAV'
 local statusCommand=family=='INAV'and 8192 or 150
 local responseWait=transport and transport.responseWait or responseWait
 local vtx={status='OFF',bands={},powers={},tablesReady=false,tablesFresh=false,tableSource='NONE',tablesStatus='NOT AVAILABLE',operation={state='IDLE'}}
 local s={family=family,transport=transport and transport.name or'CRSF',statusCommand=statusCommand,transportStats=transport and transport.stats,satellitesStatus='OFF',status='OFF',ready=false,active=false,requests=0,responses=0,timeouts=0,rejected=0,busy=0,vtx=vtx}
 local c,stage,sequence,pending,rx,sendAt,lastTick,blocked={},1,0,nil,nil,nil,nil,false
 local queue,infoWanted,vtxEnabled,gpsEnabled,lastRole={},false,false,false,nil
 local nextStatus,nextVtx,nextGps,infoRetryAt,statusInterval,vtxInterval=0,0,0,0,300,1000
 local operationId,operation,tableSignature,cache,writeHoldUntil=0,nil,nil,nil,0
 local cacheImported,cacheImportBlocked,tableReadUncertain,quietUntil,deferredDiscovery=false,false,false,0,false
 local invalidateCached
 local function opActive()return operation and(operation.state=='QUEUED'or operation.state=='WRITING'or operation.state=='SAVING'or operation.state=='VERIFYING')end
 local function operationRequestRole(q)return q and(q.role=='opIdentity'or q.role=='opApi'or q.role=='opVersion'or q.role=='cachedBand'or q.role=='cachedPower'or q.role=='opGroup'or q.role=='preflight'or q.role=='opWrite'or q.role=='opSave'or q.role=='verify')end
 local function setOp(state,now,err)
  operation.state=state;operation.changedAt=now;operation.error=err
  if state=='FAILED'or state=='CANCELLED'then
   operation.uncertain=operation.writeSent==true;operation.finishedAt=now
   if operation.uncertain then writeHoldUntil=(now or 0)+responseWait;vtx.reportedAt=nil;vtx.status='READBACK REQUIRED';nextVtx=0 end
   if operation.cachedTables and invalidateCached then invalidateCached(now,err or state)end
  end
 end
 local function clearTables()
  vtx.bands={};vtx.powers={};vtx.tablesReady=false;vtx.tablesFresh=false;vtx.tableSource='NONE';cacheImported=false;deferredDiscovery=false;vtx.tablesStatus='NOT AVAILABLE';vtx.tableError=nil;vtx.frequencyGroup=nil;vtx.frequencyGroupAt=nil;tableSignature=nil
 end
 local function clearSession()
  tableReadUncertain=false;cacheImportBlocked=false;s.uid=nil;s.uidAt=nil;s.board=nil;s.boardAt=nil;s.sensors=nil;s.lastStatus=nil;s.statusData=nil
  s.sensorHealth=nil;s.sensorHealthAt=nil;s.activeSensors=nil;s.infoError=nil;s.satellites=nil;s.satellitesAt=nil;s.satelliteSlots=nil;s.satelliteFormat=nil;s.satellitesError=nil;s.satellitesStatus=gpsEnabled and'NO CURRENT LINK'or'OFF';queue={};infoRetryAt=0;vtx.reported=nil;vtx.reportedAt=nil;clearTables()
 end
 local function cancel(reason,now)
  now=now or lastTick
  if pending and(pending.cmd==137 or pending.cmd==138)then quietUntil=math.max(quietUntil,(now or 0)+responseWait);cache=nil end
  if transport and transport.reset then transport.reset()end
  if opActive()then setOp('CANCELLED',now,reason)end
  local hadSession=s.active or pending~=nil or #queue>0 or vtx.reported~=nil
  pending=nil;rx=nil;sendAt=nil;stage=1;blocked=false
  s.active=false;s.ready=false;s.pendingCommand=nil;s.status=reason
  vtx.status=reason=='OFF'and'OFF'or'NO CURRENT LINK';if hadSession then clearSession()end
 end
 local function add(cmd,data,role,index,at)
  if pending and pending.cmd==cmd and pending.index==index then return true end
  for _,q in ipairs(queue)do if q.cmd==cmd and q.index==index then return true end end
  if #queue>=maxQueue then return false end
  queue[#queue+1]={cmd=cmd,data=data or{},role=role,index=index,at=at or 0,attempts=0,maxAttempts=3}
  return true
 end
 local function removeOptional()
  for i=#queue,1,-1 do if queue[i].role~='info'and queue[i].role~='gps'then table.remove(queue,i)end end
 end
 local function removeTableReads()
  for i=#queue,1,-1 do local role=queue[i].role;if role=='band'or role=='power'then table.remove(queue,i)end end
 end
 invalidateCached=function(now,reason)
  cache=nil;cacheImportBlocked=true;clearTables();removeTableReads()
  vtx.tableError=reason;vtx.tablesStatus='ERROR';vtx.cacheError=reason
  quietUntil=math.max(quietUntil,(now or lastTick or 0)+responseWait)
  if pending and(operationRequestRole(pending)or pending.role=='cacheDrain')then pending=nil;rx=nil;s.pendingCommand=nil end
  if transport and transport.reset then transport.reset()end
 end
 local function inavMap(r)
  if not r or not r.supported or vtx.frequencyGroup==nil then return nil end
  -- Only Tramp switches to the1.3GHz table. SmartAudio/MSP driver setters
  -- use vtx58_Bandchan2Freq regardless of frequencyGroup.
  return r.hardware==4 and vtx.frequencyGroup==2 and inav13 or inav58
 end
 local function inavBands()
  local r=vtx.reported;local map=inavMap(r);if not map then return end
  for i=1,r.bandCount do
   local frequencies={};for j=1,r.channelCount do frequencies[j]=map[i]and map[i][j]or 0 end
   local letter=string.sub(map==inav13 and'AB'or'ABEFR',i,i);if letter==''then letter='?'end
   vtx.bands[i]={index=i,name=letter,letter=letter,factory=true,frequencies=frequencies,source='INAV BUILTIN'}
  end
  local band=map[r.band];r.frequency=band and band[r.channel]or nil
  r.frequencySource='INAV TABLE';r.frequencyReported=false
  if r.minPowerIndex==0 then vtx.powers[0]={index=0,label='OFF',source='INAV MIN INDEX'}end
 end
 local function tableComplete()
  local r=vtx.reported
  if not r or not r.tableAvailable or r.bandCount==0 or r.powerCount==0 or(family=='INAV'and vtx.frequencyGroup==nil)then return false end
  for i=1,r.bandCount do if not vtx.bands[i]then return false end end
  for i=1,r.powerCount do if not vtx.powers[i]then return false end end
  vtx.tablesReady=true;vtx.tablesFresh=not cacheImported;vtx.tableSource=cacheImported and vtx.tableSource or(family=='INAV'and'INAV BUILTIN'or'FC LIVE');vtx.tablesStatus=cacheImported and'READY / CACHE'or'READY';vtx.tableError=nil
  if s.uid and family=='BF'and not cacheImported then cache={uid=s.uid,signature=tableSignature,bands=vtx.bands,powers=vtx.powers}end
  return true
 end
 local function discoverTables()
  if(lastTick or 0)<quietUntil then deferredDiscovery=true;return end
  local r=vtx.reported
  if not vtxEnabled or not s.uid or not r or not r.supported or not r.tableAvailable or vtx.tableError then return end
  if r.bandCount==0 or r.channelCount==0 or r.powerCount==0 then return end
  if tableComplete()then return end
  vtx.tablesStatus='LOADING'
  if family=='INAV'then
   if vtx.frequencyGroup==nil then add(4099,groupRequest,'group')else inavBands()end
  else for i=1,r.bandCount do if not vtx.bands[i]then add(137,{i},'band',i)end end end
  for i=1,r.powerCount do if not vtx.powers[i]then add(138,{i},'power',i)end end
 end
 local function decodeVtx(data)
  if #data==1 and(data[1]==0 or data[1]==255)then return {hardware=data[1],hardwareName='Unavailable',supported=false,ready=false,tableAvailable=false}end
  if family=='INAV'then
   if not verifiedInav(s)then return nil,'UNVERIFIED INAV RELEASE'end
   local expected=s.fcMajor==9 and s.fcMinor==1 and 12 or 11
   if #data~=expected then return nil,'INVALID INAV VTX LENGTH'end
   if data[2]>8 or data[3]>8 or data[4]>8 or data[5]>1 or data[6]>1 or data[7]>2 or data[8]>1 or data[9]>8 or data[10]>8 or data[11]>8 or(expected==12 and data[12]~=(data[1]==6 and 0 or 1))then return nil,'INVALID INAV VTX DATA'end
   local name=inavHardware[data[1]]or(data[1]==5 and'FFPV'or'Unknown')
   return {hardware=data[1],hardwareName=name,supported=inavHardware[data[1]]~=nil,
    band=data[2],channel=data[3],power=data[4],pit=data[5]==1,ready=data[6]==1,
    lowPowerDisarm=data[7],tableAvailable=data[8]==1,bandCount=data[9],channelCount=data[10],powerCount=data[11],
    minPowerIndex=data[1]==6 and 0 or 1,frequencyReported=false,frequencySource='INAV TABLE',directFrequency=false,tableSource='INAV BUILTIN'}
  end
  if #data<15 then return nil,'INVALID VTX LENGTH'end
  if data[2]>8 or data[3]>8 or data[4]>8 or data[5]>1 or data[8]>1 or data[9]>2 or data[12]>1 or data[13]>8 or data[14]>8 or data[15]>8 then return nil,'INVALID VTX DATA'end
  return {hardware=data[1],hardwareName=hardware[data[1]]or'Unknown',supported=hardware[data[1]]~=nil,
   band=data[2],channel=data[3],power=data[4],pit=data[5]==1,frequency=u16(data,6),ready=data[8]==1,
   lowPowerDisarm=data[9],pitFrequency=u16(data,10),tableAvailable=data[12]==1,bandCount=data[13],channelCount=data[14],powerCount=data[15]}
 end
 local function decode(q,data,now)
  local cmd=q.cmd
  if q.role=='cacheDrain'then if data[1]~=q.index then return nil,'OLD TABLE INDEX'end;return true end
  if cmd==2 then
   if #data~=4 then return nil,'INVALID VARIANT'end
   local name=text(data,1,4);if not name then return nil,'INVALID VARIANT'end
   s.variant=name
   if name~=(family=='INAV'and'INAV'or'BTFL')then blocked=true;s.ready=false;return nil,'UNSUPPORTED FC'end
  elseif cmd==1 then
   if #data<3 then return nil,'INVALID API'end
   s.protocol=data[1];s.apiMajor=data[2];s.apiMinor=data[3];s.api=tostring(data[2])..'.'..tostring(data[3])
  elseif cmd==3 then
   if #data<3 then return nil,'INVALID VERSION'end
   s.fcMajor=data[1];s.fcMinor=data[2];s.fcPatch=data[3];s.firmware=tostring(data[1])..'.'..tostring(data[2])..'.'..tostring(data[3])
   if family=='INAV'and s.fcMajor<8 then blocked=true;s.ready=false;return nil,'INAV 8.0+ REQUIRED'end
  elseif cmd==8192 then
   local known=verifiedInav(s)
   if #data<(known and 22 or 13)then return nil,'INVALID INAV STATUS'end
   s.statusData=data;s.lastStatus=now;s.activeSensors=u16(data,5);s.sensors=nil
  elseif cmd==164 then
   -- BF count>16 explicitly selects the NAV-SAT/GNSS wire format. Legacy
   -- NAV-SVINFO/NMEA has a channel number, not a constellation or used bit.
   -- INAV8/9 returns a compatibility stub here, never a satellite inventory.
   local count=data[1]
   if family~='BF'or not count or count>63 or #data~=1+count*4 then return nil,'INVALID SATELLITE DATA'end
   local modern=count>16;local records={}
   local names={[0]='GPS',[1]='SBAS',[2]='Galileo',[3]='BeiDou',[4]='IMES',[5]='QZSS',[6]='GLONASS'}
   for i=1,count do
    local p=2+(i-1)*4;local kind,id,quality,signal=data[p],data[p+1],data[p+2],data[p+3]
    if kind~=255 then
     local record={channelOrGnss=kind,id=id,qualityRaw=quality,quality=modern and quality%8 or quality,signal=signal}
     if modern then record.gnssId=kind;record.constellation=names[kind]or('GNSS '..kind);record.used=bit(quality,3)
     else record.channel=kind end
     records[#records+1]=record
    end
   end
   s.satellites=records;s.satellitesAt=now;s.satelliteSlots=count;s.satelliteFormat=modern and'GNSS'or'CHANNEL';s.satellitesStatus='LIVE';s.satellitesError=nil
  elseif cmd==151 then
   if #data<9 or data[1]>1 then return nil,'INVALID SENSOR HEALTH'end
   s.sensorHealth={overall=data[1],gyro=data[2],acc=data[3],mag=data[4],baro=data[5],gps=data[6],rangefinder=data[7],pitot=data[8],opticalFlow=data[9]};s.sensorHealthAt=now;s.infoError=nil
  elseif cmd==150 then
   if #data<15 then return nil,'INVALID STATUS'end
   local mask=u16(data,5)
   s.statusData=data;s.lastStatus=now
   s.sensors={mask=mask,acc=bit(mask,0),baro=bit(mask,1),mag=bit(mask,2),gps=bit(mask,3),rangefinder=bit(mask,4),gyro=bit(mask,5)}
  elseif cmd==160 then
   if #data~=12 then return nil,'INVALID UID'end
   local t={};for i=1,12,4 do t[#t+1]=string.format('%02X%02X%02X%02X',data[i+3],data[i+2],data[i+1],data[i])end
   local uid=table.concat(t)
   if s.uid and s.uid~=uid then
    clearTables();removeOptional();vtx.reported=nil;vtx.reportedAt=nil;s.board=nil;s.boardAt=nil;s.sensors=nil;s.lastStatus=nil;s.statusData=nil
    s.sensorHealth=nil;s.sensorHealthAt=nil;s.activeSensors=nil;s.satellites=nil;s.satellitesAt=nil;s.satelliteSlots=nil;s.satelliteFormat=nil;s.satellitesError=nil;s.satellitesStatus=gpsEnabled and'WAITING'or'OFF';nextGps=0
    s.variant=nil;s.api=nil;s.apiMajor=nil;s.apiMinor=nil;s.protocol=nil;s.firmware=nil;s.fcMajor=nil;s.fcMinor=nil;s.fcPatch=nil
    stage=1;s.ready=false;nextVtx=0
   end
   s.uid=uid;s.uidAt=now;s.infoError=nil
  elseif cmd==4 then
   if #data<(family=='INAV'and 9 or 11)then return nil,'INVALID BOARD'end
   local identifier=text(data,1,4);local target,p=sizedText(data,9);local name,manufacturer
   if family=='BF'then
    if p then name,p=sizedText(data,p)end
    if p then manufacturer,p=sizedText(data,p)end
   end
   if not identifier or not target or(family=='BF'and(not name or not manufacturer))then return nil,'INVALID BOARD'end
   s.board={identifier=identifier,hardwareRevision=u16(data,5),type=data[7],capabilities=data[8],target=target,name=name,manufacturer=manufacturer};s.boardAt=now;s.infoError=nil
  elseif cmd==88 then
   local reported,err=decodeVtx(data);if not reported then return nil,err end
   local signature=string.format('%s:%s:%s:%s',reported.hardware or 0,reported.bandCount or 0,reported.channelCount or 0,reported.powerCount or 0)
   if signature~=tableSignature then clearTables();removeOptional();tableSignature=signature end
   if family=='BF'and reported.tableAvailable and not cacheImportBlocked and not vtx.tablesReady and cache and cache.uid==s.uid and cache.signature==signature and not vtx.tableError then vtx.bands=cache.bands;vtx.powers=cache.powers;cacheImported=true;vtx.tableSource='RAM CACHE';vtx.tablesFresh=false end
   vtx.reported=reported;vtx.reportedAt=now;vtx.status=reported.supported and'LIVE'or'UNSUPPORTED'
   if family=='INAV'then inavBands()end
   if not reported.tableAvailable then vtx.tablesStatus='NOT AVAILABLE'end
   discoverTables()
  elseif cmd==4099 then
   if family~='INAV'or #data~=1 or data[1]>2 then return nil,'INVALID VTX FREQUENCY GROUP'end
   if vtx.frequencyGroup~=data[1]then vtx.bands={};vtx.tablesReady=false end
   vtx.frequencyGroup=data[1];vtx.frequencyGroupAt=now;inavBands();tableComplete()
  elseif cmd==137 then
   local r=vtx.reported
   if #data<5 or not r or data[1]~=q.index then return nil,'INVALID BAND INDEX'end
   local name,p=sizedText(data,2)
   if not p or p+2>#data then return nil,'INVALID BAND LENGTH'end
   local letter=text(data,p,1);local factory,count=data[p+1],data[p+2];p=p+3
   if not letter or factory>1 or count~=r.channelCount or not integer(count,1,8)or p+count*2-1~=#data then return nil,'INVALID BAND DATA'end
   local frequencies={};for i=1,count do frequencies[i]=u16(data,p);p=p+2 end
   vtx.bands[q.index]={index=q.index,name=name,letter=letter,factory=factory==1,frequencies=frequencies};tableComplete()
  elseif cmd==138 then
   if #data<4 or data[1]~=q.index then return nil,'INVALID POWER INDEX'end
   local label,p=sizedText(data,4)
   if not label or p~=#data+1 then return nil,'INVALID POWER DATA'end
   vtx.powers[q.index]={index=q.index,value=family=='BF'and u16(data,2)or nil,label=label};tableComplete()
  elseif cmd==89 or cmd==250 then
   if #data~=0 then return nil,'INVALID WRITE ACK'end
  else return nil,'UNSUPPORTED COMMAND'end
  return true
 end
 local function operationRequest(now)
  if not opActive()or now<(operation.nextAt or 0)then return nil end
  if operation.phase=='identity'then return {cmd=160,data={},role='opIdentity',attempts=operation.attempts or 0,maxAttempts=2}
  elseif operation.phase=='api'then return {cmd=1,data={},role='opApi',attempts=operation.attempts or 0,maxAttempts=2}
  elseif operation.phase=='version'then return {cmd=3,data={},role='opVersion',attempts=operation.attempts or 0,maxAttempts=2}
  elseif operation.phase=='band'then return {cmd=137,data={operation.requested.band},role='cachedBand',index=operation.requested.band,attempts=operation.attempts or 0,maxAttempts=2}
  elseif operation.phase=='power'then return {cmd=138,data={operation.requested.power},role='cachedPower',index=operation.requested.power,attempts=operation.attempts or 0,maxAttempts=2}
  elseif operation.phase=='group'then return {cmd=4099,data=groupRequest,role='opGroup',attempts=operation.attempts or 0,maxAttempts=2}
  elseif operation.phase=='preflight'then return {cmd=88,data={},role='preflight',attempts=operation.attempts or 0,maxAttempts=2}
  elseif operation.phase=='write'then return {cmd=89,data=operation.payload,role='opWrite',write=true,attempts=operation.attempts or 0,maxAttempts=2}
  elseif operation.phase=='save'then return {cmd=250,data={},role='opSave',write=true,attempts=operation.attempts or 0,maxAttempts=2}
  else return {cmd=88,data={},role='verify',attempts=operation.attempts or 0,maxAttempts=2}end
 end
 local function fail(now,reason,noRetry)
  local q=pending;if transport and transport.reset then transport.reset()end;pending=nil;rx=nil;s.pendingCommand=nil;s.status=reason;s.rejected=s.rejected+1
  if not q then return end
  if operationRequestRole(q)then
   if not opActive()then return end
   if not noRetry and q.attempts<q.maxAttempts and now<operation.deadline then
    operation.attempts=q.attempts;operation.nextAt=now+backpressure;operation.error=reason
   else setOp('FAILED',now,reason)end
   sendAt=now+backpressure
  elseif q.role=='cacheDrain'then
   if opActive()and operation.cachedTables then setOp('FAILED',now,'CACHE DRAIN '..reason)else invalidateCached(now,'CACHE DRAIN '..reason)end
   sendAt=now+backpressure
  elseif q.role=='info'then
   s.infoError=reason;infoRetryAt=now+math.max(300,statusInterval);sendAt=now+backpressure
  elseif q.role=='band'or q.role=='power'or q.role=='group'then
   if q.role~='group'then tableReadUncertain=true end
   if not noRetry and q.attempts<q.maxAttempts then q.at=now+backpressure;queue[#queue+1]=q
   else vtx.tableError=reason;vtx.tablesStatus='ERROR';vtx.tablesReady=false;removeOptional()end
   sendAt=now+backpressure
  elseif q.role=='gps'then
   s.satellitesStatus=reason;s.satellitesError=reason;nextGps=now+300;sendAt=now+backpressure
  elseif q.role=='vtx'then
   vtx.status=reason;vtx.reportedAt=nil;nextVtx=now+math.max(300,vtxInterval);sendAt=now+backpressure
  else sendAt=now+statusInterval end
 end
 local function complete(now)
  local q,data=pending,rx.data
  local ok,err=decode(q,data,now)
  if not ok then fail(now,err,true);return end
  s.responses=s.responses+1;s.lastReply=now;pending=nil;rx=nil;s.pendingCommand=nil;sendAt=now+backpressure
  if q.role=='identity'then stage=stage+1;s.ready=stage==4 end
  if q.role=='status'then nextStatus=math.max(now+backpressure,q.sentAt+statusInterval)end
  if q.role=='gps'then nextGps=math.max(now+backpressure,q.sentAt+300)end
  if q.role=='vtx'then nextVtx=vtxInterval>0 and math.max(now+backpressure,q.sentAt+vtxInterval)or math.huge end
  if q.role=='opIdentity'then
   if s.uid~=operation.requested.uid then setOp('FAILED',now,'FC IDENTITY CHANGED')
   else operation.phase=operation.cachedTables and'api'or(family=='INAV'and'group'or'preflight');operation.attempts=0;operation.nextAt=sendAt end
  elseif q.role=='opApi'then
   local w=operation.observed
   if s.protocol~=w.protocol or s.apiMajor~=w.apiMajor or s.apiMinor~=w.apiMinor then setOp('FAILED',now,'FC API CHANGED');stage=1;s.ready=false
   else operation.phase='version';operation.attempts=0;operation.nextAt=sendAt end
  elseif q.role=='opVersion'then
   local w=operation.observed
   if s.fcMajor~=w.fcMajor or s.fcMinor~=w.fcMinor or s.fcPatch~=w.fcPatch then setOp('FAILED',now,'FC VERSION CHANGED');stage=1;s.ready=false
   else operation.phase='preflight';operation.attempts=0;operation.nextAt=sendAt end
  elseif q.role=='opGroup'then
   if vtx.frequencyGroup~=operation.observed.frequencyGroup then setOp('FAILED',now,'VTX FREQUENCY GROUP CHANGED')
   else operation.phase='preflight';operation.attempts=0;operation.nextAt=sendAt end
  elseif q.role=='preflight'then
   local r,w=vtx.reported,operation.observed
   if not r or not r.ready or not r.supported or r.hardware~=w.hardware or r.frequency~=w.frequency or r.band~=w.band or r.channel~=w.channel or r.power~=w.power or r.pit~=w.pit or r.lowPowerDisarm~=w.lowPowerDisarm then setOp('FAILED',now,'VTX STATE CHANGED')
   elseif r.tableAvailable and not vtx.tablesReady then setOp('FAILED',now,'VTX TABLE CHANGED')
   else operation.phase=operation.cachedTables and(operation.requested.exactChannel and'band'or'power')or'write';operation.attempts=0;operation.nextAt=sendAt;operation.preflightAt=now end
  elseif q.role=='cachedBand'then
   local actual,w=vtx.bands[q.index],operation.expectedBand
   if not actual or actual.index~=w.index or actual.name~=w.name or actual.letter~=w.letter or actual.factory~=w.factory or #actual.frequencies~=w.channelCount or actual.frequencies[operation.requested.channel]~=operation.requested.frequency then setOp('FAILED',now,'CACHED CHANNEL CHANGED')
   else operation.phase='power';operation.attempts=0;operation.nextAt=sendAt;operation.bandVerifiedAt=now end
  elseif q.role=='cachedPower'then
   local actual,w=vtx.powers[q.index],operation.expectedPower
   if not actual or actual.index~=w.index or actual.value~=w.value or actual.label~=w.label then setOp('FAILED',now,'CACHED POWER CHANGED')
   else operation.phase='write';operation.attempts=0;operation.nextAt=sendAt;operation.powerVerifiedAt=now end
  elseif q.role=='opWrite'then operation.phase='save';operation.attempts=0;operation.nextAt=sendAt;operation.acknowledged=true;setOp('SAVING',now)
  elseif q.role=='opSave'then operation.phase='verify';operation.attempts=0;operation.nextAt=sendAt;operation.saved=true;operation.verifyDeadline=math.min(operation.deadline,now+800);setOp('VERIFYING',now)
  elseif q.role=='verify'then
   local r,w=vtx.reported,operation.requested
   local matches=r and r.supported and r.ready and r.frequency==w.frequency and r.power==w.power and r.pit==w.pit and r.lowPowerDisarm==w.lowPowerDisarm
   if w.exactChannel then matches=matches and r.band==w.band and r.channel==w.channel end
   if matches then operation.verifiedAt=now;operation.finishedAt=now;operation.uncertain=false;setOp('APPLIED',now)
   elseif now>=operation.verifyDeadline then setOp('FAILED',now,'READBACK MISMATCH')
   else operation.nextAt=now+100;operation.attempts=0;operation.error='READBACK MISMATCH';operation.readbackMismatch=true end
  end
  s.status=s.ready and'READY'or'IDENTIFYING'
 end
 local function receive(now,kind,data)
  if transport.sending and transport.sending()then return end
  if kind~=0x7B then if transport.onFrame then transport.onFrame(kind,data)end;return end
  if not pending or type(data)~='table'or #data<3 or #data>60 then return end
  if data[1]~=0xEA or data[2]~=0xC8 then return end
  for i=1,#data do if not byte(data[i])then fail(now,'INVALID BYTE',true);return end end
  local stat=data[3];if math.floor(stat/32)%4~=2 then fail(now,'MSP VERSION',true);return end
  local seq,first,ptr=stat%16,bit(stat,4),4
  if first then
   if #data<8 then fail(now,'SHORT HEADER',true);return end
   local cmd=u16(data,5);if cmd~=pending.cmd then return end
   if data[4]~=0 then fail(now,'MSP FLAGS',true);return end
   if stat>=128 then fail(now,'FC REJECTED',true);return end
   if rx then fail(now,'MSP RESTART',true);return end
   local len=u16(data,7);if len>maxPayload then fail(now,'OVERSIZE REPLY',true);return end
   rx={data={},len=len,nextSeq=seq};ptr=9
  elseif not rx then return end
  if stat>=128 then fail(now,'FC REJECTED',true);return end
  if seq~=rx.nextSeq then fail(now,'MSP SEQUENCE',true);return end
  if not first and #data<4 then fail(now,'EMPTY CHUNK',true);return end
  while ptr<=#data and #rx.data<rx.len do rx.data[#rx.data+1]=data[ptr];ptr=ptr+1 end
  if #rx.data==rx.len then complete(now)else rx.nextSeq=(seq+1)%16 end
 end
 local function scheduleInfo(now)
  if not infoWanted or not s.ready or now<infoRetryAt then return end
  if not s.uid then add(160,{},'info')end
  if not s.board then add(4,{},'info')end
  if family=='INAV'and not s.sensorHealth then add(151,{},'info')end
 end
 local function choose(now)
  if deferredDiscovery and now>=quietUntil then deferredDiscovery=false;discoverTables()end
  if stage<4 then return {cmd=identity[stage],data={},role='identity',attempts=0,maxAttempts=1}end
  local dueStatus=statusInterval>0 and now>=nextStatus
  local otherWork=opActive()or #queue>0 or(infoWanted and(not s.board or not s.uid or(family=='INAV'and not s.sensorHealth))and now>=infoRetryAt)or(vtxEnabled and now>=nextVtx)or(gpsEnabled and now>=nextGps)
  -- A slow status response must not starve optional reads/transactions forever.
  -- Alternate an overdue status with one optional command; default cadence stays.
  if dueStatus and(lastRole~='status'or not otherWork)then return {cmd=statusCommand,data={},role='status',attempts=0,maxAttempts=1}end
  local q=operationRequest(now);if q then return q end
  scheduleInfo(now)
  if gpsEnabled and now>=nextGps then add(164,{},'gps')end
  if vtxEnabled and now>=nextVtx then add(88,{},'vtx')end
  for i,item in ipairs(queue)do if now>=item.at then return table.remove(queue,i)end end
  if dueStatus then return {cmd=statusCommand,data={},role='status',attempts=0,maxAttempts=1}end
 end
 function c:tick(now,enabled,linkCurrent,disarmed)
  if not enabled then cancel('OFF',now);return s end
  if not supportedFamily then cancel('UNSUPPORTED FAMILY',now);return s end
  if not transport or type(transport.push)~='function'or type(transport.pop)~='function'then cancel('UNAVAILABLE',now);return s end
  if linkCurrent~=true then cancel('NO CURRENT LINK',now);return s end
  if disarmed~=true then cancel('ARMED / UNKNOWN',now);return s end
  if lastTick and now<lastTick then cancel('CLOCK RESET',now);writeHoldUntil=now+responseWait end
  lastTick=now
  if not s.active then s.active=true;s.status='STARTING';sendAt=now+startDelay;nextStatus=now;nextVtx=now;nextGps=now end
  if blocked then return s end
  if opActive()and now>=operation.deadline then
   if operationRequestRole(pending)then pending=nil;rx=nil;s.pendingCommand=nil end
   if transport.reset then transport.reset()end
   setOp('FAILED',now,'TRANSACTION TIMEOUT')
  end
  if opActive()and operation.phase=='verify'and now>=operation.verifyDeadline then
   if operationRequestRole(pending)then pending=nil;rx=nil;s.pendingCommand=nil end
   if transport.reset then transport.reset()end
   setOp('FAILED',now,operation.readbackMismatch and'READBACK MISMATCH'or'READBACK TIMEOUT')
  end
  if pending and now>=pending.deadline then s.timeouts=s.timeouts+1;fail(now,'RESPONSE TIMEOUT')end
  if now<quietUntil then
   -- Responses to an aborted selected-entry read carry no transaction id.
   -- Drain a full response window before allowing any new MSP request/reply.
   for _=1,maxPops do local kind,data=transport.pop();if kind==nil then break end;if kind~=0x7B and transport.onFrame then transport.onFrame(kind,data)end end
   s.status='CACHE INVALID / SETTLING';return s
  end
  if transport.tick then transport.tick(now)end
  for _=1,maxPops do local kind,data=transport.pop();if kind==nil then break end;receive(now,kind,data)end
  if blocked then return s end
  if not pending and now>=sendAt then
   local q=choose(now)
   if q then
    local packet={0xC8,0xEA,0x50+sequence,0,q.cmd%256,math.floor(q.cmd/256),#q.data,0}
    for _,b in ipairs(q.data)do packet[#packet+1]=b end
    if transport.push(q.write and 0x7C or 0x7A,packet)==true then
     sequence=(sequence+1)%16;q.sentAt=now;q.deadline=now+responseWait;q.attempts=q.attempts+1;pending=q;rx=nil
     s.requests=s.requests+1;s.pendingCommand=q.cmd;s.status='WAITING '..q.cmd;lastRole=q.role
     if q.role=='status'then nextStatus=now+statusInterval end
     if q.role=='opWrite'then operation.writeSent=true;operation.attempts=q.attempts;setOp('WRITING',now)
     elseif operationRequestRole(q)then operation.attempts=q.attempts end
    else
     s.busy=s.busy+1;s.status='TX BUSY';sendAt=now+backpressure
     if q.role=='info'or q.role=='band'or q.role=='power'or q.role=='gps'then q.at=sendAt;table.insert(queue,1,q)end
    end
   end
  end
  return s
 end
 function c:requestInfo(force)
  infoWanted=true;local now=lastTick or 0;scheduleInfo(now)
  if s.ready and now>=infoRetryAt then
   if force then
    add(160,{},'info')
    add(4,{},'info')
   end
   if family=='INAV'and(force or(s.sensorHealthAt and now-s.sensorHealthAt>=math.max(300,statusInterval)))then add(151,{},'info')end
  end
  return true
 end
 function c:useCachedTables(record)
  if family~='BF'then return false,'CACHE UNSUPPORTED FOR INAV'end
  if opActive()then return false,'TRANSACTION ACTIVE'end
  if not s.active or not s.ready or not vtxEnabled or blocked then return false,'NO CURRENT VTX SESSION'end
  local now,r=lastTick,vtx.reported
  if cacheImportBlocked or now<quietUntil or tableReadUncertain then return false,'TABLE READ UNCERTAIN / REFRESH REQUIRED'end
  if s.apiMajor~=1 or not integer(s.apiMinor,44,48)then return false,'UNVERIFIED FC API'end
  if not s.uidAt or now<s.uidAt or now-s.uidAt>800 or not vtx.reportedAt or now<vtx.reportedAt or now-vtx.reportedAt>800 then return false,'CACHE IDENTITY / STATUS OLD'end
  if not r or not r.supported or not r.ready or not r.tableAvailable then return false,'VTX NOT READY'end
  if type(record)~='table'or type(record.uid)~='string'or #record.uid~=24 or string.find(record.uid,'[^%x]')or string.upper(record.uid)~=s.uid or s.uid==string.rep('0',24)then return false,'CACHE UID MISMATCH'end
  local signature=string.format('%s:%s:%s:%s',r.hardware,r.bandCount,r.channelCount,r.powerCount)
  if record.signature~=signature or record.hardware~=r.hardware or record.bandCount~=r.bandCount or record.channelCount~=r.channelCount or record.powerCount~=r.powerCount then return false,'CACHE METADATA MISMATCH'end
  if not integer(r.bandCount,1,8)or not integer(r.channelCount,1,8)or not integer(r.powerCount,1,8)then return false,'CACHE INVALID DIMENSIONS'end
  local function array(t,n)
   if type(t)~='table'then return false end;local count=0
   for k in pairs(t)do if not integer(k,1,n)then return false end;count=count+1 end
   return count==n
  end
  local function clean(t,n)return type(t)=='string'and #t<=n and not string.find(t,'[^ -~]')end
  if not array(record.bands,r.bandCount)or not array(record.powers,r.powerCount)then return false,'CACHE TABLE COUNT MISMATCH'end
  local bands,powers={},{}
  for i=1,r.bandCount do
   local b=record.bands[i]
   if type(b)~='table'or b.index~=i or not clean(b.name,64)or not clean(b.letter,1)or type(b.factory)~='boolean'or not array(b.frequencies,r.channelCount)then return false,'CACHE INVALID BAND'end
   local frequencies={};for j=1,r.channelCount do local f=b.frequencies[j];if not integer(f,0,65535)then return false,'CACHE INVALID FREQUENCY'end;frequencies[j]=f end
   bands[i]={index=i,name=b.name,letter=b.letter,factory=b.factory,frequencies=frequencies}
  end
  for i=1,r.powerCount do
   local power=record.powers[i]
   if type(power)~='table'or power.index~=i or not integer(power.value,0,65535)or not clean(power.label,64)then return false,'CACHE INVALID POWER'end
   powers[i]={index=i,value=power.value,label=power.label}
  end
  if pending and(pending.role=='band'or pending.role=='power')then
   if pending.attempts>1 then return false,'TABLE READ ALREADY RETRIED'end
   -- Preserve and consume this already-sent command. It cannot authorize a
   -- later selected-entry verification, even if command/index are identical.
   pending.role='cacheDrain'
  end
  removeTableReads();vtx.bands=bands;vtx.powers=powers;cacheImported=true;vtx.tableSource='SD CACHE';vtx.cacheError=nil;tableComplete()
  return true
 end
 function c:setGpsEnabled(enabled)
  enabled=enabled==true
  if enabled and family~='BF'then s.satellitesStatus='COMPATIBILITY STUB';return false,'GPS SATELLITES UNSUPPORTED BY INAV'end
  if enabled==gpsEnabled then if not enabled and s.satellitesStatus=='COMPATIBILITY STUB'then s.satellitesStatus='OFF'end;return true end
  gpsEnabled=enabled
  if enabled then nextGps=0;s.satellitesStatus='WAITING'
  else
   for i=#queue,1,-1 do if queue[i].role=='gps'then table.remove(queue,i)end end
   if pending and pending.role=='gps'then if transport.reset then transport.reset()end;pending=nil;rx=nil;s.pendingCommand=nil end
   s.satellitesStatus=s.satellitesAt and'PAUSED'or'OFF'
  end
  return true
 end
 function c:setVtxEnabled(enabled)
  enabled=enabled==true
  if enabled==vtxEnabled then return end
  vtxEnabled=enabled
  if enabled then infoWanted=true;nextVtx=0;if not vtx.reported then vtx.status='WAITING'end;discoverTables()
  else removeOptional();vtx.status=vtx.reported and'PAUSED'or'OFF'end
 end
 function c:refreshVtx()
  if opActive()then return false,'TRANSACTION ACTIVE'end
  if not vtxEnabled then return false,'VTX DISABLED'end
  cache=nil;cacheImportBlocked=false;tableReadUncertain=false;clearTables();removeOptional();nextVtx=0;infoWanted=true
  if pending and(pending.role=='band'or pending.role=='power'or pending.role=='group'or pending.role=='vtx')then if pending.cmd==137 or pending.cmd==138 then quietUntil=math.max(quietUntil,(lastTick or 0)+responseWait)end;if transport and transport.reset then transport.reset()end;pending=nil;rx=nil;s.pendingCommand=nil end
  if not vtxEnabled then return false,'VTX DISABLED'end
  vtx.status='WAITING';return true
 end
 function c:setIntervals(statusSeconds,vtxSeconds)
  if not integer(statusSeconds,0,30)or not integer(vtxSeconds,0,60)then return false,'INVALID INTERVAL'end
  statusInterval=statusSeconds*100;vtxInterval=vtxSeconds*100
  nextStatus=math.min(nextStatus,(lastTick or 0)+statusInterval);nextVtx=math.min(nextVtx,(lastTick or 0)+vtxInterval)
  return true
 end
 function c:applyVtx(wanted)
  if opActive()then return false,'TRANSACTION ACTIVE'end
  if not vtxEnabled then return false,'VTX DISABLED'end
  if not s.active or not s.ready or blocked or lastTick<quietUntil then return false,'NO CURRENT FC'end
  if not s.uid then return false,'WAIT FOR FC IDENTITY'end
  if lastTick<writeHoldUntil then return false,'WAIT FOR LINK TO SETTLE'end
  if family=='BF'and(s.apiMajor~=1 or not integer(s.apiMinor,44,48))then return false,'UNVERIFIED FC API'end
  if family=='INAV'and not verifiedInav(s)then return false,'UNVERIFIED INAV RELEASE'end
  local r,now=vtx.reported,lastTick
  if not r or not vtx.reportedAt or now-vtx.reportedAt>800 then return false,'VTX STATUS OLD'end
  if not r.supported or not r.ready then return false,'VTX NOT READY'end
  if r.tableAvailable and not vtx.tablesReady then return false,'TABLES NOT READY'end
  if type(wanted)~='table'then return false,'INVALID REQUEST'end
  for k in pairs(wanted)do if k~='frequency'and k~='band'and k~='channel'and k~='power'and k~='pit'and k~='lowPowerDisarm'then return false,'UNSUPPORTED FIELD'end end
  local frequency=wanted.frequency
  local band,channel=wanted.band,wanted.channel
  if family=='INAV'and frequency~=nil and band==nil and channel==nil then
   -- INAV89 ignores a raw MHz value. Convert an exactly known firmware-table
   -- frequency into an encoded channel instead, preserving current duplicates.
   if frequency==r.frequency then band=r.band;channel=r.channel
   else
    for i=r.bandCount,1,-1 do local b=vtx.bands[i];if b then for j=1,r.channelCount do if b.frequencies[j]==frequency then band=i;channel=j;break end end end;if band then break end end
   end
   if not band then return false,'INAV CHANNEL REQUIRED'end
  end
  local exact=band~=nil or channel~=nil
  if exact then
   if not integer(band,1,8)or not integer(channel,1,8)then return false,'INVALID CHANNEL'end
   local b=vtx.bands[band];local f=b and b.frequencies[channel]
   if not f or f==0 then return false,'CHANNEL NOT AVAILABLE'end
   if frequency~=nil and frequency~=f then return false,'CHANNEL FREQUENCY MISMATCH'end
   frequency=f
  elseif frequency==nil then frequency=r.frequency;band=r.band;channel=r.channel end
  if not integer(frequency,family=='INAV'and 1000 or 5000,5999)then return false,'INVALID FREQUENCY'end
  local power=wanted.power;if power==nil then power=r.power
  elseif not integer(power,r.minPowerIndex or 1,8)or not vtx.powers[power]then return false,'POWER NOT AVAILABLE'end
  if not integer(power,r.minPowerIndex or 1,8)then return false,'UNKNOWN CURRENT POWER'end
  local pit=wanted.pit;if pit==nil then pit=r.pit elseif type(pit)~='boolean'then return false,'INVALID PIT'end
  if type(pit)~='boolean'then return false,'UNKNOWN CURRENT PIT'end
  local lowPowerDisarm=wanted.lowPowerDisarm;if lowPowerDisarm==nil then lowPowerDisarm=r.lowPowerDisarm elseif not integer(lowPowerDisarm,0,2)then return false,'INVALID LOW POWER DISARM'end
  if pit~=r.pit and r.hardware==1 then return false,'PIT UNSUPPORTED'end
  if frequency==r.frequency and power==r.power and pit==r.pit and lowPowerDisarm==r.lowPowerDisarm and(not exact or(band==r.band and channel==r.channel))then return false,'NO CHANGES'end
  if family=='INAV'then exact=true end
  local value=exact and((band-1)*8+(channel-1))or frequency
  operationId=operationId+1
  operation={id=operationId,state='QUEUED',phase='identity',startedAt=now,deadline=now+3000,nextAt=now,attempts=0,
   observed={hardware=r.hardware,frequency=r.frequency,band=r.band,channel=r.channel,power=r.power,pit=r.pit,lowPowerDisarm=r.lowPowerDisarm,frequencyGroup=vtx.frequencyGroup,protocol=s.protocol,apiMajor=s.apiMajor,apiMinor=s.apiMinor,fcMajor=s.fcMajor,fcMinor=s.fcMinor,fcPatch=s.fcPatch},
   requested={uid=s.uid,frequency=frequency,band=band,channel=channel,power=power,pit=pit,lowPowerDisarm=lowPowerDisarm,exactChannel=exact},
   payload={value%256,math.floor(value/256),power,pit and 1 or 0},uncertain=false,cachedTables=cacheImported}
  if cacheImported then
   local p=vtx.powers[power];operation.expectedPower={index=p.index,value=p.value,label=p.label}
   if exact then local b=vtx.bands[band];operation.expectedBand={index=b.index,name=b.name,letter=b.letter,factory=b.factory,channelCount=#b.frequencies}end
  end
  if family=='INAV'or wanted.lowPowerDisarm~=nil then operation.payload[5]=lowPowerDisarm end
  vtx.operation=operation;removeOptional();return true
 end
 function c:cancelVtx()
  if not opActive()then return false,'NO TRANSACTION'end
  if operationRequestRole(pending)then if transport and transport.reset then transport.reset()end;pending=nil;rx=nil;s.pendingCommand=nil end
  setOp('CANCELLED',lastTick,'CANCELLED BY USER');return true
 end
 function c:snapshot()return s end
 function c:stop()cancel('OFF')end
 return c
end
return M
