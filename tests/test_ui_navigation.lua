-- Real-app regression with actual TX16S2.12.4 key aliases. Run from project root.
-- Inspection is appended only to a loaded source copy; production source stays unchanged.
local realIO=io
local adapterOnly=(...)=='adapter'
local f=assert(realIO.open('sdcard/SCRIPTS/TOOLS/telem.lua'));local original=f:read('*a');f:close()
local tail=assert(string.find(original,'return {init=init,run=run,stop=fcLink.stop,',1,true))
local source=string.sub(original,1,tail-1)..[[return {init=init,run=run,stop=fcLink.stop,close=closeApp,setRetained=function(value)retainedSession=value==true end,background=background,snapshot=function()return inputRuntime.startup and inputRuntime.startup.view or sharedData end,
 runtimeServices=runtimeServices,
 inspect=function()
  local item=shell.focused()
  return {page=page,navFocus=menuOpen and menuIndex or nil,controlFocus=controlFocus>0 and controlFocus or nil,
   quickActive=quick.active,quickFocus=quick.focus,controlCaption=item and item[6],exitOpen=exitOpen,exitChoice=exitChoice,
   dirty=configuration.hasChanges(),appDirty=configuration.hasAppChanges(),batteryDirty=batteryConfig.hasChanges(),
   configList=configuration.isList(),editing=configuration.isEditing(),reference=referenceUi and referenceUi.snapshot(),stickMode=stickMode,commandPage=commandPage}
 end,
 arrange=function(id)menuOpen=false;controlFocus=0;exitOpen=false;chooseSection(id)end,
 setModelName=function(value)modelName=value end,
 setHome=function(value)navHome=value;if session then session.snapshot().home=value end end,
 packPicker=function()return packPicker end,inputRuntime=inputRuntime,configuration=configuration,fcLink=fcLink,telemetry=telemetry,drawPower=function(data)powerScreen(data)end}]]
