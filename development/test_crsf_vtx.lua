-- Real client + synthetic FC integration tests. No hardware verification.
local here=arg[0]:match('^(.*[/\\])')or'./'
local fixture=dofile(here..'msp_fixture.lua')
local harness,ready=fixture.new,fixture.ready
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function equal(a,b,why)
 check(#a==#b,(why or'')..' length')
 for i=1,#a do check(a[i]==b[i],(why or'')..' byte '..i)end
end
local h=ready();local s=h.c:snapshot();check(s==h.c:snapshot(),'stable snapshot object')
check(s.uid=='04030201080706050C0B0A09','UID byte order preserves high/low bytes without U32')
check(s.board.identifier=='IFRC'and s.board.target=='TARGET'and s.board.name=='BOARD'and s.board.manufacturer=='ACME','board length-prefixed strings')
check(s.board.hardwareRevision==12 and s.board.type==2 and s.board.capabilities==5,'board prefix')
check(s.sensors.acc and s.sensors.baro and s.sensors.gps and s.sensors.gyro and not s.sensors.mag and not s.sensors.rangefinder,'presence bits only')
local v=s.vtx
check(v.reported.pit and v.reported.lowPowerDisarm==2 and v.reported.hardwareName=='SmartAudio','live VTX states preserve LPD enum')
check(v.bands[1].factory and not v.bands[2].factory and v.bands[1].frequencies[1]==5658,'factory byte consumed before frequency count')
check(v.bands[2].frequencies[3]==5900 and v.powers[1].value==25 and v.powers[1].label=='25'and v.powers[2].label=='MAX','table identity/frequency/nonnumeric label')
check(h:count(137)==2 and h:count(138)==2,'every indexed table requested once')
local reads=h:count(137);for _=1,100 do h.c:setVtxEnabled(true);h.c:requestInfo()end
h.c:setVtxEnabled(false);h.c:setVtxEnabled(true)
h:pump(function()return h:count(88)>=2 end);check(h:count(137)==reads,'same UID cache survives page toggle')
local ok,err=h.c:refreshVtx();check(ok and not err,'explicit refresh accepted')
h:pump(function(st)return st.vtx.tablesReady end)
check(h:count(137)==reads+2,'refresh actually re-reads table')

-- Replies slower than the selected status interval must not starve tables.
h=ready();check(h.c:setIntervals(1,10),'short configured status interval')
check(h.c:refreshVtx(),'slow link refresh')
local slowUntil=h.now+2000
while not h.c:snapshot().vtx.tablesReady and h.now<slowUntil do
 h:tick(h.now+25)
 local q=h.sent[#h.sent]
 if q and not q.answered and h.now-q.at>=150 then q.answered=true;h:answer(q)end
end
check(h.c:snapshot().vtx.tablesReady,'optional table reads progress even when status RTT exceeds interval')

-- Explicit false is a value, not the nil/unchanged case. No reported mutation
-- until an actual readback response; no EEPROM save before write acknowledgement.
h=ready();v=h.c:snapshot().vtx;local wanted={pit=false};check(h.c:applyVtx(wanted),'PIT OFF queued');wanted.pit=true
check(v.operation.state=='QUEUED'and v.reported.pit==true,'pending separate from observed')
h:pump(function()return h:count(89)==1 end)
local write=h:last(89);equal(write.payload,{168,22,2,0},'PIT OFF independent of power')
check(v.operation.state=='SAVING'and v.operation.acknowledged and h:count(250)==0,'write ack precedes save; next callback only')
check(v.reported.pit==true,'write ack is not observed PIT')
h:pump(function(st)return st.vtx.operation.state=='APPLIED'end)
check(v.operation.saved and v.operation.verifiedAt and not v.reported.pit and not v.operation.uncertain,'applied only after save ack plus readback')
local before=h:count(89);ok,err=h.c:applyVtx({pit=false});check(not ok and err=='NO CHANGES'and h:count(89)==before,'unchanged selection does not write EEPROM')
check(h.c:applyVtx({band=2,channel=3,power=1,pit=true}),'channel/power/PIT combined apply')
h:pump(function(st)return st.vtx.operation.state=='APPLIED'end)
equal(h:last(89).payload,{10,0,1,1},'band/channel zero-based encoded as LE')
check(v.reported.frequency==5900 and v.reported.band==2 and v.reported.channel==3 and v.reported.power==1,'exact channel readback')

h=ready();before=h:count(89)
for _,bad in ipairs({{power=3},{frequency=6000},{frequency=0/0},{pit=0},{band=1},{band=1,channel=1,frequency=5800},{unsupportedField=1}})do
 ok,err=h.c:applyVtx(bad);check(not ok and type(err)=='string','invalid request rejected before writes')
end
check(h:count(89)==before,'invalid selections cause no I/O')

for _,cmd in ipairs({89,250})do
 h=ready();h.rejected[cmd]=true;check(h.c:applyVtx({pit=false}),'transaction queued before FC rejection')
 h:pump(function(st)return st.vtx.operation.state=='FAILED'end)
 v=h.c:snapshot().vtx
 check(v.operation.error=='FC REJECTED'and v.operation.uncertain,'rejection is explicit and may-have-written is honest')
 if cmd==89 then check(h:count(250)==0,'never save rejected write')end
 check(not v.operation.verifiedAt,'no applied assertion after reject')
end
h=ready();h.dropped[89]=true;check(h.c:applyVtx({pit=false}),'timeout operation queued')
h:pump(function(st)return st.vtx.operation.state=='FAILED'end,2500)
check(h:count(89)==2 and h:count(250)==0,'bounded retry count and no save without ack')
check(h.c:snapshot().vtx.operation.error=='RESPONSE TIMEOUT','lost ack outcome explicit')

h=ready();h.wrongReadback=true;check(h.c:applyVtx({pit=false}),'mismatch operation queued')
h:pump(function(st)return st.vtx.operation.state=='FAILED'end,2500)
v=h.c:snapshot().vtx;check(v.operation.error=='READBACK MISMATCH'and v.operation.saved and v.operation.uncertain,'acknowledged persisted write is not APPLIED with different readback')
check(v.reported.pit==true and not v.operation.verifiedAt,'reported state remains actual fixture')

h=ready();check(h.c:applyVtx({pit=false}),'absolute readback deadline test queued')
h:pump(function(st)return st.vtx.operation.state=='VERIFYING'end)
h.dropped[88]=true
local deadline=h.c:snapshot().vtx.operation.verifyDeadline
h:pump(function()return h:last(88)and h:last(88).at>deadline-800 end)
h:tick(deadline)
check(h.c:snapshot().vtx.operation.state=='FAILED'and h.c:snapshot().vtx.operation.error=='READBACK TIMEOUT','readback has absolute deadline independent of fragment/request retries')
h:reply(88,h:body(88),deadline+1)
check(h.c:snapshot().vtx.operation.state=='FAILED','matching late readback cannot revive failed operation')

h=ready();check(h.c:applyVtx({pit=false}),'cancel test queued');check(h.c:cancelVtx(),'unsent cancellation')
check(h.c:snapshot().vtx.operation.state=='CANCELLED'and not h.c:snapshot().vtx.operation.uncertain and h:count(89)==0,'unsent cancel is certain')
h=ready();h.dropped[89]=true;check(h.c:applyVtx({pit=false}),'in-flight cancellation queued')
h:pump(function()return h:count(89)==1 end);check(h.c:cancelVtx(),'in-flight cancellation')
check(h.c:snapshot().vtx.operation.uncertain,'sent cancellation does not claim undo')
h:reply(89,{},h.now+1);check(h:count(250)==0,'late ack after cancel does not persist')
ok,err=h.c:applyVtx({pit=false});check(not ok,'cancelled write requires new observation/cooldown before another apply')

for _,gate in ipairs({'disabled','offline','armed','unknown'})do
 h=ready();h.dropped[89]=true;check(h.c:applyVtx({pit=false}),'guard interrupted transaction starts')
 h:pump(function()return h:count(89)==1 end);local pops=h.pops;before=#h.sent
 local enabled,link,disarmed=true,true,true
 if gate=='disabled'then enabled=false elseif gate=='offline'then link=false elseif gate=='armed'then disarmed=false else disarmed=nil end
 s=h.c:tick(h.now+1,enabled,link,disarmed)
 check(h.pops==pops and #h.sent==before,'guard precedes ALL I/O: '..gate)
 check(s.vtx.operation.state=='CANCELLED'and s.vtx.operation.uncertain and not s.uid and not s.vtx.reportedAt,'cancel and invalidate session: '..gate)
end

h=ready();reads=h:count(137);h.c:stop();check(not h.c:snapshot().active,'stop cancels active session')
h.uid[1]=42;h.bands[1].name='NEW FC'
h:pump(function(st)return st.vtx.tablesReady end)
check(h:count(137)==reads+2 and h.c:snapshot().vtx.bands[1].name=='NEW FC','different UID never restores prior device table')

-- Revalidate identity/state after the user reviewed cached data and before writes.
h=ready();h.uid[1]=99;check(h.c:applyVtx({pit=false}),'device swap preflight queued')
h:pump(function(st)return st.vtx.operation.state=='FAILED'end)
check(h.c:snapshot().vtx.operation.error=='FC IDENTITY CHANGED'and h:count(89)==0 and not h.c:snapshot().board,'swapped FC cannot receive cached-device write')
h=ready();h.report.frequency=5900;check(h.c:applyVtx({pit=false}),'state-change preflight queued')
h:pump(function(st)return st.vtx.operation.state=='FAILED'end)
check(h.c:snapshot().vtx.operation.error=='VTX STATE CHANGED'and h:count(89)==0 and h.c:snapshot().vtx.reported.frequency==5900,'unreviewed VTX changes fail before writes but update observation')

-- Optional decoder errors do not overwrite accepted table data or stop status.
h=ready();check(h.c:refreshVtx(),'malformed table test refresh')
h:pump(function()return h:count(88)>=2 end)
h.dropped[137]=true;h:pump(function()return h:count(137)>=3 end)
local band={1,4,82,65,67,69,82,3,42,22,42,22,42,22} -- missing factory byte
h:reply(137,band,h.now+1)
check(h.c:snapshot().vtx.tablesStatus=='ERROR'and not h.c:snapshot().vtx.tablesReady,'malformed band cannot masquerade as complete table')
check(not h.c:applyVtx({pit=false}),'incomplete/invalid table blocks apply')
h.queue[#h.queue+1]={kind=0x10,data={236,14,22,168,0}}
h:tick(h.now+1);check(h.forwarded==1,'non-MSP reports go to optional bounded dispatcher hook')

h=ready();h.pushOk=false;check(h.c:applyVtx({pit=false}),'busy transport queues request')
local started=h.now;h:pump(function(st)return st.vtx.operation.state=='FAILED'end,3100)
check(h.c:snapshot().vtx.operation.error=='TRANSACTION TIMEOUT'and not h.c:snapshot().vtx.operation.uncertain,'permanent backpressure has absolute deadline with no sent-write claim')
check(h:count(89)==0 and h.now-started<=3050,'busy operation never sends/floods')

print('PASS: '..(checks+fixture.checks())..' assertions: real BF identity/sensors/VTX tables, explicit false PIT, write/save/readback outcomes, rejection/retry/mismatch/cancel/guards, UID cache and bounded work (synthetic FC only)')
