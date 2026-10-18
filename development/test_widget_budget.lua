-- Actual retained main; real telemetry, power, radio, session and stores.
-- Synthetic clocks establish coherent scheduling, never physical FPS/CPU claims.
local adapter=assert(loadfile('development/test_ui_navigation.lua'))('adapter')
local E=adapter.events
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function near(v,w,why)check(type(v)=='number'and math.abs(v-w)<.0001,why..': '..tostring(v))end
local base='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nmspMode=0\nvtxMode=0\nautoHome=1\nresetNativeTelemetry=0\n'
local function make(physicalArm,logModel,device)
 getUsage=nil
 local logicalArm=false
 getLogicalSwitchValue=physicalArm and function(i)if i==0 then return logicalArm end end or nil
 local initialSettings=base..(physicalArm and'armBinding=LS:L01\n'or'')
 if device then initialSettings=string.gsub(initialSettings,'mspMode=0','mspMode=1')end
 local a=adapter.make({filename=logModel,settings=initialSettings,device=device})
 if logModel then
  local factory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/model-store.lua'))()
  local store=factory.new({io=io,remove=del,rename=rename})
  check(store.save('settings',{filename=logModel,name='UITEST'},base..'errorLog=1\n',function(raw)if string.sub(raw,1,7)=='ADCFG1\n' then return{}end end),'logging fixture uses the real filename-owned store')
 end
 if physicalArm then a.setSensor('FM',nil,false,true)end
 local now=getTime();getTime=function()return now end
 local raw=getSourceValue;local reads={current=0,voltage=0,gps=0,pitch=0,roll=0}
 getSourceValue=function(id)
  if id==1006 then reads.current=reads.current+1 elseif id==1003 then reads.voltage=reads.voltage+1 elseif id==1021 then reads.gps=reads.gps+1 elseif id==1036 then reads.pitch=reads.pitch+1 elseif id==1039 then reads.roll=reads.roll+1 end
  return raw(id)
 end
 local h={app=a,reads=reads,setLogicalArm=function(v)logicalArm=v end}
 function h.step(event,touch,ticks)now=now+(ticks or 4);return a.send(event or 0,touch)end
 function h.background(ticks)now=now+(ticks or 4);a.background(1)end
 function h.now()return now end
 function h.finishStartup()
  local callbacks=0
  while a.inputs.startup do h.background();callbacks=callbacks+1;check(callbacks<300,'retained startup makes bounded progress')end
  h.background();check(a.snapshot()and not a.snapshot().initializing,'normal background service follows all cold phases')
 end
 function h.publish()
  local serial=a.inputs.serviceSerial
  for i=1,9 do h.step();if a.inputs.serviceSerial>serial then return i end end
  error('retained telemetry failed to publish within the bounded cycle')
 end
 function h.drain()
  local n=0;while a.inputs.pendingData do h.step(0,nil,1);n=n+1;check(n<5,'pending field acquisition/power/session completes in three further callbacks')end
 end
 a.setRetained(true);a.reinit();h.finishStartup();h.step();h.drain()
 return h
