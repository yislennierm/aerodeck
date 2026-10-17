local file=assert(io.open('sdcard/SCRIPTS/TOOLS/telem.lua'));local app=file:read('*a');file:close()
local prefix=app:sub(1,assert(app:find('local batteryConfig=',1,true))-1)
local now,generic,metadata,lookups=0,0,0,0
local ids={Roll=99};local units={[99]=6}
getTime=function()return now end
getFieldInfo=function(key)
 if type(key)=='number'then metadata=metadata+1;return {id=key,unit=units[key]}end
 generic=generic+1;return key=='Roll'and {id=42}or nil
end
local bitmapReads=0
Bitmap={open=function()bitmapReads=bitmapReads+1;error('Binding must not load artwork')end}
local e=assert(loadstring(prefix..'\nreturn {lookup=cachedField,telemetry=cachedTelemetryField,retry=retryMissingSources,refresh=refreshSources,open=openBackground,draw=drawBackground}'))()
for i=1,100 do assert(e.lookup('Roll').id==42);assert(e.lookup('missing')==nil)end
assert(generic==2,'Generic indicator cache retains present and absent names')
now=201;e.lookup('Roll');assert(generic==2,'Positive generic ID never expires after2seconds')
CHAR_TELEMETRY='T:'
getSourceIndex=function(name)lookups=lookups+1;assert(name:sub(1,2)=='T:');return ids[name:sub(3)]or 0 end
for i=1,100 do local f=e.telemetry('Roll');assert(f.id==99 and f.unit==6)end
assert(lookups==1 and metadata==1 and generic==2,'Positive qualified bind reads numeric metadata only once')
assert(e.telemetry('missing')==nil);assert(e.telemetry('Curr')==nil)
local before=lookups
for i=1,100 do e.telemetry('missing');e.telemetry('Curr');e.telemetry('Roll')end
assert(lookups==before,'Hot source reads do not retry misses or expire positive IDs')
ids.missing=100;units[100]=10
e.retry();assert(lookups==before+1 and e.telemetry('missing').id==100,'One round-robin missing source can bind late')
local first=lookups
for i=1,100 do e.retry()end
assert(lookups==first,'Retry budget is global, not per-name or per-callback')
now=now+49;e.retry();assert(lookups==first,'No retry before500ms')
now=now+1;e.retry();assert(lookups==first+1,'One missing source probe at500ms')
ids.Curr=101;units[101]=11
now=now+50;e.retry();assert(e.telemetry('Curr').id==101 and e.telemetry('Curr').unit==11,'Late binding caches native unit')
local bound,metabound=lookups,metadata
for i=1,1000 do now=now+100;e.retry();assert(e.telemetry('Roll').id==99)end
assert(lookups==bound and metadata==metabound,'An empty negative queue performs no warm source work')
ids.Roll=199;units[199]=7
assert(e.telemetry('Roll').id==99,'Positive IDs stay stable until explicit refresh')
e.refresh();assert(e.telemetry('Roll').id==199 and e.telemetry('Roll').unit==7,'Explicit refresh clears positive IDs and units')
assert(e.open==nil and e.draw==nil,'Removed flight-background loaders stay absent')
assert(bitmapReads==0,'Source binding, retry and refresh never load bitmaps')
print('PASS: stable qualified IDs; bounded negative-only retries; once-per-bind numeric units; explicit refresh; no binding artwork I/O')
