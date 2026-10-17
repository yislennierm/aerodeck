-- Real-app regression with actual TX16S2.12.4 key aliases. Run from project root.
-- Inspection is appended only to a loaded source copy; production source stays unchanged.
local realIO=io
local adapterOnly=(...)=='adapter'
local f=assert(realIO.open('sdcard/SCRIPTS/TOOLS/telem.lua'));local original=f:read('*a');f:close()
local tail=assert(string.find(original,'return {init=init,run=run,stop=fcLink.stop}',1,true))
local source=string.sub(original,1,tail-1)..[[return {init=init,run=run,stop=fcLink.stop,
 inspect=function()
  local item=shell.focused()
  return {page=page,navFocus=menuOpen and menuIndex or nil,controlFocus=controlFocus>0 and controlFocus or nil,
   controlCaption=item and item[6],exitOpen=exitOpen,exitChoice=exitChoice,
   dirty=configuration.hasChanges(),appDirty=configuration.hasAppChanges(),batteryDirty=batteryConfig.hasChanges(),
   configList=configuration.isList(),editing=configuration.isEditing(),stickMode=stickMode,commandPage=commandPage}
 end,
 arrange=function(id)menuOpen=false;controlFocus=0;exitOpen=false;chooseSection(id)end,
 setModelName=function(value)modelName=value end,
 setHome=function(value)navHome=value end,
 configuration=configuration,fcLink=fcLink,telemetry=telemetry,drawPower=function(data)powerScreen(data)end}]]
local E=assert(loadfile('development/events_tx16s_2124.lua'))()
local contract=assert(loadfile('development/navigation_contract.lua'))()
local decoder=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/arm-status.lua'))()
local function make(options)
options=options or {}
local now,reads,writes,bitmaps,scans=1000,0,0,0,0
local attitudeCurrent=true
local commands,disk={},{}
local cfgPath='/SCRIPTS/TOOLS/AERODECK/settings-554954455354.cfg'
local batteryPath='/SCRIPTS/TOOLS/AERODECK/battery-554954455354.cfg'
disk[cfgPath]=options.settings or 'ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nvtxMode=2\n'
disk[batteryPath]='ADBAT1 6,27,30,34,36,42,0,0\n'
io={open=function(path,mode)
 if mode=='r' and disk[path]==nil then return nil end
 return {path=path,mode=mode}
end,read=function(f)return disk[f.path]end,close=function()end,
write=function(f,s)assert(f.mode=='w');disk[f.path]=s;writes=writes+1 end}
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
for _,v in ipairs(fields)do
 if options.values and options.values[v.name]~=nil then v.value=options.values[v.name]end
 if options.current and options.current[v.name]~=nil then v.current=options.current[v.name]end
 if options.absent and options.absent[v.name]then v.present=false end
end
model={getInfo=function()return {name='UITEST'}end,getSensor=function(i)
 scans=scans+1;local v=fields[i+1];if not v or v.present==false then return nil end
 return {name=v.name,type=0,id=v.id or 10,unit=v.unit,prec=2}
end}
getTime=function()return now end
getDateTime=function()return {hour=12,min=34}end
getVersion=function()return '2.12.4' end
getFieldInfo=function(name)for i,v in ipairs(fields)do if v.present~=false and (v.name==name or i==name)then return {id=i,unit=v.unit,name=v.name}end end end
getSourceIndex=function(name)for i,v in ipairs(fields)do if v.present~=false and name==CHAR_TELEMETRY..v.name then return i end end end
getSourceValue=function(id)reads=reads+1;local v=fields[id];if v and v.present~=false then
 if v.name=='Ptch'or v.name=='Roll'then return v.value,attitudeCurrent,attitudeCurrent end
 return v.value,v.current~=false,v.current~=false
