-- Actual cache, configuration and telemetry integration; no duplicated resolver.
local realio=io
local f=assert(realio.open('sdcard/SCRIPTS/TOOLS/telem.lua'));local app=f:read('*a');f:close()
local prefix=app:sub(1,assert(app:find('local batteryConfig=',1,true))-1)
local ca=assert(app:find('local configuration=(function()',1,true));local cb=assert(app:find('function fcLink.update',ca,true))
local ta=assert(app:find('local telemetry=(function()',1,true));local tb=assert(app:find('local ROOT=',ta,true))
local source=prefix..'\nlocal fcLink={state={}};local batteryConfig={check=function()return nil,6 end,isEditing=function()return false end,hasChanges=function()return false end}\n'..app:sub(ca,cb-1)..app:sub(ta,tb-1)..'\nreturn {t=telemetry,c=configuration}'
UNIT_KTS=1;UNIT_MPH=2;UNIT_METERS_PER_SECOND=3;UNIT_FEET_PER_SECOND=4;UNIT_KMH=5;UNIT_RADIANS=6;UNIT_DEGREE=7;UNIT_FEET=8;UNIT_METERS=9
UNIT_VOLTS=10;UNIT_AMPS=11;UNIT_MAH=12;UNIT_PERCENT=13;CHAR_TELEMETRY='T:'
EVT_VIRTUAL_ENTER=101;EVT_VIRTUAL_NEXT=102;EVT_VIRTUAL_PREV=103;EVT_TOUCH_TAP=104
local checks=0
local function check(ok,message)assert(ok,message);checks=checks+1 end
local function near(value,expected,message)check(type(value)=='number'and math.abs(value-expected)<.00001,message)end
local function environment(settings,initial)
 local e={now=0,lookups=0,metadata=0,sensorReads=0,valueReads=0,writes=0,fields={},byName={},byId={},files={}}
 local path='/SCRIPTS/TOOLS/AERODECK/settings-6d6f64656c.cfg'
 function e.add(name,unit,value,current)
  local s={name=name,unit=unit,value=value,current=current~=false,id=1001+#e.fields}
  e.fields[#e.fields+1]=s;e.byName[name]=s;e.byId[s.id]=s;return s
 end
 function e.prefs(values)
  local text='ADCFG1\n';for k,v in pairs(values or {})do text=text..k..'='..tostring(v)..'\n'end;e.files[path]=text
 end
 e.prefs(settings);for _,s in ipairs(initial or {})do e.add(unpack(s))end
 getTime=function()return e.now end
 model={getInfo=function()return {name='model'}end,getSensor=function(i)e.sensorReads=e.sensorReads+1;return e.fields[i+1]end}
 getSourceIndex=function(name)e.lookups=e.lookups+1;check(name:sub(1,2)=='T:','Bind must be qualified');local s=e.byName[name:sub(3)];return s and s.id or 0 end
 getFieldInfo=function(id)
  check(type(id)=='number','Metadata must use numericID');e.metadata=e.metadata+1
  local s=e.byId[id];return s and {id=id,unit=s.unit,name=s.name}
 end
 getSourceValue=function(id)e.valueReads=e.valueReads+1;local s=e.byId[id];if s and not s.unavailable then return s.value,s.current,s.current end end
 getValue=function()error('No stale getValue fallback')end;getRSSI=function()error('No generic RSSI dependency')end
 io={open=function(name,mode)
  if mode=='w'or mode=='a'then e.writes=e.writes+1;e.files[name]='';return {name=name}end
  if e.files[name]then return {name=name}end
 end,read=function(file)return e.files[file.name]end,close=function()end,write=function(file,text)e.files[file.name]=e.files[file.name]..text end}
 local x=assert(loadstring(source))();e.t=x.t;e.c=x.c;e.c.init();e.t.init();e.path=path
 function e.sample(ticks)e.now=e.now+(ticks or 0);return e.t.sample()end
 return e
end
local e=environment({},{{'RxBt',UNIT_VOLTS,16.1},{'GSpd',UNIT_KTS,10},{'GAlt',UNIT_FEET,100},{'Ptch',UNIT_RADIANS,math.pi/6},{'Roll',UNIT_DEGREE,-15},{'FM',0,'ANGLE'}})
local d=e.sample();check(d.ok and not d.demo and d.v==16.1 and d.flight=='ANGLE','Live withoutRSSI')
near(d.speed,18.52,'Knots');near(d.alt,30.48,'Feet');near(d.pitch,-30,'Pitch sign')
for _,s in ipairs(e.fields)do s.current=false end
d=e.sample();check(not d.ok and d.v==nil and d.roll==nil and d.flight==nil,'Stale clearing')
local name,state,raw=e.t.sourceStatus({'RxBt','VFAS','Bat'});check(name=='RxBt'and state=='STALE'and raw==16.1,'Raw stale value diagnostic only')
for i=1,5 do e.t.toggle();d=e.sample();check(not d.demo and not d.ok and d.v==nil,'Refresh never fabricates demo')end
for _,s in ipairs(e.fields)do s.current=true end
e.t.init();check(e.sample().v==16.1,'Reopen restores live')
e=environment();d=e.sample();check(d.v==nil and d.a==nil,'No startup sensors')
name,state,raw=e.t.sourceStatus('RxBt');check(name=='RxBt'and state=='NOT FOUND'and raw==nil,'Notfound distinctfromstale')
local v=e.add('RxBt',UNIT_VOLTS,22.8);local a=e.add('Curr',UNIT_AMPS,0)
e.add('GSpd',UNIT_KTS,10);e.add('Ptch',UNIT_RADIANS,-math.pi/6);e.add('Roll',UNIT_RADIANS,math.pi/12)
local scans=e.sensorReads;local previous=e.lookups;local appeared=false
for i=1,40 do
 d=e.sample(50);check(e.lookups-previous<=1,'One failed bind per500ms');previous=e.lookups
 if d.v==22.8 and d.a==0 and d.pitch and d.speed then appeared=true;break end
end
check(appeared,'Late RxBt/Curr/angle/speed recovers');check(e.sensorReads==scans,'Retries never enumerate sensors')
near(d.pitch,30,'Late pitch unit');near(d.roll,15,'Late roll unit');near(d.speed,18.52,'Late speed unit')
name,state,raw=e.t.sourceStatus({'RxBt','VFAS','Bat'});check(name=='RxBt'and state=='LIVE'and raw==22.8,'Live voltage source')
name,state,raw=e.t.sourceStatus('Curr');check(name=='Curr'and state=='LIVE'and raw==0,'Real0A staysLIVE')
local metadata,reads,bindings=e.metadata,e.valueReads,e.lookups
for i=1,100 do e.t.sourceStatus('Curr');e.t.sourceStatus({'RxBt','VFAS','Bat'})end
check(e.valueReads==reads and e.lookups==bindings and e.metadata==metadata,'Diagnostic does no extra read/bind')
for i=1,200 do e.t.pollAttitude()end
check(e.lookups==bindings and e.metadata==metadata and e.sensorReads==scans,'Attitude does no retry/metadata')
v.current=false;a.current=false;d=e.sample();check(d.v==nil and d.a==nil,'Disconnected power clears')
a.current=true;a.value='bad';d=e.sample();name,state,raw=e.t.sourceStatus('Curr');check(d.a==nil and state=='INVALID'and raw==nil,'Nonnumeric current invalid')
a.value=0;a.unavailable=true;d=e.sample();name,state=e.t.sourceStatus('Curr');check(d.a==nil and state=='STALE','Unavailable existing source stale')
e=environment({voltage='CustomV',current='CustomA'},{{'CustomV',UNIT_VOLTS,25.2},{'CustomA',UNIT_AMPS,0},{'RxBt',UNIT_VOLTS,9.9},{'Curr',UNIT_AMPS,99}})
d=e.sample();check(d.v==25.2 and d.a==0,'Manual overridesAuto')
name,state,raw=e.t.sourceStatus({'RxBt','VFAS','Bat'});check(name=='CustomV'and state=='LIVE'and raw==25.2,'Diagnostic manual mapping')
e.prefs({voltage='None',current='None'});e.c.init();d=e.sample();check(d.v==nil and d.a==nil,'None remains disabled')
name,state,raw=e.t.sourceStatus({'RxBt','VFAS','Bat'});check(name==nil and state=='OFF'and raw==nil,'None OFF no old value')
e=environment({},{{'RxBt',UNIT_VOLTS,16.1}});e.sample();e.c.openSection(1)
e.c.input(EVT_VIRTUAL_ENTER);e.c.input(EVT_VIRTUAL_NEXT);check(e.c.isEditing()and e.c.hasAppChanges(),'Draft edit fixture')
e.add('LateCustom',UNIT_VOLTS,23.1);local oldScans,oldLookup=e.sensorReads,e.lookups
e.t.refresh();check(e.sensorReads==oldScans and e.lookups==oldLookup,'Incidental refresh lightweight')
e.t.refreshBindings();check(e.sensorReads==oldScans+64,'Explicit refresh one64slotpass')
check(e.c.isEditing()and e.c.hasAppChanges()and e.c.get('rcProtocol')=='None','Refresh preservesdraft/edit/active')
e.c.input(EVT_VIRTUAL_ENTER);for i=1,3 do e.c.input(EVT_VIRTUAL_NEXT)end
e.c.input(EVT_VIRTUAL_ENTER);e.c.input(EVT_VIRTUAL_PREV);e.c.input(EVT_VIRTUAL_ENTER);e.c.input(EVT_TOUCH_TAP,{x=200,y=230})
check(e.c.resolve('RxBt')=='LateCustom','Late source becomes selectable');check(e.sample().v==23.1,'New selection reads actual value')
e=environment({pack=1,capacity1=1500,cells1=6},{{'RxBt',UNIT_VOLTS,22.8},{'Capa',UNIT_MAH,300},{'Bat%',UNIT_PERCENT,91}})
d=e.sample();check(d.capacity==1500 and d.remainingMah==1200 and d.pct==80 and d.estimated==true,'Profile overrides reported Bat%')
e.byName.Capa.value=0;d=e.sample();check(d.remainingMah==1500 and d.pct==100 and d.estimated==true,'Valid0Capa gives full estimate')
e.byName.Capa.current=false;d=e.sample();check(d.capacity==1500 and d.remainingMah==nil and d.pct==91 and d.estimated==nil,'StaleCapa preserves Bat%')
e.byName.Capa.unavailable=true;d=e.sample();check(d.remainingMah==nil and d.pct==91 and d.estimated==nil,'MissingCapa no fabricated remaining')
e.byName['Bat%'].current=false;d=e.sample();check(d.pct==nil and d.remainingMah==nil,'MissingCapa staleBat% allmissing')
e.byName.Capa.current=true;e.byName.Capa.unavailable=false;e.byName.Capa.value=1700;d=e.sample();check(d.remainingMah==0 and d.pct==0 and d.estimated==true,'Consumption clipsat0')
e.prefs({pack=0});e.c.init();e.byName['Bat%'].current=true;d=e.sample();check(d.capacity==nil and d.remainingMah==nil and d.pct==91 and d.estimated==nil,'Leavingprofile clears derived fields')
e.prefs({pack=1,capacity1=1500,consumed='None'});e.c.init();d=e.sample();check(d.capacity==1500 and d.remainingMah==nil and d.pct==91 and d.estimated==nil,'ConsumedNone prevents calculation')
io=realio
print('PASS: '..checks..' late discovery, retry bounds, units, zero/stale/manual/None, preserved refresh choices and battery-profile checks')
