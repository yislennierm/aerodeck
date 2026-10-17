-- Integration-level protocol fixtures; Lua 5.1/LuaJIT and EdgeTX-compatible Lua.
local here=arg[0]:match('^(.*[/\\])') or './'
local factory=dofile(here..'../sdcard/SCRIPTS/TOOLS/AERODECK/crsf-msp.lua')
local function equal(a,b,why)
 assert(#a==#b,(why or '')..' length '..#a..' ~= '..#b)
 for i=1,#a do assert(a[i]==b[i],(why or '')..' byte '..i)end
end
local function xor(a,b)
 local r,p=0,1
 for _=1,8 do if a%2~=b%2 then r=r+p end;a=math.floor(a/2);b=math.floor(b/2);p=p*2 end
 return r
end
local function crc8(data,first,last)
 local c=0
 for i=first or 1,last or #data do
  c=xor(c,data[i])
  for _=1,8 do local high=c>=128;c=(c*2)%256;if high then c=xor(c,0xD5)end end
 end
 return c
end
-- Full CRSF frames include an outer checksum. EdgeTX strips this boundary;
-- production must neither append nor require an additional serial MSP CRC.
local requestWire={0xEE,0x0A,0x7A,0xC8,0xEA,0x50,0,2,0,0,0,0xE7}
local variantWire={0xEA,0x0E,0x7B,0xEA,0xC8,0x55,0,2,0,4,0,0x42,0x54,0x46,0x4C,0x58}
assert(crc8({49,50,51,52,53,54,55,56,57})==0xBC,'CRC8/DVB-S2 check vector')
assert(crc8(requestWire,3,#requestWire-1)==requestWire[#requestWire])
assert(crc8(variantWire,3,#variantWire-1)==variantWire[#variantWire])
local corrupted={unpack(variantWire)};corrupted[12]=corrupted[12]+1
assert(crc8(corrupted,3,#corrupted-1)~=corrupted[#corrupted],'wire corruption rejected by CRC boundary')
local variant={0xEA,0xC8,0x55,0,2,0,4,0,0x42,0x54,0x46,0x4C}
local api={0xEA,0xC8,0x56,0,1,0,3,0,0,1,46}
local version={0xEA,0xC8,0x57,0,3,0,3,0,4,5,2}
local statusBytes={125,0,0,0,0x21,0,0,0,0,0,0,35,0,3,0,0,26,0,0,0,0,0,45,0}
local function harness()
 local h={queue={},sent={},attempts=0,pops=0,pushOk=true}
 local io={push=function(kind,data)
  h.attempts=h.attempts+1
  assert(kind==0x7A,'read request frame type only; never MSP_WRITE')
  assert(#data==8 and data[1]==0xC8 and data[2]==0xEA and data[4]==0 and data[7]==0 and data[8]==0,'empty MSPv2 read only')
  local cmd=data[5]+data[6]*256
  assert(cmd==2 or cmd==1 or cmd==3 or cmd==150,'read command allowlist')
  if h.pushOk then h.sent[#h.sent+1]={kind=kind,data=data}end
  return h.pushOk
 end,pop=function()
  h.pops=h.pops+1
  if #h.queue==0 then return nil end
  local f=table.remove(h.queue,1);return f.kind,f.data
 end}
 h.c=factory.new(io)
 function h:tick(t,enabled,link,disarmed)
  if enabled==nil then enabled=true end
  if link==nil then link=true end
  if disarmed==nil then disarmed=true end
  return self.c:tick(t,enabled,link,disarmed)
 end
 function h:reply(data,t,kind)self.queue[#self.queue+1]={kind=kind or 0x7B,data=data};return self:tick(t)end
 return h
end
local function boot()
 local h=harness();h:tick(0);assert(#h.sent==0);h:tick(99);assert(#h.sent==0)
 h:tick(100);equal(h.sent[1].data,{0xC8,0xEA,0x50,0,2,0,0,0},'original Toolbox variant request')
 h:reply(variant,101);assert(h.c:snapshot().variant=='BTFL')
 h:tick(126);equal(h.sent[2].data,{0xC8,0xEA,0x51,0,1,0,0,0},'API request')
 h:reply(api,127);assert(h.c:snapshot().api=='1.46')
 h:tick(152);h:reply(version,153)
 assert(h.c:snapshot().ready and h.c:snapshot().firmware=='4.5.2')
 h:tick(178);equal(h.sent[4].data,{0xC8,0xEA,0x53,0,150,0,0,0},'status request')
 return h
end
local h=boot();local snapshot=h.c:snapshot();assert(snapshot==h.c:snapshot())
-- Response sequence is independent of request sequence, including wrap 15 -> 0.
local first={0xEA,0xC8,0x5F,0,150,0,#statusBytes,0}
for i=1,6 do first[#first+1]=statusBytes[i]end
h:reply(first,200);assert(snapshot.responses==3)
local second={0xEA,0xC8,0x40};for i=7,15 do second[#second+1]=statusBytes[i]end
h:reply(second,210);assert(snapshot.responses==3)
local last={0xEA,0xC8,0x41};for i=16,#statusBytes do last[#last+1]=statusBytes[i]end
last[#last+1]=0xAA -- Allowed CRSF padding after declared body length.
h:reply(last,220);assert(snapshot.responses==4 and snapshot.lastStatus==220)
equal(snapshot.statusData,statusBytes,'complete reassembled status')
h:tick(477);assert(#h.sent==4);h:tick(478);assert(#h.sent==5,'fixed 3s request cadence')
for t=479,977 do h:tick(t)end
assert(#h.sent==5,'one outstanding request, no queued flood')
h:tick(978);assert(snapshot.timeouts==1 and not snapshot.pendingCommand)
h:tick(1277);assert(#h.sent==5);h:tick(1278);assert(#h.sent==6,'bounded timeout retry')

h=boot();local before=h.pops
for _=1,12 do h.queue[#h.queue+1]={kind=0x29,data={1,2,3}}end
h:tick(190);assert(h.pops-before==4 and #h.queue==8,'bounded pop budget')
h=boot();h:reply({0xEC,0xC8,0x50,0,150,0,0,0},190);assert(h.c:snapshot().pendingCommand==150,'wrong destination ignored')
h:reply({0xEA,0xEC,0x50,0,150,0,0,0},191);assert(h.c:snapshot().pendingCommand==150,'wrong origin ignored')
h:reply(api,192);assert(h.c:snapshot().pendingCommand==150,'late different command ignored')
h:reply({0xEA,0xC8,0x40,1},193);assert(h.c:snapshot().pendingCommand==150,'orphan continuation ignored')

local bad={
 {{0xEA,0xC8,0x50},'SHORT HEADER'},
 {{0xEA,0xC8,0x30,0,150,0,0,0},'MSP VERSION'},
 {{0xEA,0xC8,0x50,1,150,0,0,0},'MSP FLAGS'},
 {{0xEA,0xC8,0x50,0,150,0,1,1},'OVERSIZE REPLY'},
 {{0xEA,0xC8,0xD0,0,150,0,0,0},'FC REJECTED'},
 {{0xEA,0xC8,0x50,0,150,0,1,0,512},'INVALID BYTE'},
 {{0xEA,0xC8,0x50,0,150,0,0,0},'INVALID STATUS'}
}
for _,case in ipairs(bad)do
 h=boot();local s=h:reply(case[1],190)
 assert(s.status==case[2] and not s.pendingCommand,case[2]);h:tick(489);assert(#h.sent==4);h:tick(490);assert(#h.sent==5)
end
h=boot();h:reply(first,190);local s=h:reply({0xEA,0xC8,0x41,0},191)
assert(s.status=='MSP SEQUENCE' and not s.pendingCommand,'sequence gap rejected')
h=boot();h:reply(first,190);h:tick(677);assert(h.c:snapshot().pendingCommand==150);h:tick(678)
assert(h.c:snapshot().timeouts==1,'partial chunks cannot extend absolute deadline')

h=harness();h:tick(0);h.pushOk=nil;h:tick(100)
assert(#h.sent==0 and h.c:snapshot().busy==1 and not h.c:snapshot().pendingCommand,'nil push backpressure')
h.pushOk=true;h:tick(124);assert(#h.sent==0);h:tick(125)
equal(h.sent[1].data,{0xC8,0xEA,0x50,0,2,0,0,0},'sequence retained on backpressure')
h=harness();h:tick(0);h:tick(100)
s=h:reply({0xEA,0xC8,0x50,0,2,0,4,0,73,78,65,86},101)
assert(s.variant=='INAV' and s.status=='UNSUPPORTED FC' and #h.sent==1)
for t=102,2000 do h:tick(t)end
assert(#h.sent==1,'unknown firmware never continues or polls')

for _,gate in ipairs({'disabled','offline','armed','unknown'})do
 h=boot();local pops=h.pops;local sent=#h.sent
 if gate=='disabled' then s=h.c:tick(190,false,true,true)
 elseif gate=='offline' then s=h.c:tick(190,true,false,true)
 elseif gate=='armed' then s=h.c:tick(190,true,true,false)
 else s=h.c:tick(190,true,true,nil)end
 assert(h.pops==pops and #h.sent==sent and not s.active and not s.ready and not s.pendingCommand,gate..' gate before I/O')
 assert(s.firmware=='4.5.2','cached identity preserved')
 h:tick(200);h:tick(299);assert(#h.sent==sent);h:tick(300)
 assert(h.sent[#h.sent].data[5]==2,'fresh handshake after interrupted session')
end
h=boot();h.c:stop();assert(h.c:snapshot().status=='OFF' and not h.c:snapshot().pendingCommand)
h=boot();h:tick(2);assert(h.c:snapshot().status=='STARTING');h:tick(101);assert(#h.sent==4)
h:tick(102);assert(#h.sent==5 and h.sent[5].data[5]==2,'clock wrap/restart is bounded')
s=factory.new({}):tick(0,true,true,true);assert(s.status=='UNAVAILABLE')
print('PASS: original read fixtures, outer CRC boundary, handshake/status, chunks/sequence wrap, bounds, retries, backpressure, no writes, all eligibility gates')