local E=assert(loadfile('tests/fixtures/events_tx16s_2124.lua'))()
local contract=assert(loadfile('tests/fixtures/navigation_contract.lua'))()
local modelStoreFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/model-store.lua'))()
local timerFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/timer-owner.lua'))()
local logFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/diagnostics-log.lua'))()
local extremaFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/native-extrema.lua'))()
local referenceFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/reference.lua'))()
local referenceUiFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/reference-ui.lua'))()
local powerFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/power-policy.lua'))()
local linkFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/link.lua'))()
local adaptersFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/msp-adapters.lua'))()
local nativeFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/vtx-native.lua'))()
local protocolsFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/protocols.lua'))()
local mspFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/crsf-msp.lua'))()
local sessionFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/session.lua'))()
local inputsFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/input-indicators.lua'))()
local radioFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/radio-status.lua'))()
local modelImageFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/model-image.lua'))()
local quickPackFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/quick-pack.lua'))()
local pickerFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/input-picker.lua'))()
local navigationFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/navigation-utils.lua'))()
local decoder=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/arm-status.lua'))()
local function make(options)
options=options or {}
local now,reads,writes,bitmaps,scans=1000,0,0,0,0
local attitudeCurrent=true
local commands,disk={},{}
local actualModel={name='UITEST',filename=options.filename}
local timerWrites,timerResets,sensorResets={},{},{}
local timers=options.timers or{}
local cfgPath='/SCRIPTS/TOOLS/AERODECK/settings-554954455354.cfg'
local batteryPath='/SCRIPTS/TOOLS/AERODECK/battery-554954455354.cfg'
disk[cfgPath]=options.settings or 'ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nvtxMode=2\n'
disk[batteryPath]='ADBAT1 6,27,30,34,36,42,0,0\n'
io={open=function(path,mode)
 if mode=='r' and disk[path]==nil then return nil end
 return {path=path,mode=mode}
end,read=function(f,n)local s=disk[f.path];return s and string.sub(s,1,n or #s)end,close=function()end,
write=function(f,s)assert(f.mode=='w');disk[f.path]=s;writes=writes+1 end}
del=function(path)if disk[path]then disk[path]=nil;return 0 end;return 4 end
rename=function(from,to)if not disk[from]then return 4 end;if disk[to]then return 8 end;disk[to]=disk[from];disk[from]=nil;return 0 end
SMLSIZE=0;TINSIZE=128;MIDSIZE=256;DBLSIZE=512;CUSTOM_COLOR=4096;RIGHT=65536;CENTER=131072;SOLID=0
for k,v in pairs(E)do _G[k]=v end
EVT_MENU_BREAK=nil;EVT_VIRTUAL_NEXT_REPT=nil;EVT_VIRTUAL_PREV_REPT=nil
UNIT_KTS=1;UNIT_MPH=2;UNIT_METERS_PER_SECOND=3;UNIT_FEET_PER_SECOND=4
UNIT_KMH=5;UNIT_RADIANS=6;UNIT_DEGREE=7;UNIT_FEET=8;UNIT_METERS=9;UNIT_TEXT=10
CHAR_TELEMETRY='T:'
local fields={
 {name='RxBt',unit=0,value=24}, {name='Curr',unit=0,value=12},
 {name='Capa',unit=0,value=340}, {name='RQly',unit=0,value=99},
 {name='1RSS',unit=0,value=-56}, {name='RSNR',unit=0,value=8},
 {name='GPS',unit=0,value={lat=25.9976807,lon=-97.1573563}},
 {name='Sats',unit=0,value=13}, {name='GSpd',unit=UNIT_KMH,value=31},
 {name='GAlt',unit=UNIT_METERS,value=33}, {name='Hdg',unit=UNIT_DEGREE,value=150},
 {name='Ptch',id=30,unit=UNIT_RADIANS,value=.1},
 {name='Roll',id=30,unit=UNIT_RADIANS,value=.2},
 {name='FM',id=33,unit=UNIT_TEXT,value='ACRO*'}
}
if options.fields then fields=options.fields end
for i,v in ipairs(fields)do
 v.sourceId=1000+i*3
 if options.values and options.values[v.name]~=nil then v.value=options.values[v.name]end
 if options.current and options.current[v.name]~=nil then v.current=options.current[v.name]end
 if options.absent and options.absent[v.name]then v.present=false end
end
model={getInfo=function()return actualModel end,getTimer=function(index)return timers[index]end,
 setTimer=function(index,params)timerWrites[#timerWrites+1]={index=index,params=params};local t=timers[index]or{};timers[index]=t;for k,v in pairs(params)do t[k]=v end end,
 resetTimer=function(index)timerResets[#timerResets+1]=index;local t=timers[index];if t then t.value=t.start or 0 end end,
 resetSensor=function(index)sensorResets[#sensorResets+1]=index;local s=fields[index+1];if s then s.current=false end end,
 getSensor=function(i)
 scans=scans+1;local v=fields[i+1];if not v or v.present==false then return nil end
 return {name=v.name,type=0,id=v.id or 10,unit=v.unit,prec=2}
end}
getTime=function()return now end
getDateTime=function()return {hour=12,min=34}end
getVersion=function()return '2.12.4' end
getFieldInfo=function(name)for i,v in ipairs(fields)do if v.present~=false and (v.name==name or v.sourceId==name)then return {id=v.sourceId,unit=v.unit,name=v.name}end end end
getSourceIndex=function(name)for i,v in ipairs(fields)do if v.present~=false and name==CHAR_TELEMETRY..v.name then return v.sourceId end end end
getSourceValue=function(id)
 if id=='tx-voltage'then return options.radioVoltage or 8.1,options.radioCurrent~=false,options.radioCurrent~=false end
 reads=reads+1;local offset=(id-1000)%3;local index=math.floor((id-1000)/3);local v=fields[index]
 if v and v.present~=false then
  local current=v.current~=false
  if v.name=='Ptch'or v.name=='Roll'then current=attitudeCurrent end
  local value=v.value
  if offset>0 then local bounds=options.extrema and options.extrema[v.name];if bounds then value=offset==1 and bounds.min or bounds.max else value=type(value)=='number'and value or nil end end
  return value,current,current
 end
end
getGeneralSettings=function()return options.radioGeneral or{battMin=6.6,battMax=8.4,battWarn=6.6}end
getValue=function(name)return name=='tx-voltage' and 8.1 or 0 end
getSwitchIndex=function(name)return name=='Tele' and 999 or nil end
getSwitchValue=function(id)return id==999 end
playTone=function()end;playHaptic=function()end
local device=options.device
if device then crossfireTelemetryPush=device.transport.push;crossfireTelemetryPop=device.transport.pop else crossfireTelemetryPush=function()return true end;crossfireTelemetryPop=function()end end
local state={status='OFF',ready=false,active=false,responses=0,timeouts=0}
loadScript=function(path)
 if string.find(path,'radio-status.lua',1,true)then return function()return radioFactory end end
 if string.find(path,'model-image.lua',1,true)then return function()return modelImageFactory end end
 if string.find(path,'quick-pack.lua',1,true)then return function()return quickPackFactory end end
 if string.find(path,'input-indicators.lua',1,true)then return function()return inputsFactory end end
 if string.find(path,'input-picker.lua',1,true)then return function()return pickerFactory end end
 if string.find(path,'navigation-utils.lua',1,true)then return function()return navigationFactory end end
 if string.find(path,'model-store.lua',1,true)then return function()return modelStoreFactory end end
 if string.find(path,'timer-owner.lua',1,true)then return function()return timerFactory end end
 if string.find(path,'diagnostics-log.lua',1,true)then return function()return logFactory end end
 if string.find(path,'native-extrema.lua',1,true)then return function()return extremaFactory end end
 if string.find(path,'reference-ui.lua',1,true)then return function()return referenceUiFactory end end
 if string.find(path,'/reference.lua',1,true)then return function()return referenceFactory end end
 if string.find(path,'power-policy.lua',1,true)then return function()return powerFactory end end
 if string.find(path,'/link.lua',1,true)then return function()return linkFactory end end
 if string.find(path,'msp-adapters.lua',1,true)then return function()return adaptersFactory end end
 if string.find(path,'vtx-native.lua',1,true)then return function()return nativeFactory end end
 if string.find(path,'protocols.lua',1,true)then return function()return protocolsFactory end end
 if string.find(path,'session.lua',1,true)then return function()return sessionFactory end end
 if string.find(path,'crsf-msp.lua',1,true)and device then return function()return mspFactory end end
 if string.find(path,'crsf-msp.lua',1,true)then return function()return {new=function()
  return {snapshot=function()return state end,tick=function()return state end,
   stop=function()state.active=false;state.ready=false end}
 end}end end
 if string.find(path,'arm-status.lua',1,true)then return function()return decoder end end
end
local maskInfo={};local inkColor
Bitmap={open=function(path)
 bitmaps=bitmaps+1
 if string.find(path,'/icons/',1,true)then
  local size=string.find(path,'-18.png',1,true)and 18 or 30
  return {size,size,path}
 end
 error('Native cockpit must not load instrument bitmaps: '..path)
end,getSize=function(b)return b[1],b[2]end,toMask=function(b)
 assert(b[3]and string.find(b[3],'/icons/',1,true),'only icons enter the mask renderer')
 local mask=string.char(b[1],0,b[2],0)..b[3]
 maskInfo[mask]={size=b[1],path=b[3]};return mask
end}
lcd={RGB=function(r,g,b)return r*65536+g*256+b end,setColor=function(_,color)inkColor=color end,
drawFilledRectangle=function(x,y,w,h)commands[#commands+1]={kind='fill',x=x,y=y,w=w,h=h,color=inkColor}end,
drawText=function(x,y,text,flags)commands[#commands+1]={kind='text',x=x,y=y,text=tostring(text),flags=flags or 0,color=inkColor}end,
drawLine=function(x,y,x2,y2,pattern,flags)commands[#commands+1]={kind='line',x=x,y=y,x2=x2,y2=y2,color=inkColor}end,
drawFilledCircle=function(x,y,r)commands[#commands+1]={kind='disc',x=x,y=y,r=r,color=inkColor}end,
drawLineWithClipping=function()end,drawCircle=function(x,y,r)commands[#commands+1]={kind='circle',x=x,y=y,r=r,color=inkColor}end,
drawFilledTriangle=function()end,drawHudRectangle=function(pitch,roll,xmin,xmax,ymin,ymax)
 commands[#commands+1]={kind='hud',pitch=pitch,roll=roll,xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax}
end,drawBitmap=function()end,drawBitmapPattern=function(mask,x,y,flags)
 local info=assert(maskInfo[mask],'draw the actual converted icon mask')
 commands[#commands+1]={kind='pattern',x=x,y=y,size=info.size,path=info.path,flags=flags,color=inkColor}
end}

-- Deliberately proportional: caption tests must use measurement, not #text.
lcd.sizeText=function(text,flags)
 local font=(flags or 0)%1024;local scale=font==TINSIZE and .75 or font==MIDSIZE and 1.5 or font==DBLSIZE and 2 or 1
 local widths={W=10,M=9,I=3,[' ']=4,['/']=5,['.']=3};local width=0
 for i=1,#text do local c=string.sub(text,i,i);width=width+(widths[c]or 7)end
 local height=font==TINSIZE and 12 or font==MIDSIZE and 29 or font==DBLSIZE and 38 or 17
 return width*scale,height
end
local app=assert(loadstring(source,'@telem-under-test'))();app.init()
local a={}
a.send=function(event,touch)now=now+10;commands={};local result=app.run(event,touch);if device then device:service(now)end;return result end
local function visible(predicate)
 for i,c in ipairs(commands)do
  if c.kind=='text' and predicate(c.text,c)then
   local width,height=lcd.sizeText(c.text,c.flags);local left=c.x
   if math.floor(c.flags/RIGHT)%2==1 then left=left-width end
   local hidden=false
   for j=i+1,#commands do
    local r=commands[j]
    if r.kind=='fill' and r.x<=left and r.y<=c.y and r.x+r.w>=left+width and r.y+r.h>=c.y+height then hidden=true;break end
   end
   if not hidden then return c end
  end
 end
end
a.state=function()
 local s=app.inspect()
 local caption=visible(function(text,c)return c.y>=35 and c.y<61 and string.find(text,' / SELECT SECTION',1,true)end)
 s.navCaption=caption and string.gsub(caption.text,' / SELECT SECTION','')
 return s
end
a.arrange=function(id)app.arrange(id);assert(a.send(0)==0)end
-- Drive the actual unified inspector through the visible header and rotary input.
a.gpsOpenInfo=function()
 if not app.inputRuntime.gpsInfo then assert(a.send(E.EVT_TOUCH_TAP,{x=345,y=47})==0)end
 return assert(app.inputRuntime.gpsInfo,'unified GPS inspector must open')
end
a.gpsScrollTo=function(title)
 a.gpsOpenInfo()
 for i=1,300 do
  for _,c in ipairs(commands)do if c.kind=='text'and c.text==title and c.y>=64 and c.y<216 then return app.inputRuntime.gpsInfo end end
  local m=app.inputRuntime.gpsInfo;local before=m.offset
  assert(a.send(E.EVT_VIRTUAL_NEXT)==0)
  if m.offset==before then break end
 end
 error('GPS info row is not reachable: '..title)
end
a.gpsAction=function(key)
 assert(a.send(E.EVT_TOUCH_TAP,{x=400,y=259})==0)
 local m=assert(app.inputRuntime.gpsMenu,'GPS actions must open');assert(m.kind=='ACTIONS')
 for i,row in ipairs(m.rows)do if row[1]==key then assert(a.send(E.EVT_TOUCH_TAP,{x=180,y=m.top+24+(i-1)*30+15})==0);return end end
 error('Unknown GPS action '..tostring(key))
end
a.bitmapLoads=function()return bitmaps end
a.sourceScans=function()return scans end
a.writes=function()return writes end
a.visible=function(text)return visible(function(v)return string.find(v,text,1,true)~=nil end)~=nil end
a.sourceStatus=function(names)return app.telemetry.sourceStatus(names)end
a.drawPower=function(data)commands={};app.drawPower(data);return commands end
a.config=app.configuration
a.inputs=app.inputRuntime
a.packPicker=app.packPicker
a.savedSettings=function()return disk[cfgPath]end
a.files=disk;a.timerWrites=timerWrites;a.timerResets=timerResets;a.sensorResets=sensorResets;a.timers=timers
a.setModelInfo=function(info)actualModel=info end
a.background=function(ticks)now=now+(ticks or 20);app.background()end
a.snapshot=app.snapshot
a.settle=function()now=now+20;return a.send(0)end -- Wait for the real 200ms slow-sample deadline.
a.reinit=app.init
a.close=app.close;a.setRetained=app.setRetained;a.runtimeServices=app.runtimeServices
a.fcState=function()return app.fcLink.state end
a.sourceReads=function()return reads end
a.telemetryData=function()
 local sampled=app.telemetry.sample();local result={}
 for k,v in pairs(sampled)do result[k]=v end
 return result
end
a.setSensor=function(name,value,current,present)
 for _,v in ipairs(fields)do if v.name==name then
  v.value=value;v.current=current;v.present=present;return
 end end
 error('Unknown test sensor '..name)
end
a.addSensor=function(name,value,unit,current)
 fields[#fields+1]={name=name,value=value,unit=unit or 0,current=current,sourceId=1000+(#fields+1)*3}
end
a.setWarning=function(enabled)fields[1].value=enabled and 19.8 or 24 end
a.setAttitude=function(pitch,roll)fields[12].value=pitch;fields[13].value=roll end
a.setAttitudeCurrent=function(current)attitudeCurrent=current end
a.setFlightMode=function(value)fields[14].value=value end
a.setModelName=function(value)actualModel.name=value;app.setModelName(value)end
a.setHome=function(value)app.setHome(value)end
a.setFooterData=function(voltage,satellites)fields[1].value=voltage;fields[8].value=satellites end
a.setMSP=function(status,age)
 state.active=status~='OFF';state.status=status;state.ready=status=='READY'
 state.lastStatus=age and now-age or nil
end
a.commands=function()return commands end
a.hud=function()for _,c in ipairs(commands)do if c.kind=='hud' then return c end end end
a.prepareDirty=function(store)
 a.arrange(8)
 if store=='app' or store=='both' then
  app.configuration.openSection(1);assert(a.send(0)==0)
  assert(a.send(E.EVT_VIRTUAL_ENTER)==0);assert(a.send(E.EVT_VIRTUAL_NEXT)==0);assert(a.send(E.EVT_VIRTUAL_ENTER)==0)
 end
 if store=='battery' or store=='both' then
  app.configuration.openSection(3);assert(a.send(0)==0)
  assert(a.send(E.EVT_VIRTUAL_ENTER)==0);assert(a.send(E.EVT_VIRTUAL_NEXT)==0);assert(a.send(E.EVT_VIRTUAL_ENTER)==0)
 end
 assert(app.configuration.hasChanges(),'fixture edit must create a real draft change')
end
a.setArmingPacket=function(bytes,major,minor)
 state.active=true;state.ready=true;state.status='READY';state.lastStatus=now
 state.statusData=bytes;state.apiMajor=major;state.apiMinor=minor
end
a.setArmingFlags=function(bits,minor,count)
 local bytes={};for i=1,21 do bytes[i]=0 end
 bytes[16]=0;bytes[17]=count or 26
 for _,bit in ipairs(bits or {0,7})do
  local index=18+math.floor(bit/8);bytes[index]=bytes[index]+2^(bit%8)
 end
 a.setArmingPacket(bytes,1,minor or 46)
end
assert(a.send(0)==0);assert(a.send(0)==0)
return a
end
if adapterOnly then io=realIO;return {make=make,events=E}end
contract.run(make,E)
local scenarios=0
local function check(name,fn)local a=make();local ok,why=pcall(fn,a);assert(ok,name..': '..tostring(why));scenarios=scenarios+1 end
check('dirty short-RTN modal captures navigation and can cancel',function(a)
 a.prepareDirty('app');a.arrange(1)
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().exitOpen and a.state().page==1)
 assert(a.send(E.EVT_SYS_BREAK)==0 and a.state().exitOpen and a.state().navFocus==nil,'modal owns SYS')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and not a.state().exitOpen and a.state().dirty,'RTN cancels exit without discarding')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().exitOpen)
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==8 and a.state().configList and a.state().dirty,'Keep Editing opens Setup categories and retains draft')
 assert(a.writes()==0,'Keep Editing never saves implicitly')
end)
check('discard/exit clears both app and battery drafts without saving',function(a)
 a.prepareDirty('both');a.arrange(1);assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().exitOpen)
 assert(a.send(E.EVT_VIRTUAL_NEXT_PAGE)==0 and a.state().exitChoice==2 and a.state().page==1,'modal captures PAGE as choice movement')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==1 and not a.state().dirty and not a.state().appDirty and not a.state().batteryDirty,'Discard/Exit clears both draft stores')
 assert(a.writes()==0,'discard never writes settings')
end)
check('Setup categories back to Flight; VTX-linked settings back to Video',function(a)
 a.arrange(8);assert(a.state().configList)
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==1)
 a.arrange(11);assert(a.send(E.EVT_TOUCH_TAP,{x=385,y=232})==0 and a.state().page==8 and not a.state().configList)
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==8 and a.state().configList)
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==11)
end)
check('arming reason ENTER does not silently move the selection',function(a)
 a.setArmingFlags();a.arrange(10);assert(a.send(E.EVT_TOUCH_TAP,{x=55,y=120})==0 and a.visible('Throttle too high'))
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.visible('Throttle too high'))
end)
check('warning details can be focused and activated from Flight',function(a)
 a.setWarning(true);assert(a.send(0)==0)
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==1)
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().controlCaption=='THROTTLE / INPUT STATES')
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().controlCaption=='ALERT DETAILS')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==3,'visible alert action opens Power')
end)
check('reselecting Setup opens categories and preserves both unsaved stores',function(a)
 a.prepareDirty('both');assert(not a.state().configList and a.state().appDirty and a.state().batteryDirty)
 local before=a.bitmapLoads()
 assert(a.send(E.EVT_TOUCH_TAP,{x=323,y=15})==0 and a.state().page==8 and a.state().configList,'Setup icon has a stable category landing')
 assert(a.state().appDirty and a.state().batteryDirty and a.writes()==0,'category landing retains both drafts without saving')
 assert(a.bitmapLoads()==before,'same-page Setup navigation preserves graphics cache')
end)
for _,degrees in ipairs({-20,0,20})do
 check('both horizons use normalized CRSF pitch '..degrees,function(a)
  a.setAttitude(degrees*math.pi/180,7*math.pi/180)
  for _,pageId in ipairs({1,11})do
   a.arrange(pageId);if pageId==11 then a.send(E.EVT_TOUCH_TAP,{x=420,y=45})end;local h=assert(a.hud(),'visible attitude must use native horizon')
   assert(math.abs(h.pitch+degrees)<.000001,'raw CRSF pitch must be negated before rendering')
   assert(math.abs(h.roll-7)<.000001,'Roll sign must remain unchanged')
   assert(h.xmin==(pageId==1 and 136 or 341),'correct full-size/inset renderer')
   if pageId==1 then
    for _,c in ipairs(a.commands())do if c.kind=='text' and c.y>=65 and c.y<83 then
     assert(c.x~=141 and c.x~=300,'primary attitude has no redundant P/R readouts')
    end end
   end
  end
 end)
