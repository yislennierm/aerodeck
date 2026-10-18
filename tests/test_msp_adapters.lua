-- Real client over normalized CRSF and six-byte S.Port wire fixtures.
-- Synthetic FC only; no hardware or RF-link verification.
local source=debug.getinfo(1,'S').source:sub(2)
local here=source:match('^(.*[/\\])')or'./'
local root=arg[1]or(here..'../')
local modules=root..'/sdcard/SCRIPTS/TOOLS/AERODECK/'
local factory=dofile(modules..'crsf-msp.lua')
local adapters=dofile(modules..'msp-adapters.lua')
local fixture=dofile(root..'/tests/fixtures/msp_fixture.lua')
local checks=0
local verifiedInavReleases={{8,0,0},{8,0,1},{9,0,0},{9,0,1},{9,1,0}}
local unpack=table.unpack or unpack -- Lua5.3 native-number verification and LuaJIT hosts.
local function check(v,s)checks=checks+1;assert(v,s)end
local function eq(a,b,s)check(#a==#b,s..' length');for i=1,#a do check(a[i]==b[i],s..' byte'..i)end end
local function copy(a)local b={};for i=1,#a do b[i]=a[i]end;return b end
local function append(a,b)for _,v in ipairs(b)do a[#a+1]=v end;return a end
local function str(s)local a={#s};for i=1,#s do a[#a+1]=s:byte(i)end;return a end
local function encode6(a)
 local id=a[1]+a[2]*256
 local hi=a[5]+a[6]*256
 return id,a[3]+a[4]*256+(hi>=32768 and hi-65536 or hi)*65536
end
local function decode6(id,val)
 local a={id%256,math.floor(id/256)}
 for i=3,6 do local low=val%256;a[i]=low;val=math.floor((val-low)/256)end
 return a
end
local function packet(cmd,data,seq)
 local a={0xC8,0xEA,0x50+(seq or 0),0,cmd%256,math.floor(cmd/256),#data%256,math.floor(#data/256)}
 return append(a,data)
end
local function newHarness(kind,family,release)
 local h=fixture.new({external=true})
 local originalBody=h.body
 h.health={1,0,1,2,3,0,4,1,0};h.status=append({125,0,0,0,43,0,12,0,0,64,0,0,128},{0,0,0,0,0,0,0,0,0})
 h.release=release or{8,0,1};h.frequencyGroup=0
 if family=='INAV'then
  h.board=append({73,78,65,86,7,0,2,0},str('INAV_TARGET'))
  function h:body(cmd,index)
   if cmd==2 then return {73,78,65,86} elseif cmd==1 then return {0,2,5}
   elseif cmd==3 then return self.release elseif cmd==8192 then return self.status
   elseif cmd==151 then return self.health
   elseif cmd==88 then
    local r=self.report;local data={r.hardware,r.band,r.channel,r.power,r.pit and 1 or 0,r.ready and 1 or 0,r.lowPower,1,#self.bands,#self.bands[1].frequencies,#self.powers}
    if self.release[1]==9 and self.release[2]==1 then data[#data+1]=r.hardware==6 and 0 or 1 end
    return data
   elseif cmd==138 then local p=self.powers[index];return append({index,0,0},str(p.label))
   elseif cmd==4099 then return {self.frequencyGroup}end
   return originalBody(self,cmd,index)
  end
 end
 local transport=h.transport
 if kind=='S.PORT'then
  h.sport={queue={},sent={},pops=0,pushOk=true,responseSeq=0,request=nil}
  local sp=h.sport
  local io={push=function(sensor,frame,id,value)
   check(sensor==0x0D and frame==0x30,'S.Port request address/frame')
   check(id%1==0 and value%1==0,'integer S.Port fields')
   local a=decode6(id,value)
   sp.sent[#sp.sent+1]={sensor=sensor,frame=frame,id=id,value=value,bytes=a,accepted=sp.pushOk}
   if not sp.pushOk then return false end
   local first=math.floor(a[1]/16)%2==1;local seq=a[1]%16
   if first then
    check(math.floor(a[1]/32)%4==2 and a[2]==0,'MSPv2 S.Port start/flags')
    sp.request={cmd=a[3]+a[4]*256,len=a[5]+a[6]*256,data={},nextSeq=(seq+1)%16}
   else
    local q=sp.request;check(q and q.nextSeq==seq,'ordered S.Port continuation')
    q.nextSeq=(seq+1)%16
    for i=2,6 do if #q.data<q.len then q.data[#q.data+1]=a[i]end end
   end
   local q=sp.request
   if q and #q.data==q.len then
    local p=packet(q.cmd,q.data,0)
    transport.push((q.cmd==89 or q.cmd==250)and 0x7C or 0x7A,p);sp.request=nil
   end
   return true
  end,pop=function()
   sp.pops=sp.pops+1
   if #sp.queue==0 then return nil end
   local f=table.remove(sp.queue,1);return f.sensor,f.frame,f.id,f.value
  end}
  h.rawIo=io;h.adapter=assert(adapters.new(kind,io))
  function h:wireReplies()
   local body,cmd,rejected
   while #self.queue>0 do
    local f=table.remove(self.queue,1);local a=f.data
    check(f.kind==0x7B,'fixture creates MSP replies only')
    local first=math.floor(a[3]/16)%2==1
    if first then body={};cmd=a[5]+a[6]*256;rejected=a[3]>=128 end
    for i=first and 9 or 4,#a do body[#body+1]=a[i]end
    -- Fixture may use multiple logical CRSF chunks; emit only when complete.
    local expected=first and(a[7]+a[8]*256)or sp.replyLength
    sp.replyLength=expected
    if #body==expected then
     local bytes={0x50+sp.responseSeq+(rejected and 128 or 0),0,cmd%256,math.floor(cmd/256),#body%256,math.floor(#body/256)}
     local id,value=encode6(bytes);sp.queue[#sp.queue+1]={sensor=0x1B,frame=0x32,id=id,value=value};sp.responseSeq=(sp.responseSeq+1)%16
     local p=1
     while p<=#body do
      bytes={0x40+sp.responseSeq};for _=1,5 do bytes[#bytes+1]=body[p]or 0;p=p+1 end
      id,value=encode6(bytes);sp.queue[#sp.queue+1]={sensor=0,frame=0x32,id=id,value=value};sp.responseSeq=(sp.responseSeq+1)%16
     end
    end
   end
  end
 else h.adapter=assert(adapters.new(kind,transport))end
 h.c=factory.new(h.adapter,{family=family})
 function h:step(t,enabled,link,disarmed)
  self.now=t
  local pushes=kind=='S.PORT'and #self.sport.sent or #self.sent
  local pops=kind=='S.PORT'and self.sport.pops or self.pops
  local s=self.c:tick(t,enabled~=false,link~=false,disarmed~=false)
  local afterPush=kind=='S.PORT'and #self.sport.sent or #self.sent
  local afterPop=kind=='S.PORT'and self.sport.pops or self.pops
  check(afterPush-pushes<=1,'one physical request fragment per callback')
  check(afterPop-pops<=4,'four physical pops per callback')
  self:service(t)
  if self.wireReplies then self:wireReplies()end
  return s
 end
 function h:untilState(fn,limit)
  local start=self.now
  while not fn(self.c:snapshot())and self.now-start<(limit or 6000)do self:step(self.now+25)end
  check(fn(self.c:snapshot()),'bounded scenario completed')
  return self.c:snapshot()
 end
 return h
end
-- Adapter validation, exact first request, signed word and all-byte fidelity.
local raw={sent={},queue={},pushOk=true}
local io={push=function(...)raw.sent[#raw.sent+1]={...};return raw.pushOk end,pop=function()local f=table.remove(raw.queue,1);if f then return unpack(f)end end}
check(not adapters.new('OTHER',io),'unknown transport rejected')
check(not adapters.new('CRSF',{}),'missing hooks rejected')
local a=assert(adapters.new('S.PORT',io))
check(a.push(0x7A,packet(2,{})),'S.Port queue accepts variant read');check(#raw.sent==0,'enqueue does no physical I/O')
a.tick();eq({raw.sent[1][1],raw.sent[1][2],raw.sent[1][3],raw.sent[1][4]},{13,48,80,2},'original MSPWSP variant request')
check(not a.sending(),'zero-payload request completes in one fragment')
local payload={1,2,3,4,255,128,7,8,9,10,11}
check(a.push(0x7C,packet(89,payload)),'bounded write queued')
check(not a.push(0x7A,packet(1,{})),'single queued body only')
raw.pushOk=false;a.tick();local held=copy(raw.sent[#raw.sent]);a.tick();eq(raw.sent[#raw.sent],held,'backpressure retries exact bytes and sequence')
raw.pushOk=true;a.tick();for _=1,3 do a.tick()end
local reconstructed={};for i=#raw.sent-2,#raw.sent do local f=raw.sent[i];local b=decode6(f[3],f[4]);for j=2,6 do if #reconstructed<#payload then reconstructed[#reconstructed+1]=b[j]end end end
eq(reconstructed,payload,'multi-fragment request payload preserves signed high bits')
check(raw.sent[#raw.sent-2][4]<0,'high-bit word uses signed integer')
local words={{0,0,1,0,0,128},{255,255,255,255,255,255},{1,2,1,0,128,127},{80,0,2,0,0,0}}
for _,bytes in ipairs(words)do
 local id,val=encode6(bytes);raw.queue[#raw.queue+1]={27,50,id,val};local frame,b=a.pop();check(frame==0x7B,'S.Port response frame normalized');eq({b[3],b[4],b[5],b[6],b[7],b[8]},bytes,'S.Port signed response fidelity')
end
raw.queue={{26,50,0,0},{27,49,0,0},{27,50,-1,0},{27,50,0,0/0}}
for _=1,4 do local frame,b=a.pop();check(frame==0 and b==nil,'foreign or malformed Sport frame dropped without fake reply')end
check(a.stats.dropped==2 and a.stats.invalid==2,'transport diagnostic counters')
check(a.push(0x7A,packet(4,{1,2,3})),'partial cancellation queued');a.tick();local before=#raw.sent;a.reset();a.tick();check(#raw.sent==before and not a.sending(),'reset never finishes a cancelled partial body')
for _,bad in ipairs({packet(1,{256}),packet(1,{-1}),{200,234,80,1,1,0,0,0},packet(1,{1})})do
 if #bad==9 and bad[9]==1 then bad[7]=2 end
 check(not a.push(0x7A,bad),'invalid normalized body rejected')
end
-- Real FC identity/status/inventory on BOTH transports and all verified INAV releases.
for _,kind in ipairs({'CRSF','S.PORT'})do
 for _,release in ipairs(verifiedInavReleases)do
  local h=newHarness(kind,'INAV',release);h.c:requestInfo();local s=h:untilState(function(st)return st.sensorHealth~=nil and st.lastStatus~=nil end)
  check(s.family=='INAV'and s.transport==kind and s.statusCommand==8192,'family/transport reported truthfully')
  check(s.variant=='INAV'and s.firmware==table.concat(release,'.')and s.api=='2.5','INAV handshake decodes actual identity')
  check(s.board.target=='INAV_TARGET'and s.board.identifier=='INAV'and s.board.name==nil and s.board.manufacturer==nil,'INAV board only reports available strings')
  check(s.activeSensors==43 and s.sensors==nil,'INAV active mask is not BF presence booleans')
  check(s.sensorHealth.overall==1 and s.sensorHealth.mag==2 and s.sensorHealth.baro==3 and s.sensorHealth.rangefinder==4 and s.sensorHealth.opticalFlow==0,'nine-byte health states preserve unknown values')
  eq(s.statusData,h.status,'raw8192 all22 bytes preserved')
  check(h:count(8192)>=1 and h:count(150)==0 and h:count(160)==1 and s.uid=='04030201080706050C0B0A09','INAV status and actual UID use supported commands')
  check(not h.c:applyVtx({pit=false}),'INAV VTX apply requires explicit backend enable')
  h.health[2]=2;local prior=s.sensorHealthAt
  h:step(prior+350);h.c:requestInfo();h:untilState(function(st)return st.sensorHealthAt>prior end)
  check(s.sensorHealth.gyro==2,'diagnostics refresh reads real new sensor health')
  check(h:count(88)==0 and h:count(89)==0 and h:count(250)==0,'INAV does not poll or write VTX by default')
  local oldUid=s.uid;h.uid[1]=99;h.health[2]=3;h.c:requestInfo(true)
  h:untilState(function(st)return st.uid~=oldUid and st.ready==false end)
  check(s.sensorHealth==nil and s.sensorHealthAt==nil and s.statusData==nil and s.lastStatus==nil,'UID change invalidates prior INAV status/health before re-handshake')
  h:untilState(function(st)return st.sensorHealth~=nil and st.lastStatus~=nil end)
  check(s.ready and s.sensorHealth.gyro==3,'new INAV identity obtains fresh sensor-health/status')
 end
 local h=newHarness(kind,'BF');h.c:requestInfo();h.c:setVtxEnabled(true)
 local s=h:untilState(function(st)return st.vtx.tablesReady end)
 check(s.variant=='BTFL'and s.statusCommand==150 and s.uid~=nil,'BF identity/status preserved')
 check(s.vtx.bands[2].frequencies[3]==5900 and s.vtx.powers[2].label=='MAX','indexed tables traverse physical adapter')
 check(h.c:applyVtx({pit=false}),'explicit PIT OFF transaction accepted over '..kind)
 h:untilState(function(st)return st.vtx.operation.state=='APPLIED'end)
 eq(h:last(89).payload,{168,22,2,0},'write payload across '..kind)
 check(h:count(89)==1 and h:count(250)==1 and not s.vtx.reported.pit,'one write/save + actual readback '..kind)
 if kind=='S.PORT'then
  local writeFragments=0;for _,f in ipairs(h.sport.sent)do if f.accepted then writeFragments=writeFragments+1 end end
  check(writeFragments>#h.sent,'S.Port fragmentation really occurred')
 end
end
-- Real INAV VTX has different status offsets, hardware IDs, power values,
-- no137 band getter and no arbitrary-frequency setter. Same transaction guards.
for _,kind in ipairs({'CRSF','S.PORT'})do
 for _,release in ipairs(verifiedInavReleases)do
  local h=newHarness(kind,'INAV',release);h.c:setVtxEnabled(true)
  local s=h:untilState(function(st)return st.vtx.tablesReady end)
  local v=s.vtx;local r=v.reported
  check(r.hardwareName=='SmartAudio'and r.ready and r.pit and r.lowPowerDisarm==2,'INAV11/12-byte status distinct offsets')
  check(r.frequency==5845 and r.frequencySource=='INAV TABLE'and r.frequencyReported==false,'INAV frequency labelled derived rather than measured')
  check(v.powers[1].value==nil and v.powers[1].label=='25'and v.powers[2].value==nil,'INAV reserved numeric power does not become0mW')
  check(h:count(137)==0 and h:count(138)==2 and h:count(4099)==1,'INAV reads actual labels and configured frequency group without unsupported137')
  local group=h:last(4099).payload;local name={};for i=1,#group-1 do name[i]=string.char(group[i])end
  check(table.concat(name)=='vtx_frequency_group'and group[#group]==0,'INAV setting query is named and NUL-terminated')
  local ok,why=h.c:applyVtx({frequency=5801});check(not ok and why=='INAV CHANNEL REQUIRED','arbitrary MHz cannot silently do nothing on INAV')
  check(h.c:applyVtx({band=2,channel=3,power=1,pit=false,lowPowerDisarm=0}),'INAV channel/power/PIT/LPD operation queued')
  h:untilState(function(st)return st.vtx.operation.state=='APPLIED'end)
  eq(h:last(89).payload,{10,0,1,0,0},'INAV encoded exact channel and explicit OFF fields')
  check(h:count(250)==1 and v.reported.band==2 and v.reported.channel==3 and not v.reported.pit and v.reported.lowPowerDisarm==0,'INAV saved settings verified via actual88 readback')
  check(h.c:applyVtx({frequency=5865}),'known MHz maps to actual INAV channel')
  h:untilState(function(st)return st.vtx.operation.state=='APPLIED'end)
  eq(h:last(89).payload,{0,0,1,0,0},'INAV first channel encodes0 rather than rawMHz')
  check(h.c:applyVtx({pit=true}),'INAV PIT-only operation preserves current channel')
  h:untilState(function(st)return st.vtx.operation.state=='APPLIED'end)
  eq(h:last(89).payload,{0,0,1,1,0},'INAV unchanged channel explicitly encoded even without frequency selection')
  -- Frequency-group change between review and apply fails before any write.
  local prior=h:count(89);h.frequencyGroup=2;check(h.c:applyVtx({pit=false}),'INAV group-change preflight starts')
  h:untilState(function(st)return st.vtx.operation.state=='FAILED'end)
  check(v.operation.error=='VTX FREQUENCY GROUP CHANGED'and h:count(89)==prior,'changed frequency group cannot receive stale reviewed-channel writes')
 end
 -- INAV MSP hardware6 and power0 are distinct from BF MSP hardware5.
 local h=newHarness(kind,'INAV',{9,1,0});h.report.hardware=6;h.c:setVtxEnabled(true)
 local s=h:untilState(function(st)return st.vtx.tablesReady end)
 check(s.vtx.reported.hardwareName=='MSP'and s.vtx.reported.minPowerIndex==0 and s.vtx.powers[0].label=='OFF','INAV hardware6 has explicit zero/off index')
 check(h.c:applyVtx({power=0}),'INAV advertised minimum0 accepted')
 h:untilState(function(st)return st.vtx.operation.state=='APPLIED'end)
 check(h:last(89).payload[3]==0 and s.vtx.reported.power==0,'INAV zero power persists through wire/readback')
 -- Tramp1.3GHz uses a different verified firmware table; no5.8GHz bounds guess.
 h=newHarness(kind,'INAV',{9,1,0});h.report.hardware=4;h.frequencyGroup=2;h.bands[1].frequencies={1080,1120,1160,1200,1240,1280,1320,1360};h.bands[2].frequencies={1080,1120,1160,1200,1258,1280,1320,1360};h.c:setVtxEnabled(true)
 s=h:untilState(function(st)return st.vtx.tablesReady end)
 check(s.vtx.reported.frequency==1120 and s.vtx.bands[2].frequencies[5]==1258,'INAV Tramp1.3GHz mapping uses actual configured group')
 check(h.c:applyVtx({frequency=1258}),'INAV1.3GHz mapped channel accepted')
 h:untilState(function(st)return st.vtx.operation.state=='APPLIED'end)
 eq(h:last(89).payload,{12,0,2,1,2},'INAV1.3GHz uses channel code and preserves power/PIT/LPD')
end
-- Family-specific preflight and outcomes cannot turn acknowledgements into
-- a false success, including the additional INAV frequency-group request.
for _,kind in ipairs({'CRSF','S.PORT'})do
 for _,reject in ipairs({89,250})do
  local h=newHarness(kind,'INAV',{9,1,0});h.c:setVtxEnabled(true);h:untilState(function(st)return st.vtx.tablesReady end)
  h.rejected[reject]=true;check(h.c:applyVtx({pit=false,lowPowerDisarm=0}),'INAV rejection transaction queued')
  local s=h:untilState(function(st)return st.vtx.operation.state=='FAILED'end)
  check(s.vtx.operation.error=='FC REJECTED'and s.vtx.operation.uncertain and not s.vtx.operation.verifiedAt,'INAV rejection is an explicit uncertain failure')
  if reject==89 then check(h:count(250)==0,'INAV rejected write never followed by EEPROM save')end
 end
 local h=newHarness(kind,'INAV',{9,1,0});h.c:setVtxEnabled(true);h:untilState(function(st)return st.vtx.tablesReady end)
 h.wrongReadback=true;check(h.c:applyVtx({pit=false}),'INAV readback mismatch transaction queued')
 local s=h:untilState(function(st)return st.vtx.operation.state=='FAILED'end)
 check(s.vtx.operation.error=='READBACK MISMATCH'and s.vtx.operation.saved and not s.vtx.operation.verifiedAt and s.vtx.reported.pit,'INAV mismatch never claims applied')
 h=newHarness(kind,'INAV',{9,1,0});h.c:setVtxEnabled(true);h:untilState(function(st)return st.vtx.tablesReady end)
 h.dropped[4099]=true;check(h.c:applyVtx({pit=false}),'INAV missing preflight setting starts')
 s=h:untilState(function(st)return st.vtx.operation.state=='FAILED'end)
 check(h:count(4099)==3 and h:count(89)==0 and not s.vtx.operation.uncertain and s.vtx.operation.error=='RESPONSE TIMEOUT','INAV group preflight bounded to2 attempts without any write')
 for _,release in ipairs({{8,0,2},{8,1,0},{9,0,2},{9,1,1},{9,2,0},{10,0,0}})do
  h=newHarness(kind,'INAV',release);h.c:setVtxEnabled(true)
  s=h:untilState(function(st)return st.vtx.status=='UNVERIFIED INAV RELEASE'end)
  check(not h.c:applyVtx({pit=false})and h:count(89)==0 and h:count(250)==0,'unknown INAV release never accepts guessed write layout')
 end
end
-- BF existing four-byte writes remain unchanged; explicit LPD adds only byte5.
h=newHarness('CRSF','BF');h.c:setVtxEnabled(true);s=h:untilState(function(st)return st.vtx.tablesReady end)
check(h.c:applyVtx({lowPowerDisarm=0}),'BF explicit LPD0 queued')
h:untilState(function(st)return st.vtx.operation.state=='APPLIED'end)
eq(h:last(89).payload,{168,22,2,1,0},'BF explicit LPD extension wire format')
check(s.vtx.reported.lowPowerDisarm==0,'BF LPD readback verified')
for _,bad in ipairs({-1,3,0/0,'0',false})do check(not h.c:applyVtx({lowPowerDisarm=bad}),'invalid LPD enum rejected before transport')end
-- Guards invalidate and stop physical output, including an already queued fragment.
for _,guard in ipairs({'off','link','armed'})do
 local h=newHarness('S.PORT','BF');h:step(0);h:step(100)
 check(h.adapter.sending(),'request pending before physical send')
 local n=#h.sport.sent;local pops=h.sport.pops
 h:step(101,guard~='off',guard~='link',guard~='armed')
 check(#h.sport.sent==n and h.sport.pops==pops and not h.adapter.sending(),'guard precedes physical S.Port I/O: '..guard)
end
local h=newHarness('CRSF','INAV',{7,1,2});local s=h:untilState(function(st)return st.status=='INAV 8.0+ REQUIRED'end)
check(not s.ready and h:count(8192)==0,'unsupported old INAV stops before status')
h=newHarness('CRSF','INAV');h.body=function(self,cmd,index)if cmd==2 then return{66,84,70,76}end;error('variant mismatch must stop')end
s=h:untilState(function(st)return st.status=='UNSUPPORTED FC'end);check(not s.ready and #h.sent==1,'family mismatch stops handshake')
h=newHarness('CRSF','OTHER');h:step(0);h:step(1000);check(#h.sent==0,'unknown family cannot emit I/O')
-- Known INAV malformed status and health never replace last accepted values.
h=newHarness('CRSF','INAV');h.c:requestInfo();s=h:untilState(function(st)return st.sensorHealth~=nil and st.lastStatus~=nil end)
local statusAt=s.lastStatus;local healthAt=s.sensorHealthAt
h.status={1,2,3};h:untilState(function(st)return st.status=='INVALID INAV STATUS'end)
check(s.lastStatus==statusAt and #s.statusData==22,'short status preserves last known packet without fresh timestamp')
h.health={1,2};h.c:requestInfo(true);h:untilState(function(st)return st.infoError=='INVALID SENSOR HEALTH'end)
check(s.sensorHealthAt==healthAt and s.sensorHealth.gyro==0,'short health preserves last known health without fresh timestamp')
-- Maximum bounded packet traverses sequence wrap without dropping any byte.
raw.sent={};local big={};for i=1,256 do big[i]=(i*37)%256 end
check(a.push(0x7A,packet(164,big)),'256-byte bounded body accepted')
for _=1,53 do a.tick()end
check(not a.sending()and #raw.sent==53,'maximum body uses one header +52 fragments')
local all={};local seq
for i,f in ipairs(raw.sent)do
 local b=decode6(f[3],f[4]);if seq then check(b[1]%16==seq,'sequence wraps modulo16')end;seq=(b[1]%16+1)%16
 if i>1 then for j=2,6 do if #all<256 then all[#all+1]=b[j]end end end
end
eq(all,big,'all256 payload bytes survive signed packing and wrap')
check(not a.push(0x7A,packet(164,append(copy(big),{1}))), '257-byte body rejected before I/O')

-- S.Port uses its original longer deadline, not the CRSF five-second cutoff.
h=newHarness('S.PORT','BF');h:step(0);h:step(100);h:step(125)
local heldReply=h.sport.queue;h.sport.queue={}
h:step(650);check(h.c:snapshot().timeouts==0 and h.c:snapshot().pendingCommand==2,'S.Port request still pending after CRSF deadline')
h.sport.queue=heldReply;h:step(675)
check(h.c:snapshot().variant=='BTFL'and h.c:snapshot().timeouts==0,'six-second S.Port reply accepted before eight-second deadline')
h=newHarness('S.PORT','BF');h.sport.pushOk=false;h:step(0);h:step(100);h:step(899);local n=#h.sport.sent
h:step(900);check(h.c:snapshot().timeouts==1 and #h.sport.sent==n and not h.adapter.sending(),'deadline resets queued fragments before physical send')

-- Cancellation after only the S.Port write header cannot send its payload later.
h=newHarness('S.PORT','BF');h.c:requestInfo();h.c:setVtxEnabled(true);h:untilState(function(st)return st.vtx.tablesReady end)
check(h.c:applyVtx({pit=false}),'S.Port partial-write cancellation starts')
h:untilState(function(st)return st.vtx.operation.state=='WRITING'and h.adapter.sending()end)
h:step(h.now+25);check(h.sport.request and h.sport.request.cmd==89 and h:count(89)==0,'only the physical write header sent')
check(h.c:cancelVtx(),'cancel stops unsent write remainder')
for _=1,10 do h:step(h.now+25)end
check(h:count(89)==0 and h:count(250)==0 and h.c:snapshot().vtx.operation.state=='CANCELLED','no abandoned write payload or EEPROM save after cancel')

-- GPS164 actual BF records: GNSS format is explicit via count>16; legacy
-- channel data must never be relabelled as constellation/navigation-used.
for _,kind in ipairs({'CRSF','S.PORT'})do
 h=newHarness(kind,'BF');local oldBody=h.body
 local modern={32,0,12,237,45,6,4,4,31,7,50,13,24}
 for _=4,32 do append(modern,{255,0,0,0})end
 h.satelliteBody=modern
 function h:body(cmd,index)if cmd==164 then return self.satelliteBody end;return oldBody(self,cmd,index)end
 check(h.c:setGpsEnabled(true),'GPS optional reads enabled '..kind)
 h.c:requestInfo();h.c:setVtxEnabled(true)
 s=h:untilState(function(st)return st.satellitesAt~=nil and st.vtx.tablesReady end)
 check(s.lastStatus~=nil,'GPS/status/VTX table reads share one bounded queue without starvation')
 check(s.satellitesStatus=='LIVE'and s.satelliteSlots==32 and s.satelliteFormat=='GNSS'and #s.satellites==3,'GNSS padding omitted without falsifying wire slot count')
 local rec=s.satellites[1]
 check(rec.gnssId==0 and rec.constellation=='GPS'and rec.id==12 and rec.qualityRaw==237 and rec.quality==5 and rec.used==true and rec.signal==45,'GNSS actual flags/id/signal decoded')
 check(rec.health==nil,'no unproved satellite-health field')
 check(s.satellites[2].constellation=='GLONASS'and s.satellites[2].used==false and s.satellites[3].constellation=='GNSS 7','unknown GNSS id retained truthfully')
 local prior=s.satellitesAt
 h.satelliteBody={3,0,10,5,35,1,23,255,0,255,0,0,0}
 h:untilState(function(st)return st.satellitesAt>prior end)
 check(s.satelliteFormat=='CHANNEL'and #s.satellites==2 and s.satellites[1].channel==0,'legacy channel format distinguished')
 check(s.satellites[1].gnssId==nil and s.satellites[1].constellation==nil and s.satellites[1].used==nil,'legacy fields do not fabricate constellation/used')
 check(s.satellites[2].quality==255 and s.satellites[2].qualityRaw==255,'legacy raw unknown quality preserved rather than masking to7')
 prior=s.satellitesAt;h.satelliteBody={32,0}
 h:untilState(function(st)return st.satellitesError=='INVALID SATELLITE DATA'end)
 check(s.satellitesAt==prior and #s.satellites==2,'malformed satellite packet does not refresh accepted data')
 check(h.c:setGpsEnabled(false),'GPS disable accepted')
 local reads=h:count(164);for _=1,30 do h:step(h.now+25)end
 check(h:count(164)==reads and s.satellitesStatus=='PAUSED','GPS page departure stops optional wire reads')
 h.c:stop();check(s.satellites==nil and s.satellitesAt==nil,'session stop invalidates all GPS observations')
 h=newHarness(kind,'INAV');local ok,why=h.c:setGpsEnabled(true)
 check(not ok and why=='GPS SATELLITES UNSUPPORTED BY INAV'and h.c:snapshot().satellitesStatus=='COMPATIBILITY STUB','INAV164 stub is explicit unsupported capability')
 h:untilState(function(st)return st.lastStatus~=nil end)
 check(h:count(164)==0 and h.c:snapshot().satellites==nil,'INAV stub cannot masquerade as one satellite')
end
-- Cache optimization traverses BOTH physical transports; an already-sending
-- S.Port indexed read is consumed before a new selected-entry verification.
local function deep(t)local c={};for k,v in pairs(t)do c[k]=type(v)=='table'and deep(v)or v end;return c end
local function tableRecord(st)
 local v,r=st.vtx,st.vtx.reported
 return{uid=st.uid,signature=string.format('%s:%s:%s:%s',r.hardware,r.bandCount,r.channelCount,r.powerCount),hardware=r.hardware,bandCount=r.bandCount,channelCount=r.channelCount,powerCount=r.powerCount,bands=deep(v.bands),powers=deep(v.powers)}
end
for _,kind in ipairs({'CRSF','S.PORT'})do
 local cold=newHarness(kind,'BF');cold.c:setVtxEnabled(true);local st=cold:untilState(function(x)return x.vtx.tablesReady end)
 local record=tableRecord(st)
 local h=newHarness(kind,'BF');h.c:setVtxEnabled(true);st=h:untilState(function(x)return x.uid and x.vtx.reportedAt end)
 check(h.c:useCachedTables(record),'cached tables accepted over '..kind)
 check(h:count(137)==0 and h:count(138)==0 and not st.vtx.tablesFresh,'cache skips all initial indexed wire reads '..kind)
 h.c:setIntervals(0,60);check(h.c:applyVtx({band=2,channel=3,power=1,pit=false}),'cache exact apply starts '..kind)
 h:untilState(function(x)return x.vtx.operation.state=='APPLIED'end)
 check(h:count(137)==1 and h:count(138)==1 and h:count(89)==1 and h:count(250)==1 and not st.vtx.tablesFresh,'only selected cached entries checked over '..kind)
 -- Start a fresh session with the first enumeration read already in flight.
 h=newHarness(kind,'BF');h.c:setVtxEnabled(true);st=h:untilState(function(x)return x.uid and x.vtx.reportedAt end)
 h.c:setIntervals(0,60);h:step(h.now+25)
 if kind=='S.PORT'then h:step(h.now+25);check(h.sport.request and h.sport.request.cmd==137 and h.adapter.sending(),'S.Port137 header already sent; index payload still pending')
 else check(h:count(137)==1,'CRSF137 response already queued')end
 check(h.c:useCachedTables(record),'import does not cancel physical old table read '..kind)
 check(h.c:applyVtx({band=1,channel=1,power=1,pit=false}),'cache operation waits for old table read '..kind)
 if kind=='S.PORT'then h:step(h.now+25)end -- completes original indexed request and queues its old response
 h.bands[1].frequencies[1]=5700
 h:untilState(function(x)return x.vtx.operation.state=='FAILED'end)
 check(h:count(137)==2 and h:count(89)==0 and st.vtx.operation.error=='CACHED CHANNEL CHANGED','old indexed response cannot authorize fresh selected write '..kind)
end
-- EdgeTX's restricted Lua string library has no string method metatable.
-- Exercise module loading AND full real-wire decode/write flows in that state;
-- fixtures precompute only their string-based payload construction beforehand.
local noMeta={}
for _,kind in ipairs({'CRSF','S.PORT'})do for _,family in ipairs({'BF','INAV'})do
 local h=newHarness(kind,family,{9,1,0});local bodies={}
 for _,cmd in ipairs({137,138})do bodies[cmd]={};for index=1,2 do bodies[cmd][index]=h:body(cmd,index)end end
 local original=h.body
 function h:body(cmd,index)if bodies[cmd]then return copy(bodies[cmd][index])end;return original(self,cmd,index)end
 noMeta[#noMeta+1]=h
end end
local oldStringMeta=debug.getmetatable('')
debug.setmetatable('',nil)
local ran,why=pcall(function()
 local realFactory=dofile(modules..'crsf-msp.lua')
 local realAdapters=dofile(modules..'msp-adapters.lua')
 check(realFactory and realAdapters,'runtime modules load without a string metatable')
 for _,h in ipairs(noMeta)do
  local family=h.c:snapshot().family
  h.adapter=assert(realAdapters.new(h.adapter.name,h.rawIo or h.transport));h.c=realFactory.new(h.adapter,{family=family})
  h.c:requestInfo();h.c:setVtxEnabled(true)
  local s=h:untilState(function(st)return st.vtx.tablesReady and st.board~=nil end)
  check(s.uid~=nil and s.board.target~=nil,'UID/board/string table labels decode without methods')
  if family=='BF'then
   local uidAt,reportedAt=s.uidAt,s.vtx.reportedAt;h.c:setIntervals(0,1);h.c:requestInfo(true)
   h:untilState(function(st)return st.uidAt>uidAt and st.vtx.reportedAt>reportedAt end);h.c:setIntervals(0,60)
   local accepted,why=h.c:useCachedTables(tableRecord(s));check(accepted,'cache import validates without string methods: '..tostring(why))
  end
  check(h.c:applyVtx({pit=false,lowPowerDisarm=0}),'apply without string methods')
  h:untilState(function(st)return st.vtx.operation.state=='APPLIED'end)
  check(not s.vtx.reported.pit and s.vtx.reported.lowPowerDisarm==0,'full wire/readback without string method metatable')
 end
end)
debug.setmetatable('',oldStringMeta)
check(ran,'no-string-metatable integration: '..tostring(why))
print('PASS: '..(checks+fixture.checks())..' checks: real BF/INAV client over CRSF and six-byte S.Port, signed words, fairness/budgets, guards, identity/health and write/save/readback (synthetic only)')
