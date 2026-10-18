-- Actual main + actual owner/logger/store, native API/SD mocked by common app
-- harness. No production hook/fixture code and no physical hardware claim.
local adapter=assert(loadfile('tests/test_ui_navigation.lua'))('adapter')
local storeFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/model-store.lua'))()
local E=adapter.events
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function configured(lines)
 local timer={mode=5,value=67,start=120,countdownBeep=2,minuteBeep=true,persistent=2,name='USER TMR',showElapsed=true,switch=-17,countdownStart=1,extraHaptic=2}
 local a=adapter.make({filename='model1.yml',timers={[0]=timer}})
 local payload='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\ntimerIndex=1\nresetNativeTelemetry=0\n'..lines
 local store=storeFactory.new({io=io,remove=del,rename=rename})
 assert(store.save('settings',{filename='model1.yml',name='UITEST'},payload,function(raw)if string.sub(raw,1,7)=='ADCFG1\n' then return {}end end))
 a.reinit();a.send(0) -- Deliberate external-file reload, not a display rename.
 return a,timer
end
local a,timer=configured('timerHost=RADIO\nerrorLog=0\nresetModelTimer=0\n')
local sd=a.writes()
for i=1,50 do a.send(0);a.background(20)end
check(#a.timerWrites==0 and #a.timerResets==0 and timer.mode==5 and timer.value==67,'RADIO actual app preserves selected native timer configuration/value')
check(a.writes()==sd and not a.runtimeServices.log().enabled,'off log/shared foreground-background generate no SD writes')
a.arrange(12);a.send(E.EVT_TOUCH_TAP,{x=400,y=232});a.send(E.EVT_TOUCH_TAP,{x=400,y=232})
check(#a.timerResets==0,'Radio New Flight does not reset a timer unless its explicit reset option is enabled')
a,timer=configured('timerHost=AERODECK\nerrorLog=0\nresetModelTimer=1\n')
check(#a.timerWrites==2 and a.snapshot().timerOwner.owned and timer.mode==0 and timer.value==0 and timer.name==a.snapshot().timerOwner.leaseName,'actual app claims native lease once before applying native timer configuration')
a.setFlightMode('ACRO');a.settle()
check(timer.mode==1 and a.snapshot().timerOwner.armed==true,'current FC armed indication starts native owned timer')
local nativeWrites=#a.timerWrites;timer.value=23;a.background(120)
check(a.snapshot().timerOwner.owned and timer.mode==1 and #a.timerWrites==nativeWrites and timer.value==23,'background retains same native ownership/value without claim/repeated writes')
a.setFlightMode('ACRO*');a.settle()
check(timer.mode==0 and a.snapshot().timerOwner.armed==false,'current disarmed state pauses native owned timer')
a.arrange(12);a.send(E.EVT_TOUCH_TAP,{x=400,y=232});a.send(E.EVT_TOUCH_TAP,{x=400,y=232})
check(#a.timerResets==1 and timer.value==0,'confirmed New Flight invokes owned reset exactly once even with Radio-reset option also enabled')
a.setRetained(true);a.arrange(1);nativeWrites=#a.timerWrites;timer.value=44
check(a.send(E.EVT_VIRTUAL_EXIT)==1 and a.snapshot().timerOwner.owned and #a.timerWrites==nativeWrites,'retained widget fullscreen RTN returns1 without releasing/reclaiming native owner')
a.background(120);check(timer.value==44 and a.snapshot().timerOwner.owned and #a.timerWrites==nativeWrites,'retained compact/hidden callback continues native owner without resetting current value')
a.close()
check(not a.runtimeServices.timer().owned and timer.mode==5 and timer.value==44 and timer.start==120 and timer.name=='USER TMR','explicit close restores original timer settings/name while preserving elapsed value')
a,timer=configured('timerHost=AERODECK\nerrorLog=0\n')
a.arrange(1);timer.value=51
check(a.send(E.EVT_VIRTUAL_EXIT)==1 and not a.runtimeServices.timer().owned and timer.mode==5 and timer.value==51,'standalone tool RTN releases timer and preserves live value')
a,timer=configured('timerHost=AERODECK\nerrorLog=0\n')
nativeWrites=#a.timerWrites;a.setModelInfo({filename='model2.yml',name='SECOND MODEL'});a.background(120)
check(#a.timerWrites==nativeWrites and not a.snapshot().timerOwner.owned and a.snapshot().timerOwnershipWarning,'actual model switch never restores old native timer into new model and exposes loss warning')

-- Display names are captions, not native model identity. A rename must not
-- create another flight, reset ownership, write preferences or lose mute.
a,timer=configured('timerHost=AERODECK\nerrorLog=0\nautoHome=1\n')
a.setFlightMode('ACRO');a.settle();a.background(200)
local renamedSession=a.snapshot().session;local renamedHome=renamedSession.home
a.setSensor('GPS',{lat=renamedHome.lat+.001,lon=renamedHome.lon},true);a.background(120)
a.arrange(12);a.send(E.EVT_TOUCH_TAP,{x=210,y=232});a.arrange(1)
local renamedTrack=renamedSession.track;local renamedLast=renamedSession.lastKnown;local priorElapsed=renamedSession.flightSeconds
local priorOwner=a.snapshot().timerOwner;local priorTimerWrites=#a.timerWrites;local priorTimerResets=#a.timerResets;local priorSD=a.writes();timer.value=81
check(renamedHome and #renamedTrack>=2 and priorElapsed>0 and renamedSession.muted and priorOwner.owned,'rename regression starts with actual live home/history/elapsed/mute/native ownership')
a.setModelInfo({filename='model1.yml',name='NewName'});a.send(0)
check(a.snapshot().session==renamedSession and renamedSession.home==renamedHome and renamedSession.track==renamedTrack and renamedSession.lastKnown==renamedLast,'same-filename display rename retains the exact flight/navigation session objects')
check(renamedSession.flightSeconds>=priorElapsed and renamedSession.muted and #renamedTrack>=2,'display rename preserves elapsed time, mute and accumulated track')
check(a.snapshot().timerOwner==priorOwner and priorOwner.owned and timer.mode==1 and timer.value==81 and #a.timerWrites==priorTimerWrites and #a.timerResets==priorTimerResets,'display rename never releases/reclaims or resets an owned native timer')
check(a.writes()==priorSD and a.visible('NewName'),'display rename updates the visible caption without dirtying any AERODECK preference/log file')
a.setModelInfo({filename='model2.yml',name='NewName'});a.background(120)
check(a.snapshot().session~=renamedSession and a.snapshot().session.flightSeconds==0 and not a.snapshot().session.muted,'different native filename still starts independent flight state even with the same display caption')
check(#a.timerWrites==priorTimerWrites and #a.timerResets==priorTimerResets,'actual model switch does not restore/reset the old timer into the new model')

a=configured('timerHost=RADIO\nerrorLog=1\n')
sd=a.writes();a.setMSP('RESPONSE TIMEOUT',0);a.settle()
local state=a.runtimeServices.log()
check(state.enabled and #state.events==1 and state.events[1].message=='RESPONSE TIMEOUT','working Error-log setting records actual MSP failure state into RAM')
for i=1,30 do a.send(0)end
check(#state.events==1 and state.events[1].repeats==1 and a.writes()==sd,'unchanged actual error state is not repeatedly recorded and never writes per frame')
a.setMSP('READY',0);a.settle();a.background(50);a.setMSP('SECOND ERROR',0);a.settle()
check(#state.events==2 and a.writes()==sd,'changed observed failure produces a distinct RAM event without warm SD IO')
a.arrange(12)
for i=1,4 do a.send(E.EVT_TOUCH_TAP,{x=100,y=75})end
check(a.visible('ERROR LOG')and a.visible('SECOND ERROR'),'fifth Diagnostics view displays selected observed event')
a.send(E.EVT_TOUCH_TAP,{x=50,y=232});check(a.visible('RESPONSE TIMEOUT'),'Previous Error control reaches the prior actual event')
a.send(E.EVT_TOUCH_TAP,{x=180,y=232});check(a.visible('SECOND ERROR'),'Next Error control reaches later actual event')
a.send(E.EVT_TOUCH_TAP,{x=350,y=232})
local path='/SCRIPTS/TOOLS/AERODECK/errors.log'
check(a.files[path] and string.find(a.files[path],'SECOND ERROR',1,true) and not state.pending and a.writes()==sd+1,'explicit Save Log reaches actual verified bounded log file once')
a.setMSP('THIRD ERROR',0);a.background(50);a.send(0);local before=a.writes();a.send(E.EVT_TOUCH_TAP,{x=350,y=232})
check(a.writes()==before and state.pending,'explicit Save Log enforces native30s retry bound and retains pending events')
check(#a.timerWrites==0 and #a.timerResets==0,'diagnostics logging and paging never claim/reset a Radio-owned timer')

-- Failed native restoration must keep the actual app/session and captured
-- original config available for an explicit retry, rather than closing/reload.
local function failModeWrite(t)
 t.mode=nil
 local fail=true
 setmetatable(t,{__newindex=function(table,key,value)
  if key=='mode'and fail then error('native mode restore failure')end
  rawset(table,key,value)
 end})
 return function()fail=false end
end
a,timer=configured('timerHost=AERODECK\nerrorLog=0\n')
a.arrange(1);timer.value=62
local allowRestore=failModeWrite(timer)
check(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.runtimeServices.timer().owned,'failed standalone native restore keeps app open with its owner metadata')
check(a.visible('TIMER RELEASE FAILED')or a.snapshot().timerError=='SET TIMER FAILED','failed exit restoration is visible instead of claiming successful close')
allowRestore()
check(a.send(E.EVT_VIRTUAL_EXIT)==1 and not a.runtimeServices.timer().owned and timer.mode==5 and timer.value==62,'explicit exit retry restores original native config and preserves current value')
a,timer=configured('timerHost=AERODECK\nerrorLog=0\n');a.arrange(12)
for i=1,3 do a.send(E.EVT_TOUCH_TAP,{x=100,y=75})end
local beforeSession=a.snapshot().session;timer.value=73;allowRestore=failModeWrite(timer)
a.send(E.EVT_TOUCH_TAP,{x=350,y=103})
check(a.runtimeServices.timer().owned and a.snapshot().session==beforeSession and timer.value==73,'failed Reload restoration preserves the current app/session rather than discarding original ownership')
allowRestore();a.send(E.EVT_TOUCH_TAP,{x=350,y=103})
check(a.runtimeServices.timer().owned and a.snapshot().session~=beforeSession,'successful explicit Reload safely restores then initializes a new owned session')
print('runtime-services: '..checks..' actual application integration checks passed')