end
check('clean attitude clears immediately when its source becomes stale or missing',function(a)
 local function angleCount()
  local n=0;for _,c in ipairs(a.commands())do if c.kind=='text'and(c.x==141 or c.x==300)and c.y>=65 and c.y<83 then n=n+1 end end
  return n
 end
 a.setAttitude(.2,-.4);a.arrange(1);assert(a.hud()and angleCount()==0,'current attitude draws the horizon without numeric overlays')
 a.setAttitudeCurrent(false);assert(a.send(0)==0)
 assert(not a.hud()and angleCount()==0 and a.visible('UNAVAILABLE'),'stale native telemetry cannot leave stale angle values or a horizon')
 a.setAttitudeCurrent(true);a.setAttitude(nil,nil);assert(a.send(0)==0)
 assert(not a.hud()and angleCount()==0,'missing attitude remains unavailable')
 a.setAttitude(0,0);assert(a.send(0)==0)
 assert(a.hud()and angleCount()==0,'a current level attitude restores the horizon without numeric overlays')
end)
check('repeated ENTER operates the visibly focused non-navigation control',function(a)
 a.arrange(6)
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().controlCaption=='SENSORS')
 for i=1,3 do assert(a.send(E.EVT_VIRTUAL_NEXT)==0)end
 assert(a.state().controlCaption=='STICK MODE' and a.state().stickMode==2)
 local focus=a.state().controlFocus
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().stickMode==3 and a.state().controlFocus==focus,'first Mode activation retains visible focus')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().stickMode==4 and a.state().controlFocus==focus,'second Mode activation needs no hidden refocus step')
end)
local function focusBox(a,top,bottom)
 local n,x,y,x2,y2=0,480,272,0,0
 for _,c in ipairs(a.commands())do if c.kind=='line'and c.color==0x68dded and c.y>=top and c.y<=bottom and c.y2>=top and c.y2<=bottom then
  n=n+1;x=math.min(x,c.x,c.x2);y=math.min(y,c.y,c.y2);x2=math.max(x2,c.x,c.x2);y2=math.max(y2,c.y,c.y2)
 end end
 assert(n==4,'one visible focus rectangle has four edges');return {x=x,y=y,w=x2-x+1,h=y2-y+1}
