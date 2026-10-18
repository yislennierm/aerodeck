-- Actual application/session and actual UI->MSP client->fake FC wire path.
local adapter=assert(loadfile('development/test_ui_navigation.lua'))('adapter')
local deviceFactory=dofile('development/msp_fixture.lua')
local E=adapter.events
local checks=0
local function check(v,why)assert(v,why);checks=checks+1 end
local settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nvtxMode=2\nautoHome=1\nhomeSats=8\n'
local a=adapter.make({settings=settings})
local initial=a.snapshot().session
check(a.state().page==1 and initial.home and initial.home.source=='LOCAL AUTO','Home captured without opening GPS')
local lat,lon=initial.home.lat,initial.home.lon
a.setSensor('GPS',{lat=lat+.001,lon=lon},true);a.background(120)
check(a.snapshot().session.current.lat==lat+.001 and #initial.track>=2,'Hidden sampling acquires path')
a.arrange(7);check(a.snapshot().session.home.lat==lat,'Opening GPS cannot move home')
a.setSensor('GPS',{lat=lat+.002,lon=lon},false);a.background(120)
check(initial.current==nil and initial.home.lat==lat and initial.lastKnown.lat==lat+.001,'Stale current clears; owned home and last known remain')

local h=deviceFactory.new({external=true,clock=function()return getTime()end})
a=adapter.make({settings=settings,device=h})
a.arrange(11)
for i=1,240 do a.send(0);if a.fcState().vtx.tablesReady then break end end
local s=a.fcState()
check(s.uid and s.board and s.vtx.tablesReady,'Actual app obtains FC identity, board and VTX tables')
local function count(command)local n=0;for _,q in ipairs(h.sent)do if q.cmd==command then n=n+1 end end;return n end
check(count(89)==0 and count(250)==0,'Opening Video and discovery never writes')
-- Default favourite1 is5865; selection is pending only.
a.send(E.EVT_TOUCH_TAP,{x=35,y=124})
check(count(89)==0 and count(250)==0,'Favourite selection never applies automatically')
check(h.report.frequency==5800,'Reported hardware remains unchanged while selecting')
a.send(E.EVT_TOUCH_TAP,{x=261,y=232})
for i=1,300 do a.send(0);if s.vtx.operation.state=='APPLIED' then break end end
check(s.vtx.operation.state=='APPLIED' and h.report.frequency==5865,'Explicit Apply reaches89/save88 readback through actual client')
check(count(89)==1 and count(250)==1,'One explicit request produces one setting write and one save')
-- PIT startsON: toggle actual UI toOFF, preserving selected output power.
a.send(E.EVT_TOUCH_TAP,{x=392,y=132});a.send(E.EVT_TOUCH_TAP,{x=261,y=232})
for i=1,300 do a.send(0);if s.vtx.operation.state=='APPLIED' and h.report.pit==false then break end end
check(s.vtx.operation.state=='APPLIED' and h.report.pit==false,'PIT false survives UI and wire readback')
-- Fail a subsequent save; success must not be invented.
h.rejected[250]=true;a.send(E.EVT_TOUCH_TAP,{x=392,y=98});a.send(E.EVT_TOUCH_TAP,{x=261,y=232})
for i=1,300 do a.send(0);if s.vtx.operation.state=='FAILED' then break end end
check(s.vtx.operation.state=='FAILED' and s.vtx.operation.uncertain,'Rejected save remains a failed uncertain transaction')
a.background(100)
check(a.snapshot().session.home and not a.fcState().active,'Compact/hidden retains session while suspending foreground exchange')
-- Real physical native extrema: source IDs are three slots apart in this adapter.
a=adapter.make({settings=settings,extrema={Ptch={min=-.5,max=.2},Roll={min=-.3,max=.4},RxBt={min=19.9,max=25.2}}})
a.arrange(5);a.send(E.EVT_TOUCH_TAP,{x=65,y=45})
check(a.visible('NATIVE MIN')and a.visible('-11.5'),'Actual MIN view reverses native pitch extrema before radians/sign normalization')
a.send(E.EVT_TOUCH_TAP,{x=65,y=45})
check(a.visible('NATIVE MAX')and a.visible('28.6'),'Actual MAX view retains physical pitch ordering')
local frsky={
 {name='VFAS',unit=0,value=16.2},{name='RxBt',unit=0,value=5.1},{name='Curr',unit=0,value=1.4},{name='Fuel',unit=0,value=370},
 {name='RSSI',unit=0,value=85},{name='Tmp1',unit=0,value=14},{name='Tmp2',unit=0,value=1813},
 {name='5230',unit=0,value=123},{name='5240',unit=0,value=-45},{name='A4',unit=0,value=4.08},
 {name='GPS',unit=0,value={lat=1,lon=2}},{name='Hdg',unit=7,value=270}}
a=adapter.make({settings='ADCFG1\nrcProtocol=FrSky\nfcType=Betaflight\nautoHome=1\n',fields=frsky})
a.send(0);local real=a.snapshot()
check(real.v==16.2 and real.rxV==5.1 and real.mah==370,'FrSky actual app keeps flight VFAS, receiver supply and Fuel separate')
check(real.pitch==-12.3 and real.roll==-4.5 and real.fcArmed==true and real.flight=='ANGL','FrSky encoded angles and FC flags normalize in the actual app')
check(real.sats==13 and real.fix==true and real.session.home,'Reported FrSky GPS fix/count feed page-independent session')
check(real.cell==4.08 and real.powerState.averageCell~=real.cell and real.cellProvenance=='REPORTED CELL','Direct reported A4 remains separate from pack-average cell')
local frskySession=real.session;local frskyHome=frskySession.home;local frskyLast=frskySession.lastKnown;local frskyLastTick=frskyLast.tick;local frskyCode=real.plusCode
a.setSensor('Tmp2',813,true);a.setSensor('GPS',{lat=1.1,lon=2.1},true);a.background(100)
check(a.snapshot().fix==false,'A real no-fix update remains false rather than disappearing through Lua boolean fallbacks')
check(a.snapshot().gps.lat==1.1 and frskySession.current==nil,'actual FrSky raw coordinates stay available to telemetry while known no-fix cannot claim CURRENT navigation')
check(frskySession.lastKnown==frskyLast and frskyLast.lat==1 and frskyLast.lon==2 and frskyLast.tick==frskyLastTick,'actual encoded no-fix does not overwrite last accepted GPS location or timestamp')
check(frskySession.home==frskyHome and frskySession.homeDistance==nil and frskySession.homeBearing==nil and #frskySession.track==1,'actual fix loss retains local home/history but clears live navigation and adds no invalid track')
check(frskyCode~=nil and a.snapshot().plusCode==nil and a.snapshot().lastPlusCode==frskyCode,'actual current Plus Code disappears on reported no-fix while separately labelled last-known code is retained')
a.setSensor('Tmp2',1813,true);a.background(100)
check(frskySession.current and frskySession.current.lat==1.1 and frskySession.lastKnown.lat==1.1 and frskySession.homeDistance>0 and #frskySession.track==2,'actual reported fix recovery resumes page-independent navigation with genuine retained home')
-- Filename-capable real UI offers deliberate legacy import, never automatic
-- ownership; Save/reopen/rename/duplicate preserve each native model's data.
local legacy='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nvtxMode=0\ntheme=2\n'
a=adapter.make({filename='model1.yml',settings=legacy})
local legacyPath='/SCRIPTS/TOOLS/AERODECK/settings-554954455354.cfg'
local legacyBattery='/SCRIPTS/TOOLS/AERODECK/battery-554954455354.cfg'
local appPath='/SCRIPTS/TOOLS/AERODECK/settings-model-6d6f64656c312e796d6c.cfg'
local app2Path='/SCRIPTS/TOOLS/AERODECK/settings-model-6d6f64656c322e796d6c.cfg'
local batteryPath='/SCRIPTS/TOOLS/AERODECK/battery-model-6d6f64656c312e796d6c.cfg'
local originalLegacy,originalBattery=a.files[legacyPath],a.files[legacyBattery]
check(a.config.get('theme')==0 and a.config.storage().state=='IMPORT AVAILABLE' and not a.files[appPath],'filename-capable app never silently inherits ambiguous name settings')
local function importAction(app,steps)
 app.arrange(8);assert(app.config.openSection(12,'errorLog'));app.send(0)
 for i=1,steps do app.send(E.EVT_VIRTUAL_NEXT)end
 app.send(E.EVT_VIRTUAL_ENTER)
end
importAction(a,1)
check(a.config.get('theme')==2 and a.config.storage().state=='IMPORTED' and a.files[appPath],'Application import reaches verified filename store through actual UI')
check(a.files[legacyPath]==originalLegacy and a.files[legacyBattery]==originalBattery,'app import preserves both original legacy domains')
importAction(a,1) -- The completed App import action is now correctly hidden.
check(a.files[batteryPath] and string.sub(a.files[batteryPath],1,9)=='ADMODEL1\n' and a.files[legacyBattery]==originalBattery,'Battery import reaches separate canonical domain without changing legacy data')
local function nextTheme(app)
 app.arrange(8);assert(app.config.openSection(11,'theme'));app.send(0)
 app.send(E.EVT_VIRTUAL_ENTER);app.send(E.EVT_VIRTUAL_NEXT);app.send(E.EVT_VIRTUAL_ENTER)
 app.send(E.EVT_TOUCH_TAP,{x=205,y=232})
end
nextTheme(a)
check(a.config.get('theme')==3 and not a.config.hasAppChanges() and a.files[appPath..'.bak'],'actual Save updates owner file and validated backup')
local savedFirst=a.files[appPath];local beforeWrites=a.writes()
a.setModelInfo({filename='model1.yml',name='RENAMED DISPLAY'});a.send(0)
check(a.config.get('theme')==3 and a.files[appPath]==savedFirst and a.writes()==beforeWrites,'display rename/reopen retains filename settings without migration writes')
a.setModelInfo({filename='model1.yml',name='UITEST'});a.send(0)
a.setModelInfo({filename='model2.yml',name='UITEST'});a.send(0)
check(a.config.get('theme')==0 and a.config.storage().state=='IMPORT AVAILABLE' and not a.files[app2Path],'same-name duplicate has independent defaults and explicit legacy choice')
nextTheme(a)
check(a.config.get('theme')==1 and a.files[app2Path] and a.files[appPath]==savedFirst,'duplicate saves only its own native filename settings')
a.setModelInfo({filename='model1.yml',name='UITEST'});a.send(0)
check(a.config.get('theme')==3,'return to first same-name model restores only its own preferences')
a.setModelInfo({filename='model2.yml',name='UITEST'});a.send(0)
check(a.config.get('theme')==1,'return to duplicate restores independently saved preferences')
local savedSecond=a.files[app2Path];a.arrange(8);a.config.openSection(12,'errorLog');a.send(0)
check(not a.visible('IMPORT LEGACY APP SETTINGS') and a.config.get('theme')==1 and a.files[app2Path]==savedSecond and a.files[legacyPath]==originalLegacy,'existing owner hides ambiguous import action and preserves canonical/legacy data')
a.arrange(8);a.config.openSection(11,'theme');a.send(0)
a.send(E.EVT_VIRTUAL_ENTER);a.send(E.EVT_VIRTUAL_NEXT);a.send(E.EVT_VIRTUAL_ENTER)
local nativeWrite=io.write
io.write=function(handle,raw)if handle.path==app2Path..'.tmp'then error('injected native SD failure')end;return nativeWrite(handle,raw)end
a.send(E.EVT_TOUCH_TAP,{x=205,y=232});io.write=nativeWrite
check(a.config.get('theme')==1 and a.config.hasAppChanges() and a.files[app2Path]==savedSecond,'actual filename Save failure keeps prior active settings/canonical file and pending draft')
check(a.visible('SAVE FAILED'),'actual verified-store save failure is visible to the user')
a.config.discardAll()

-- Offline guides/catalogues are useful without an FC; actual controls reach
-- real entries and notes, never transmit commands or fabricate live readiness.
local offline=deviceFactory.new({external=true,clock=function()return getTime()end})
a=adapter.make({settings='ADCFG1\nrcProtocol=Off\nfcType=Off\nmspMode=0\nvtxMode=0\n',device=offline})
a.arrange(6)
local reference=a.state().reference
check(reference.guideFamily=='BF' and reference.guideCount==20 and reference.guidePages==4 and a.visible('MANUAL ONLY / NO COMMANDS'),'actual offline Stick Guide exposes complete labelled BF manual catalogue')
a.send(E.EVT_TOUCH_TAP,{x=80,y=75});reference=a.state().reference
check(reference.guideFamily=='INAV' and reference.guideCount==28 and reference.guidePages==6,'family control opens INAV offline guides without FC discovery')
for i=1,10 do a.send(E.EVT_TOUCH_TAP,{x=345,y=75})end
check(a.state().reference.guidePage==6 and a.state().reference.guideSelected==26,'guide Next reaches final page and clamps at real final entries')
for i=1,2 do a.send(E.EVT_TOUCH_TAP,{x=290,y=75})end
a.send(E.EVT_TOUCH_TAP,{x=200,y=195});reference=a.state().reference
check(reference.guidePage==4 and reference.guideSelected==20 and reference.guideScrollMax>1,'actual row selects long INAV bypass guide rather than placeholder')
a.send(E.EVT_TOUCH_TAP,{x=450,y=75})
check(a.state().reference.guideScroll==2,'Note Down reaches additional manual instructions')
local oldMode=a.state().reference.mode;a.send(E.EVT_TOUCH_TAP,{x=210,y=75})
check(a.state().reference.mode==oldMode%4+1,'Stick Mode changes actual manual axis diagrams only')
a.arrange(10);a.send(E.EVT_TOUCH_TAP,{x=70,y=75});reference=a.state().reference
check(reference.reference and reference.armCount>=26 and not reference.liveAvailable and a.visible('OFFLINE REFERENCE'),'offline arming catalogue is explicitly reference, never live readiness')
a.send(E.EVT_TOUCH_TAP,{x=200,y=75});reference=a.state().reference
check(reference.referenceFamily=='INAV' and reference.armCount>0,'offline arming family opens actual INAV reason catalogue')
check(#offline.sent==0 and #a.timerWrites==0 and #a.timerResets==0 and #a.sensorResets==0,'offline catalogue actions send no protocol/native timer/sensor commands')

-- Provider gates stop actual source calls, including fast attitude, preserving
-- independent link/FC information. Count source IDs, not source-name lookups.
a=adapter.make({settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nbatteryEnabled=0\ncurrentEnabled=0\ngyroEnabled=0\ngpsEnabled=0\nbaroEnabled=0\npitotEnabled=0\n'})
local nativeRead=getSourceValue;local readCounts={}
getSourceValue=function(id)readCounts[id]=(readCounts[id]or 0)+1;return nativeRead(id)end
local disabled={'RxBt','Curr','Capa','GPS','Sats','GSpd','GAlt','Hdg','Ptch','Roll'}
local ids={};for _,name in ipairs(disabled)do ids[name]=getSourceIndex(CHAR_TELEMETRY..name)end
for i=1,50 do a.send(0);a.background(20)end
getSourceValue=nativeRead
for _,name in ipairs(disabled)do check((readCounts[ids[name]]or 0)==0,'provider off makes zero actual native reads for '..name)end
local data=a.snapshot()
check(data.v==nil and data.a==nil and data.mah==nil and data.gps==nil and data.pitch==nil and data.roll==nil,'disabled source fields are absent rather than stale held values')
check(data.lq==99 and data.rssi==-56,'disabled physical providers preserve independent real link readings')

-- New GPS ownership clears old home/track/last-known but preserves elapsed and
-- mute. Re-read saved config without reloading the app or replacing its session.
local navigationSettings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nautoHome=1\nhomeSats=8\ngps=GPS\n'
a=adapter.make({settings=navigationSettings})
local navigationSession=a.snapshot().session;local oldHome=navigationSession.home
a.setFlightMode('ACRO');a.send(0);a.setSensor('GPS',{lat=oldHome.lat+.001,lon=oldHome.lon},true);a.background(200)
a.arrange(12);a.send(E.EVT_TOUCH_TAP,{x=210,y=232})
local elapsed=navigationSession.flightSeconds
check(#navigationSession.track>=2 and navigationSession.muted,'GPS test starts with real owned history/elapsed/mute')
local nextLat=oldHome.lat+.02;a.addSensor('GPS2',{lat=nextLat,lon=oldHome.lon},0,true)
local gps2Settings=string.gsub(navigationSettings,'gps=GPS\n','gps=GPS2\n',1)
a.files[legacyPath]=gps2Settings;a.config.init();a.background(120)
local current=a.snapshot().session
check(current==navigationSession and current.home and current.home~=oldHome and current.home.lat==nextLat,'GPS source change captures a new local home without replacing the whole session')
check(#current.track==1 and current.track[1].lat==nextLat and current.lastKnown.lat==nextLat,'GPS source change removes old history and last-known point')
check(current.flightSeconds>=elapsed and current.muted,'GPS ownership change preserves local arm elapsed/mute')
a.files[legacyPath]=gps2Settings..'gpsEnabled=0\n';a.config.init();a.background(120)
check(current.home==nil and current.lastKnown==nil and #current.track==0 and current.current==nil,'turning off GPS provider clears prior navigation ownership/history, not just visible numeric fields')
a.files[legacyPath]=gps2Settings..'gpsEnabled=1\n';a.config.init();a.background(120)
check(current.home and current.home.lat==nextLat and #current.track==1 and current.muted and current.flightSeconds>=elapsed,'reenabling current GPS establishes new local navigation history while preserving elapsed/mute')
print('PASS: '..checks..' actual application session and Video-to-MSP-to-FC integration checks')