end end
getValue=function(name)return name=='tx-voltage' and 8.1 or 0 end
getSwitchIndex=function(name)return name=='Tele' and 999 or nil end
getSwitchValue=function(id)return id==999 end
playTone=function()end;playHaptic=function()end
local state={status='OFF',ready=false,active=false,responses=0,timeouts=0}
loadScript=function(path)
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
a.send=function(event,touch)now=now+10;commands={};return app.run(event,touch)end
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
a.bitmapLoads=function()return bitmaps end
a.sourceScans=function()return scans end
a.writes=function()return writes end
a.visible=function(text)return visible(function(v)return string.find(v,text,1,true)~=nil end)~=nil end
a.sourceStatus=function(names)return app.telemetry.sourceStatus(names)end
a.drawPower=function(data)commands={};app.drawPower(data);return commands end
a.config=app.configuration
a.savedSettings=function()return disk[cfgPath]end
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
 fields[#fields+1]={name=name,value=value,unit=unit or 0,current=current}
end
a.setWarning=function(enabled)fields[1].value=enabled and 19.8 or 24 end
a.setAttitude=function(pitch,roll)fields[12].value=pitch;fields[13].value=roll end
a.setAttitudeCurrent=function(current)attitudeCurrent=current end
a.setFlightMode=function(value)fields[14].value=value end
a.setModelName=function(value)app.setModelName(value)end
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
 a.arrange(11);assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==11)
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==8 and not a.state().configList)
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==8 and a.state().configList)
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==11)
end)
check('arming reason ENTER does not silently move the selection',function(a)
 a.setArmingFlags();a.arrange(10);assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.visible('Throttle too high'))
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.visible('Throttle too high'))
end)
check('warning details can be focused and activated from Flight',function(a)
 a.setWarning(true);assert(a.send(0)==0)
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==1)
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().controlCaption=='ALERT DETAILS')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==3,'visible alert action opens Power')
end)
check('reselecting Setup opens categories and preserves both unsaved stores',function(a)
 a.prepareDirty('both');assert(not a.state().configList and a.state().appDirty and a.state().batteryDirty)
 local before=a.bitmapLoads()
 assert(a.send(E.EVT_TOUCH_TAP,{x=386,y=15})==0 and a.state().page==8 and a.state().configList,'Setup icon has a stable category landing')
 assert(a.state().appDirty and a.state().batteryDirty and a.writes()==0,'category landing retains both drafts without saving')
 assert(a.bitmapLoads()==before,'same-page Setup navigation preserves graphics cache')
end)
for _,degrees in ipairs({-20,0,20})do
 check('both horizons use normalized CRSF pitch '..degrees,function(a)
  a.setAttitude(degrees*math.pi/180,7*math.pi/180)
  for _,pageId in ipairs({1,11})do
   a.arrange(pageId);local h=assert(a.hud(),'visible attitude must use native horizon')
   assert(math.abs(h.pitch+degrees)<.000001,'raw CRSF pitch must be negated before rendering')
   assert(math.abs(h.roll-7)<.000001,'Roll sign must remain unchanged')
   assert(h.xmin==(pageId==1 and 78 or 341),'correct full-size/inset renderer')
   if pageId==1 then
    local pitch,roll
    for _,c in ipairs(a.commands())do if c.kind=='text'and c.y>=65 and c.y<83 then
     if c.x==141 then pitch=c elseif c.x==300 then roll=c end
    end end
    assert(pitch and math.abs(tonumber(pitch.text)+degrees)<.000001,'pitch readout uses the same normalized radians and sign as its native horizon')
    assert(roll and roll.text=='+7','roll readout retains its original sign')
    if degrees==0 then assert(pitch.text=='+0','real zero pitch remains available without a negative-zero artifact')end
   end
  end
 end)
