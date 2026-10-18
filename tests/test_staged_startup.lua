-- Actual main staged startup, using the real provider/store/session factories.
-- Budgeted native enumeration is exercised separately and in actual EdgeTX.
local adapter=assert(loadfile('tests/test_ui_navigation.lua'))('adapter')
local E=adapter.events;local checks=0
local function check(v,why)assert(v,why);checks=checks+1 end
local function make()
 local a=adapter.make({settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nautoHome=1\n'})
 a.setRetained(true);a.reinit();return a
end
local a=make();local writes=a.writes()
check(a.snapshot()and a.snapshot().initializing and a.snapshot().ok==false,'retained init exposes an honest stable startup view immediately')
check(a.inputs.startup.phase==1,'init never runs the first heavy phase in the widget init callback')
lcd.clear=function()end
a.send(0)
check(a.inputs.startup.phase==2 and a.visible('AERODECK'),'full screen advances one cold phase and displays startup rather than telemetry')
local callbacks,inventoryCallbacks=1,0
while a.inputs.startup do
 local before=a.inputs.startup.phase
 a.background(20);callbacks=callbacks+1
 if before==6 then inventoryCallbacks=inventoryCallbacks+1 end
 if a.inputs.startup then check(a.inputs.startup.phase==before or a.inputs.startup.phase==before+1,'one callback cannot consume two initialization phases')end
 check(callbacks<200,'cold startup is bounded and makes progress')
end
check(callbacks>=10 and inventoryCallbacks>0,'startup separates every module phase and services the input discovery phase')
check(a.snapshot()==nil,'final initialization callback yields before starting normal telemetry work')
a.background(20)
check(a.snapshot()and not a.snapshot().initializing and a.snapshot().session.current and a.snapshot().session.home,'next scheduled callback starts a real shared GPS/home session')
check(a.inputs.startupVisible==true,'branding remains active until the first complete dashboard, including initial telemetry acquisition')
for i=1,8 do a.send(0);if not a.inputs.startupVisible then break end end
check(a.inputs.startupVisible==false and a.hud()~=nil,'the first full dashboard ends startup branding without a forced display delay')
check(a.writes()==writes,'startup and discovery perform no implicit settings writes')
local scans=a.sourceScans();for i=1,30 do a.background(20)end
check(a.sourceScans()==scans,'complete warm startup never repeats native sensor inventory enumeration')
-- Explicit runtime refresh is also incremental on the widget, retaining flight.
local session=a.snapshot().session;local home=session.home
a.inputs.refresh()
check(not a.inputs.provider.ready()and string.find(a.inputs.label('arm','NATIVE'),'discovering',1,true),'refresh exposes pending input inventory instead of an invalid picker table')
check(a.inputs.open('arm','NATIVE')==false,'picker cannot open an incomplete catalog')
a.background(20)
check(a.snapshot().session==session and a.snapshot().session.home==home,'input refresh preserves the live flight/home session')
local refreshCallbacks=1
while not a.inputs.provider.ready()do a.background(20);refreshCallbacks=refreshCallbacks+1;check(refreshCallbacks<100,'bounded runtime input refresh makes progress')end
a.background(20)
check(refreshCallbacks>1 and a.inputs.label('arm','NATIVE')=='Native FC data','completed runtime discovery reapplies actual saved bindings')
check(a.writes()==writes and a.sourceScans()==scans,'runtime input discovery neither writes SD nor rescans telemetry sensors')

-- RTN returns to the widget while its retained cold initialization can finish.
a=make();lcd.clear=function()end
check(a.send(E.EVT_VIRTUAL_EXIT)==1 and a.inputs.startup,'RTN during startup leaves fullscreen without discarding the retained initialization')
for i=1,180 do if not a.inputs.startup then break end;a.background(20)end
a.background(20);check(a.snapshot()and a.snapshot().session and not a.snapshot().initializing,'hidden startup can complete and sample after fullscreen return')
-- A model switch during cold work restarts ownership before loading preferences.
a=make();a.background(20);a.background(20)
a.setModelInfo({filename='second.yml',name='SECOND'});a.background(20)
check(a.inputs.startup.phase==1 and a.inputs.startup.info.filename=='second.yml','changed model restarts cold phases before old-owner work can continue')
for i=1,180 do if not a.inputs.startup then break end;a.background(20)end
a.background(20)
check(a.snapshot()and a.snapshot().session.modelId=='FILE:second.yml','completed session belongs to the new native model file')
check(#a.timerWrites==0 and #a.timerResets==0,'read-only default startup/model switching never claims or resets a native timer')

-- A warm model change must yield before any old configuration/session work.
-- Exercise both public callbacks with real saved envelopes and native timer APIs.
local storeFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/model-store.lua'))()
local function timer(name)return{name=name,mode=3,start=60,value=57,countdownBeep=1,minuteBeep=true,persistent=1}end
local function edit(config,key)
 config.openSection(6,key);config.input(E.EVT_VIRTUAL_ENTER);config.input(E.EVT_VIRTUAL_NEXT);config.input(E.EVT_VIRTUAL_ENTER)
end
for _,callback in ipairs({'fullscreen','background'})do
 local timers={[0]=timer('FIRST'),[1]=timer('SPARE')}
 local live=adapter.make({filename='first.yml',timers=timers})
 edit(live.config,'timerHost');edit(live.config,'timerIndex')
 check(live.config.save(),'first model saves real timer ownership preferences')
 check(live.config.get('timerHost')=='AERODECK'and live.config.get('timerIndex')==1,'first model explicitly owns Timer1')
 live.setRetained(true);live.reinit()
 for _=1,300 do if not live.inputs.startup then break end;live.background(20)end
 live.background(20)
 check(live.runtimeServices.timer().owned,'first model really holds the native lease before changing models')
 local store=storeFactory.new({io=io,remove=del,rename=rename})
 local second={filename='second.yml',name='SECOND'}
 local payload='ADCFG1\ntimerHost=RADIO\ntimerIndex=2\ntheme=2\n'
 check(store.save('settings',second,payload,function()return{}end),'second model has independent owner-bound preferences')
 local secondPath=assert(store.paths('settings',second)).canonical
 local savedSecond=live.files[secondPath]
 check(type(savedSecond)=='string'and string.find(savedSecond,'ADMODEL1',1,true),'new-model preferences use the actual checksummed model store')
 -- Queue the real four-batch radio reset, then switch before its first batch.
 live.send(E.EVT_SYS_LONG);live.send(E.EVT_TOUCH_TAP,{x=30,y=126});live.send(E.EVT_TOUCH_TAP,{x=30,y=126})
 check(not live.state().quickActive and #live.sensorResets==0,'confirmed old-model reset is queued, not already finished')
 check(live.config.get('resetNativeTelemetry')==1 and #live.timerResets==1,'confirmed reset reached the real owned timer and enabled native-statistics reset path')
 local beforeWrites,beforeResets,beforeSensors= #live.timerWrites,#live.timerResets,#live.sensorResets
 local nativeSecond=timer('SECOND');timers[0]=nativeSecond
 local nativeSpare=timer('BSPARE');timers[1]=nativeSpare
 live.setModelInfo(second)
 if callback=='fullscreen'then check(live.send(0)==0,'warm fullscreen model change yields normally')else live.background(20)end
 check(live.inputs.startup and live.inputs.startup.phase==1,'warm '..callback..' model switch yields before the first cold phase')
 check(live.snapshot().initializing and live.snapshot().ok==false,'old live snapshot is not exposed for the new model')
 check(#live.timerWrites==beforeWrites and #live.timerResets==beforeResets,'old timer preferences cannot claim/reset a new-model timer in the restart callback')
 check(#live.sensorResets==beforeSensors,'old queued radio-statistics job cannot touch the new model in the restart callback')
 local steps=0
 while live.inputs.startup do
  live.background(20);steps=steps+1
  check(#live.timerWrites==beforeWrites and #live.timerResets==beforeResets,'cold stages never configure a native timer before current-model live service')
  check(#live.sensorResets==beforeSensors,'old reset job stays paused throughout cold stages and is discarded')
  check(steps<300,'replacement model cold startup completes')
 end
 live.background(20)
 check(live.config.get('timerHost')=='RADIO'and live.config.get('timerIndex')==2 and live.config.get('theme')==2,'new live session uses its own saved preferences rather than the previous model draft')
 check(live.snapshot().session.modelId=='FILE:second.yml','new live session belongs to the new model file')
 check(#live.timerWrites==beforeWrites and #live.timerResets==beforeResets,'current-model RADIO preference preserves both native timers')
 check(nativeSecond.name=='SECOND'and nativeSecond.mode==3 and nativeSecond.start==60 and nativeSecond.value==57,'new-model Timer1 configuration/value remain unchanged')
 check(nativeSpare.name=='BSPARE'and nativeSpare.mode==3 and nativeSpare.value==57,'new-model selected Timer2 remains native owned')
 check(#live.sensorResets==beforeSensors,'no later callback resumes the previous model radio reset job')
 check(live.files[secondPath]==savedSecond,'loading a replacement model does not rewrite its saved preferences')
end

print('PASS: '..checks..' actual staged startup, ownership, fullscreen/hidden and warm inventory checks')
