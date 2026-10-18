-- Bounded, read-only Betaflight MSPv2 status client for EdgeTX CRSF.
-- Empty read requests only: FC_VARIANT(2), API_VERSION(1), FC_VERSION(3), STATUS_EX(150).
-- CRSF carries the MSP body without its serial checksum. EdgeTX validates/adds
-- the outer CRSF CRC8/DVB-S2; do not append an inner MSP CRC here.
local M={}
local commands={2,1,3,150}
local interval,startDelay,responseWait,backpressure=300,100,500,25 -- getTime ticks
local maxPayload,maxPops=256,4
local function byte(v)return type(v)=='number' and v>=0 and v<=255 and v%1==0 end
function M.new(transport)
 local s={status='OFF',ready=false,active=false,requests=0,responses=0,timeouts=0,rejected=0,busy=0}
 local c,stage,sequence,pending,rx,sendAt,lastTick,blocked={},1,0,nil,nil,nil,nil,false
 local function cancel(reason)
  pending=nil;rx=nil;sendAt=nil;stage=1;blocked=false
  s.active=false;s.ready=false;s.pendingCommand=nil;s.status=reason
 end
 local function fail(now,reason)
  pending=nil;rx=nil;s.pendingCommand=nil;s.status=reason;s.rejected=s.rejected+1
  sendAt=now+interval
 end
 local function complete(now)
  local cmd,data=pending.cmd,rx.data
  if cmd==2 then
   if #data~=4 then fail(now,'INVALID VARIANT');return end
   s.variant=string.char(data[1],data[2],data[3],data[4])
   if s.variant~='BTFL' then
    pending=nil;rx=nil;s.pendingCommand=nil;s.ready=false;s.status='UNSUPPORTED FC';blocked=true
    return
   end
  elseif cmd==1 then
   if #data<3 then fail(now,'INVALID API');return end
   s.protocol=data[1];s.apiMajor=data[2];s.apiMinor=data[3]
   s.api=tostring(data[2])..'.'..tostring(data[3])
  elseif cmd==3 then
   if #data<3 then fail(now,'INVALID VERSION');return end
   s.fcMajor=data[1];s.fcMinor=data[2];s.fcPatch=data[3]
   s.firmware=tostring(data[1])..'.'..tostring(data[2])..'.'..tostring(data[3])
  elseif cmd==150 then
   -- Stable STATUS_EX prefix is 15 bytes. Keep later/version-specific flags raw.
   if #data<15 then fail(now,'INVALID STATUS');return end
   s.statusData=data;s.lastStatus=now
  end
  local sentAt=pending.sentAt
  s.responses=s.responses+1;s.lastReply=now;pending=nil;rx=nil;s.pendingCommand=nil
  if stage<4 then stage=stage+1;sendAt=now+backpressure else sendAt=math.max(now+backpressure,sentAt+interval)end
  s.ready=stage==4;s.status=s.ready and 'READY' or 'IDENTIFYING'
 end
 local function receive(now,kind,data)
  if kind~=0x7B or not pending or type(data)~='table' or #data<3 or #data>60 then return end
  if data[1]~=0xEA or data[2]~=0xC8 then return end
  for i=1,#data do if not byte(data[i])then fail(now,'INVALID BYTE');return end end
  local stat=data[3]
  if math.floor(stat/32)%4~=2 then fail(now,'MSP VERSION');return end
  local seq=stat%16
  local first=math.floor(stat/16)%2==1
  local ptr=4
  if first then
   if #data<8 then fail(now,'SHORT HEADER');return end
   local cmd=data[5]+data[6]*256
   if cmd~=pending.cmd then return end -- Ignore another/late command's reply.
   if data[4]~=0 then fail(now,'MSP FLAGS');return end
   local len=data[7]+data[8]*256
   if len>maxPayload then fail(now,'OVERSIZE REPLY');return end
   rx={data={},len=len,nextSeq=seq};ptr=9
  elseif not rx then return end
  if stat>=128 then fail(now,'FC REJECTED');return end
  if seq~=rx.nextSeq then fail(now,'MSP SEQUENCE');return end
  if not first and #data<4 then fail(now,'EMPTY CHUNK');return end
  while ptr<=#data and #rx.data<rx.len do rx.data[#rx.data+1]=data[ptr];ptr=ptr+1 end
  if #rx.data==rx.len then complete(now)else rx.nextSeq=(seq+1)%16 end
 end
 function c:tick(now,enabled,linkCurrent,disarmed)
  if not enabled then cancel('OFF');return s end
  if not transport or type(transport.push)~='function' or type(transport.pop)~='function' then cancel('UNAVAILABLE');return s end
  if linkCurrent~=true then cancel('NO CURRENT LINK');return s end
  if disarmed~=true then cancel('ARMED / UNKNOWN');return s end
  if lastTick and now<lastTick then cancel('CLOCK RESET')end
  lastTick=now
  if not s.active then s.active=true;s.status='STARTING';sendAt=now+startDelay end
  if blocked then return s end
  -- A strict per-callback budget avoids a Lua-queue drain monopolizing the UI.
  for _=1,maxPops do
   local kind,data=transport.pop()
   if kind==nil then break end
   receive(now,kind,data)
  end
  if blocked then return s end
  if pending and now-pending.sentAt>=responseWait then
   s.timeouts=s.timeouts+1;pending=nil;rx=nil;s.pendingCommand=nil;s.status='RESPONSE TIMEOUT';sendAt=now+interval
  end
  if not pending and now>=sendAt then
   local cmd=commands[stage]
   -- C8 destination, EA origin, START|MSPv2|sequence, flags, command LE, zero length.
   local packet={0xC8,0xEA,0x50+sequence,0,cmd%256,math.floor(cmd/256),0,0}
   if transport.push(0x7A,packet)==true then
    sequence=(sequence+1)%16;pending={cmd=cmd,sentAt=now};rx=nil
    s.requests=s.requests+1;s.pendingCommand=cmd;s.status='WAITING '..cmd
   else s.busy=s.busy+1;s.status='TX BUSY';sendAt=now+backpressure end
  end
  return s
 end
 function c:snapshot()return s end
 function c:stop()cancel('OFF')end
 return c
end
return M
