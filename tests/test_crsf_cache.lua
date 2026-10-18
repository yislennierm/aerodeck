-- Actual BF client + synthetic FC: cached labels reduce table reads, while each
-- cached write must validate fresh selected entries. No hardware verification.
local here=string.match(arg[0],'^(.*[/\\])')or'./'
local root=arg[1]or(here..'../')
local fixture=dofile(root..'/tests/fixtures/msp_fixture.lua')
local factory=dofile(root..'/sdcard/SCRIPTS/TOOLS/AERODECK/crsf-msp.lua')
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function copy(t)local c={};for k,v in pairs(t)do c[k]=type(v)=='table'and copy(v)or v end;return c end
local function eq(a,b,why)check(#a==#b,why..' length');for i=1,#a do check(a[i]==b[i],why..' item '..i)end end
local cold=fixture.ready();local coldState=cold.c:snapshot();local r=coldState.vtx.reported
local record={uid=coldState.uid,hardware=r.hardware,bandCount=r.bandCount,channelCount=r.channelCount,powerCount=r.powerCount,
 signature=string.format('%s:%s:%s:%s',r.hardware,r.bandCount,r.channelCount,r.powerCount),bands=copy(coldState.vtx.bands),powers=copy(coldState.vtx.powers)}
local function warm(import)
 local h=fixture.new();h.c:requestInfo();h.c:setVtxEnabled(true)
 h:pump(function(s)return s.uid~=nil and s.vtx.reportedAt~=nil end)
 check(h:count(137)==0 and h:count(138)==0,'metadata available before table enumeration')
 if import~=false then check(h.c:useCachedTables(record),'validated SD cache accepted')end
 return h
end
local h=warm();local s=h.c:snapshot();local v=s.vtx
check(v.tablesReady and not v.tablesFresh and v.tableSource=='SD CACHE'and v.tablesStatus=='READY / CACHE','usable cache never labelled fully fresh')
h:pump(function()return h:count(150)>=2 end)
check(h:count(137)==0 and h:count(138)==0,'warm cache eliminates all four initial indexed RF reads')
check(cold:count(137)==2 and cold:count(138)==2,'cold reference actually enumerates every advertised entry')
-- Independent ownership: neither caller mutations nor later SD-record changes
-- silently change the values the user reviewed.
local rec=copy(record);h=warm(false);check(h.c:useCachedTables(rec),'caller record imported')
rec.bands[2].frequencies[3]=1234;rec.powers[1].label='BAD'
check(h.c:snapshot().vtx.bands[2].frequencies[3]==5900 and h.c:snapshot().vtx.powers[1].label=='25','import copies bounded table contents')
h.c:setIntervals(0,60);local first=#h.sent+1
check(h.c:applyVtx({band=2,channel=3,power=1,pit=false}),'cached exact-channel transaction queued')
h:pump(function(st)return st.vtx.operation.state=='APPLIED'end)
local wire={};for i=first,#h.sent do wire[#wire+1]=h.sent[i].cmd end
eq(wire,{160,1,3,88,137,138,89,250,88},'cached write validates identity/version/status then selected entries before write/save/readback')
check(h:last(137).payload[1]==2 and h:last(138).payload[1]==1,'only requested band and power indexes queried')
check(h:count(137)==1 and h:count(138)==1,'cached write does not enumerate unselected entries')
v=h.c:snapshot().vtx
check(v.operation.bandVerifiedAt and v.operation.powerVerifiedAt and v.operation.preflightAt<v.operation.bandVerifiedAt and v.operation.bandVerifiedAt<v.operation.powerVerifiedAt,'selected verification occurs after fresh preflight')
check(v.operation.verifiedAt and not v.operation.uncertain and not v.tablesFresh and v.tableSource=='SD CACHE','APPLIED confirms transaction without claiming all cached tables fresh')
-- Arbitrary MHz still verifies the current/selected power, without a fake band.
h=warm();h.c:setIntervals(0,60);first=#h.sent+1
check(h.c:applyVtx({frequency=5901,pit=false}),'custom MHz from cached table queued')
h:pump(function(st)return st.vtx.operation.state=='APPLIED'end)
wire={};for i=first,#h.sent do wire[#wire+1]=h.sent[i].cmd end
eq(wire,{160,1,3,88,138,89,250,88},'raw MHz always freshly checks selected power but needs no band lookup')
check(h:last(89).payload[1]+h:last(89).payload[2]*256==5901,'raw MHz is preserved after power verification')
-- Any selected semantic entry change stops before the first write.
for _,change in ipairs({'frequency','bandName','bandLetter','factory','powerValue','powerLabel','badPowerIndex','badBandIndex','shortBand'})do
 h=warm();h.c:setIntervals(0,60)
 if change=='frequency'then h.bands[2].frequencies[3]=5899
 elseif change=='bandName'then h.bands[2].name='RENAMED'
 elseif change=='bandLetter'then h.bands[2].letter='X'
 elseif change=='factory'then h.bands[2].factory=1
 elseif change=='powerValue'then h.powers[1].value=30
 elseif change=='powerLabel'then h.powers[1].label='OTHER'
 else
  local original=h.body
  function h:body(cmd,index)
   local body=original(self,cmd,index)
   if change=='badPowerIndex'and cmd==138 then body[1]=2
   elseif change=='badBandIndex'and cmd==137 then body[1]=1
   elseif change=='shortBand'and cmd==137 then body[#body]=nil end
   return body
  end
 end
 check(h.c:applyVtx({band=2,channel=3,power=1,pit=false}),'changed cache scenario starts: '..change)
 h:pump(function(st)return st.vtx.operation.state=='FAILED'end)
 v=h.c:snapshot().vtx
 check(h:count(89)==0 and h:count(250)==0 and not v.operation.uncertain,'changed/invalid selected entry causes zero writes: '..change)
 check(not v.tablesReady and v.tablesStatus=='ERROR'and v.operation.error~=nil,'changed cache loses usable readiness: '..change)
 check(not h.c:applyVtx({pit=false}),'failed cache cannot authorize another operation: '..change)
end
-- Current-state, API, FW and device identity must still match what was reviewed.
for _,change in ipairs({'api','firmware','uid','dimensions','currentState'})do
 h=warm();h.c:setIntervals(0,60)
 local original=h.body
 function h:body(cmd,index)
  if cmd==1 and change=='api'then return {0,1,47}
  elseif cmd==3 and change=='firmware'then return {4,5,3}end
  return original(self,cmd,index)
 end
 if change=='uid'then h.uid[1]=99 elseif change=='dimensions'then h.bands[3]=copy(h.bands[2])elseif change=='currentState'then h.report.power=1 end
 check(h.c:applyVtx({band=2,channel=3,power=1,pit=false}),'cached identity preflight starts: '..change)
 h:pump(function(st)return st.vtx.operation.state=='FAILED'end)
 check(h:count(89)==0 and h:count(250)==0,'changed identity/version/metadata causes no write: '..change)
end
for _,lost in ipairs({137,138})do
 h=warm();h.c:setIntervals(0,60);h.dropped[lost]=true
 check(h.c:applyVtx({band=2,channel=3,power=1,pit=false}),'selected-reply timeout starts')
 h:pump(function(st)return st.vtx.operation.state=='FAILED'end)
 v=h.c:snapshot().vtx
 check(h:count(lost)==2 and h:count(89)==0 and v.operation.error=='RESPONSE TIMEOUT'and not v.operation.uncertain,'selected read timeout has bounded retries and no write')
end
-- The old in-flight137 cannot satisfy the subsequent selected137 verification.
h=warm(false);h.c:setIntervals(0,60);h:tick(h.now+25)
local old=h:last(137);check(old and old.payload[1]==1 and not old.answered,'old enumeration request on wire')
local oldReply=h:body(137,1)
check(h.c:useCachedTables(record),'cache can adopt while consuming an existing table request')
check(h.c:applyVtx({band=1,channel=1,power=1,pit=false}),'cached apply waits behind old table response')
h:reply(137,oldReply,h.now+1);old.answered=true
check(not h.c:snapshot().vtx.operation.bandVerifiedAt and h:count(89)==0,'old packet consumed as drain only')
h.bands[1].frequencies[1]=5700
h:pump(function(st)return st.vtx.operation.state=='FAILED'end)
check(h:count(137)==2 and h.c:snapshot().vtx.operation.error=='CACHED CHANNEL CHANGED'and h:count(89)==0,'fresh selected137 still required and detects actual new channel')
-- The equivalent in-flight138 case also needs a second, fresh indexed reply.
h=warm(false);h.c:setIntervals(0,60)
while not h:last(138)do
 h:tick(h.now+25);local q=h.sent[#h.sent]
 if q and not q.answered and q.cmd~=138 then q.answered=true;h:answer(q)end
end
old=h:last(138);oldReply=h:body(138,old.payload[1])
check(h.c:useCachedTables(record),'power enumeration can be drained safely')
check(h.c:applyVtx({frequency=5901,power=1,pit=false}),'custom MHz queued behind old138')
h:reply(138,oldReply,h.now+1);old.answered=true;h.powers[1].value=30
h:pump(function(st)return st.vtx.operation.state=='FAILED'end)
check(h:count(138)==2 and h.c:snapshot().vtx.operation.error=='CACHED POWER CHANGED'and h:count(89)==0,'old138 cannot authorize selected power')
-- No response to the preserved request fails the queued apply, rather than
-- silently discarding its identity and allowing a later matching packet.
h=warm(false);h.c:setIntervals(0,60);h:tick(h.now+25);old=h:last(137);old.answered=true
check(h.c:useCachedTables(record),'drain timeout cache starts');check(h.c:applyVtx({band=1,channel=1,pit=false}),'drain timeout operation queued')
h:pump(function(st)return st.vtx.operation.state=='FAILED'end)
check(h.c:snapshot().vtx.operation.error=='CACHE DRAIN RESPONSE TIMEOUT'and h:count(89)==0,'drain timeout cancels before identity/selected preflight writes')
-- Late replies after cancellation are consumed during an absolute quiet window.
h=warm();h.c:setIntervals(0,60);h.dropped[137]=true;check(h.c:applyVtx({band=2,channel=3,pit=false}),'cached cancellation starts')
h:pump(function()return h:count(137)==1 end)
check(h.c:cancelVtx(),'cached selected-read cancellation')
local cancelledAt=h.now;h:reply(137,h:body(137,2),h.now+1)
check(h.c:snapshot().vtx.operation.state=='CANCELLED'and h:count(89)==0 and not h.c:snapshot().vtx.tablesReady,'late selected response cannot revive cancelled operation')
check(h.c:refreshVtx(),'explicit refresh can request full discovery after cancellation')
check(not h.c:useCachedTables(record),'cache cannot bypass quiet window')
local sent=#h.sent;h:tick(cancelledAt+499);check(#h.sent==sent,'full old-response window forbids new requests')
h.dropped[137]=nil;h:pump(function(st)return st.vtx.tablesReady end)
check(h.c:snapshot().vtx.tablesFresh and h.c:snapshot().vtx.tableSource=='FC LIVE'and h:count(89)==0,'refresh returns fully live discovery, not stale cache readiness')
-- Stop/refresh of a background indexed read also leaves a response window
-- before a future cache session can reuse the same command/index.
for _,method in ipairs({'stop','refreshVtx'})do
 h=warm(false);h.c:setIntervals(0,60);h:tick(h.now+25);old=h:last(137);old.answered=true
 local at=h.now;h.c[method](h.c);local sent=#h.sent
 h:reply(137,h:body(137,1),h.now+1);h:tick(at+499)
 check(#h.sent==sent,'aborted background indexed request is quarantined: '..method)
 h:pump(function(st)return st.vtx.reportedAt~=nil and st.vtx.reportedAt>at and st.ready end)
 check(h:count(89)==0,'no implicit write while recovering background request: '..method)
end
-- Independent input validation: rejected records must not replace current data.
local mutations={
 function(x)x.uid='FFFFFFFFFFFFFFFFFFFFFFFF'end,function(x)x.signature='3:8:8:8'end,
 function(x)x.hardware=4 end,function(x)x.bandCount=0 end,function(x)x.channelCount=9 end,
 function(x)x.bands[3]=copy(x.bands[1])end,function(x)x.bands[1].index=0 end,
 function(x)x.bands[1].frequencies[1]=0/0 end,function(x)x.bands[1].frequencies[1]=65536 end,
 function(x)x.bands[1].frequencies[0]=1 end,function(x)x.bands[1].frequencies[2]=nil end,
 function(x)x.bands[1].name=string.rep('X',65)end,function(x)x.bands[1].letter='AB'end,
 function(x)x.bands[1].factory=1 end,function(x)x.powers[1].value=-1 end,
 function(x)x.powers[1].value=65536 end,function(x)x.powers[1].label='bad\nlabel'end,
 function(x)x.powers[0]=copy(x.powers[1])end,function(x)x.powers[1]=nil end}
for _,mutate in ipairs(mutations)do
 h=warm(false);local bad=copy(record);mutate(bad)
 local prior=h.c:snapshot().vtx.bands
 check(not h.c:useCachedTables(bad)and h.c:snapshot().vtx.bands==prior and not h.c:snapshot().vtx.tablesReady,'invalid cache independently rejected without partial mutation')
end
h=warm(false);h:tick(h.now+801);check(not h.c:useCachedTables(record),'old UID/status cannot load SD cache')
local inav=factory.new({}, {family='INAV'});local ok,why=inav:useCachedTables(record)
check(not ok and why=='CACHE UNSUPPORTED FOR INAV','BF cache never interpreted as INAV shape')
-- RAM restoration after a new session uses the same fresh selected-entry gate.
h=fixture.ready();h.c:stop();h.c:requestInfo();h.c:setVtxEnabled(true)
h:pump(function(st)return st.vtx.tablesReady end)
v=h.c:snapshot().vtx
check(not v.tablesFresh and v.tableSource=='RAM CACHE','prior-session RAM tables are not silently live')
h.bands[2].frequencies[3]=5899;local writes=h:count(89)
check(h.c:applyVtx({band=2,channel=3,pit=false}),'RAM cache operation starts')
h:pump(function(st)return st.vtx.operation.state=='FAILED'end)
check(h:count(89)==writes and h.c:snapshot().vtx.operation.error=='CACHED CHANNEL CHANGED','RAM restoration also verifies selected actual channel before write')
print('PASS: '..(checks+fixture.checks())..' checks: warm-cache RF reduction, independent bounds, fresh UID/API/FW/status/selected band+power verification, mismatches, drain identity, cancellation/quarantine and RAM parity (synthetic only)')