end
local function inside(r,x,y,w,h)return x>=r.x and y>=r.y and x+w<=r.x+r.w and y+h<=r.y+r.h end
check('main selection and physical focus enclose native30px icons',function(a)
 for _,id in ipairs({1,10,5,7,11,8,6})do
  a.arrange(id);local image,bar,plate
  for _,c in ipairs(a.commands())do
   if c.kind=='pattern'and c.size==30 and c.y==2 and ((id==10 and string.find(c.path,'/gpp_bad.png',1,true))or(id~=10 and c.color==0xe8f2f5))then image=c end
   if c.kind=='fill'and c.y==31 and c.h==2 and c.color==0xa4e37d then bar=c end
   if c.kind=='fill'and c.y==1 and c.h==32 and c.color==0x0f1f2b then plate=c end
  end
  assert(image and bar and plate,'selected image, underline and backplate render')
  assert(bar.w>=30 and bar.x<=image.x and bar.x+bar.w>=image.x+30,'underline spans the full icon')
  assert(bar.x+bar.w/2==image.x+15 and inside(plate,image.x,image.y,30,30),'selection centers and encloses the complete icon')
  assert(a.send(E.EVT_SYS_BREAK)==0);local r=focusBox(a,0,33)
  assert(r.x==plate.x and r.y==plate.y and r.w==plate.w and r.h==plate.h and inside(r,image.x,image.y,30,30),'physical focus uses the same enclosing plate')
 end
end)
check('context groups center native font boxes without changing tab routes',function(a)
 local groups={{pages={10,13},tabs={10,13}},{pages={5,3,9},tabs={5,3,9}},
  {pages={11},tabs={11}},{pages={6,4,12},tabs={6,4,12}}}
 local names={[1]='speed',[10]='gpp_bad',[5]='table_chart',[3]='battery_full',[9]='cell_tower',[7]='my_location',
  [2]='route',[11]='head_mounted_device',[6]='sports_esports',[4]='sensors',[12]='bug_report',[13]='sports_esports'}
 for _,g in ipairs(groups)do for _,page in ipairs(g.pages)do
  a.arrange(page);local top,small=0,0
  for _,c in ipairs(a.commands())do if c.kind=='pattern'then
   assert(c.flags==CUSTOM_COLOR)
   if c.y==2 then assert(c.size==30);top=top+1 elseif c.y==38 then assert(c.size==18);small=small+1 end
  end end
  assert(top==7 and small==#g.tabs,'seven navigation icons and every owning context icon render')
  local left,width=0,480
  for i,id in ipairs(g.tabs)do
   local x=left+math.floor((i-1)*width/#g.tabs);local right=left+math.floor(i*width/#g.tabs)
   local r={x=x+1,y=35,w=right-x-2,h=26};local image,caption
   for _,c in ipairs(a.commands())do if c.kind=='pattern'and c.y>=35 and c.y<61 and string.find(c.path,'/'..names[id]..'-18.png',1,true)then image=c end end
   assert(image and image.y==38,'context image uses the shared content row')
   for _,c in ipairs(a.commands())do if c.kind=='text'and c.x==image.x+24 and c.y>=35 and c.y<61 then caption=c end end
   assert(caption,'context label follows its image and six-pixel gap');local w,h=lcd.sizeText(caption.text,caption.flags)
   assert(inside(r,image.x,image.y,18,18)and inside(r,caption.x,caption.y,w,h),'tab encloses complete image and native text')
   assert(caption.y==35+math.floor((24-h)/2)and math.abs(image.y+9-caption.y-h/2)<=.5,'text centers the measured native font height')
   local l,rgt=r.x+6,r.x+r.w-6-(page==11 and 90 or 0)
   assert(image.x>=l and caption.x+w<=rgt and math.abs((image.x+caption.x+w)/2-(l+rgt)/2)<=.5,'whole icon/text group centers with gutters and Video reference reserved')
   assert(a.send(E.EVT_TOUCH_TAP,{x=x+math.floor((right-x)/2),y=44})==0 and a.state().page==id,'tab geometry retains its destination');a.arrange(page)
  end
 end end
end)
check('context keyboard outline encloses18px icon and native text',function(a)
 for _,page in ipairs({5,3,9,6,4,12})do
  a.arrange(page);assert(a.send(E.EVT_VIRTUAL_ENTER)==0);local r=focusBox(a,35,60);local image,caption
  assert(r.y==35 and r.h==26,'keyboard context outline shares tab height')
  for _,c in ipairs(a.commands())do if c.kind=='pattern'and c.size==18 and c.y==38 and inside(r,c.x,c.y,18,18)then image=c end end
  assert(image,'focused tab encloses image')
  for _,c in ipairs(a.commands())do if c.kind=='text'and c.x==image.x+24 and c.y>=35 and c.y<61 then caption=c end end
  assert(caption,'focused label stays with image');local w,h=lcd.sizeText(caption.text,caption.flags);assert(inside(r,caption.x,caption.y,w,h),'focus encloses full native font box')
 end
end)
local function footer(a)
 local icons,texts={},{}
 for _,c in ipairs(a.commands())do
  if c.kind=='pattern'and c.y>=246 then icons[c.x]=c
  elseif c.kind=='text'and c.y>=246 then texts[c.x]=c end
 end
 return icons,texts
end
local function footerBounds(a)
 local icons,texts=footer(a)
 local flight=a.state().page==1
 for _,v in ipairs({{128,flight and'home'or'battery_full'},{248,flight and'satellite_alt'or'cell_tower'}})do
  local c=icons[v[1]]
  assert(c and c.size==18 and c.y==250 and string.find(c.path,'/'..v[2]..'-18.png',1,true),'footer retains the exact icon meaning, native size and stable position')
 end
 for _,c in pairs(icons)do
  if flight then assert(not string.find(c.path,'cell_tower',1,true)and not string.find(c.path,'battery_full',1,true),'Flight footer keeps unique navigation context')end
 end
 for _,c in pairs(texts)do
  local w,h=lcd.sizeText(c.text,c.flags);local left,right=c.x,c.x+w
  if math.floor(c.flags/RIGHT)%2==1 then left=c.x-w;right=c.x end
  local cellLeft,cellRight=left<120 and 0 or left<240 and 120 or left<304 and 240 or 304,
   left<120 and 120 or left<240 and 240 or left<304 and 304 or 480
  assert(left>=cellLeft and right<=cellRight and c.y>=247 and c.y+h<=271,'normal footer text must fit its own cell and measured font box')
  assert(c.text~='FM'and c.text~='99%'and c.text~='-56 dBm'and c.text~='24.0V'and not string.find(c.text,'MSP ',1,true),'footer preserves unique mode/home/satellites/arming data without redundant prefixes or MSP/link/battery status')
 end
 return icons,texts
end
check('Arm toolbar replaces duplicate Flight with exact focus, touch bounds and caller return',function(a)
 a.arrange(1)
 assert(not a.visible('ARM INFO'),'Flight must not regain an ARM INFO context button')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().controlCaption=='FLIGHT PANEL','first ENTER reveals panel selector')
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().controlCaption=='THROTTLE / INPUT STATES','NEXT reveals throttle/input strip')
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().controlCaption=='FLIGHT PANEL','ordinary body controls wrap without hidden Arm footer')
 assert(a.send(E.EVT_SYS_BREAK)==0 and a.state().navFocus==0 and a.state().navCaption=='FLIGHT','Home owns the only Flight focus')
 assert(a.send(E.EVT_VIRTUAL_PREV)==0 and a.state().navFocus==6 and a.state().navCaption=='ARM INFO','Home previous focuses the final Arm toolbar destination')
 local r=focusBox(a,0,33);local arm
 for _,c in ipairs(a.commands())do if c.kind=='pattern'and c.y==2 and string.find(c.path,'/gpp_bad.png',1,true)then arm=c end end
 assert(arm and inside(r,arm.x,arm.y,30,30),'physical focus encloses the complete toolbar Arm icon')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==10 and a.state().navFocus==nil,'ENTER activates the new Arm root')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==1,'Arm RTN restores Flight caller')
 for _,point in ipairs({{420,0},{479,33},{455,15}})do
  a.arrange(1);assert(a.send(E.EVT_TOUCH_TAP,{x=point[1],y=point[2]})==0 and a.state().page==10,'every edge of last toolbar cell opens Arm')
  assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==1,'each toolbar entry preserves its caller')
 end
 for _,point in ipairs({{431,259},{432,259},{479,271},{324,35},{401,62},{240,45}})do
  a.arrange(1);assert(a.send(E.EVT_TOUCH_TAP,{x=point[1],y=point[2]})==0 and a.state().page==1,'normal footer and compass do not open Arm')
 end
