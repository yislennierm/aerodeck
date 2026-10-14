local f=assert(io.open('sdcard/SCRIPTS/TOOLS/telem.lua'));local app=f:read('*a');f:close()
local a=assert(string.find(app,'local telemetry=(function()',1,true));local b=assert(string.find(app,"local ROOT=",a,true))
local source="local cachedTelemetryField=getFieldInfo; local refreshSources=function()end\n"..string.sub(app,a,b-1)..'\nreturn telemetry'
local current=true
UNIT_KTS=1;UNIT_MPH=2;UNIT_METERS_PER_SECOND=3;UNIT_FEET_PER_SECOND=4;UNIT_KMH=5;UNIT_RADIANS=6;UNIT_DEGREE=7;UNIT_FEET=8;UNIT_METERS=9
local fields={{name='RxBt',unit=0,value=16.1},{name='GSpd',unit=UNIT_KTS,value=10},{name='GAlt',unit=UNIT_FEET,value=100},{name='Ptch',unit=UNIT_RADIANS,value=math.pi/6},{name='Roll',unit=UNIT_DEGREE,value=-15},{name='FM',unit=0,value='ANGLE'}}
configuration={get=function(k)if k=='startLive'then return 0 elseif k=='pack'then return 0 end end,resolve=function(n)return n end,value=function(n)for _,v in ipairs(fields)do if v.name==n and current then return v.value end end end,linkStatus=function()end}
batteryConfig={check=function()return nil,4 end}
model={getSensor=function(i)return fields[i+1]end}
getFieldInfo=function(n)for i,v in ipairs(fields)do if v.name==n then return {id=i}end end end
getSourceValue=function(id)return fields[id].value,current,current end
getRSSI=function()error('Live reader must not require generic RSSI')end
getTime=function()return 1000 end
local t=assert(loadstring(source))();t.init();local d=t.sample()
assert(d.ok and not d.demo and d.v==16.1 and d.flight=='ANGLE')
assert(math.abs(d.speed-18.52)<.001 and math.abs(d.alt-30.48)<.001 and math.abs(d.pitch-30)<.001)
current=false;d=t.sample();assert(not d.ok and d.v==nil and d.roll==nil and d.flight==nil)
for i=1,5 do t.toggle();d=t.sample();assert(not d.demo and not d.ok and d.v==nil) end
current=true;t.init();d=t.sample();assert(not d.demo and d.v==16.1)
print('PASS: live without RSSI, units, flight mode, stale clearing, no demo via refresh or old startup setting')
