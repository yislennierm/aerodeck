-- Exercise real app event routing and drawing with EdgeTX/LCD boundary mocks.
-- This is an application regression test; it is not a radio diagnostic tool.
local realIO=io
local file=assert(realIO.open('sdcard/SCRIPTS/TOOLS/telem.lua'));local source=file:read('*a');file:close()
local tail=assert(string.find(source,'return {init=init,run=run,stop=fcLink.stop}',1,true))
source=string.sub(source,1,tail-1)..[[return {init=init,run=run,stop=fcLink.stop,
 inspect=function()return {page=page,menu=menuOpen,menuIndex=menuIndex,stickMode=stickMode,commandPage=commandPage,navHome=navHome,trackCount=#navTrack}end,
 configuration=configuration,fcLink=fcLink,navSnapshot=navSnapshot}]]
local decoder=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/arm-status.lua'))()
local now,reads,writes=1000,0,0
local commands,disk={},{}
local cfgPath='/SCRIPTS/TOOLS/AERODECK/settings-554954455354.cfg'
local batteryPath='/SCRIPTS/TOOLS/AERODECK/battery-554954455354.cfg'
disk[cfgPath]='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nvtxMode=2\nautoHome=1\n'
disk[batteryPath]='ADBAT1 6,27,30,34,36,42,0,0\n'
io={open=function(path,mode)
 if mode=='r' and disk[path]==nil then return nil end
 return {path=path,mode=mode}
end,read=function(f)return disk[f.path]end,close=function()end,
write=function(f,s)assert(f.mode=='w');disk[f.path]=s;writes=writes+1 end}
SMLSIZE=0;MIDSIZE=256;DBLSIZE=512;CUSTOM_COLOR=4096;RIGHT=65536;CENTER=131072;SOLID=0
EVT_TOUCH_TAP=1;EVT_VIRTUAL_ENTER=2;EVT_VIRTUAL_NEXT=3;EVT_VIRTUAL_PREV=4
EVT_VIRTUAL_NEXT_PAGE=5;EVT_VIRTUAL_PREV_PAGE=6;EVT_VIRTUAL_EXIT=7
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
model={getInfo=function()return {name='UITEST'}end,getSensor=function(i)
 local v=fields[i+1];if not v then return nil end
 return {name=v.name,type=0,id=v.id or 10,unit=v.unit,prec=2}
end}
getTime=function()return now end
getDateTime=function()return {hour=12,min=34}end
getVersion=function()return '2.12.4' end
getFieldInfo=function(name)for i,v in ipairs(fields)do if v.name==name then return {id=i}end end end
getSourceIndex=function(name)for i,v in ipairs(fields)do if name==CHAR_TELEMETRY..v.name then return i end end end
getSourceValue=function(id)reads=reads+1;local v=fields[id];if v then return v.value,true,true end end
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
local bitmapDims={{480,38},{96,208},{88,208},{296,44},{296,30}}
local bitmapLoads=0
Bitmap={open=function(path)
 bitmapLoads=bitmapLoads+1
 local tile=tonumber(string.match(path,'fc(%d)')or string.match(path,'chrome%-(%d)'))
 local d=tile and bitmapDims[tile] or string.find(path,'bezel',1,true)and {152,152}or {18,30}
 return {d[1],d[2]}
end,getSize=function(b)return b[1],b[2]end}
lcd={RGB=function(r,g,b)return r*65536+g*256+b end,setColor=function()end,
drawFilledRectangle=function(x,y,w,h)commands[#commands+1]={kind='fill',x=x,y=y,w=w,h=h}end,
drawText=function(x,y,text,flags)commands[#commands+1]={kind='text',x=x,y=y,text=tostring(text),flags=flags or 0}end,
drawLine=function()end,drawLineWithClipping=function()end,drawCircle=function()end,
drawFilledTriangle=function()end,drawHudRectangle=function()end,drawBitmap=function()end}
local app=assert(loadstring(source))();app.init()
local function frame(event,touch)
 now=now+10;commands={};assert(app.run(event or 0,touch)==0);return app.inspect()
end
local function tap(x,y)return frame(EVT_TOUCH_TAP,{x=x,y=y})end
local function visible(predicate)
 for i,c in ipairs(commands)do
  if c.kind=='text' and predicate(c.text,c)then
   local width=#c.text*6;local left=c.x
   if math.floor(c.flags/RIGHT)%2==1 then left=left-width end
   local hidden=false
   for j=i+1,#commands do
    local r=commands[j]
    if r.kind=='fill' and r.x<=left and r.y<=c.y and r.x+r.w>=left+width and r.y+r.h>=c.y+12 then hidden=true;break end
   end
   if not hidden then return c end
  end
 end
end
local function has(text)return visible(function(v)return string.find(v,text,1,true)~=nil end)end
local function context(text)
 local c=visible(function(v)return v==text end)
 return c and c.y>=35 and c.y<61
end
local function iconOnlyHeader()
 assert(not visible(function(_,c)return c.x>=104 and c.y<34 end),'section navigation contains icons without header text labels')
end


local function out(k,v)print(k..'='..tostring(v))end
for i=1,35 do frame()end
out('flight_autoHome_set',app.inspect().navHome~=nil);out('flight_track_samples',app.inspect().trackCount)
tap(260,15);out('gps_autoHome_set',app.inspect().navHome~=nil);out('gps_track_samples',app.inspect().trackCount)
tap(130,15);local beforeLoads=bitmapLoads;tap(130,15);out('active_flight_tap_bitmap_loads',bitmapLoads-beforeLoads)
EVT_SYS_BREAK=42;frame(EVT_SYS_BREAK);out('SYS_opens_drawer',app.inspect().menu)
tap(386,15);out('initial_config_model_setup',context('MODEL SETUP'))
frame(EVT_VIRTUAL_NEXT_PAGE);out('PAGE_from_config_destination',app.inspect().page)
tap(386,15);tap(100,73);frame(EVT_VIRTUAL_NEXT);frame(EVT_VIRTUAL_ENTER)
out('rotary_edit_writes',writes);out('active_rc_after_rotary_enter',app.configuration.get('rcProtocol'))
now=now+10;out('RTN_after_edit_return',app.run(EVT_VIRTUAL_EXIT));app.init();frame()
out('rc_after_reopen',app.configuration.get('rcProtocol'))
tap(450,15);tap(30,44);out('stick_page_start',app.inspect().commandPage)
frame(EVT_VIRTUAL_NEXT);out('stick_rotary_next_page',app.inspect().commandPage)
tap(20,231);out('stick_PREV_first',app.inspect().commandPage);tap(20,231);out('stick_PREV_second',app.inspect().commandPage)
io=realIO