end)
check('Radio Inputs context and physical routes preserve caller ownership without sibling loops',function(a)
 local function tap(x,y,id)assert(a.send(E.EVT_TOUCH_TAP,{x=x,y=y})==0 and a.state().page==id)end
 local function back(id)assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==id,'RTN must restore expected caller '..id)end
 a.arrange(1);tap(230,233,13);back(1)
 a.arrange(1);tap(230,233,13);tap(455,15,10);back(1)
 a.arrange(5);tap(455,15,10)
 assert(a.visible('ARM INFO')and not a.visible('FM /'),'Arm context uses its actual name rather than obsolete Flight mode caption')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().controlCaption=='RADIO INPUTS','Arm first physical control exposes its visible sibling tab')
 local r=focusBox(a,35,60);assert(r.x==241 and r.w==238,'Radio Inputs physical focus uses complete second context tab')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==13,'second ENTER opens Radio Inputs')
 back(10);back(5)
 a.arrange(5);tap(455,15,10);tap(360,44,13);tap(120,44,10);tap(360,44,13)
 back(10);back(5)
 -- A previous unrelated Arm caller must not leak through the sibling tab.
 a.arrange(1);tap(230,233,13);tap(120,44,10);back(1)
 a.arrange(5);tap(455,15,10);back(5)
 a.arrange(1);tap(230,233,13)
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().controlCaption=='ARM INFO','Radio Inputs first physical control is its visible Arm sibling')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==10,'Radio Inputs physical Arm sibling activates')
 back(1)
 assert(a.writes()==0,'all sibling and caller navigation is read only')
