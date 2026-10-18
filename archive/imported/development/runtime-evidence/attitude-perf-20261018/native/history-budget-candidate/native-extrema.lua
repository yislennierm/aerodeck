-- Native EdgeTX2.12.4 sensor extrema, distinct from AERODECK session history.
-- Caller supplies qualified PRIMARY telemetry source IDs, never timer/switch/
-- output IDs or an already suffixed Min/Max source. Native IDs are base+1/+2.
-- getSourceValue returns value,isCurrent,isFresh; the third flag is NOT an
-- ever-received flag. Old numeric values require observed/current receipt or
-- explicit provider receipt knowledge. Never use getValue's fabricated zero.
-- Sources: radio/src/{mixer.cpp:522-535,lua/api_general.cpp:721-797,
-- telemetry/telemetry_sensors.cpp:253-264} at official EdgeTX v2.12.4.
-- Native voltage minima reset on a new native voltage maximum. Resetting a
-- sensor is caller-owned: this module never resets sensors or applies policy.
-- invertExtrema=true is only for caller-verified NEGATIVE-scale normalizers:
-- physical MIN uses native MAX and vice versa, retaining exact provenance.
-- begin/step privately acquire up to64 fields, then atomically publish into
-- stable output records. No partly sampled MAX can appear in a MIN snapshot.
local M={}
local maxFields=64
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function primaryId(id)return finite(id)and id%1==0.0 and id>0 and id<65534 end
local function validKey(key)return type(key)=='string'and #key>0 and #key<=64 or finite(key)and key%1==0.0 end
function M.new(opts)
 opts=opts or{}
 local read,normalize,knownReceived=opts.getSourceValue,opts.normalize,opts.received
 local records,order,work,seen={},{},{},{}
 local s={origin='NATIVE',mode=nil,records=records,order=order,count=0,pending=false,completed=0,total=0}
 local api,epoch={},0
 local active,jobMode,jobCount,jobAt,jobError=false,nil,0,1,nil
 local function empty(r,state,err)
  r.value=nil;r.rawValue=nil;r.current=false;r.fresh=false;r.state=state;r.error=err;r.provenance=nil;r.normalizationProvenance=nil
 end
 local function resetRecord(r)
  r.received=false;r.nativeId=nil;r.nativeMode=nil;empty(r,'NOT RECEIVED')
 end
 local function cancel()
  active=false;s.pending=false;s.targetMode=nil;s.completed=0;s.total=0
 end
 local function acquire(r)
  if r.mode~='MIN'and r.mode~='MAX'then empty(r,'INVALID','INVALID MODE')
  elseif not primaryId(r.id)then empty(r,'UNAVAILABLE','UNBOUND PRIMARY SENSOR')
  elseif type(read)~='function'or type(normalize)~='function'then empty(r,'UNAVAILABLE','API UNAVAILABLE')
  else
   r.nativeMode=r.invertExtrema and(r.mode=='MIN'and'MAX'or'MIN')or r.mode
   r.nativeId=r.id+(r.nativeMode=='MAX'and 2 or 1)
   local ok,raw,current,fresh=pcall(read,r.nativeId)
   if not ok then empty(r,'UNAVAILABLE','READ ERROR')
   elseif raw==nil then r.received=false;empty(r,'NOT RECEIVED')
   elseif not finite(raw)then empty(r,'INVALID','NONNUMERIC EXTREMUM')
   elseif type(current)~='boolean'or type(fresh)~='boolean'then empty(r,'INVALID','INVALID CURRENTNESS FLAGS')
   else
    local received=r.received or current==true
    if not received and type(knownReceived)=='function'then local good,answer=pcall(knownReceived,r.id);received=good and answer==true end
    if not received then empty(r,'NOT RECEIVED')
    else
     r.received=true
     local good,value,err,provenance=pcall(normalize,r.profileField or r.key,raw,r.unit)
     if not good then empty(r,'INVALID','NORMALIZE ERROR')
     elseif not finite(value)then empty(r,'INVALID',type(err)=='string'and err or'INVALID NORMALIZED VALUE')
     else
      r.value=value;r.rawValue=raw;r.current=current==true;r.fresh=current==true and fresh==true
      r.state=current==true and'CURRENT'or'HISTORICAL';r.normalizationProvenance=provenance
      r.provenance=r.invertExtrema and(r.mode=='MIN'and'NORMALIZED NATIVE MIN / SOURCE MAX'or'NORMALIZED NATIVE MAX / SOURCE MIN')or provenance
     end
    end
   end
  end
 end
 local function publish()
  epoch=epoch+1;s.mode=jobMode;s.error=jobError;s.count=0
  for i=1,jobCount do local w=work[i];local key=w.key
   if key~=nil then
    local r=records[key];if not r then r={key=key,origin='NATIVE'};records[key]=r end
    r.epoch=epoch;r.name=w.name;r.id=w.id;r.unit=w.unit;r.profileField=w.profileField;r.mode=w.mode
    r.invertExtrema=w.invertExtrema;r.nativeId=w.nativeId;r.nativeMode=w.nativeMode;r.received=w.received
    r.value=w.value;r.rawValue=w.rawValue;r.current=w.current;r.fresh=w.fresh;r.state=w.state;r.error=w.error
    r.provenance=w.provenance;r.normalizationProvenance=w.normalizationProvenance
    s.count=s.count+1;order[s.count]=key
   end
  end
  for i=s.count+1,#order do order[i]=nil end
  for key,r in pairs(records)do if r.epoch~=epoch then records[key]=nil end end
  active=false;s.pending=false;s.targetMode=nil;s.completed=jobCount;s.total=jobCount
 end
 function api.snapshot()return s end -- Stable borrowed read-only view.
 function api.cancel()cancel();return s end
 function api.resetBindings()
  cancel();for _,r in pairs(records)do resetRecord(r)end;s.error=nil
 end
 function api.begin(fields,mode)
  cancel();jobMode=mode;jobAt=1;jobCount=0;jobError=nil
  if mode~='MIN'and mode~='MAX'then jobError='INVALID MODE'end
  for key in pairs(seen)do seen[key]=nil end
  if type(fields)~='table'then jobError='INVALID FIELDS'
  else
   jobCount=math.min(#fields,maxFields)
   for i=1,jobCount do
    local w=work[i];if not w then w={};work[i]=w end
    resetRecord(w);w.key=nil
    local d=fields[i];local key=type(d)=='table'and d.key
    if not validKey(key)then jobError='INVALID FIELD'
    elseif seen[key]then jobError='DUPLICATE FIELD'
    else
     seen[key]=true;w.key=key;w.name=d.name;w.id=d.id;w.unit=d.unit;w.profileField=d.profileField;w.mode=mode;w.invertExtrema=d.invertExtrema==true
     local old=records[key]
     if old and old.id==w.id and old.name==w.name and old.unit==w.unit and old.profileField==w.profileField and old.invertExtrema==w.invertExtrema then w.received=old.received==true end
    end
   end
   if #fields>maxFields then jobError='TOO MANY FIELDS'end
  end
  active=true;s.pending=true;s.targetMode=mode;s.total=jobCount;s.completed=0
  return s
 end
 function api.step(limit)
  if not active then return s,true,0 end
  limit=limit or 4
  if not finite(limit)or limit%1~=0.0 or limit<1 then return s,false,0,'INVALID STEP LIMIT'end
  limit=math.min(limit,maxFields)
  local processed=0
  while jobAt<=jobCount and processed<limit do
   local w=work[jobAt];if w.key~=nil then acquire(w)end
   jobAt=jobAt+1;processed=processed+1
  end
  s.completed=jobAt-1
  if jobAt>jobCount then publish();return s,true,processed end
  return s,false,processed
 end
 function api.sample(fields,mode)
  api.begin(fields,mode);api.step(maxFields);return s
 end
 return api
end
return M
