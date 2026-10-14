local f=assert(io.open('sdcard/SCRIPTS/TOOLS/telem.lua'));local app=f:read('*a');f:close()
local prefix=string.sub(app,1,assert(string.find(app,'local batteryConfig=',1,true))-1)
local now,calls=0,0
getTime=function()return now end
getFieldInfo=function(name)calls=calls+1;return name=='Roll' and {id=42} or nil end
local dims={{480,38},{96,208},{88,208},{296,44},{296,30}}
Bitmap={open=function(path)local i=tonumber(string.match(path,'fc(%d)') or string.match(path,'chrome%-(%d)'));if i==4 then return {0,0}end;return dims[i]end,getSize=function(b)return b[1],b[2]end}
local exports=assert(loadstring(prefix..'\nreturn {lookup=cachedField,telemetry=cachedTelemetryField,refresh=refreshSources,open=openBackground,stats=renderStats}'))()
for i=1,100 do assert(exports.lookup('Roll').id==42);assert(exports.lookup('missing')==nil)end
assert(calls==2,'Cache should resolve present and missing fields once')
now=201;exports.lookup('Roll');assert(calls==2,'Bound sources must not expire after two seconds')
CHAR_TELEMETRY='T:'
local lookups=0
getSourceIndex=function(n)lookups=lookups+1;return n=='T:Roll' and 99 or 0 end
for i=1,100 do assert(exports.telemetry('Roll').id==99)end
assert(lookups==1 and calls==2,'Qualified lookup must bind once, without generic name lookup')
assert(exports.telemetry('missing')==nil)
now=100000;assert(exports.telemetry('Roll').id==99 and lookups==2)
exports.refresh();assert(exports.telemetry('Roll').id==99 and lookups==3)
local tiles=exports.open('flight');assert(#tiles==4,'A failed tile must not discard successful tiles')
assert(exports.stats.background=='FAILED 4')
print('PASS: stable qualified telemetry binding, explicit refresh, partial bitmap failure retains background and reports failure')
