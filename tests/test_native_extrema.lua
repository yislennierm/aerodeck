-- Actual native-extrema module; no host/radio IO or fabricated sensor values.
local M=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/native-extrema.lua'))()
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local values,reads,normalizations,received={},{},{},{}
local function read(id)
 reads[#reads+1]=id
 local v=values[id]
 if v=='THROW' then error('native failure') end
 if v then return v[1],v[2],v[3] end
end
local function normalize(field,raw,unit)
 normalizations[#normalizations+1]={field,raw,unit}
 if field=='bad' then return nil,'UNKNOWN UNIT' end
 if field=='throw' then error('bad normalizer') end
 if unit=='A' then return raw*0.1,nil,'NATIVE DECIMAL AMPS' end
 if unit=='RAD' then return -raw*180/math.pi,nil,'RADIANS / NEGATIVE PITCH' end
 return raw,nil,'NATIVE PHYSICAL VALUE'
end
local fields={{key='voltage',name='RxBt',id=100,unit='V',profileField='v'},{key='current',name='Curr',id=103,unit='A',profileField='a'}}
local n=M.new({getSourceValue=read,normalize=normalize,received=function(id)return received[id]end})
local snap=n.sample(fields,'MIN');local vr=snap.records.voltage;local ar=snap.records.current
check(snap==n.snapshot() and snap.origin=='NATIVE' and snap.mode=='MIN' and snap.count==2,'stable native snapshot has explicit mode and field count')
check(reads[1]==101 and reads[2]==104 and #reads==2,'MIN reads only qualified base+1 numeric IDs')
check(vr.state=='NOT RECEIVED' and vr.value==nil and not vr.current and not vr.fresh,'native never-received nil is explicitly absent')
check(#normalizations==0,'missing native values never reach a value fabricating normalizer')
values[101]={0,false,false};values[104]={0,false,true}
n.sample(fields,'MIN')
check(vr.value==nil and vr.state=='NOT RECEIVED' and ar.value==nil,'unproven old zero is never fabricated as a real minimum')
check(ar.state=='NOT RECEIVED' and not ar.fresh,'third fresh flag is not an ever-received flag')
values[101]={0,true,false};values[104]={250,true,true}
check(n.sample(fields,'MIN')==snap and snap.records.voltage==vr and snap.records.current==ar,'same fields retain snapshot/order/record identity')
check(vr.value==0 and vr.state=='CURRENT' and vr.current and not vr.fresh,'received real zero remains CURRENT even without newest freshness')
check(ar.value==25 and ar.rawValue==250 and ar.current and ar.fresh and ar.provenance=='NATIVE DECIMAL AMPS','normalizer uses native unit/profileField and preserves independent current/fresh')
check(normalizations[1][1]=='v' and normalizations[2][1]=='a','physical normalization receives configured profile fields')
values[102]={25.2,true,false};values[105]={400,true,true}
local order=snap.order
n.sample(fields,'MAX')
check(reads[#reads-1]==102 and reads[#reads]==105,'MAX reads base+2, no string suffix or fallback')
check(vr.mode=='MAX' and vr.value==25.2 and ar.value==40 and snap.order==order,'mode changes reuse records while returning independent native maxima')
values[102]={25.2,false,false};values[105]={400,false,false}
n.sample(fields,'MAX')
check(vr.state=='HISTORICAL' and vr.value==25.2 and not vr.current and not vr.fresh,'previously observed native receipt permits explicitly historical values')
check(ar.state=='HISTORICAL' and ar.origin=='NATIVE','historical native extrema never claim session/live provenance')
n.resetBindings();n.sample(fields,'MAX')
check(vr.value==nil and vr.state=='NOT RECEIVED' and snap.records.voltage==vr,'explicit binding reset clears receipt without replacing stable record objects')
received[100]=true;n.sample(fields,'MAX')
check(vr.value==25.2 and vr.state=='HISTORICAL' and not vr.current,'provider receipt knowledge allows first-open stale native extrema honestly')
check(ar.value==nil,'receipt is scoped to the primary sensor ID')
received[100]=nil;values[102]=nil;n.sample(fields,'MAX');values[102]={0,false,false};n.sample(fields,'MAX')
check(vr.state=='NOT RECEIVED' and vr.value==nil,'native sensor unavailable/reset clears prior module receipt knowledge')
local before=#reads;n.sample(fields,'LIVE')
check(#reads==before and snap.error=='INVALID MODE' and vr.value==nil and vr.state=='INVALID','invalid extrema mode cannot silently read or retain old mode values')
values[101]={11,true,true};values[104]={25,true,true};n.sample(fields,'MIN')
fields[1].id=106;values[107]={0,false,false};n.sample(fields,'MIN')
check(vr.id==106 and vr.value==nil and vr.state=='NOT RECEIVED','changing primary binding cannot inherit old sensor receipt')
fields[1].id=100;values[101]={12,true,true};n.sample(fields,'MIN');fields[1].unit='RAW';values[101]={12,false,false};n.sample(fields,'MIN')
check(vr.value==nil,'changing normalization unit clears receipt ownership')
fields[1].unit='V';fields[1].id=nil;n.sample(fields,'MIN')
check(vr.state=='UNAVAILABLE' and vr.error=='UNBOUND PRIMARY SENSOR','unbound source is unavailable rather than zero')
for _,id in ipairs({0,-1,1.5,math.huge,0/0,65534,'RxBt'})do
 fields[1].id=id;local count=#reads;n.sample(fields,'MIN');check(#reads==count+1 and vr.value==nil and vr.state=='UNAVAILABLE','invalid primary ID never triggers its native read')
end
fields[1].id=100
for _,raw in ipairs({math.huge,-math.huge,0/0,'25.2',{lat=0,lon=0},false})do
 values[101]={raw,true,true};n.sample(fields,'MIN');check(vr.value==nil and vr.state=='INVALID','GPS/text/nonfinite/non-numeric extrema cannot become physical values')
end
values[101]={1,nil,nil};n.sample(fields,'MIN')
check(vr.state=='INVALID' and vr.error=='INVALID CURRENTNESS FLAGS','getValue-like one-return function cannot impersonate current native API')
values[101]='THROW';n.sample(fields,'MIN')
check(vr.value==nil and vr.state=='UNAVAILABLE' and vr.error=='READ ERROR','native read failure is explicit and nonfatal')
values[101]={1,true,true};fields[1].profileField='bad';n.sample(fields,'MIN')
check(vr.state=='INVALID' and vr.error=='UNKNOWN UNIT' and vr.value==nil,'normalization error never leaks raw value as physical data')
fields[1].profileField='throw';n.sample(fields,'MIN')
check(vr.state=='INVALID' and vr.error=='NORMALIZE ERROR','normalizer exception is contained')
fields[1].profileField='v'
local unavailable=M.new({getSourceValue=read});check(unavailable.sample(fields,'MIN').records.voltage.state=='UNAVAILABLE','missing physical normalizer fails explicitly')
unavailable=M.new({normalize=normalize});check(unavailable.sample(fields,'MIN').records.voltage.value==nil,'missing native API never falls back to getValue')
local throws=M.new({getSourceValue=read,normalize=normalize,received=function()error('no provider')end})
values[101]={0,false,false};check(throws.sample(fields,'MIN').records.voltage.state=='NOT RECEIVED','provider receipt failure is not mistaken for receipt')

-- Native ordering is the default. Only a verified explicit negative-scale
-- descriptor swaps native IDs before normalization into physical MIN/MAX.
local pitch={{key='pitch',id=200,name='Ptch',unit='RAD'}}
values[201]={-math.pi/6,true,true};values[202]={math.pi/9,true,true}
local p=n.sample(pitch,'MIN').records.pitch
check(math.abs(p.value-30)<0.00001 and p.nativeId==201 and p.origin=='NATIVE','native MIN is normalized after reading exact native MIN even with pitch sign inversion')
n.sample(pitch,'MAX');check(math.abs(p.value+20)<0.00001 and p.nativeId==202,'native MAX ordering is not confused with normalized/session extrema')
pitch[1].invertExtrema=true
n.sample(pitch,'MIN')
check(math.abs(p.value+20)<0.00001 and p.nativeId==202 and p.mode=='MIN' and p.nativeMode=='MAX' and p.invertExtrema,'verified negative-scale physical MIN reads native MAX before normalization')
check(p.provenance=='NORMALIZED NATIVE MIN / SOURCE MAX' and p.normalizationProvenance=='RADIANS / NEGATIVE PITCH' and p.origin=='NATIVE','swapped extrema expose requested/actual native provenance and independent normalizer evidence')
n.sample(pitch,'MAX')
check(math.abs(p.value-30)<0.00001 and p.nativeId==201 and p.provenance=='NORMALIZED NATIVE MAX / SOURCE MIN','asymmetric negative raw range produces physically correct normalized maximum')
values[201]={-math.pi/6,false,false};values[202]={math.pi/9,false,false}
pitch[1].invertExtrema=false;n.sample(pitch,'MAX')
check(p.value==nil and p.state=='NOT RECEIVED','changing inverse descriptor invalidates receipt instead of retaining old normalization ownership')
values[201]={-math.pi/6,true,true};values[202]={math.pi/9,true,true}
n.sample(pitch,'MAX');pitch[1].invertExtrema=true;values[201][2]=false;values[201][3]=false
n.sample(pitch,'MAX');check(p.value==nil and p.state=='NOT RECEIVED','enabling inverse descriptor also clears previous non-inverted receipt')
values[201][2]=true;values[201][3]=true
n.sample(pitch,'MAX');check(p.value==30 or math.abs(p.value-30)<0.00001,'new current sample establishes inverted binding receipt')
check(snap.records.voltage==nil and #snap.order==1 and snap.order[1]=='pitch','removed bindings disappear instead of accumulating records')

-- No allocation per sample: actual output tables remain identical across many
-- samples/mode changes/GC; module has no playback, transport, IO or policy calls.
local stableRecords,stableOrder=snap.records,snap.order
local baseline=p
for i=1,2000 do
 local mode=i%2==0 and 'MIN' or 'MAX';local s=n.sample(pitch,mode)
 check(s==snap and s.records==stableRecords and s.order==stableOrder and s.records.pitch==baseline,'warm native extrema output identity remains stable')
end
collectgarbage('collect');n.sample(pitch,'MIN');check(snap.records.pitch==baseline,'GC cannot evict native binding/output state')
local stringMeta=debug.getmetatable('');debug.setmetatable('',nil)
local strippedOK,strippedError=pcall(function()n.resetBindings();check(n.sample(pitch,'MIN').records.pitch.value~=nil,'native extrema work with stripped EdgeTX string library')end)
debug.setmetatable('',stringMeta);check(strippedOK,'stripped string compatibility: '..tostring(strippedError))
local count=#reads;n.sample(nil,'MIN');check(snap.error=='INVALID FIELDS' and snap.count==0 and #snap.order==0 and next(snap.records)==nil and #reads==count,'invalid field list clears visible binding set without native reads')
local many={};for i=1,70 do many[i]={key='field'..i,id=100+3*i,unit='V'}end
n.sample(many,'MIN');check(snap.error=='TOO MANY FIELDS' and snap.count==64 and #snap.order==64,'field count/read work is bounded to native64-sensor capacity')
print('native-extrema: '..checks..' checks passed')