end
check('live angle readouts clear immediately when their source becomes stale or missing',function(a)
 local function angleCount()
  local n=0;for _,c in ipairs(a.commands())do if c.kind=='text'and(c.x==141 or c.x==300)and c.y>=65 and c.y<83 then n=n+1 end end
  return n
 end
 a.setAttitude(.2,-.4);a.arrange(1);assert(a.hud()and angleCount()==2,'current attitude provides both actual angle values')
 a.setAttitudeCurrent(false);assert(a.send(0)==0)
 assert(not a.hud()and angleCount()==0 and a.visible('UNAVAILABLE'),'stale native telemetry cannot leave stale angle values or a horizon')
 a.setAttitudeCurrent(true);a.setAttitude(nil,nil);assert(a.send(0)==0)
 assert(not a.hud()and angleCount()==0,'missing attitude remains unavailable')
 a.setAttitude(0,0);assert(a.send(0)==0)
 assert(a.hud()and angleCount()==2,'a current level attitude restores the real angle values')
end)
check('repeated ENTER operates the visibly focused non-navigation control',function(a)
 a.arrange(6)
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().controlCaption=='SENSORS')
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0);assert(a.send(E.EVT_VIRTUAL_NEXT)==0)
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
 for _,id in ipairs({1,5,7,11,8,6})do
  a.arrange(id);local image,bar,plate
  for _,c in ipairs(a.commands())do
   if c.kind=='pattern'and c.size==30 and c.y==2 and c.color==0xe8f2f5 then image=c end
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
 local groups={{pages={10},tabs={1,10}},{pages={5,3,9},tabs={5,3,9}},{pages={7,2},tabs={7,2}},
  {pages={11},tabs={11}},{pages={6,4,12},tabs={6,4,12}}}
 local names={[1]='speed',[10]='gpp_bad',[5]='table_chart',[3]='battery_full',[9]='cell_tower',[7]='my_location',
  [2]='route',[11]='head_mounted_device',[6]='sports_esports',[4]='sensors',[12]='bug_report'}
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
 for _,page in ipairs({5,3,9,7,2,6,4,12})do
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
 for _,v in ipairs({{128,'home'},{248,'satellite_alt'},{447,'gpp_bad'}})do
  local c=icons[v[1]]
  assert(c and c.size==18 and c.y==250 and string.find(c.path,'/'..v[2]..'-18.png',1,true),'footer retains the exact icon meaning, native size and stable position')
 end
 for _,c in pairs(icons)do
  assert(not string.find(c.path,'cell_tower',1,true)and not string.find(c.path,'battery_full',1,true),'footer must not repeat link or battery indicators')
 end
 for _,c in pairs(texts)do
  local w,h=lcd.sizeText(c.text,c.flags);local left,right=c.x,c.x+w
  if math.floor(c.flags/RIGHT)%2==1 then left=c.x-w;right=c.x end
  local cellLeft,cellRight=left<120 and 0 or left<240 and 120 or left<304 and 240 or 304,
   left<120 and 120 or left<240 and 240 or left<304 and 304 or 432
  assert(left>=cellLeft and right<=cellRight and c.y>=247 and c.y+h<=271,'normal footer text must fit its own cell and measured font box')
  assert(c.text~='FM'and c.text~='99%'and c.text~='-56 dBm'and c.text~='24.0V'and not string.find(c.text,'MSP ',1,true),'footer preserves unique mode/home/satellites/arming data without redundant prefixes or MSP/link/battery status')
 end
 return icons,texts
end
check('icon-only arming shortcut replaces the upper-right button with exact bottom focus and bounds',function(a)
 a.arrange(1)
 assert(not a.visible('ARM INFO'),'Flight must not retain a text-labelled ARM INFO button')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==1,'first ENTER reveals footer focus')
 local r=focusBox(a,246,271)
 assert(r.x==432 and r.y==246 and r.w==48 and r.h==26,'physical focus must use the complete footer Arm hit area')
 local icons=footer(a);assert(icons[447]and inside(r,447,250,18,18),'focus encloses the actual icon')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==10,'second ENTER opens arming reasons')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==1,'RTN returns to Flight')
 for _,point in ipairs({{432,246},{479,271},{455,259}})do
  a.arrange(1);assert(a.send(E.EVT_TOUCH_TAP,{x=point[1],y=point[2]})==0 and a.state().page==10,'every edge of the icon-only footer cell routes to arming reasons')
 end
 for _,point in ipairs({{431,259},{432,245},{480,259},{324,35},{401,62},{240,45}})do
  a.arrange(1);assert(a.send(E.EVT_TOUCH_TAP,{x=point[1],y=point[2]})==0 and a.state().page==1,'normal status/compass and adjacent pixels must not activate arming reasons')
 end
