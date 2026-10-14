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

jit.off()
local realio=io;local file=assert(io.open('sdcard/SCRIPTS/TOOLS/telem.lua'));local code=file:read('*a');file:close()
code=string.gsub(code,'return {init=init,run=run}\n$','return {init=init,run=run,metrics=renderStats}\n')
local tick,lookups,reads,writes=0,0,0,0
getTime=function()return tick end
getValue=function()return 0 end
getVersion=function()return 'test' end
model.getInfo=function()return {name='benchmark'}end
CHAR_TELEMETRY='T:'
getSourceIndex=function(n)lookups=lookups+1;for i,v in ipairs(fields)do if n=='T:'..v.name then return i end end;return 0 end
getFieldInfo=function()error('Telemetry must use qualified source lookup')end
getSourceValue=function(id)reads=reads+1;local v=fields[id];if v.name=='Roll' or v.name=='Ptch' then return math.sin(tick/100),true,true end;return v.value,true,true end
local noop=function()end
lcd=setmetatable({RGB=function()return 0 end},{__index=function()return noop end})
CUSTOM_COLOR=0;SMLSIZE=0;MIDSIZE=0;DBLSIZE=0;SOLID=0;RIGHT=0
local dims={{480,38},{96,208},{88,208},{296,44},{296,30}}
Bitmap={open=function(path)local i=tonumber(string.match(path,'fc(%d)'));if i then return dims[i]end;return {152,152}end,getSize=function(b)return b[1],b[2]end}
io={open=function(path,mode)if mode=='w' or mode=='a' then writes=writes+1 end end}
local app=assert(loadstring(code))();app.init();app.run(0);local bound=lookups
for i=1,12000 do tick=tick+1;app.run(0)end
assert(lookups==bound,'Resolved IDs must survive 120 simulated seconds without rediscovery')
assert(writes==0,'No diagnostic writes permitted inside refresh')
assert(app.metrics.attitudeHz>=99,'Attitude must be sampled on callbacks skipped by redraw limiter')
assert(app.metrics.fps<=26 and app.metrics.fps>=24)
io=realio
print(string.format('PASS: 12000 callbacks; %d source binds, zero runtime writes; attitude %.1f Hz, draw %.1f Hz (mock clock)',lookups,app.metrics.attitudeHz,app.metrics.fps))
