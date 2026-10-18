-- One GPS dashboard and one live, scrollable inspector; no view carousel.
local adapter=assert(loadfile('development/test_ui_navigation.lua'))('adapter')
local E=adapter.events;local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local a=adapter.make()
local function tap(x,y)check(a.send(E.EVT_TOUCH_TAP,{x=x,y=y})==0,'GPS stays operational')end
a.arrange(2)
check(a.state().page==7 and not a.inputs.gpsViews and not a.inputs.gpsView,'one dashboard replaces five GPS views')
for _,caption in ipairs({'HOME m','BRG deg','ETA @GS','REL deg','GS km/h','GPS ALT m','COG deg','V/S m/s'})do check(a.visible(caption),'visible compact rail metric '..caption)end
check(a.visible('25.9976807')and a.visible('-97.1573563'),'dashboard shows exact current coordinates')
check(a.snapshot().plusCode and a.visible(a.snapshot().plusCode),'dashboard shows the actual recovery code')
check(a.send(E.EVT_SYS_BREAK)==0 and a.visible('GPS / SELECT SECTION'),'section focus remains clear')
check(a.send(E.EVT_VIRTUAL_EXIT)==0,'close section focus')
local session=a.snapshot().session;local home,trail=session.home,session.track
local opens=a.bitmapLoads();check(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().controlCaption=='GPS INFO','first physical focus matches visible Info')
check(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.inputs.gpsInfo,'ENTER opens the one inspector')
for _,title in ipairs({'Aircraft LAT','Aircraft LON','Position Plus Code','Ground speed','GPS altitude','GPS course','Body yaw','Vertical speed','Home LAT','Home LON','Home Plus Code','Home reference','Local home distance','Local home bearing','Home relative to GPS course','ETA at current ground speed','Reported position fix','Reported quality index','Physical HDOP','FC home fix','FC home distance','FC home bearing','Reported satellite count','SV record status','FC satellite status'})do
 a.gpsScrollTo(title);check(a.visible(title),'retained field reachable without changing GPS page: '..title)
 check(a.state().page==7 and a.inputs.gpsInfo~=nil,'every field stays in the same inspector')
end
check(a.visible('NO CURRENT SV DETAIL')or a.inputs.gpsInfo.entries==nil,'count does not fabricate SV records')
local fc=a.fcState();fc.active=true;fc.satellitesAt=getTime();fc.satellites={}
for i=1,24 do fc.satellites[i]={id=i,constellation='GPS',qualityRaw=4,signal=35,used=i%2==0}end
a.settle();a.send(0)
a.gpsScrollTo('SV 24 / GPS');check(a.visible('Q 4 / S 35 / USED YES'),'last actual SV record is reachable without truncating the list')
local m=a.inputs.gpsInfo;local offset=m.offset
check(a.send(E.EVT_VIRTUAL_PREV_PAGE)==0 and m.offset==math.max(0,offset-8),'PAGE moves through the same list')
local scans,writes=a.sourceScans(),a.writes()
for i=1,20 do a.send(0)end
check(a.sourceScans()==scans and a.writes()==writes and a.bitmapLoads()==opens,'scrolling/warm inspector adds no scans, writes or image loads')
check(a.snapshot().session.home==home and a.snapshot().session.track==trail,'reading info preserves home and trail ownership')
check(a.send(E.EVT_VIRTUAL_EXIT)==0 and not a.inputs.gpsInfo,'RTN returns directly to map')
check(a.visible('HOME m')and a.visible('COG deg'),'dashboard is restored immediately')
a.gpsOpenInfo();tap(20,259);check(not a.inputs.gpsInfo and a.state().page==7,'Map action closes inspector')
a.gpsOpenInfo();tap(20,15);check(a.state().page==1 and not a.inputs.gpsInfo,'Home is one action from inspector')
a.arrange(7);a.setWarning(true);a.settle();a.send(0)
check(a.visible('BATTERY CRITICAL')and not a.visible('ACTIONS'),'critical warning owns the bottom bar')
a.gpsOpenInfo();check(a.visible('BATTERY CRITICAL'),'Info remains accessible without obscuring warning')
tap(70,259);check(a.state().page==3,'warning opens actual power details')
a=adapter.make();a.arrange(7);a.gpsAction('refresh');check(a.visible('SENSOR BINDINGS REFRESHED'),'Refresh remains real')
for i=1,20 do a.send(0)end
a.gpsAction('home');check(a.snapshot().session.home.source=='LOCAL MANUAL','Set Home uses real session')
for _,preset in ipairs({3,4})do
 a=adapter.make({settings='ADCFG1\nstartPage='..preset..'\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nmspMode=0\n'})
 check(a.state().page==7 and(a.inputs.gpsInfo~=nil)==(preset==4),'saved GPS opening presets map to dashboard or consolidated Info')
end
print('PASS: '..checks..' actual consolidated GPS checks; eight rail metrics, coordinates/recovery on map, all preserved data/SV records in one inspector, physical input and alerts')
