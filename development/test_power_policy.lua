-- Test actual pure battery policy. All telemetry is explicit synthetic current
-- data; no native sensor, timer, audio, model or filesystem function is invoked.
local M=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/power-policy.lua'))()
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function near(value,expected,why)check(type(value)=='number' and math.abs(value-expected)<0.00001,why)end
local thresholds={noPower=2.7,min=3,critical=3.4,low=3.6,max=4.2}
local function cfg(extra)
 local c={cells=6,profile=0,thresholds=thresholds,alertType=3,audible=2,modelId='AOS5',sourceId='CRSF'}
 for k,v in pairs(extra or {})do c[k]=v end;return c
end
local function d(v,extra)
 local data={v=v,a=0,mah=0,reportedPct=91}
 for k,value in pairs(extra or {})do data[k]=value end;return data
end

-- Explicit adapter for current ADBAT1 units/enumerations; no silent settings edit.
local original={6,27,30,34,36,42,3,0}
local legacy=M.fromLegacy(original,{modelId='AOS5',profile=2})
check(legacy.cells==6 and legacy.thresholds.noPower==2.7 and legacy.thresholds.max==4.2,'legacy decivolt thresholds become volts explicitly')
check(legacy.alertType==3 and legacy.audible==1 and legacy.profile==2,'legacy audible0 means critical-only in module enumeration')
original[8]=1;check(M.fromLegacy(original).audible==2,'legacy audible1 means critical+low')
check(original[2]==27 and original[6]==42,'adapter never modifies persisted values')
check(M.fromLegacy({6,27,30,36,34,42,3,0})==nil,'invalid legacy threshold ordering stays explicit')

-- Original bounded1..6 inference, honest uncertainty, float32 boundary tolerance.
for cells=1,6 do
 local v=4.2*cells
 local count,source=M.inferCells(v,4.2,2.7)
 check(count==cells and source=='VOLTAGE ESTIMATE','full-pack inference exactly at '..cells..'S threshold')
end
check(M.inferCells(25.200000762939453,4.2,2.7)==6,'nativefloat32 maximum6S boundary does not become a fabricated1S fallback')
check(M.inferCells(25.206,4.2,2.7)==nil,'meaningful above-range pack stays unknown, not1S')
for _,v in ipairs({0,2,2.7,2.700000047683716})do local c,e=M.inferCells(v,4.2,2.7);check(c==nil and e=='NO POWER','no current power does not imply a physical1S cell count')end
for _,v in ipairs({-1,0/0,math.huge,'25.2'})do check(M.inferCells(v,4.2,2.7)==nil,'invalid voltage never infers cells')end
check(M.inferCells(nil,4.2,2.7)==nil,'missing voltage remains unknown')

-- Automatic inference latches through discharge/stale gaps, owns reset boundaries.
local auto=M.new();local acfg=cfg({cells=0})
local state=auto.update(0,d(25.2),acfg)
check(state==auto.snapshot() and state.cells==6 and state.cellsEstimated and state.cellSource=='VOLTAGE ESTIMATE','auto count is session metadata with explicit estimate provenance')
auto.update(100,d(16.8),acfg)
check(state.cells==6 and state.condition=='BELOW MIN','discharged6S is never silently reclassified4S mid-flight')
auto.update(200,{},acfg)
check(state.cells==6 and state.averageCell==nil and state.condition=='NO DATA','stale gap preserves estimated identity but removes current cell measurement')
auto.update(300,d(16.8),acfg);check(state.cells==6,'same pack remains latched after telemetry recovers')
auto.update(400,d(0),acfg)
check(state.cells==nil and state.condition=='NO POWER','genuine current no-power clears inferred pack identity')
auto.update(500,d(16.8),acfg);check(state.cells==4,'current reconnection can infer a new4S pack')
auto.reset();auto.update(600,d(25.2),acfg);check(state.cells==6,'explicit new flight reset allows new inference')
auto.update(700,d(16.8),cfg({cells=0,sourceId='OTHER GPS-POWER FEED'}))
check(state.cells==4,'explicit battery source change resets inferred cell ownership')
auto.update(800,d(25.2),cfg({cells=0,modelId='OTHER MODEL'}))
check(state.cells==6,'model identity change resets inferred pack ownership')
local unknown=M.new();unknown.update(0,d(30),acfg)
check(unknown.snapshot().cells==nil and unknown.snapshot().condition=='UNKNOWN CELLS','out-of-auto-range value has explicit unknown cells')
local manual=M.new();manual.update(0,d(44.4),cfg({cells=12}))
check(manual.snapshot().cells==12 and not manual.snapshot().cellsEstimated and manual.snapshot().cellSource=='MANUAL','explicit manual count supports12S independently of1..6 automatic inference')