end)
check('all twelve pages share one footer with truthful missing and zero data',function(a)
 a.arrange(7) -- Initialize the existing GPS lifecycle before arranging a fixed local home.
 a.setHome({lat=25.9976807,lon=-97.1573563})
 for _,id in ipairs({1,5,3,9,7,2,11,8,6,4,12,10})do
  a.arrange(id);local icons,texts=footerBounds(a)
  assert(texts[8].text=='ACRO*'and texts[152].text=='0'and texts[272].text=='13'and texts[312].text=='FLAGS --','all pages use the same actual mode, local home, satellites and unavailable arming state: page'..id..' mode='..tostring(texts[8]and texts[8].text)..' home='..tostring(texts[152]and texts[152].text)..' sats='..tostring(texts[272]and texts[272].text)..' flags='..tostring(texts[312]and texts[312].text))
  if id~=10 then
   assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=259})==0 and a.state().page==10,'the same footer shortcut works on every page including Setup')
   assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==id,'RTN from the shared arming shortcut returns its actual originating page')
  end
 end
 a.arrange(1);a.setHome(nil);a.setFooterData(24,nil);a.setFlightMode(nil);assert(a.send(0)==0)
 local _,texts=footerBounds(a)
 assert(texts[8].text=='--'and texts[152].text=='--'and texts[272].text=='--','missing mode, home and satellites must not become fabricated zeroes')
 a.setFooterData(24,0);assert(a.send(0)==0);_,texts=footerBounds(a);assert(texts[272].text=='0','real zero satellites remains available')
 a.setFlightMode('HORIZON');assert(a.send(0)==0);_,texts=footerBounds(a);assert(texts[8].text=='HORIZON','ordinary mode retains readable17px text')
 a.setFlightMode('A VERY LONG FLIGHT MODE FOR THIS FOOTER');assert(a.send(0)==0);_,texts=footerBounds(a)
 assert(string.find(texts[8].text,'...',1,true)and lcd.sizeText(texts[8].text,texts[8].flags)<=104,'long mode values truncate inside their104px field')
end)
check('footer arming summary uses fresh real API1.48 flags and never claims readiness',function(a)
 local function summary(expected)
  assert(a.send(0)==0);local _,texts=footerBounds(a);assert(texts[312].text==expected,'expected arming summary '..expected..', got '..tostring(texts[312]and texts[312].text))
 end
 a.arrange(1);a.setArmingFlags({18},48,30);summary('GPS')
 a.setArmingFlags({7,18,23},48,30);summary('THROTTLE +2')
 a.setArmingFlags({},48,30);summary('NO FLAGS')
 local _,texts=footer(a);assert(not string.find(texts[312].text,'READY',1,true)and not string.find(texts[312].text,'ARMED',1,true),'a zero mask cannot prove armed/ready state')
 a.setArmingFlags({29},99,32);summary('BIT 29')
 a.setMSP('READY',900);summary('STATUS OLD')
 a.setMSP('OFF');summary('FLAGS --')
 a.setArmingPacket({0},1,48);summary('STATUS ERROR')
 a.setArmingFlags({18},48,30);summary('GPS')
end)
check('arming shortcut stays available during warnings, notices and menu focus',function(a)
 a.setWarning(true);assert(a.send(0)==0)
 local icons,texts=footer(a);assert(icons[447]and a.visible('BATTERY CRITICAL'),'warning and dedicated arming icon remain visible together')
 for _,c in pairs(texts)do
  local w,h=lcd.sizeText(c.text,c.flags);local left=c.x
  if math.floor(c.flags/RIGHT)%2==1 then left=c.x-w end
  assert(left>=0 and left+w<=432 and c.y==246+math.floor((26-h)/2),'warning text fits the left432px and stays clear of the arming shortcut')
  assert(c.text~='99%'and c.text~='24.0V','warnings do not repeat compact rail values')
 end
 assert(a.send(E.EVT_TOUCH_TAP,{x=431,y=259})==0 and a.state().page==3,'warning-details touch target reaches the pixel before the Arm target')
 a.arrange(1);assert(a.send(E.EVT_TOUCH_TAP,{x=432,y=259})==0 and a.state().page==10,'warning does not steal the first Arm target pixel')
 a.setWarning(false);a.arrange(7);assert(a.send(E.EVT_TOUCH_TAP,{x=30,y=231})==0 and a.visible('SENSOR BINDINGS REFRESHED'),'fixture opens the real refresh notice')
 icons,texts=footer(a);assert(icons[447],'notice retains the arming icon')
 for _,c in pairs(texts)do local w,h=lcd.sizeText(c.text,c.flags);assert(c.x+w<=432 and c.y==246+math.floor((26-h)/2),'notice stays left of the dedicated arming shortcut')end
 assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=259})==0 and a.state().page==10,'notice does not swallow Arm touch')
 a.arrange(5);assert(a.send(E.EVT_SYS_BREAK)==0 and a.state().navFocus==2)
 assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=259})==0 and a.state().page==10 and a.state().navFocus==nil,'footer Arm touch also works while top navigation is focused')
