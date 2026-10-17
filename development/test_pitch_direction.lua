-- Pitch convention verified against original Toolbox2.0 CRSF GYRO bytecode.
-- Exercise the real telemetry module: raw CRSF radians become nose-up-positive
-- display degrees. Other axes, degree sources, current flags and mappings stay intact.
local f=assert(io.open('sdcard/SCRIPTS/TOOLS/telem.lua'));local app=f:read('*a');f:close()
local a=assert(string.find(app,'local telemetry=(function()',1,true));local b=assert(string.find(app,'local ROOT=',a,true))
local source='local cachedTelemetryField=getFieldInfo;local refreshSources=function()end;local retryMissingSources=function()end\n'..string.sub(app,a,b-1)..'\nreturn telemetry'
UNIT_KTS=1;UNIT_MPH=2;UNIT_METERS_PER_SECOND=3;UNIT_FEET_PER_SECOND=4;UNIT_KMH=5;UNIT_RADIANS=6;UNIT_DEGREE=7;UNIT_FEET=8;UNIT_METERS=9
local current,mapped=true,nil
local fields={{name='Ptch',unit=UNIT_RADIANS,value=0},{name='Roll',unit=UNIT_RADIANS,value=0},
 {name='Yaw',unit=UNIT_RADIANS,value=math.pi/6},{name='Hdg',unit=UNIT_DEGREE,value=150}}
model={getSensor=function(i)return fields[i+1]end}
getTime=function()return 1000 end
getFieldInfo=function(name)for i,s in ipairs(fields)do if s.name==name then return {id=i}end end end
getSourceValue=function(id)return fields[id].value,current,current end
configuration={resolve=function(name)return name=='Ptch'and mapped or name end,get=function(key)if key=='pack'then return 0 end end,
 value=function()end,linkStatus=function()end,refreshSensorChoices=function()end}
batteryConfig={check=function()return nil,0 end}
local t=assert(loadstring(source))()
local checks=0
local function near(actual,expected,why)
 assert(type(actual)=='number'and math.abs(actual-expected)<.00001,why..': expected '..expected..', got '..tostring(actual));checks=checks+1
end
for _,degrees in ipairs({-90,-30,-10,0,10,30,90,180})do
 fields[1].value=degrees*math.pi/180;fields[2].value=15*math.pi/180;t.init()
 local pitch,roll=t.pollAttitude();near(pitch,-degrees,'CRSF pitch sign');near(roll,15,'CRSF roll sign')
 local d=t.sample();near(d.pitch,-degrees,'shared display pitch');near(d.roll,15,'shared display roll')
 near(d.yaw,30,'yaw unaffected');near(d.hdg,150,'heading unaffected')
end
fields[1].value=0;t.init();assert(string.format('%.1f',t.sample().pitch)=='0.0','level must not display negative zero');checks=checks+1
fields[1].unit=UNIT_DEGREE;fields[1].value=23;t.init();near(t.sample().pitch,23,'degree sources retain their existing convention')
fields[1].name='MyPitch';fields[1].unit=UNIT_RADIANS;fields[1].value=-math.pi/6;mapped='MyPitch';t.init()
near(t.pollAttitude(),30,'renamed/mapped radian pitch uses the same correction')
fields[1].unit=999;t.init();assert(t.sample().pitch==nil,'unsupported pitch unit must stay unavailable');checks=checks+1
fields[1].unit=UNIT_RADIANS;t.init();current=false
local pitch,roll=t.pollAttitude();assert(pitch==nil and roll==nil,'stale attitude must clear');checks=checks+1
assert(t.sample().pitch==nil,'stale shared pitch must stay unavailable');checks=checks+1
print('PASS: '..checks..' pitch direction, unit, mapping and stale-data checks')
