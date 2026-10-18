-- Whole real app: positive attitude IDs stay fixed while failed-only discovery is bounded.
jit.off()
local realio=io;local file=assert(realio.open('sdcard/SCRIPTS/TOOLS/telem.lua'));local code=file:read('*a');file:close()
code=code:gsub('return {init=init,run=run,stop=fcLink.stop}\n$','return {init=init,run=run,stop=fcLink.stop,metrics=renderStats,telemetry=telemetry}\n')
UNIT_KTS=1;UNIT_MPH=2;UNIT_METERS_PER_SECOND=3;UNIT_FEET_PER_SECOND=4;UNIT_KMH=5;UNIT_RADIANS=6;UNIT_DEGREE=7;UNIT_FEET=8;UNIT_METERS=9
local fields={{name='RxBt',unit=0,value=16.1},{name='GSpd',unit=UNIT_KTS,value=10},{name='GAlt',unit=UNIT_FEET,value=100},{name='Ptch',unit=UNIT_RADIANS,value=0},{name='Roll',unit=UNIT_DEGREE,value=0},{name='FM',unit=0,value='ANGLE'}}
local tick,lookups,reads,writes,metadata,sensorReads=0,0,0,0,0,0
local positiveByName={}
getTime=function()return tick end
getValue=function()error('Live telemetry must not fall back to getValue')end
getVersion=function()return 'test'end
model={getInfo=function()return {name='benchmark'}end,getSensor=function(i)sensorReads=sensorReads+1;return fields[i+1]end}
CHAR_TELEMETRY='T:'
getSourceIndex=function(name)
 lookups=lookups+1
 for i,v in ipairs(fields)do if name=='T:'..v.name then positiveByName[v.name]=(positiveByName[v.name]or 0)+1;return i end end
 return 0
end
getFieldInfo=function(id)
 assert(type(id)=='number','Telemetry metadata must use numeric ID')
 metadata=metadata+1;return fields[id]and {id=id,unit=fields[id].unit}
end
getSourceValue=function(id)
 reads=reads+1;local field=assert(fields[id])
 if field.name=='Roll'or field.name=='Ptch'then return math.sin(tick/100),true,true end
 return field.value,true,true
end
local noop=function()end
lcd=setmetatable({RGB=function()return 0 end},{__index=function()return noop end})
CUSTOM_COLOR=0;SMLSIZE=0;MIDSIZE=0;DBLSIZE=0;SOLID=0;RIGHT=0
Bitmap={open=function(path)
 assert(path:find('/icons/',1,true),'Flight may load icon masks only')
 local size=path:find('-18.png',1,true)and 18 or 30;return {size,size,path}
end,getSize=function(bitmap)return bitmap[1],bitmap[2]end,toMask=function(bitmap)return bitmap[3]end}
io={open=function(_,mode)if mode=='w'or mode=='a'then writes=writes+1 end end}
local app=assert(loadstring(code))();app.init();app.run(0)
local bound,initialMetadata,initialScans=lookups,metadata,sensorReads
for i=1,12000 do
 tick=tick+1
 if i==1200 then fields[#fields+1]={name='Curr',unit=11,value=0}end
 local before=lookups;app.run(0)
 assert(lookups-before<=1,'Warm callback may probe at most one missing name')
end
assert(lookups-bound<=math.floor(12000/50),'Failed-name retries are globally limited to two per simulated second')
for _,name in ipairs({'RxBt','GSpd','GAlt','Ptch','Roll','FM'})do assert(positiveByName[name]==1,'Positive ID rebound: '..name)end
assert(positiveByName.Curr==1 and metadata==initialMetadata+1,'Late current binds native metadata once')
assert(sensorReads==initialScans,'Warm app must never enumerate all sensor metadata')
local name,state,raw=app.telemetry.sourceStatus('Curr')
assert(name=='Curr'and state=='LIVE'and raw==0,'Late real zero current reaches live diagnostics')
assert(writes==0,'No automatic diagnostic/settings writes inside refresh')
assert(app.metrics.attitudeHz>=99,'Attitude polling must continue on callbacks skipped by redraw limiter')
assert(app.metrics.fps<=26 and app.metrics.fps>=24)
io=realio
print(string.format('PASS:12000 callbacks; positiveIDs never rebound; %d bounded missing probes; one late0A bind; no warm enumerations/writes; attitude %.1fHz, draw %.1fHz (mock clock)',lookups-bound,app.metrics.attitudeHz,app.metrics.fps))