end)
check('body focus order is preserved and footer Arm follows existing controls',function(a)
 for _,case in ipairs({{5,{'POWER','RC LINK'}},{7,{'TRACK / HOME','REFRESH SENSORS','SET LOCAL HOME'}},{6,{'SENSORS','DIAGNOSTICS','STICK MODE','NEXT COMMANDS'}}})do
  a.arrange(case[1]);assert(a.send(E.EVT_VIRTUAL_ENTER)==0)
  for i,caption in ipairs(case[2])do
   assert(a.state().controlCaption==caption,'existing visible context/body focus order must stay stable: '..caption)
   assert(a.send(E.EVT_VIRTUAL_NEXT)==0)
  end
  local r=focusBox(a,246,271);assert(r.x==432 and r.w==48,'Arm is appended after existing enabled page controls')
  assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==10,'focused appended Arm opens reasons')
 end
end)
check('Setup physical footer navigation preserves its category and does not change settings',function(a)
 a.arrange(8);local before=a.writes()
 assert(a.send(E.EVT_VIRTUAL_PREV)==0,'PREV can leave the first Setup category for the footer')
 local r=focusBox(a,246,271);assert(r.x==432 and r.y==246 and r.w==48 and r.h==26,'Setup uses the same visible Arm focus')
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().page==8 and a.state().configList and a.state().controlFocus==nil,'NEXT beyond the last enabled footer control returns to the unchanged category list')
 assert(a.send(E.EVT_VIRTUAL_PREV)==0);assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==8 and a.state().configList and a.state().controlFocus==nil,'RTN from footer focus stays in Setup categories')
 assert(a.send(E.EVT_VIRTUAL_PREV)==0);assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==10,'Setup footer activates through physical ENTER')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==8 and a.state().configList,'Arm RTN restores Setup category origin')
 assert(a.writes()==before and not a.state().dirty,'accessing arming reasons must not change or save settings')
end)
check('clearing a Setup warning restores category focus and ENTER immediately',function(a)
 a.setWarning(true);a.arrange(8)
 assert(a.send(E.EVT_VIRTUAL_PREV)==0 and a.state().controlCaption=='ALERT DETAILS','fixture focuses the actual live warning action')
 a.setWarning(false);assert(a.send(0)==0)
 assert(a.state().page==8 and a.state().configList and a.state().controlFocus==nil,'clearing the warning must remove its disabled hidden footer focus')
 local categoryHighlight=false
 for _,c in ipairs(a.commands())do
  if c.kind=='fill'and c.x==10 and c.y==64 and c.w==460 and c.h==18 and c.color==0xa4e37d then categoryHighlight=true end
 end
 assert(categoryHighlight,'the unchanged first category must visibly regain focus in the warning-clear frame')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==8 and not a.state().configList,'ENTER immediately opens the selected category without rotary or RTN recovery')
 assert(a.writes()==0 and not a.state().dirty,'warning focus recovery must not change or write settings')