end
local function painted(a,why)
 check(#a.commands()>0,why..' paints a real frame')
 check(a.hud()~=nil,why..' includes the current Flight horizon')
end
local function view(v)
 local r={};for k,x in pairs(v or{})do if type(x)~='table'then r[k]=x else local t={};for j,y in pairs(x)do if type(y)~='table'then t[j]=y end end;r[k]=t end end;return r
end
local function unchanged(actual,expected,why)
 for k,x in pairs(expected)do
  if type(x)=='table'then for j,y in pairs(x)do check(actual[k]and actual[k][j]==y,why..' '..tostring(k)..'.'..tostring(j))end
  else check(actual[k]==x,why..' '..tostring(k))end
 end
 for k in pairs(actual)do check(expected[k]~=nil,why..' has no prematurely added '..tostring(k))end
end
local h=make();local a=h.app
local initialWrites,initialScans=a.writes(),a.sourceScans()
local home=a.snapshot().session.home;check(home~=nil,'current GPS establishes genuine local home')
local acquisitions,publications=0,0
local firstPitch,firstRoll=h.reads.pitch,h.reads.roll
local firstAcquire,lastAcquire
for i=1,120 do
 local rawPitch=-(i%50)/100;local rawRoll=(i%60)/200
 local latitude=25.9976807+i/100000
 a.setAttitude(rawPitch,rawRoll);a.setSensor('Curr',i,true,true);a.setSensor('GPS',{lat=latitude,lon=-97.1573563},true,true)
 local old=a.snapshot();local serial=a.inputs.serviceSerial;local currentReads=h.reads.current
 local oldA,oldLat=old.a,old.session.current.lat
 local oldPower,oldRadio=view(old.powerState),view(old.radioStatus)
 local pending=a.inputs.pendingData
 local expectedA=pending and pending.data.a
 local expectedLat=pending and pending.data.gps and pending.data.gps.lat
 h.step();painted(a,'regular field/power/publish callback')
 if a.inputs.serviceSerial~=serial then
  publications=publications+1
  check(pending and pending.phase==4 and a.inputs.serviceSerial==serial+1,'only a completed fourth phase publishes once')
  near(a.snapshot().a,expectedA,'published current is the acquired value, not a later source')
  near(a.snapshot().session.current.lat,expectedLat,'published moving GPS belongs to the same acquired sample')
 else
  check(a.snapshot()==old,'in-progress work cannot replace the displayed snapshot')
  near(old.a,oldA,'in-progress work cannot mutate published current')
  near(old.session.current.lat,oldLat,'session position changes only at publication')
  unchanged(old.powerState,oldPower,'in-progress derive leaves published battery view intact')
  unchanged(old.radioStatus,oldRadio,'in-progress acquisition leaves published radio view intact')
 end
 if h.reads.current>currentReads then
  acquisitions=acquisitions+1;local acquired=a.inputs.pendingData
  check(acquired and acquired.phase==2 and h.reads.current-currentReads==1,'one acquire phase reads each power source once')
  if lastAcquire then check(acquired.at-lastAcquire==20,'acquire starts on the genuine200ms cadence')else firstAcquire=acquired.at end
  lastAcquire=acquired.at
 else check(h.reads.current==currentReads,'remaining fields/power/publish/render do not repeat power acquisition')end
 near(a.snapshot().pitch,-rawPitch*180/math.pi,'published pitch follows every callback')
 near(a.snapshot().roll,rawRoll*180/math.pi,'published roll follows every callback')
 near(a.hud().pitch,-rawPitch*180/math.pi,'every painted horizon uses the fresh pitch')
 near(a.hud().roll,rawRoll*180/math.pi,'every painted horizon uses the fresh roll')
 check(a.snapshot().session.home==home,'moving aircraft never moves local home')
end
check(acquisitions==24 and publications>=23 and publications<=24,'4.8s at25callbacks/s acquires24real slow samples, with only publication latency at the boundary')
check(h.reads.pitch-firstPitch==120 and h.reads.roll-firstRoll==120,'attitude sources are read once per callback, never again during slow acquisition')
check(a.writes()==initialWrites and a.sourceScans()==initialScans,'steady loop neither writes SD nor enumerates source inventory')
h.drain()
-- Fast attitude freshness is independent of the four-phase slow snapshot.
a.setAttitudeCurrent(false);h.step()
check(a.snapshot().pitch==nil and a.snapshot().roll==nil,'stale attitude clears on this callback')
check(not a.hud()and #a.commands()>0,'missing attitude paints a real unavailable view, never a cached horizon or blank frame')
a.setAttitudeCurrent(true);a.setAttitude(-.2,.3);h.step();painted(a,'attitude recovery')
near(a.snapshot().pitch,.2*180/math.pi,'fast pitch recovers without waiting for publication')
near(a.snapshot().roll,.3*180/math.pi,'fast roll recovers without waiting for publication')
-- Slow loss/recovery keeps last-known/home distinct from current values.
h.drain();local known=a.snapshot().session.lastKnown.lat
a.setSensor('GPS',nil,false,true);a.setSensor('Curr',99,false,true);h.publish()
check(a.snapshot().gps==nil and a.snapshot().session.current==nil and a.snapshot().a==nil,'stale slow sources clear together at publication')
near(a.snapshot().session.lastKnown.lat,known,'loss retains owned last-known position')
check(a.snapshot().session.home==home,'loss retains locked home')
a.setSensor('GPS',{lat=26.001,lon=-97.15},true,true);a.setSensor('Curr',0,true,true);h.publish()
near(a.snapshot().session.current.lat,26.001,'GPS recovers through the real session')
check(a.snapshot().a==0 and a.snapshot().session.home==home,'genuine0A is valid and home remains locked')
-- Source or independent battery revision invalidates a partially derived sample.
local function edit(key,event)
 check(a.config.openSection(1,key),'source settings are reachable')
 a.config.input(E.EVT_VIRTUAL_ENTER);a.config.input(event);a.config.input(E.EVT_VIRTUAL_ENTER)
 check(a.config.save(),'source settings use the actual transactional store')
end
h.step(0,nil,20);check(a.inputs.pendingData and a.inputs.pendingData.phase==2,'fixture acquires an old-configuration sample')
local before=a.inputs.serviceSerial;local rejected=a.inputs.pendingData
edit('current',E.EVT_VIRTUAL_NEXT);check(a.config.get('current')=='None','None is an explicit source choice')
h.step();painted(a,'source revision reacquisition')
check(a.inputs.serviceSerial==before and a.inputs.pendingData~=rejected and a.inputs.pendingData.revision==a.config.revision(),'source revision discards old pending work before publication')
h.drain();check(a.inputs.serviceSerial==before+1 and a.snapshot().a==nil,'only the new disabled-source sample is published')
check(a.inputs.sampleRevision==a.config.revision(),'published revision matches active settings')
edit('current',E.EVT_VIRTUAL_PREV);h.step();h.drain()
check(a.snapshot().a==0,'Auto restoration publishes genuine zero current')
local batteryRevision=a.inputs.sampleBatteryRevision
h.step(0,nil,20);rejected=a.inputs.pendingData;before=a.inputs.serviceSerial
check(a.config.openSection(3),'battery limits are reachable')
a.config.input(E.EVT_VIRTUAL_ENTER);a.config.input(E.EVT_VIRTUAL_NEXT);a.config.input(E.EVT_VIRTUAL_ENTER)
a.config.input(E.EVT_TOUCH_TAP,{x=200,y=230});h.step();painted(a,'battery revision reacquisition')
check(a.inputs.serviceSerial==before and a.inputs.pendingData~=rejected,'battery save discards its old pending sample')
h.drain();check(a.inputs.sampleBatteryRevision~=batteryRevision and a.snapshot().cells==7,'independent battery revision reaches actual policy')
-- A stalled/over-age pending acquisition is never published as current.
h.step(0,nil,20);rejected=a.inputs.pendingData;before=a.inputs.serviceSerial
check(rejected and rejected.phase==2,'age fixture starts with acquired data')
a.setSensor('Curr',17,true,true);h.step(0,nil,31)
check(a.inputs.serviceSerial==before and a.inputs.pendingData~=rejected and a.inputs.pendingData.at==h.now(),'over300ms pending data is discarded and acquired again')
h.drain();near(a.snapshot().a,17,'only the replacement fresh acquisition is published')
-- Heavy explicit actions paint opaque progress instead of an empty LVGL buffer.
local resetCount=a.snapshot().session.resetCount;local savedWrites=a.writes()
h.step(E.EVT_SYS_LONG);h.step(E.EVT_TOUCH_TAP,{x=30,y=126})
check(a.state().quickActive,'New Flight requires confirmation')
before=a.inputs.serviceSerial;h.step(E.EVT_TOUCH_TAP,{x=30,y=126})
check(a.inputs.serviceSerial==before+1 and not a.hud()and a.visible('UPDATING SETTINGS / FLIGHT DATA'),'New Flight performs one atomic service and paints explicit progress')
check(a.inputs.pendingData==nil and a.snapshot().session.resetCount==resetCount+1,'New Flight clears old pending work and resets once')
check(#a.sensorResets==0 and a.writes()==savedWrites,'local reset respects disabled native resets and does not save settings')
local oldSession=a.snapshot().session
h.step(E.EVT_SYS_LONG);before=a.inputs.serviceSerial;h.step(E.EVT_TOUCH_TAP,{x=30,y=151})
check(a.inputs.startup and a.inputs.startup.phase==1 and a.visible('STARTING SESSION'),'Reload paints progress and enters staged startup')
check(a.inputs.pendingData==nil and a.inputs.serviceSerial==before and a.snapshot().initializing,'Reload cannot publish pending data from the old session')
h.finishStartup()
check(a.snapshot().session~=oldSession and a.config.get('current')=='Auto'and a.snapshot().cells==7,'Reload creates a new session while preserving both saved stores')
check(a.writes()==savedWrites,'Reload reads saved stores without rewriting them')
-- Exceptional high usage paints progress and preserves input navigation.
h=make();a=h.app;h.drain();getUsage=function()return 30 end
a.setAttitude(-.4,.1);h.step(E.EVT_SYS_BREAK,nil,1)
check(a.state().navFocus~=nil and a.visible('UPDATING SETTINGS / FLIGHT DATA'),'exceptional input callback paints progress and keeps SYS focus')
h.step(E.EVT_VIRTUAL_NEXT,nil,1);h.step(E.EVT_VIRTUAL_ENTER,nil,1)
check(a.state().page==5 and #a.commands()>0,'rotary/ENTER destination is preserved during progress callbacks')
getUsage=function()return 0 end;h.step()
check(a.state().page==5 and #a.commands()>0,'ordinary next callback paints the requested destination')
-- Fresh arm guard is independent of the slower displayed state, including a
-- user-assigned logical source when native FM is unavailable.
for _,physicalArm in ipairs({false,true})do
 h=make(physicalArm);a=h.app;h.drain()
 local armedSerial=a.inputs.serviceSerial;local armedResets=a.snapshot().session.resetCount
 check(a.snapshot().armed==false and a.inputs.armedNow()==false,'arming fixture starts genuinely disarmed')
 if physicalArm then h.setLogicalArm(true)else a.setFlightMode('ACRO')end
 check(a.inputs.armedNow()==true,'fresh arm guard sees the transition before the next slow sample')
 h.step(E.EVT_SYS_LONG,nil,1);h.step(E.EVT_TOUCH_TAP,{x=30,y=126},1);h.step(E.EVT_TOUCH_TAP,{x=30,y=126},1)
 check(a.inputs.serviceSerial==armedSerial and a.snapshot().armed==false,'arm transition remains strictly between slow publications')
 check(a.snapshot().session.resetCount==armedResets and #a.sensorResets==0 and #a.timerResets==0,'fresh armed state blocks reset despite older disarmed display cache')
end
-- Retained Save Log is an explicit two-callback transaction, not synchronous IO
-- appended to a PFD. The toast must follow verified promotion, never begin().
local function openLog(h)
 local a=h.app
 a.runtimeServices.record('SCHEDULER TEST','controlled explicit log event')
 local state=a.runtimeServices.log()
 check(state.enabled and state.pending,'actual logger owns pending RAM events')
 a.arrange(12)
 for i=1,4 do h.step(E.EVT_TOUCH_TAP,{x=100,y=75})end
 check(a.visible('ERROR LOG'),'actual Diagnostics reaches its Error Log view')
 return state
end
h=make(false,'budget-log.yml');a=h.app
local logState=openLog(h);local logWrites=a.writes();before=a.inputs.serviceSerial
h.step(E.EVT_TOUCH_TAP,{x=350,y=232})
check(logState.flushing and logState.flushPhase==1 and logState.pending,'Save Log starts a real deferred job')
check(a.writes()==logWrites and not a.visible('ERROR LOG SAVED'),'begin performs no file write or false successful toast')
h.step()
check(logState.flushing and logState.flushPhase==2 and logState.pending and a.visible('SAVING ERROR LOG'),'first dedicated callback prepares snapshot and paints Saving')
check(a.writes()==logWrites and a.inputs.serviceSerial==before,'prepare callback performs no write or combined telemetry service')
h.step()
local logPath='/SCRIPTS/TOOLS/AERODECK/errors.log'
check(not logState.flushing and not logState.pending and logState.state=='SAVED'and a.files[logPath],'second callback verifies and promotes actual log bytes')
check(a.writes()==logWrites+1 and a.visible('ERROR LOG SAVED')and not a.hud(),'successful toast follows final verified write on its opaque frame')
check(a.inputs.serviceSerial==before,'dedicated log IO does not combine slow telemetry or PFD drawing')
-- A failed write retains the pending events and never pretends success.
-- The adapter's logger captured its own native clock during initial load.
-- Advance that clock through the actual background entry for the30s retry bound.
a.background(3001);h.step();a.runtimeServices.record('SCHEDULER TEST','new event after explicit save')
h.step(E.EVT_TOUCH_TAP,{x=350,y=232});h.step()
local fs=io;local savedWrite=fs.write
fs.write=function(f,raw)if f.path==logPath..'.tmp'then return false end;return savedWrite(f,raw)end
logWrites=a.writes();h.step();fs.write=savedWrite
check(logState.pending and not logState.flushing and logState.state=='ERROR'and logState.error=='WRITE ERROR','failed actual write leaves events pending with a concrete error')
check(a.writes()==logWrites and a.visible('ERROR LOG SAVE FAILED')and not a.visible('ERROR LOG SAVED'),'failure paints its own opaque error view without a success toast')
-- Model identity is checked before either IO phase; changed-model startup must
-- not execute an old pending log transaction. Cover before prepare and promote.
for _,phase in ipairs({1,2})do
 h=make(false,'budget-log-'..phase..'.yml');a=h.app;logState=openLog(h)
 h.step(E.EVT_TOUCH_TAP,{x=350,y=232});if phase==2 then h.step()end
 check(logState.flushing and logState.flushPhase==phase,'model-change fixture starts at the requested transaction boundary')
 local logOpens=0;local fs=io;local savedOpen=fs.open
 fs.open=function(path,mode)if string.find(path,'errors.log',1,true)then logOpens=logOpens+1 end;return savedOpen(path,mode)end
 logWrites=a.writes();a.setModelInfo({filename='next-model-'..phase..'.yml',name='NEXT MODEL'});h.step()
 check(a.inputs.startup and a.visible('STARTING NEW MODEL')and #a.commands()>0,'model restart immediately paints opaque progress before yielding')
 check(logOpens==0 and a.writes()==logWrites,'fresh model identity prevents old log IO before startup')
 h.finishStartup()
 check(not logState.flushing and logOpens==0 and a.writes()==logWrites,'new model configuration cancels old log job without any log IO')
 fs.open=savedOpen
end
-- Repeated cancellation must reuse unfinished work, never swap into the still
-- published table. Change real raw voltage/current/GPS AND derived cell state;
-- unchanged source values would hide the double-buffer aliasing regression.
local cancel=make();local ca=cancel.app;cancel.drain()
local shown=ca.snapshot();local shownPower=view(shown.powerState)
local shownV,shownA,shownMah,shownCell=shown.v,shown.a,shown.mah,shown.cell
local shownGPS,shownLat=shown.gps,shown.gps.lat
local shownSession,shownSessionLat=shown.session,shown.session.current.lat
local serial=ca.inputs.serviceSerial
local function intact(why)
 check(ca.snapshot()==shown and ca.inputs.serviceSerial==serial,why..' retains the displayed snapshot and serial')
 near(shown.v,shownV,why..' leaves published raw voltage intact')
 near(shown.a,shownA,why..' leaves published raw current intact')
 near(shown.mah,shownMah,why..' leaves published consumed charge intact')
 near(shown.cell,shownCell,why..' leaves published derived cell intact')
 check(shown.gps==shownGPS and shown.session==shownSession,why..' keeps owned position/session identities')
 near(shown.gps.lat,shownLat,why..' leaves published raw GPS intact')
 near(shown.session.current.lat,shownSessionLat,why..' leaves committed session GPS intact')
 unchanged(shown.powerState,shownPower,why..' keeps all published battery fields intact')
 painted(ca,why)
end
local function changedSources(i)
 ca.setSensor('RxBt',19.2+i*.6,true,true);ca.setSensor('Curr',3+i,true,true)
 ca.setSensor('Capa',400+i*20,true,true)
 ca.setSensor('GPS',{lat=26.1+i/100,lon=-97.1-i/100},true,true)
end
changedSources(1)
local voltageReads,gpsReads=cancel.reads.voltage,cancel.reads.gps
cancel.step(0,nil,20)
check(ca.inputs.pendingData.phase==2 and cancel.reads.voltage==voltageReads+1 and cancel.reads.gps==gpsReads,'first acquisition batch samples power but defers GPS to the next callback')
intact('first changed acquisition')
for i=1,5 do
 cancel.step(0,nil,1)
 check(ca.inputs.pendingData.phase==3,'second acquisition batch completes before power policy')
 near(ca.inputs.pendingData.data.gps.lat,26.1+i/100,'second batch samples the new real GPS position')
 intact('remaining acquisition before cancellation')
 cancel.step(0,nil,1)
 check(ca.inputs.pendingData.phase==4,'power phase finishes before session publication')
 near(ca.inputs.pendingData.data.cell,(19.2+i*.6)/6,'working power policy sees the changed real voltage')
 intact('derived working sample before cancellation')
 local abandoned=ca.inputs.pendingData
 changedSources(i+1)
 if i<=3 then
  check(ca.config.openSection(11,'accent'),'unrelated saved setting supplies a genuine revision')
  ca.config.input(E.EVT_VIRTUAL_ENTER);ca.config.input(i%2==1 and E.EVT_VIRTUAL_NEXT or E.EVT_VIRTUAL_PREV);ca.config.input(E.EVT_VIRTUAL_ENTER)
  check(ca.config.save(),'revision cancellation uses the actual model settings store')
 end
 cancel.step(0,nil,i<=3 and 1 or 31)
 check(ca.inputs.pendingData~=abandoned and ca.inputs.pendingData.phase==2,'revision/age cancellation begins replacement work without publishing the abandoned sample')
 intact(i<=3 and'repeated configuration cancellation'or'repeated stale-work cancellation')
 check(ca.inputs.pendingData.data~=shown,'replacement acquisition never targets the still-visible table')
end
cancel.step(0,nil,1);intact('final remaining acquisition')
cancel.step(0,nil,1);intact('final derived sample')
cancel.step(0,nil,1)
check(ca.snapshot()~=shown and ca.inputs.serviceSerial==serial+1 and ca.inputs.pendingData==nil,'only the final uncancelled fourth phase replaces the displayed snapshot')
near(ca.snapshot().v,22.8,'final published voltage belongs to the sixth sample')
near(ca.snapshot().a,9,'final published current belongs to the sixth sample')
near(ca.snapshot().mah,520,'final published consumption belongs to the sixth sample')
near(ca.snapshot().cell,3.8,'final derived cell matches the final raw voltage')
near(ca.snapshot().gps.lat,26.16,'final raw GPS matches the sixth sample')
near(ca.snapshot().session.current.lat,26.16,'final session position matches the final acquired GPS')
-- Moderate prefix work defers only the next slow phase. Fresh attitude and a
-- cached-but-complete body are still painted; the next lower-cost callback resumes.
local margin=make();local ma=margin.app;margin.drain()
local oldSerial,oldCurrent=ma.inputs.serviceSerial,ma.snapshot().a
getUsage=function()return 12 end
ma.setSensor('Curr',45,true,true);ma.setAttitude(-.31,.17)
local readsBefore=margin.reads.current
margin.step(0,nil,20)
check(ma.inputs.pendingData==nil and ma.inputs.serviceSerial==oldSerial and margin.reads.current==readsBefore,'above10percent prefix defers slow acquisition without inventing a sample')
painted(ma,'moderate-prefix cached frame')
near(ma.snapshot().a,oldCurrent,'moderate-prefix frame keeps last completed power')
near(ma.hud().pitch,.31*180/math.pi,'moderate-prefix frame paints freshly read pitch')
near(ma.hud().roll,.17*180/math.pi,'moderate-prefix frame paints freshly read roll')
getUsage=function()return 0 end;margin.step(0,nil,1)
check(ma.inputs.pendingData and ma.inputs.pendingData.phase==2 and margin.reads.current==readsBefore+1,'next low-cost callback starts the actual slow acquisition')
local held=ma.inputs.pendingData
getUsage=function()return 12 end;margin.step(0,nil,1)
check(ma.inputs.pendingData==held and held.phase==2 and ma.inputs.serviceSerial==oldSerial,'moderate prefix also leaves an in-progress phase untouched')
painted(ma,'moderate-prefix pending frame')
getUsage=function()return 0 end;margin.step(0,nil,1)
check(ma.inputs.pendingData==held and held.phase==3,'low-cost callback resumes the exact deferred phase')
margin.drain();near(ma.snapshot().a,45,'resumed work finally publishes the real changed current')
-- Modal bodies are cheaper than the PFD and may advance data despite that prefix.
margin.step(0,nil,20);held=ma.inputs.pendingData
check(held and held.phase==2,'modal fixture starts with a pending first batch')
getUsage=function()return 12 end;margin.step(E.EVT_SYS_LONG,nil,1)
check(ma.state().quickActive and ma.visible('QUICK ACTIONS')and not ma.hud(),'modal paints its actual opaque controls rather than an occluded PFD')
check(ma.inputs.pendingData==held and held.phase==3,'visible modal permits remaining-field progress with moderate prefix')
margin.step(0,nil,1);check(held.phase==4 and ma.visible('QUICK ACTIONS'),'modal also permits bounded power derivation')
oldSerial=ma.inputs.serviceSerial;margin.step(0,nil,1)
check(ma.inputs.serviceSerial==oldSerial+1 and ma.inputs.pendingData==nil and ma.visible('QUICK ACTIONS'),'modal publishes the completed sample while retaining the visible controls')
getUsage=nil
-- Simulate recurring cost at the ACTUAL native transport pop, through real main,
-- link dispatcher, MSP client and packet fixture. No fake replacement tick loop.
local wireFactory=assert(loadfile('development/msp_fixture.lua'))()
local function costlyLink()
 local usage,costOn=2,true
 local device=wireFactory.new({external=true});local pop=device.transport.pop
 device.transport.pop=function()if costOn then usage=12 end;return pop()end
 local h=make(false,nil,device)
 getUsage=function()return usage end
 return h,device,function(on)costOn=on end,function()usage=2 end
end
local fair,device,costOn,resetUsage=costlyLink();local fa=fair.app
local fairWrites=fa.writes();local skipped,transportCallbacks,published=0,0,0
local previousSerial=fa.inputs.serviceSerial
for i=1,60 do
 resetUsage();fa.setAttitude(-i/200,i/300);fa.setSensor('Curr',100+i,true,true)
 local priority=fa.inputs.samplingPriority(fair.now()+4)
 local pops,pushes=device.pops,#device.sent
 fair.step()
 painted(fa,'continuous transport-load frame')
 near(fa.hud().pitch,i/200*180/math.pi,'transport-load frame retains per-callback pitch')
 if priority then
  skipped=skipped+1
  check(device.pops==pops and #device.sent==pushes,'sampling-priority callback skips only the dispatcher, with no RF reads/writes')
 else
  transportCallbacks=transportCallbacks+1
  check(device.pops>pops,'nonpriority callback resumes the actual transport queue')
 end
 if fa.inputs.serviceSerial~=previousSerial then published=published+1;previousSerial=fa.inputs.serviceSerial end
end
check(skipped>0 and transportCallbacks>0 and published>=4,'published400ms priority prevents permanent slow-sample starvation under recurring transport cost')
check(fa.writes()==fairWrites,'transport fairness has no steady SD side effects')
for _,q in ipairs(device.sent)do check(q.cmd~=89 and q.cmd~=250,'passive fairness test never emits FC configuration writes')end
-- A revision can create pending work while the published sample is still young.
-- Its independent200ms priority must prevent starvation BEFORE the400ms threshold.
fair,device,costOn,resetUsage=costlyLink();fa=fair.app
costOn(false)
check(fa.config.openSection(11,'accent'),'young-pending fixture changes a real saved setting')
fa.config.input(E.EVT_VIRTUAL_ENTER);fa.config.input(E.EVT_VIRTUAL_NEXT);fa.config.input(E.EVT_VIRTUAL_ENTER)
check(fa.config.save(),'young-pending revision is persisted by the actual store')
resetUsage();fair.step(0,nil,1)
local young=fa.inputs.pendingData;check(young and young.phase==2,'revision forces an early acquisition before normal200ms cadence')
local earlyAt=young.at;local startAt=fair.now();local youngSerial=fa.inputs.serviceSerial;local firstPriority
costOn(true)
for i=1,28 do
 resetUsage();local priority=fa.inputs.samplingPriority(fair.now()+1);local pops,pushes=device.pops,#device.sent
 fair.step(0,nil,1);painted(fa,'young-pending transport-load frame')
 if priority then
  firstPriority=firstPriority or fair.now()
  check(device.pops==pops and #device.sent==pushes,'young pending priority withholds transport rather than bypassing wire guards')
 end
 if fa.inputs.serviceSerial~=youngSerial then break end
end
check(firstPriority and firstPriority-earlyAt==20 and firstPriority-startAt<40,'pending200ms threshold wins before the independent published400ms threshold')
check(fa.inputs.serviceSerial==youngSerial+1 and fa.inputs.pendingData==nil,'young pending phases finish instead of ageing out or starving')
getUsage=nil
getUsage=nil;getLogicalSwitchValue=nil
print('PASS: '..checks..' retained always-draw, atomic snapshots, cadence, attitude, loss, revisions, actions, arming and deferred log checks (synthetic; no physical FPS/CPU claim)')