end)
check('all thirteen pages retain truthful full-width status and a shared Arm toolbar',function(a)
 a.arrange(7);a.setHome({lat=25.9976807,lon=-97.1573563});a.settle()
 for _,id in ipairs({1,5,3,9,11,8,6,4,12,10,13})do
  if id==13 then a.arrange(1)end
  a.arrange(id);local icons,texts=footerBounds(a)
  assert(not icons[447],'former footer Arm icon is removed on every page')
  assert(texts[8].text=='ACRO'and texts[152].text==(id==1 and'0'or'24.0')and texts[272].text==(id==1 and'13'or'99')and texts[312].text=='FLAGS --','shared status values remain truthful on page '..id)
  for _,x in ipairs({432,455,479})do assert(a.send(E.EVT_TOUCH_TAP,{x=x,y=259})==0 and a.state().page==id,'ordinary expanded status is inert')end
  if id~=10 then
   assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=15})==0 and a.state().page==10,'toolbar Arm is reachable from every page including Setup and Radio Inputs')
   assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==(id==13 and 1 or id),'Arm RTN restores its actual owner without sibling loops')
  end
 end
 a.arrange(1);a.setHome(nil);a.setFooterData(24,nil);a.setFlightMode(nil);assert(a.settle()==0)
 local _,texts=footerBounds(a)
 assert(texts[8].text=='--'and texts[152].text=='--'and texts[272].text=='--','missing mode/home/satellites never fabricate zero')
 a.setFooterData(24,0);assert(a.settle()==0);_,texts=footerBounds(a);assert(texts[272].text=='0','real zero satellites is available')
 a.setFlightMode('HORIZON');assert(a.settle()==0);_,texts=footerBounds(a);assert(texts[8].text=='HORIZON','ordinary mode retains native17px text')
 a.setFlightMode('A VERY LONG FLIGHT MODE FOR THIS FOOTER');assert(a.settle()==0);_,texts=footerBounds(a)
 assert(string.find(texts[8].text,'...',1,true)and lcd.sizeText(texts[8].text,texts[8].flags)<=104,'long mode fits unchanged104px field')
end)
check('expanded arming summary retains API1.48 truth and status-aware toolbar tint',function(a)
 local function summary(expected,footerColor,shieldColor)
  assert(a.settle()==0);local _,texts=footerBounds(a);assert(texts[312].text==expected,'expected arming summary '..expected..', got '..tostring(texts[312]and texts[312].text))
  assert(lcd.sizeText(texts[312].text,texts[312].flags)<=160,'arming text fits newly expanded160px field')
  local arm;for _,c in ipairs(a.commands())do if c.kind=='pattern'and c.y==2 and string.find(c.path,'/gpp_bad.png',1,true)then arm=c end end
  assert(texts[312].color==footerColor,'footer retains its descriptive status color independently')
  assert(arm and arm.color==shieldColor and(arm.color==0xfa5b40 or arm.color==0xa4e37d),'toolbar shield is exclusively green or red')
  assert(arm.x>=417 and arm.x+30<=480,'shield is in the last toolbar slot')
 end
 a.arrange(1);a.setArmingFlags({18},48,30);summary('GPS',0xffae62,0xfa5b40)
 a.setArmingFlags({7,18,23},48,30);summary('THROTTLE +2',0xffae62,0xfa5b40)
 a.setArmingFlags({},48,30);summary('NO FLAGS',0xe8f2f5,0xa4e37d)
 local _,texts=footer(a);assert(not string.find(texts[312].text,'READY',1,true)and not string.find(texts[312].text,'ARMED',1,true),'zero mask never claims ready/armed')
 a.setArmingFlags({29},99,32);summary('BIT 29',0xffae62,0xfa5b40)
 a.setArmingFlags({},99,32);summary('NO FLAGS',0xe8f2f5,0xfa5b40)
 a.setMSP('READY',900);summary('STATUS OLD',0xffae62,0xfa5b40)
 a.setMSP('OFF');summary('FLAGS --',0x8ca4b3,0xfa5b40)
 a.setArmingPacket({0},1,48);summary('STATUS ERROR',0xffae62,0xfa5b40)
 a.setArmingFlags({18},48,30);summary('GPS',0xffae62,0xfa5b40)
end)
check('binary Arm shield stays green or red independently of Cyan and Amber accents',function()
 for _,accent in ipairs({2,3})do
  local b=make({settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nvtxMode=2\naccent='..accent..'\n'})
  local function shield(expected)
   assert(b.settle()==0)
   local image;for _,c in ipairs(b.commands())do if c.kind=='pattern'and c.y==2 and string.find(c.path,'/gpp_bad.png',1,true)then image=c end end
   assert(image and image.x>=417 and image.color==expected,'accent '..accent..' must not recolor binary shield')
  end
  b.setArmingFlags({},48,30);shield(0xa4e37d)
  b.setArmingFlags({18},48,30);shield(0xfa5b40)
  b.setArmingFlags({},99,32);shield(0xfa5b40)
  b.setArmingFlags({},48,29);shield(0xfa5b40)
  b.setMSP('READY',900);shield(0xfa5b40)
  b.setMSP('OFF');shield(0xfa5b40)
  b.setArmingPacket({0},1,48);shield(0xfa5b40)
  b.setArmingFlags({},48,30);b.setWarning(true);shield(0xa4e37d)
  assert(b.visible('BATTERY CRITICAL'),'independent battery warning remains visible while FC flags clear')
  assert(b.writes()==0,'visual status never writes configuration')
 end
end)
check('full-width warning details and notices keep Arm in the toolbar',function(a)
 a.setWarning(true);assert(a.send(0)==0)
 local icons,texts=footer(a);assert(not icons[447]and a.visible('BATTERY CRITICAL'),'warning uses footer without duplicate Arm icon')
 for _,c in pairs(texts)do
  local w,h=lcd.sizeText(c.text,c.flags);local left=c.x
  if math.floor(c.flags/RIGHT)%2==1 then left=c.x-w end
  assert(left>=0 and left+w<=480 and c.y==246+math.floor((26-h)/2),'warning fits and centers within full480px footer')
 end
 for _,x in ipairs({0,431,432,479})do
  a.arrange(1);assert(a.send(E.EVT_TOUCH_TAP,{x=x,y=259})==0 and a.state().page==3,'all warning pixels including former Arm cell open Power')
 end
 a.arrange(1);assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=15})==0 and a.state().page==10,'warning never steals toolbar Arm')
 a.setWarning(false);a.settle();a.arrange(7);a.gpsAction('refresh');assert(a.visible('SENSOR BINDINGS REFRESHED'),'real refresh notice remains')
 icons,texts=footer(a);assert(not icons[447],'notice has no footer Arm icon')
 for _,c in pairs(texts)do local w,h=lcd.sizeText(c.text,c.flags);assert(c.x+w<=480 and c.y==246+math.floor((26-h)/2),'notice uses full footer with measured font center')end
 assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=259})==0 and a.state().page==7,'notice status remains inert')
 assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=15})==0 and a.state().page==10,'notice does not swallow toolbar Arm')
 a.arrange(5);assert(a.send(E.EVT_SYS_BREAK)==0 and a.state().navFocus==1)
 assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=15})==0 and a.state().page==10 and a.state().navFocus==nil,'toolbar touch closes active navigation focus')
