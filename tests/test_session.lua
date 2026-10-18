-- Exercise the actual session factory with explicit current-data fixtures.
-- No radio, telemetry producer or native timer is changed by this portable test.
local factory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/session.lua'))()
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function near(a,b,epsilon,why)check(type(a)=='number' and math.abs(a-b)<=(epsilon or 0.00001),why)end
local function settings(extra)
 local result={modelId='AOS5',sourceId='LIVE / CRSF',autoHome=0,homeSats=8,trail=90,timerIndex=0}
 for k,v in pairs(extra or {})do result[k]=v end
 return result
end
local function data(lat,lon,extra)
 local result={gps=lat and {lat=lat,lon=lon} or nil,sats=13,speed=0,alt=0,hdg=0,armed=false}
 for k,v in pairs(extra or {})do result[k]=v end
 return result
end

-- GPS is updated by update(), with no dependence on a screen or draw callback.
local date={year=2026,mon=10,day=17,hour=12,min=34,sec=56}
local dateReads=0
local app=factory.new({getDateTime=function()dateReads=dateReads+1;return date end})
local cfg=settings({autoHome=1})
local input=data(0,0,{reportedPct=91,pct=80,capacity=1500})
local s=app.update(0,input,cfg)
check(s==app.snapshot(),'snapshot is the stable session view')
check(s.current.lat==0 and s.current.lon==0,'valid zero coordinates are current')
check(s.lastKnown~=s.current and s.lastKnown~=input.gps,'last-known state has its own owned coordinate table')
check(s.home and s.home.source=='LOCAL AUTO','auto home is explicitly local, not an FC home/fix claim')
check(s.home.satsAtSet==13 and s.home.tick==0,'home retains count and capture tick as metadata')
check(s.home.fix==nil and s.fix==nil and s.hdop==nil,'count-based local capture never invents fix or HDOP')
check(#s.track==1 and s.track[1].tick==0 and s.track[1].seconds==0,'history has explicit timestamps, including zero')
check(s.track[1].dateTime~=date and s.track[1].dateTime.sec==56,'optional wall clock is copied into the history point')
check(s.speed==0 and s.alt==0 and s.hdg==0,'genuine scalar zero is retained')
check(input.reportedPct==91 and input.pct==80 and input.capacity==1500 and s.pct==nil,'raw/derived power values remain external and unchanged')
input.gps.lat=55;date.sec=1
check(s.current.lat==0 and s.lastKnown.lat==0 and s.home.lat==0 and s.track[1].lat==0,'all coordinate ownership is independent from caller mutation')
check(s.track[1].dateTime.sec==56,'history wall clock is independent from caller mutation')

-- Current, last-known and local home have distinct freshness/lifetime semantics.
local home=s.home
local ownedCurrent,ownedLast=s.current,s.lastKnown
app.update(5,data(0,0.000001),cfg)
check(s.current==ownedCurrent and s.lastKnown==ownedLast,'moving GPS updates owned point storage without allocating replacements each sample')
app.update(10,{gps={lat=0,lon=0},gpsCurrent=false},cfg)
check(s.current==nil and s.lastKnown.lat==0 and s.lastKnown.lon==0.000001 and s.home==home,'stale GPS clears current but retains last-known/home')
check(s.homeDistance==nil and s.homeBearing==nil,'stale current GPS cannot present live home navigation')
check(s.speed==nil and s.alt==nil and s.hdg==nil and s.sats==nil,'missing scalar inputs do not reuse old values')
local ok,why=app.setHome()
check(ok==false and why=='NO CURRENT GPS' and s.home==home,'manual home cannot use a stale last-known coordinate')
for _,bad in ipairs({{lat=91,lon=0},{lat=-91,lon=0},{lat=0,lon=181},{lat=0,lon=-181},{lat=0/0,lon=0},{lat=0,lon=math.huge},{lat='0',lon=0},{lat=0}})do
 app.update(11,{gps=bad},cfg)
 check(s.current==nil and s.lastKnown.lat==0,'invalid/NaN/infinite/out-of-range coordinates are rejected')
end
app.update(100,data(0,0.001),cfg)
near(s.homeDistance,111.1949266,0.01,'home distance uses real spherical coordinates')
near(s.homeBearing,270,0.001,'home bearing points from current aircraft toward home')
check(s.home==home,'auto home does not follow the moving aircraft')
check(app.setHome()==true,'manual home captures a current valid coordinate')
check(s.home.source=='LOCAL MANUAL' and s.home.lon==0.001,'manual home exposes honest local provenance')
check(#s.track==0 and s.homeDistance==0 and s.homeBearing==nil,'manual home starts a new local trail and has no invented zero-distance bearing')

-- Count thresholds are explicitly heuristics; optional arming requirement is independent.
local gated=factory.new()
local gateCfg=settings({autoHome=1,homeRequiresArmed=1})
gated.update(0,data(1,2),gateCfg)
check(not gated.snapshot().home,'optional arm gate blocks disarmed automatic local home')
gated.update(100,data(1,2,{armed=true,sats=7}),gateCfg)
check(not gated.snapshot().home,'configured minimum satellites is respected')
gated.update(200,data(1,2,{armed=true,sats=8}),gateCfg)
check(gated.snapshot().home.source=='LOCAL AUTO','threshold equality and known armed state permit local home')
local noCount=factory.new()
noCount.update(0,{gps={lat=1,lon=2},armed=true},settings({autoHome=1}))
check(noCount.snapshot().current and not noCount.snapshot().home,'a coordinate alone never invents satellite count/fix for auto home')

local noFix=factory.new()
noFix.update(0,data(1,2,{fix=false}),settings({autoHome=1}))
check(noFix.snapshot().fix==false and not noFix.snapshot().home,'Genuine no-fix blocks count-based auto home')
check(noFix.snapshot().current==nil and noFix.snapshot().lastKnown==nil and #noFix.snapshot().track==0,'reported no-fix coordinates cannot become current, last-known or historical navigation')
local fixOk,fixWhy=noFix.setHome();check(not fixOk and fixWhy=='NO REPORTED GNSS FIX','Genuine no-fix blocks manual home')
noFix.update(100,data(1,2,{fix=true}),settings({autoHome=1}))
check(noFix.snapshot().fix==true and noFix.snapshot().home,'A reported fix permits valid home acquisition')
local fixed=noFix.snapshot();local fixedHome=fixed.home;local fixedKnown=fixed.lastKnown;local fixedTrack=fixed.track;local fixedTick=fixed.lastKnown.tick
noFix.update(200,data(1.1,2.1,{fix=false}),settings({autoHome=1}))
check(fixed.fix==false and fixed.current==nil and fixed.lastKnown==fixedKnown and fixed.lastKnown.lat==1 and fixed.lastKnown.lon==2 and fixed.lastKnown.tick==fixedTick,'known no-fix never overwrites the last accepted location or receipt timestamp')
check(fixed.home==fixedHome and fixed.track==fixedTrack and #fixed.track==1 and fixed.homeDistance==nil and fixed.homeBearing==nil,'fix loss retains prior home/history but clears current bearing/distance and adds no invalid track point')
fixOk,fixWhy=noFix.setHome();check(not fixOk and fixWhy=='NO REPORTED GNSS FIX'and fixed.home==fixedHome,'manual no-fix error remains specific after current coordinates are gated')
noFix.update(300,data(1.1,2.1,{fix=true}),settings({autoHome=1}))
check(fixed.current and fixed.current.lat==1.1 and fixed.lastKnown.lat==1.1 and fixed.lastKnown.tick==300 and #fixed.track==2 and fixed.homeDistance>0,'a fresh reported fix resumes current navigation against retained local home')

-- Normalize owned coordinates to floats so the native int32/float32 VM never
-- compares old fractional values to integer zero when detecting motion.
local fractions=factory.new();local fractionCfg=settings({autoHome=1})
fractions.update(0,data(0,0),fractionCfg)
fractions.update(100,data(0.1,0.1),fractionCfg)
check(#fractions.snapshot().track==2 and fractions.snapshot().homeDistance>10000,'subdegree movement from integer zero updates real geometry and track')
fractions.update(200,data(0,0),fractionCfg)
check(#fractions.snapshot().track==3 and fractions.snapshot().current.lat==0 and fractions.snapshot().lastKnown.lon==0 and fractions.snapshot().homeDistance==0 and fractions.snapshot().homeBearing==nil,'returning fractional coordinates to integer zero invalidates geometry and records movement')

-- Histories are bounded, <=1 Hz, movement-deduplicated and independent of rendering.
local bounded=factory.new({maxHistory=3,getDateTime=function()dateReads=dateReads+1;return date end})
local boundedCfg=settings({trail=999999})
local startDates=dateReads
for tick=0,1000 do bounded.update(tick,data(1,tick/100000),boundedCfg)end
local b=bounded.snapshot()
check(#b.track==3 and b.track[1].tick==800 and b.track[3].tick==1000,'hard maximum bounds retained history in chronological order')
check(dateReads-startDates==11,'clock metadata is sampled only with actual bounded history writes')
check(b.track[1].clockEpoch==0 and b.track[3].seconds==10,'history records the current clock epoch and seconds')
local n=#b.track
for tick=1001,2000 do bounded.update(tick,data(1,0.01),boundedCfg)end
check(#b.track==n and b.track[3].tick==1000,'stationary samples do not waste history or retimestamp old trail points')
check(b.lastKnown.tick==2000 and b.current.tick==2000,'stationary current/last-known freshness still advances')
bounded.update(2100,data(1,0.02),settings({trail=1}))
check(#b.track==1 and b.track[1].lon==0.02,'a reduced history setting shrinks existing history and preserves the latest changed point')
bounded.update(2200,data(1,0.03),settings({trail=-50}))
check(#b.track==1,'invalid low trail length cannot remove the final bounded point')
local interval=factory.new({historyInterval=1,maxHistory=2})
for tick=0,99 do interval.update(tick,data(2,tick/1000),settings())end
check(#interval.snapshot().track==1,'caller cannot configure a faster-than-1Hz history loop')

-- Real elapsed time does not clamp long gaps to one second or bridge uncertainty.
local elapsed=factory.new();local elapsedCfg=settings()
elapsed.update(0,{armed=true},elapsedCfg)
elapsed.update(550,{armed=true},elapsedCfg)
near(elapsed.snapshot().flightSeconds,5.5,nil,'a continuously armed 5.5s gap counts the full delta')
elapsed.update(650,{armed=false},elapsedCfg)
check(elapsed.snapshot().armed==false,'explicit false remains disarmed rather than unknown')
near(elapsed.snapshot().flightSeconds,5.5,nil,'an uncertain transition interval is not assumed fully armed')
elapsed.update(750,{armed=true},elapsedCfg);elapsed.update(850,{armed=true},elapsedCfg)
near(elapsed.snapshot().flightSeconds,6.5,nil,'a new known armed interval resumes elapsed time')
elapsed.update(950,{},elapsedCfg);elapsed.update(1050,{armed=true},elapsedCfg)
near(elapsed.snapshot().flightSeconds,6.5,nil,'unknown arm state breaks continuity instead of counting unseen flight')
elapsed.update(1150,{armed='ACTIVE'},elapsedCfg)
check(elapsed.snapshot().armed==nil,'truthy strings are not accepted as an actual arm state')
elapsed.update(1250,{armed=true},elapsedCfg);elapsed.update(1350,{armed=true},elapsedCfg)
near(elapsed.snapshot().flightSeconds,7.5,nil,'explicit boolean state is required on both interval ends')
elapsed.update(1350,{armed=true},elapsedCfg)
near(elapsed.snapshot().flightSeconds,7.5,nil,'duplicate callbacks do not double-count elapsed time')
elapsed.update(20,{armed=true},elapsedCfg)
near(elapsed.snapshot().flightSeconds,7.5,nil,'clock rollback does not add negative or wrapped elapsed time')
check(elapsed.snapshot().clockEpoch==1,'clock rollback is explicitly recorded for timestamp interpretation')
elapsed.update(120,{armed=true},elapsedCfg)
near(elapsed.snapshot().flightSeconds,8.5,nil,'elapsed resumes against the new clock origin')
local stable=elapsed.snapshot()
elapsed.update(0/0,{armed=true},elapsedCfg);elapsed.update(math.huge,{armed=true},elapsedCfg)
check(elapsed.snapshot()==stable and stable.flightSeconds==8.5,'invalid timestamps leave state intact')

-- Owner changes reset session-local state without issuing native reset callbacks.
local resetCalls,newFlightCalls,timerResets=0,0,{}
local owners=factory.new({onReset=function()resetCalls=resetCalls+1 end,onNewFlight=function()newFlightCalls=newFlightCalls+1 end,resetTimer=function(i)timerResets[#timerResets+1]=i end})
owners.update(0,data(1,2,{armed=true}),settings({autoHome=1}))
owners.update(500,data(1,2,{armed=true}),settings({autoHome=1}))
owners.setMuted(true)
owners.update(600,{},settings({modelId='OTHER'}))
local owner=owners.snapshot()
check(owner.modelId=='OTHER' and owner.home==nil and owner.lastKnown==nil and #owner.track==0 and owner.flightSeconds==0,'model owner change clears previous local flight state')
check(owner.resetReason=='MODEL CHANGED' and not owner.muted,'model reset also clears the previous model mute state')
owners.update(700,data(3,4),settings({modelId='OTHER',autoHome=1}))
owners.update(800,{},settings({modelId='OTHER',sourceId='OTHER SOURCE'}))
check(owner.resetReason=='SOURCE CHANGED' and owner.home==nil and owner.lastKnown==nil,'source owner change clears previous GPS history/home')
check(resetCalls==0 and newFlightCalls==0 and #timerResets==0,'identity changes never invoke explicit or native reset callbacks')
owners.setMuted(true)
check(owners.toggleMuted()==false and owners.toggleMuted()==true,'mute toggles belong to the session instance')
owners.setMuted(1);check(not owner.muted,'mute setter only accepts an explicit boolean true')
local independent=factory.new()
check(not independent.snapshot().muted and #independent.snapshot().track==0,'separate factory instances have no shared global state')
owners.reset()
check(resetCalls==1 and newFlightCalls==0 and owner.resetReason=='EXPLICIT RESET','explicit reset invokes only its own injected callback')
owners.newFlight()
check(newFlightCalls==1 and resetCalls==1 and #timerResets==0,'new flight never implicitly resets an OS timer')

-- Read native model timers 1..3 at <=1Hz using their zero-based API indices.
local timerCalls={};local timerValue={name='Flight',value=0,start=0,mode=1,nested={unsafe=true}}
local timers=factory.new({getTimer=function(index)timerCalls[#timerCalls+1]=index;return timerValue end,resetTimer=function(index)timerResets[#timerResets+1]=index end})
for _,index in ipairs({0,-1,4,1.5,'1'})do timers.update(0,{},settings({timerIndex=index}))end
timers.update(0,{},settings());timers.update(0,{}, {})
check(#timerCalls==0 and timers.snapshot().modelTimer==nil,'nil/0/invalid selected timer performs no native API call')
for tick=0,299 do timers.update(tick,{},settings({timerIndex=1}))end
check(#timerCalls==3 and timerCalls[1]==0,'selected Timer1 reads native index0 only once each100ticks')
local timer=timers.snapshot().modelTimer
check(timer.value==0 and timer.index==1 and timer.sampleTick==200,'native zero timer value is valid and selected index/time explicit')
check(timer~=timerValue and timer.nested==nil,'snapshot never exposes caller-owned mutable nested timer state')
timerValue.value=99;check(timer.value==0,'a cached timer value cannot be changed through the producer table')
timers.update(300,{},settings({timerIndex=2}));timers.update(301,{},settings({timerIndex=3}))
check(timerCalls[4]==1 and timerCalls[5]==2,'changing timer selection polls the new native index immediately')
timers.update(302,{},settings({timerIndex=0}))
check(timers.snapshot().modelTimer==nil,'disabling timer clears the old native timer presentation')
check(#timerResets==0,'timer reads never issue timer resets')
timers.update(303,{},settings({timerIndex=3}))
check(timers.newFlight()==true and #timerResets==0,'ordinary new flight still does not reset the selected model timer')
timers.update(304,{},settings({timerIndex=3}))
check(timers.newFlight({resetModelTimer=true})==true and timerResets[1]==2,'only explicit request resets exactly the selected native model timer')
timers.update(305,{},settings({timerIndex=0}))
local resetOK,resetWhy=timers.newFlight({resetModelTimer=true})
check(resetOK==false and resetWhy=='NO MODEL TIMER SELECTED' and #timerResets==1,'no selected timer means no guessed reset target')

-- A GPS provider change has navigation ownership, not ownership of flight timing.
local sourceTimerReads=0
local sourceOwner=factory.new({getTimer=function()sourceTimerReads=sourceTimerReads+1;return {value=17}end})
local firstSource=settings({autoHome=1,timerIndex=1})
sourceOwner.update(0,data(1,2,{armed=true}),firstSource)
sourceOwner.update(50,data(1,2,{armed=true}),firstSource)
sourceOwner.setMuted(true)
local sourceState=sourceOwner.snapshot();local oldTimer=sourceState.modelTimer
sourceOwner.update(75,{armed=true},settings({sourceId='GPS PROVIDER 2',timerIndex=1}))
check(sourceState.home==nil and sourceState.current==nil and sourceState.lastKnown==nil and #sourceState.track==0,'GPS provider change clears only that provider navigation state')
near(sourceState.flightSeconds,0.75,nil,'GPS provider change preserves the continuously armed elapsed interval')
check(sourceState.muted and sourceState.modelTimer==oldTimer and sourceTimerReads==1,'GPS provider change preserves mute and cached native model timer without another API read')

-- Invalid or failing explicit timer actions cannot erase a local home/history.
local atomic=factory.new({resetTimer=function()error('timer refused')end,onNewFlight=function()newFlightCalls=newFlightCalls+1 end})
atomic.update(0,data(1,2),settings({autoHome=1,timerIndex=1}))
local atomicState=atomic.snapshot();local atomicHome=atomicState.home;local atomicTrack=atomicState.track
local beforeNewFlight=newFlightCalls
check(atomic.newFlight({resetModelTimer=true})==false,'native reset failure is returned')
check(atomicState.home==atomicHome and atomicState.track==atomicTrack and newFlightCalls==beforeNewFlight,'failed native reset preserves session and does not trigger subsequent reset callback')
local unselected=factory.new()
unselected.update(0,data(1,2),settings({autoHome=1}))
local unselectedHome=unselected.snapshot().home
check(unselected.newFlight({resetModelTimer=true})==false and unselected.snapshot().home==unselectedHome,'missing timer target is validated before clearing local flight state')

-- API errors and malformed timer results are explicit and rate-bounded.
local failures=0
local broken=factory.new({getTimer=function()failures=failures+1;error('unavailable device')end})
for tick=0,199 do broken.update(tick,{},settings({timerIndex=1}))end
check(failures==2 and broken.snapshot().modelTimer==nil and broken.snapshot().timerError:match('unavailable device'),'failed timer read is throttled and does not fabricate a value')
local invalid=factory.new({getTimer=function()return {value=0/0}end})
invalid.update(0,{},settings({timerIndex=1}))
check(invalid.snapshot().timerError=='INVALID TIMER' and invalid.snapshot().modelTimer==nil,'NaN/native malformed timer values remain unavailable')
local noAPI=factory.new();noAPI.update(0,{},settings({timerIndex=1}))
check(noAPI.snapshot().timerError=='TIMER API UNAVAILABLE','missing native timer API is an explicit optional capability state')
check(noAPI.newFlight({resetModelTimer=true})==false and noAPI.snapshot().lastError=='TIMER RESET API UNAVAILABLE','native timer reset cannot fall back to an unapproved mechanism')
local rejected=factory.new({onNewFlight=function()return false,'reset rejected' end})
check(rejected.newFlight()==false and rejected.snapshot().lastError=='reset rejected','explicit reset callback rejection is visible')

-- Wrap near the date line uses a short local distance rather than a world-spanning one.
-- Explicit binary32 coordinates are identical inputs on native and host Lua.
-- Independent equatorial arc:2*(180-179.998992919921875)*pi/180*6371000
-- =223.964399669m. Half a metre allows native float32 trig argument reduction,
-- while still rejecting long-way-around or degree/radian/unit mistakes.
local wrap=factory.new();wrap.update(0,data(0,179.998992919921875),settings());wrap.setHome()
wrap.update(100,data(0,-179.998992919921875),settings())
near(wrap.snapshot().homeDistance,223.964399669,0.5,'antimeridian position changes preserve correct local distance at native coordinate/trig precision')
near(wrap.snapshot().homeBearing,270,0.001,'antimeridian home bearing uses the short path')

-- Measure real geometry calls, so a static warm frame cannot rerun trigonometry.
local trigCalls=0;local countedMath={}
for key,value in pairs(math)do countedMath[key]=value end
for _,name in ipairs({'sin','cos','atan','sqrt'})do
 local original=math[name]
 countedMath[name]=function(...)trigCalls=trigCalls+1;return original(...)end
end
local environment=setmetatable({math=countedMath},{__index=_G})
local countedChunk
if setfenv then countedChunk=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/session.lua'));setfenv(countedChunk,environment)
else countedChunk=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/session.lua','t',environment))end
local counted=countedChunk().new()
counted.update(0,data(2,3),settings({autoHome=1}))
check(trigCalls==0,'a home captured exactly at current position needs no trigonometric recomputation')
counted.update(100,data(2,3.001),settings({autoHome=1}))
check(trigCalls>0,'moving coordinate causes the real navigation geometry to be evaluated')
local warmTrig=trigCalls
for tick=101,500 do counted.update(tick,data(2,3.001),settings({autoHome=1}))end
check(trigCalls==warmTrig,'unchanged coordinate/home pair reuses geometry across warm samples')
local savedDistance=counted.snapshot().homeDistance
counted.update(501,{},settings({autoHome=1}))
check(counted.snapshot().homeDistance==nil,'cached geometry cannot survive into a stale current-state presentation')
counted.update(502,data(2,3.001),settings({autoHome=1}))
check(trigCalls==warmTrig and counted.snapshot().homeDistance==savedDistance,'same coordinate returning current reuses geometry without showing stale values')
counted.setHome();counted.update(503,data(2,3.001),settings({autoHome=1}))
check(counted.snapshot().homeDistance==0 and trigCalls==warmTrig,'manual home invalidates prior geometry using the known zero-distance case')

print('session: '..checks..' checks passed')