-- Five enabled/chemistry favourites; no inferred chemistry voltage curve.
local profiles={
 {chemistry='OFF',cells=6,capacity=1500},
 {chemistry='LIPO',cells=6,capacity=1500},
 {chemistry='LIION',cells=6,capacity=1500},
 {chemistry='LIPO',cells=99,capacity=100000},
 {chemistry='LIPO',cells=4,capacity=850,enabled=false}
}
local favourites=M.favourites(profiles)
check(#favourites==3 and favourites[1].id==2 and favourites[2].chemistry=='LIION' and favourites[3].cells==99,'quick chooser exposes only enabled favourites and preserves indices/chemistry/limits')
favourites[1].cells=1;check(profiles[2].cells==6,'favourite list does not mutate settings through shared records')
local lipo,liion=M.new(),M.new()
local lp=lipo.update(0,d(21.6,{mah=300}),cfg({profile=2,profiles=profiles}))
local li=liion.update(0,d(21.6,{mah=300}),cfg({profile=3,profiles=profiles}))
check(lp.chemistry=='LIPO' and li.chemistry=='LIION' and lp.condition==li.condition and lp.cell==li.cell,'chemistry metadata cannot secretly change voltage thresholds/curves')
check(lp.cells==6 and lp.cellSource=='FAVOURITE' and lp.profileId==2,'selected favourite supplies known configured cell count')
check(lp.capacity==1500 and lp.remainingMah==1200 and lp.derivedPct==80 and lp.displayPct==80 and lp.pctEstimated,'current consumed mAh derives capacity-based remaining')
check(lp.reportedPct==91,'reportedBat% remains independent from derived profile percent')
lipo.update(100,d(21.6,{mah=0,reportedPct=0}),cfg({profile=2,profiles=profiles}))
check(lp.reportedPct==0 and lp.remainingMah==1500 and lp.derivedPct==100,'real0 consumption/percentage survive without conflating reported and derived values')
lipo.update(200,d(21.6,{mah=1600}),cfg({profile=2,profiles=profiles}))
check(lp.remainingMah==0 and lp.derivedPct==0,'capacity consumption above the profile is bounded at zero remaining')
lipo.update(300,{v=21.6,reportedPct=91},cfg({profile=2,profiles=profiles}))
check(lp.capacity==1500 and lp.remainingMah==nil and lp.derivedPct==nil and lp.displayPct==91 and not lp.pctEstimated,'missing current Capa never fabricates full remaining capacity')
lipo.update(400,d(21.6,{mah=0,consumedCurrent=false}),cfg({profile=2,profiles=profiles}))
check(lp.remainingMah==nil and lp.derivedPct==nil,'stale consumed0 cannot create a fictitious100% pack')
lipo.update(500,d(21.6),cfg({profile=0,profiles=profiles}))
check(lp.capacity==nil and lp.remainingMah==nil and lp.derivedPct==nil and lp.displayPct==91,'leaving favourite mode clears all derived capacity state')
lipo.update(600,d(21.6),cfg({profile=1,profiles=profiles}))
check(lp.condition=='PROFILE OFF' and lp.cells==nil and lp.capacity==nil,'disabled favourite cannot silently apply hidden settings')
lipo.update(700,d(366.3),cfg({profile=4,profiles=profiles}))
check(lp.cells==99 and lp.capacity==100000,'explicit favourite spec supports99S/100000mAh without an automatic hardware claim')
local invalid=M.new()
for _,case in ipairs({cfg({cells=13}),cfg({profile=6}),cfg({alertType=4}),cfg({audible=3}),cfg({thresholds={noPower=3,min=2,critical=3.4,low=3.6,max=4.2}})})do
 invalid.update(0,d(22.8),case);check(invalid.snapshot().condition=='INVALID CONFIG','bad policy config never runs an alarm using invented settings')
end

-- Exact threshold inclusivity, with nativefloat32-style max noise quantized away.
local boundary=M.new()
for _,case in ipairs({
 {2.7,'NO POWER'},{2.999,'BELOW MIN'},{3,'CRITICAL'},{3.4,'CRITICAL'},{3.401,'LOW'},
 {3.6,'LOW'},{3.601,'OK'},{4.2,'OK'},{4.201,'ABOVE MAX'}
})do boundary.update(0,d(case[1]*6),cfg({alertType=0}));check(boundary.snapshot().condition==case[2],'per-cell threshold boundary '..case[1]..'→'..case[2])end
boundary.update(0,d(25.200000762939453),cfg({alertType=0}))
check(boundary.snapshot().condition=='OK','exact25.2V/6S float32 sample does not raise above-max warning')
boundary.update(0,d(25.206),cfg({alertType=0}));check(boundary.snapshot().condition=='ABOVE MAX','meaningful+6mV pack delta still raises above-max warning')
boundary.update(0,d(21.6,{reportedCell=3.3}),cfg({alertType=0}))
near(boundary.snapshot().averageCell,3.6,'current pack average respects physical units within native float32 division precision')
check(boundary.snapshot().cell==3.3 and boundary.snapshot().cellProvenance=='REPORTED CELL','genuine reported cell measurement stays distinct from pack average')
boundary.update(0,d(21.6,{reportedCell=3.3,reportedCellCurrent=false}),cfg({alertType=0}))
check(boundary.snapshot().cellProvenance=='PACK / CONFIGURED CELLS','stale reported cell cannot override current derived pack average')
near(boundary.snapshot().cell,3.6,'pack average after stale direct cell respects native float32 division precision')

-- Native warning patterns/cadence are bounded under normal updates and jitter.
local alerts={};local alarms=M.new({onAlert=function(event)alerts[#alerts+1]=event end})
local alarmState=alarms.update(0,d(20.4),cfg())
check(#alerts==1 and alarmState.alertDue and alarmState.nextAlertAt==400,'first critical warning is immediate and next due is4s')
check(alerts[1].kind=='CRITICAL' and #alerts[1].tones==4 and #alerts[1].haptics==2,'critical warning exposes original four-tone/two-haptic pattern')
check(alerts[1].tones[1].frequency==4000 and alerts[1].tones[2].frequency==5000 and alerts[1].tones[1].durationMs==24 and alerts[1].tones[1].pauseMs==100,'critical native tone arguments preserve literal milliseconds from original source')
check(alerts[1].haptics[1].nativeDuration==10 and alerts[1].haptics[1].nativePause==150 and alerts[1].haptics[1].heartbeatMs==5 and alerts[1].haptics[1].durationMs==nil,'haptic original native arguments remain distinct from milliseconds and include5ms heartbeat provenance')
for tick=1,399 do alarms.update(tick,d(20.4),cfg())end
check(#alerts==1 and not alarmState.alertDue,'foreground sample rate cannot flood critical warning repeats')
alarms.update(400,d(20.4),cfg());check(#alerts==2 and alarmState.nextAlertAt==800,'critical repeat fires at exactly4s')
alarms.update(450,d(21.6),cfg());check(#alerts==3 and alerts[3].kind=='LOW' and alarmState.nextAlertAt==1050,'low warning owns its6s cadence independently')
check(#alerts[3].tones==2 and alerts[3].tones[1].pauseMs==200 and #alerts[3].haptics==1 and alerts[3].haptics[1].interrupt,'low native sound/haptic pattern is distinct')
for tick=451,799 do alarms.update(tick,d(tick%2==0 and 20.4 or 21.6),cfg())end
check(#alerts==3,'critical/low threshold jitter cannot re-arm tones on every frame')
alarms.update(800,d(20.4),cfg());check(#alerts==4 and alerts[4].kind=='CRITICAL','critical cooldown survives intervening low samples')
alarms.update(1050,d(21.6),cfg());check(#alerts==5 and alerts[5].kind=='LOW','low cooldown survives intervening critical samples')
alarms.update(2000,d(20.4),cfg({muted=true}))
check(#alerts==5 and alarmState.condition=='CRITICAL' and alarmState.muted and alarmState.nextAlertAt==nil,'mute stops emitted alerts but never hides the visual condition')
alarms.update(2001,d(20.4),cfg());check(#alerts==6,'unmute resumes current warning after elapsed cooldown')
alarms.update(10000,d(20.4),cfg());check(#alerts==7,'a long suspended gap emits one current event, never a catch-up burst')
alarms.update(0,d(20.4),cfg());check(#alerts==8,'clock rollback resets cadence without a long false suppression')

-- Original alert-type/audible selection and disabled/stale/no-power boundaries.
for alertType=0,3 do
 local events={};local policy=M.new({onAlert=function(e)events[#events+1]=e end})
 policy.update(0,d(20.4),cfg({alertType=alertType,audible=1}))
 check(#events==(alertType==0 and 0 or 1),'visual-only versus emitted critical alert type '..alertType)
 if alertType>0 then check(events[1].sound==(alertType==1 or alertType==3) and events[1].haptic==(alertType==2 or alertType==3),'independent sound/haptic selection '..alertType)end
 policy.update(1000,d(21.6),cfg({alertType=alertType,audible=1}))
 check(#events==(alertType==0 and 0 or 1),'critical-only suppresses low sound and haptic as original')
end
local none={};local silent=M.new({onAlert=function(e)none[#none+1]=e end})
for _,case in ipairs({
 {data=d(0),config=cfg(),condition='NO POWER'},
 {data=d(20.4,{telemetryCurrent=false}),config=cfg(),condition='NO DATA'},
 {data=d(20.4,{voltageCurrent=false}),config=cfg(),condition='NO DATA'},
 {data=d(20.4),config=cfg({enabled=false}),condition='DISABLED'},
 {data=d(20.4),config=cfg({audible=0}),condition='CRITICAL'},
 {data=d(20.4),config=cfg({muted=true}),condition='CRITICAL'}
})do silent.update(0,case.data,case.config);check(silent.snapshot().condition==case.condition and #none==0,'disabled/stale/no-power/mute condition does not emit an alert')end
local failed=M.new({onAlert=function()error('audio queue unavailable')end})
failed.update(0,d(20.4),cfg());check(failed.snapshot().error:match('audio queue unavailable') and failed.snapshot().nextAlertAt==400,'callback exception remains bounded and explicit')

-- Voltage-range percentage is separate from reported/capacity charge data.
local range=M.new();local rangeState=range.snapshot()
range.update(0,d(22.8),cfg())
near(rangeState.voltagePct,100*0.8/1.2,'known average cell gives a native-threshold voltage-range fraction')
check(rangeState.voltagePctOrigin=='CELL VOLTAGE RANGE'and rangeState.displayPct==91 and rangeState.reportedPct==91,'voltage estimate is explicitly labelled and never substitutes for reported charge percent')
for _,case in ipairs({{18,0},{25.2,100},{17.4,0},{26,100}})do
 range.update(1,d(case[1]),cfg());near(rangeState.voltagePct,case[2],'voltage-range endpoints and clamping')
end
range.update(2,d(22.8),cfg({thresholds={noPower=2.7,min=3.2,critical=3.4,low=3.6,max=4.4}}))
near(rangeState.voltagePct,50,'threshold changes recalculate rather than retaining old range')
range.update(3,d(nil,{reportedCell=3.8}),cfg({cells=0}))
near(rangeState.voltagePct,100*0.8/1.2,'current direct cell can supply range without invented pack voltage/cell count')
check(rangeState.cellProvenance=='REPORTED CELL'and rangeState.v==nil,'direct cell provenance remains independent')
for _,case in ipairs({d(nil),d(0),d(22.8,{voltageCurrent=false}),d(nil,{reportedCell=3.8,reportedCellCurrent=false}),d(16.2),d(0,{reportedCell=3.8})})do
 range.update(4,case,cfg());check(rangeState.voltagePct==nil,'unknown/stale/no-power input clears previous voltage range estimate')
end
range.update(5,d(22.8),cfg({cells=0}));check(rangeState.voltagePct~=nil,'valid auto cells still provide an explicitly derived range')
range.update(6,d(100),cfg({cells=0,sourceId='OTHER'}));check(rangeState.voltagePct==nil and rangeState.condition=='UNKNOWN CELLS','outside auto range does not fabricate a cell percentage')
range.update(7,d(22.8,{mah=350,reportedPct=91}),cfg({profile=1,profiles={{chemistry=1,cells=6,capacity=1500}}}))
near(rangeState.voltagePct,100*0.8/1.2,'voltage range remains independent of capacity consumption')
near(rangeState.displayPct,1150/1500*100,'existing fractional capacity percentage remains unchanged')
check(rangeState.reportedPct==91 and rangeState.pctEstimated,'raw reported percent remains separate from both derived indications')
range.update(8,d(22.8),cfg({enabled=false}));near(rangeState.voltagePct,100*0.8/1.2,'disabling alerts does not hide observed voltage range')
range.reset();check(rangeState.voltagePct==nil,'explicit reset clears derived voltage range')
-- Malformed fractional configuration never becomes an integer via a mixed
-- number equality shortcut in the native Lua VM.
for _,extra in ipairs({{cells=6.5},{profile=0.5},{alertType=1.5},{audible=1.5}})do
 range.update(9,d(22.8),cfg(extra));check(rangeState.condition=='INVALID CONFIG'and rangeState.voltagePct==nil,'fractional config enums/counts rejected')
end
for _,profile in ipairs({{chemistry=1.5,cells=6,capacity=1500},{chemistry=1,cells=6.5,capacity=1500},{chemistry=2,cells=6,capacity=1500.5}})do
 range.update(10,d(22.8),cfg({profile=1,profiles={profile}}))
 check(rangeState.condition=='INVALID PROFILE'and rangeState.voltagePct==nil,'fractional favourite metadata cannot create a live battery profile')
 check(#M.favourites({profile})==0,'invalid favourite excluded from quick selection')
end
print('power-policy: '..checks..' checks passed')