end)
check('body focus keeps visible controls and never visits removed footer Arm',function(a)
 for _,case in ipairs({{5,{'POWER','RC LINK'}},{7,{'GPS INFO','MAP / ZOOM','GPS ACTIONS'}},{6,{'SENSORS','DIAGNOSTICS','GUIDE FAMILY','STICK MODE','NEXT GUIDES'}}})do
  a.arrange(case[1]);assert(a.send(E.EVT_VIRTUAL_ENTER)==0)
  for _,caption in ipairs(case[2])do
   assert(a.state().controlCaption==caption,'existing visible focus order stays stable: '..caption)
   assert(a.send(E.EVT_VIRTUAL_NEXT)==0)
  end
  for i=1,24 do
   local state=a.state();assert(state.controlCaption~='ARM INFO'and state.controlCaption~='ALERT DETAILS','normal focus contains only visible context/body controls')
   assert(a.send(E.EVT_VIRTUAL_NEXT)==0)
  end
  assert(a.writes()==0,'traversing focus does not save settings')
 end
end)
check('Setup without a warning has no phantom footer focus and Arm preserves categories',function(a)
 a.arrange(8);local before=a.writes()
 assert(a.send(E.EVT_VIRTUAL_PREV)==0 and a.state().controlFocus==nil and a.state().configList,'first category PREV cannot focus deleted Arm footer')
 assert(a.send(E.EVT_SYS_BREAK)==0 and a.state().navFocus==4)
 for i=1,2 do assert(a.send(E.EVT_VIRTUAL_NEXT)==0)end
 assert(a.state().navFocus==6 and a.state().navCaption=='ARM INFO')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==10,'physical navigation opens Arm from Setup')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==8 and a.state().configList,'RTN restores original category list')
 assert(a.writes()==before and not a.state().dirty,'Arm round trip does not change settings')
end)
check('clearing a Setup warning restores category focus and ENTER immediately',function(a)
 a.setWarning(true);a.arrange(8)
 assert(a.send(E.EVT_VIRTUAL_PREV)==0 and a.state().controlCaption=='ALERT DETAILS','PREV focuses actual warning')
 local r=focusBox(a,246,271);assert(r.x==0 and r.w==480,'warning focus includes reclaimed footer area')
 a.setWarning(false);assert(a.settle()==0)
 assert(a.state().page==8 and a.state().configList and a.state().controlFocus==nil,'cleared warning drops hidden focus')
 local categoryHighlight=false
 for _,c in ipairs(a.commands())do if c.kind=='fill'and c.x==10 and c.y==64 and c.w==460 and c.h==18 and c.color==0xa4e37d then categoryHighlight=true end end
 assert(categoryHighlight,'first category visibly regains focus immediately')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==8 and not a.state().configList,'ENTER immediately opens category')
 assert(a.writes()==0 and not a.state().dirty,'warning recovery writes no settings')
end)
check('Setup warning focus returns directly to categories in both directions',function(a)
 a.setWarning(true);a.arrange(8)
 assert(a.send(E.EVT_VIRTUAL_PREV)==0 and a.state().controlCaption=='ALERT DETAILS')
 assert(a.send(E.EVT_VIRTUAL_PREV)==0 and a.state().controlFocus==nil and a.state().configList,'PREV from sole warning control returns to categories')
 assert(a.send(E.EVT_VIRTUAL_PREV)==0 and a.state().controlCaption=='ALERT DETAILS')
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().controlFocus==nil and a.state().configList,'NEXT from warning returns to categories without ghost Arm')
end)
check('Setup toolbar Arm round trip preserves draft and active value edit',function(a)
 a.prepareDirty('app');assert(a.state().page==8 and a.state().dirty and not a.state().editing)
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().editing)
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().editing)
 assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=15})==0 and a.state().page==10,'toolbar Arm works during pending Setup edit')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==8 and a.state().editing and a.state().dirty,'RTN restores exact form and active edit')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==8 and not a.state().editing and a.state().dirty,'restored edit can still cancel without dropping prior draft')
 assert(a.writes()==0,'Arm never commits settings')
end)
check('Arm self-route preserves reason and exit modal captures toolbar and former footer',function(a)
 a.setArmingFlags();a.arrange(10);assert(a.send(E.EVT_TOUCH_TAP,{x=55,y=120})==0 and a.visible('Throttle too high'))
 assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=15})==0 and a.state().page==10 and a.visible('Throttle too high'),'selected Arm toolbar does not reset reason')
 a.prepareDirty('app');a.arrange(1);assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().exitOpen)
 for _,point in ipairs({{455,15},{20,15},{455,259}})do
  assert(a.send(E.EVT_TOUCH_TAP,{x=point[1],y=point[2]})==0 and a.state().exitOpen and a.state().page==1,'exit modal owns all navigation touches')
 end
 assert(a.state().dirty and a.writes()==0,'modal cannot silently save/discard')