end)
check('Setup footer orders Arm before warning details and traverses without wrapping',function(a)
 a.setWarning(true);a.arrange(8)
 assert(a.send(E.EVT_VIRTUAL_PREV)==0 and a.state().controlCaption=='ALERT DETAILS','PREV enters the final enabled warning control')
 local r=focusBox(a,246,271);assert(r.x==0 and r.w==432,'warning focus excludes the Arm shortcut cell')
 assert(a.send(E.EVT_VIRTUAL_PREV)==0);r=focusBox(a,246,271);assert(r.x==432 and r.w==48,'PREV moves linearly from warning details to Arm')
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().controlCaption=='ALERT DETAILS','NEXT moves linearly from Arm to warning details')
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().controlFocus==nil and a.state().configList,'NEXT after warning details returns to categories without wrapping')
end)
check('Setup Arm round-trip preserves drafts and the current value edit',function(a)
 a.prepareDirty('app');assert(a.state().page==8 and a.state().dirty and not a.state().editing)
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().editing,'fixture starts a real pending value edit')
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().editing)
 assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=259})==0 and a.state().page==10,'Arm tap works during an active Setup edit')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==8 and a.state().editing and a.state().dirty,'RTN restores the same Setup form and active edit')
 assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().page==8 and not a.state().editing and a.state().dirty,'the original edit can still be cancelled without discarding the earlier draft')
 assert(a.writes()==0,'arming detail navigation never commits or writes settings')
end)
check('Arm self-route is disabled and exit modal captures the footer',function(a)
 a.setArmingFlags();a.arrange(10);assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.visible('Throttle too high'))
 assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=259})==0 and a.state().page==10 and a.visible('Throttle too high'),'selected arming footer icon does not reset its own reason selection')
 a.prepareDirty('app');a.arrange(1);assert(a.send(E.EVT_VIRTUAL_EXIT)==0 and a.state().exitOpen)
 assert(a.send(E.EVT_TOUCH_TAP,{x=455,y=259})==0 and a.state().exitOpen and a.state().page==1,'unsaved-exit modal owns footer taps')
 assert(a.state().dirty and a.writes()==0,'modal footer touch cannot discard or save drafts')
end)
check('Power Sources and Limits actions support keyboard focus, precise settings and return',function(a)
 a.arrange(3);assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().controlCaption=='TELEMETRY')
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().controlCaption=='RC LINK')
 assert(a.send(E.EVT_VIRTUAL_NEXT)==0 and a.state().controlCaption=='BATTERY SOURCES')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().page==8 and not a.state().configList,'Sources opens the real Model Setup form')
 assert(a.send(E.EVT_VIRTUAL_ENTER)==0 and a.state().editing)
 local selectedVoltage=false
 for _,c in ipairs(a.commands())do if c.kind=='text'and c.text=='Battery voltage'and c.color==0x070f16 then selectedVoltage=true end end
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
 assert(b.state().controlCaption=='ARM INFO','physical focus skips disabled Limits and reaches the next enabled action')
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
 for _,c in ipairs(a.commands())do if c.kind=='text'and c.x==43 and c.y>=18 and c.y<34 then name=c end end
 assert(name and name.flags%1024==TINSIZE,'long model name fitting never promotes to a taller font')
 local w,h=lcd.sizeText(name.text,name.flags)
 assert(w<=54 and h==12 and name.y>=18 and name.y+h<=33,'tiny name stays within54px by15px header row')
 assert(name.y==18+math.floor((15-h)/2)and string.find(name.text,'...',1,true),'tiny name is centered with visible truncation')
end)
io=realIO
print('PASS: '..scenarios..' dirty-exit, settings-return, draft-preservation, repeated-control, arming, warning-action and pitch-rendering scenarios')