end)
check('Power Sources and Limits actions support keyboard focus, precise settings and return',function(a)
 a.arrange(3);assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().controlCaption=='TELEMETRY')
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().controlCaption=='RC LINK')
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().controlCaption=='BATTERY SOURCES')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==8 and not a.state().configList,'Sources opens the real Model Setup form')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().editing)
 local selectedVoltage=false
 for _,c in ipairs(a.commands())do if c.kind=='text'and c.text=='Battery voltage'and c.color==0x050c13 then selectedVoltage=true end end
 assert(selectedVoltage,'Sources lands on voltage row rather than unrelated protocol settings')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and not a.state().editing)
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().configList)
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==3,'settings returns to the originating Power page')
 assert(a.send(E.EVT_TOUCH_TAP,{x=390,y=231})==0 and a.state().page==8 and a.visible('Pack cell count'),'Limits opens the actual battery store')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().configList)
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==3,'battery limits return to Power')
 assert(a.writes()==0 and not a.state().dirty,'opening source/limit actions does not save or change preferences')
end)
check('Power Refresh and Limits retain physical focus order and explicit return',function(a)
 a.arrange(3);assert(a.send(E.EVT_VIRTUAL_ENTER)==0)
 for i=1,3 do assert(a.send(E.EVT_VIRTUAL_NEXT)==0)end
 assert(a.state().controlCaption=='REFRESH','Power refresh follows Sources in physical focus order')
 local before=a.sourceScans();local focus=a.state().controlFocus
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==3 and a.sourceScans()>before and a.state().controlFocus==focus,'keyboard Refresh performs a real refresh and retains visible focus')
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().controlCaption=='CELL LIMITS')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==8 and a.visible('Pack cell count'),'keyboard Limits opens the battery store')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().configList)
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==3)
 assert(a.send(E.EVT_TOUCH_TAP,{x=70,y=231})==0 and a.state().page==8,'touch Sources shares the keyboard route')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().configList)
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==3,'touch Sources returns to Power')
end)
check('unavailable battery Limits stay visibly disabled and skipped by keys',function(a)
 local b=make({settings='ADCFG1\nrcProtocol=ELRS / CRSF\nvoltage=None\n'});b.arrange(3)
 assert(b.send(E.EVT_TOUCH_TAP,{x=390,y=231})==0 and b.state().page==3,'disabled Limits touch does not open a hidden category')
 assert(b.send(E.EVT_VIRTUAL_ENTER)==0)
 for i=1,4 do assert(b.send(E.EVT_VIRTUAL_NEXT)==0)end
 assert(b.state().controlCaption=='TELEMETRY','physical focus skips disabled Limits/Profile and wraps to the next visible context action')
 assert(b.writes()==0 and b.config.get('voltage')=='None','disabled actions preserve the explicit source choice')
end)
check('Power and Sensors refresh invalidate real cached source bindings',function(a)
 a.setSensor('Curr',nil,false,false);a.arrange(3)
 a.addSensor('LateCurrent',4.5,0,true)
 local before=a.sourceScans()
 assert(a.send(E.EVT_TOUCH_TAP,{x=210,y=231})==0 and a.visible('SENSOR BINDINGS REFRESHED'))
 assert(a.sourceScans()>before,'Power Refresh scans metadata rather than only repainting')
 local scans=a.sourceScans();for i=1,20 do assert(a.send(0)==0)end
 assert(a.sourceScans()==scans,'ordinary redraws do not repeat all-sensor scans')
 a.arrange(4);a.setSensor('Curr',6,true,true);before=a.sourceScans()
 assert(a.send(E.EVT_TOUCH_TAP,{x=300,y=231})==0 and a.visible('SENSOR BINDINGS REFRESHED'))
 assert(a.sourceScans()>before,'Sensors Refresh updates shared telemetry bindings too')
 a.arrange(3);assert(a.visible('6.0 A'),'Power consumes the restored actual current source')
end)
check('long model name with descenders keeps tiny font and header bounds',function(a)
 a.setModelName('ggy MMMM pqy ggy MMMM pqy');assert(a.send(0)==0);local name
 for _,c in ipairs(a.commands())do if c.kind=='text'and c.x==60 and c.y>=18 and c.y<34 then name=c end end
 assert(name and name.flags%1024==TINSIZE,'long model name fitting never promotes to a taller font')
 local w,h=lcd.sizeText(name.text,name.flags)
 assert(w<=54 and h==12 and name.y>=18 and name.y+h<=33,'tiny name stays within54px by15px header row')
 assert(name.y==18+math.floor((15-h)/2)and string.find(name.text,'...',1,true),'tiny name is centered with visible truncation')
end)
check('Data Arm Inputs Settings parent-back preserves the original section caller',function(a)
 a.arrange(5)
 assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=15})==0 and a.state().page==10)
 assert(a.send(E.EVT_TOUCH_TAP,{x=360,y=45})==0 and a.state().page==13)
 assert(a.send(E.EVT_TOUCH_TAP,{x=120,y=232})==0 and a.state().page==8 and not a.state().configList)
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==8 and a.state().configList)
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==13,'Settings parent return restores Inputs without changing its caller')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==10,'Inputs returns to Arm rather than revisiting Setup')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==5,'Arm returns to Data after the whole settings round trip')
 assert(a.writes()==0 and not a.state().dirty,'read-only caller navigation writes no settings')
end)
check('reentering Arm from Inputs settings cannot create a return cycle',function(a)
 for _,origin in ipairs({1,5,8})do
  a.arrange(origin)
  if origin==1 then assert(a.send(E.EVT_TOUCH_TAP,{x=230,y=233})==0)
  else assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=15})==0);assert(a.send(E.EVT_TOUCH_TAP,{x=360,y=45})==0)end
  assert(a.state().page==13)
  assert(a.send(E.EVT_TOUCH_TAP,{x=120,y=232})==0 and a.state().page==8)
  assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=15})==0 and a.state().page==10)
  assert(a.send(E.EVT_TOUCH_TAP,{x=360,y=45})==0 and a.state().page==13)
  assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==10)
  assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==origin,'RTN leaves the Arm/Inputs/Setup section instead of cycling')
  if origin==8 then for i=1,3 do if a.state().page==1 then break end;assert(a.send(E.EVT_VIRTUAL_EXIT)==0)end;assert(a.state().page==1,'restored Setup caller exits Home without looping')end
 end
end)
io=realIO
print('PASS: '..scenarios..' dirty-exit, settings-return, draft-preservation, repeated-control, arming, warning-action and pitch-rendering scenarios')
