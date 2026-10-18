-- Read-only physical-input and native-FC indicator provider. No output/model
-- setters, transport, telemetry pop, source writes or persistent numeric IDs.
local M={sources={
 api='https://github.com/EdgeTX/edgetx/blob/v2.12.4/radio/src/lua/api_general.cpp#L2568-L2857',
 names='https://github.com/EdgeTX/edgetx/blob/v2.12.4/radio/src/strhelpers.cpp#L472-L563',
 inputNames='https://github.com/EdgeTX/edgetx/blob/v2.12.4/radio/util/hw_defs/legacy_names.py',
 values='https://github.com/EdgeTX/edgetx/blob/v2.12.4/radio/src/mixer.cpp#L335-L482',
 toolbox='Original RDINP/INDINIT/INDUPD/SIN; archive SHA256 9e4b21056c25359d7fcda6a2cd8e997867c2ec400dc7d33cdc18464611a4e766'
}}
local floor,min,max,abs=math.floor,math.min,math.max,math.abs
local roles={'arm','cut','acro','angle','horizon','air','turtle','rth','wrth','throttle','limiter'}
local modePriority={'acro','horizon','angle'}
local percentages={throttle=true,limiter=true}
local predicates={'LOW','MID','HIGH','NOT_LOW','NOT_MID','NOT_HIGH'}
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function integer(v)return finite(v)and v%1==0.0 end
local function call(fn,...)
 if type(fn)~='function'then return nil end
 local ok,a,b,c=pcall(fn,...);if ok then return a,b,c end
end
local function lower(v)return type(v)=='string'and string.lower(v)or''end
local function sourceLabel(value)
 if type(value)~='string'then return value end
 -- EdgeTX prepends UTF-8 CHAR_STICK/POT/SLIDER/SWITCH/TRIM to source
 -- labels, but not to position names. Remove only those verified glyphs.
 local a,b=string.byte(value,1,2)
 if a==194 and b and b>=137 and b<=141 then return string.sub(value,3)end
 return value
end
local function physicalKind(name)
 name=lower(name)
 if name=='thr'or name=='rud'or name=='ail'or name=='ele'or name=='ste'then return'stick'end
 if string.match(name,'^trim%-[%w_%-]+$')then return'trim'end
 if name=='6pos'or name=='6p'then return'sixpos'end
 if name=='ls'or name=='rs'or name=='sl'or name=='sr'or name=='lcs'or name=='rcs'then return'slider'end
 if string.match(name,'^[sp]%d+$')then return'pot'end
 if name=='jsx'or name=='jsy'or string.match(name,'^ext%d+$')then return'aux'end
end
local fallback={'thr','rud','ele','ail','ste','s1','s2','s3','s4','p1','p2','6pos','6P','ls','rs','sl','sr','lcs','rcs','jsx','jsy','ext1','ext2','ext3','ext4',
 'trim-ail','trim-ele','trim-thr','trim-rud','trim-t5','trim-t6','trim-t7','trim-t8'}
for byte=string.byte('a'),string.byte('z')do fallback[#fallback+1]='s'..string.char(byte)end
local function sourcePredicate(value,predicate)
 local positive=predicate
 local inverted=string.sub(predicate,1,4)=='NOT_'
 if inverted then positive=string.sub(predicate,5)end
 local result=positive=='LOW'and value< -512 or positive=='HIGH'and value>512 or positive=='MID'and value>=-512 and value<=512
 return inverted and not result or not inverted and result
end
function M.new(api,options)
 api=api or{};options=options or{}
 local budget=options.learnBudget or 8
 if not integer(budget)or budget<1 or budget>16 then budget=8 end
 local inventory,byIdentity,byField,bySource,bindings={},{},{},{},{}
 local stems={}
 local discovery={state='NEW',stage='NEW',index=0,work=0,totalWork=0,sourceProbes=0,switchProbes=0,fallbackProbes=0,cpuPaused=false}
 local scan,syncRefresh
 local cacheValue,cacheSwitch,cacheLogical={},{},{}
 local token=0
 local snapshot={roles={},modeOverrideConfigured=false,modeOverrideState='OFF',modeOverride=nil,modeConflict=false}
 local previewOut={state='UNAVAILABLE'}
 local previewBinding,previewIdentity,previewRole
 local picker={}
 local learner={status='IDLE',reads=0,budget=budget,candidate=nil}
 local learnCandidates,learnBaseline,learnCursor,learnPhase={}, {},1,nil
 local learnStart,learnTimeout,lastLearn,changed,pending=0,1000,nil,{},nil
 local provider={}
 local function cycle()
  token=token+1
  if token>1000000000 then
   token=1
   for _,cache in ipairs({cacheValue,cacheSwitch,cacheLogical})do for _,item in pairs(cache)do item.stamp=nil end end
  end
 end
 local function cached(cache,index,read)
  local item=cache[index]
  if not item then item={};cache[index]=item end
  if item.stamp~=token then item.value,item.current=read(index);item.stamp=token end
  return item.value,item.current
 end
 local function analogRead(index)
  local value,current
  if type(api.getSourceValue)=='function'then value,current=call(api.getSourceValue,index)
  else value=call(api.getValue,index);current=finite(value)end
  return finite(value)and current==true and value or nil,current==true
 end
 local function switchRead(index)
  local value=call(api.getSwitchValue,index);if type(value)=='boolean'then return value,true end;return nil,false
 end
 local function logicalRead(index)
  local value=call(api.getLogicalSwitchValue,index);if type(value)=='boolean'then return value,true end;return nil,false
 end
 local function cancelLearn(status)
  learnPhase=nil;pending=nil;learner.status=status or'IDLE';learner.candidate=nil
 end
 function provider.cancelLearn()cancelLearn('CANCELLED')end
 local function addSource(index,label,field,available)
  if not integer(index)or index<=0 or bySource[index]then return end
  field=field or call(api.getFieldInfo,index)
  if type(field)~='table'or type(field.name)~='string'or field.unit~=nil then return end
  local canonical=lower(field.name);local kind=physicalKind(canonical)
  local switchInfo=call(api.getSwitchInfo,index)
  if type(switchInfo)=='table'and(switchInfo.type==1 or switchInfo.type==2 or switchInfo.type==3)then kind='switch'end
  if not kind and type(api.getSwitchInfo)~='function'and string.match(canonical,'^s[a-z]$')then kind='switch'end
  if not kind then return end
  if available~=true then
   if type(api.getSourceName)=='function'then label=call(api.getSourceName,index);available=type(label)=='string'and label~=''
   elseif type(api.getSourceValue)=='function'then local _,current=analogRead(index);available=current
   else available=false end -- Legacy getValue returns zero for nonexistent inputs.
  end
  if not available then return end
  local item={field=canonical,index=index,label=sourceLabel(label or field.name),kind=kind,available=true,positions={},positivePositions={},switchType=type(switchInfo)=='table'and switchInfo.type or nil}
  bySource[index]=item;byField[canonical]=item;inventory.sources[#inventory.sources+1]=item
  if kind=='switch'then inventory.switches[#inventory.switches+1]=item else inventory.analogs[#inventory.analogs+1]=item end
  if kind~='stick'and kind~='aux'then
   local labelStem,fieldStem=string.upper(item.label),string.upper(item.field)
   if not stems[labelStem]then stems[labelStem]=item end
   if not stems[fieldStem]then stems[fieldStem]=item end
  end
 end
 local function sourceForPosition(name)
  if string.sub(name,1,1)=='!'then name=string.sub(name,2)end
  local upper=string.upper(name)
  -- A native position must contain a suffix after its source stem. Longest
  -- prefix and first-inventory-source tie semantics match the synchronous reader.
  for length=#upper-1,1,-1 do
   local source=stems[string.sub(upper,1,length)]
   if source then return source end
  end
 end
 local function addPosition(index,name)
  if not integer(index)or index==0 or type(name)~='string'or name==''then return end
  if #name>128 then inventory.partial=true;return end
  local base=string.sub(name,1,1)=='!'and string.sub(name,2)or name
  if string.match(base,'^L%d%d$')then return end
  local source=sourceForPosition(name)
  if not source then return end
  local identity='SW:'..name;if byIdentity[identity]then return end
  local item={identity=identity,label=name,kind='switchPosition',index=index,available=true,source=source,inverted=index<0}
  byIdentity[identity]=item;inventory.predicates[#inventory.predicates+1]=item
  source.positions[#source.positions+1]=item
  if index>0 then source.positivePositions[#source.positivePositions+1]=item end
 end
 local function addChoice(list,identity,label,kind,available)
  list[#list+1]=identity;list.labels[#list]=label;list.items[#list]={identity=identity,label=label,kind=kind,available=available}
 end
 local function resolve(identity,role)
  if identity=='OFF'then return{identity=identity,kind='off',label='Off'}end
  if identity=='NATIVE'then return{identity=identity,kind='native',label='Native FC data'}end
  if type(identity)~='string'or #identity>128 then return nil,'INVALID INPUT IDENTITY'end
  local switchName=string.match(identity,'^SW:(.+)$')
  if switchName and not percentages[role]then
   local present=byIdentity[identity]
   if present then return present end
   local index=call(api.getSwitchIndex,switchName)
   local name=integer(index)and call(api.getSwitchName,index)or nil
   return{identity=identity,kind='switchPosition',label=name or switchName,index=type(name)=='string'and index or nil,available=type(name)=='string'}
  end
  local negated,number=string.match(identity,'^LS:(!?)L(%d%d)$')
  if number and not percentages[role]then
   number=tonumber(number);if number<1 or number>64 then return nil,'INVALID LOGICAL SWITCH'end
   return{identity=identity,kind='logical',label=negated..string.format('L%02d',number),ordinal=number-1,inverted=negated=='!'}
  end
  local inverted,name=string.match(identity,'^SRC(!?):([%w_%-]+)$')
  if name and percentages[role]then
   name=lower(name);local source=byField[name]
   if source and source.kind=='switch'then return nil,'ANALOG CONTROL REQUIRED'end
   return{identity='SRC'..inverted..':'..name,kind='analog',label=source and source.label or name,source=source,index=source and source.index,inverted=inverted=='!'}
  end
  local field,predicate=string.match(identity,'^PRED:([%w_%-]+):([A-Z_]+)$')
  if field and not percentages[role]then
   local valid=false;for _,p in ipairs(predicates)do if predicate==p then valid=true;break end end
   if not valid then return nil,'INVALID SWITCH PREDICATE'end
   field=lower(field);local source=byField[field]
   if source and source.kind~='switch'then return nil,'PHYSICAL SWITCH REQUIRED'end
   return{identity='PRED:'..field..':'..predicate,kind='predicate',label=(source and source.label or field)..' '..predicate,source=source,index=source and source.index,predicate=predicate}
  end
  return nil,'INVALID INPUT IDENTITY'
 end
 local function applyBinding(role,identity)
  if not snapshot.roles[role]then return false,'UNKNOWN INDICATOR ROLE'end
  local item,errorText=resolve(identity,role);if not item then return false,errorText end
  bindings[role]=item
  local out=snapshot.roles[role];out.identity=item.identity;out.source=item.label;out.state=item.kind=='off'and'OFF'or'UNAVAILABLE';out.value=nil;out.raw=nil
  out.override=item.kind~='off'and item.kind~='native'
  return true,item.identity
 end
 function provider.bind(role,identity)
  if discovery.state~='READY'then return false,'INPUT DISCOVERY IN PROGRESS'end
  return applyBinding(role,identity)
 end
 local function unavailable()
  for _,role in ipairs(roles)do local out=snapshot.roles[role];out.state=bindings[role].kind=='off'and'OFF'or'UNAVAILABLE';out.value=nil;out.raw=nil end
  snapshot.modeOverrideState=snapshot.modeOverrideConfigured and'UNAVAILABLE'or'OFF';snapshot.modeOverride=nil;snapshot.modeConflict=false
 end
 function provider.ready()return discovery.state=='READY'end
 function provider.refreshState()return discovery end -- Borrowed stable progress view.
 function provider.beginRefresh()
  cancelLearn('CANCELLED');inventory={sources={},switches={},analogs={},predicates={},logical={},partial=false,discoveryPending=true};byIdentity={};byField={};bySource={};stems={};picker={}
  previewBinding=nil;previewIdentity=nil;previewRole=nil;previewOut.state='UNAVAILABLE';previewOut.value=nil;previewOut.raw=nil
  cacheValue={};cacheSwitch={};cacheLogical={};token=0
  scan={stage='SOURCES',index=0,initialized=false}
  discovery.state='DISCOVERING';discovery.stage='SOURCES';discovery.index=0;discovery.work=0;discovery.totalWork=0;discovery.sourceProbes=0;discovery.switchProbes=0;discovery.fallbackProbes=0;discovery.cpuPaused=false
  unavailable();return discovery
 end
 function provider.cancelRefresh()
  if discovery.state~='DISCOVERING'then return false,'NOT DISCOVERING'end
  scan=nil;inventory.discoveryPending=false;discovery.state='CANCELLED';discovery.stage='CANCELLED';discovery.cpuPaused=false;discovery.work=0;discovery.sourceProbes=0;discovery.switchProbes=0;discovery.fallbackProbes=0
  unavailable();cancelLearn('CANCELLED');return true
 end
 local function stage(name)
  scan.stage=name;scan.index=0;scan.initialized=false;scan.iterator=nil;scan.iteratorState=nil;scan.previous=nil
 end
 local function choiceStep()
  if not scan.initialized then
   scan.boolean={labels={},items={}};scan.numeric={labels={},items={}};scan.choiceStage='BASE';scan.initialized=true
  end
  local boolean,numeric=scan.boolean,scan.numeric
  if scan.choiceStage=='BASE'then
   scan.index=scan.index+1
   local identity=scan.index==1 and'OFF'or'NATIVE';local label=scan.index==1 and'Off'or'Native FC data';local kind=scan.index==1 and'off'or'native'
   addChoice(boolean,identity,label,kind,true);addChoice(numeric,identity,label,kind,true)
   if scan.index==2 then scan.choiceStage='POSITIONS';scan.index=0 end
  elseif scan.choiceStage=='POSITIONS'then
   local item=inventory.predicates[scan.index+1]
   if item then scan.index=scan.index+1;addChoice(boolean,item.identity,item.label,item.kind,item.available)
   else scan.choiceStage='LOGICAL';scan.index=0 end
  elseif scan.choiceStage=='LOGICAL'then
   local item=inventory.logical[scan.index+1]
   if item then scan.index=scan.index+1;addChoice(boolean,item.identity,item.label,'logical',item.available);addChoice(boolean,'LS:!'..item.label,'!'..item.label,'logical',item.available)
   else scan.choiceStage='SWITCHES';scan.index=0;scan.predicate=1 end
  elseif scan.choiceStage=='SWITCHES'then
   local source=inventory.switches[scan.index+1]
   if source then
    local predicate=predicates[scan.predicate]
    if source.switchType~=2 or(predicate~='MID'and predicate~='NOT_MID')then addChoice(boolean,'PRED:'..source.field..':'..predicate,source.label..' '..predicate,'predicate',true)end
    scan.predicate=scan.predicate+1;if scan.predicate>#predicates then scan.predicate=1;scan.index=scan.index+1 end
   else scan.choiceStage='ANALOGS';scan.index=0 end
  elseif scan.choiceStage=='ANALOGS'then
   local source=inventory.analogs[scan.index+1]
   if source then scan.index=scan.index+1;addChoice(numeric,'SRC:'..source.field,source.label,source.kind,true);addChoice(numeric,'SRC!:'..source.field,source.label..' reversed',source.kind,true)
   else scan.choiceStage='ROLES';scan.index=0 end
  elseif scan.choiceStage=='ROLES'then
   local role=roles[scan.index+1]
   if role then scan.index=scan.index+1;picker[role]=percentages[role]and numeric or boolean
   else stage('REBIND')end
  end
 end
 local function workItem()
  if scan.stage=='SOURCES'then
   if not scan.initialized then
    scan.iterator,scan.iteratorState,scan.previous=call(api.sources);scan.initialized=true
    if type(scan.iterator)~='function'then inventory.partial=true;stage('FALLBACK')end
   else
    discovery.sourceProbes=discovery.sourceProbes+1
    local index,label=call(scan.iterator,scan.iteratorState,scan.previous)
    if index==nil then stage('FALLBACK')
    else
     scan.previous=index;scan.index=scan.index+1;addSource(index,label,nil,true)
     if scan.index>=1024 then inventory.partial=true;stage('FALLBACK')end
    end
   end
  elseif scan.stage=='FALLBACK'then
   local name=fallback[scan.index+1]
   if name then
    scan.index=scan.index+1;discovery.fallbackProbes=discovery.fallbackProbes+1
    local field=call(api.getFieldInfo,name);if type(field)=='table'then addSource(field.id,nil,field,false)end
   else stage('SWITCHES')end
  elseif scan.stage=='SWITCHES'then
   if not scan.initialized then
    scan.iterator,scan.iteratorState,scan.previous=call(api.switches);scan.initialized=true
    if type(scan.iterator)~='function'then inventory.partial=true;stage('LOGICAL')end
   else
    discovery.switchProbes=discovery.switchProbes+1
    local index,name=call(scan.iterator,scan.iteratorState,scan.previous)
    if index==nil then stage('LOGICAL')
    else
     scan.previous=index;scan.index=scan.index+1;addPosition(index,name)
     if scan.index>=1024 then inventory.partial=true;stage('LOGICAL')end
    end
   end
  elseif scan.stage=='LOGICAL'then
   scan.index=scan.index+1;local name=string.format('L%02d',scan.index)
   inventory.logical[scan.index]={identity='LS:'..name,label=name,kind='logical',ordinal=scan.index-1,available=type(api.getLogicalSwitchValue)=='function'}
   if scan.index>=64 then stage('CHOICES')end
  elseif scan.stage=='CHOICES'then choiceStep()
  elseif scan.stage=='REBIND'then
   local role=roles[scan.index+1]
   if role then scan.index=scan.index+1;applyBinding(role,bindings[role].identity)
   else scan=nil;inventory.discoveryPending=false;discovery.state='READY';discovery.stage='READY';discovery.index=0 end
  end
 end
 function provider.refreshStep(maxWork)
  discovery.work=0;discovery.sourceProbes=0;discovery.switchProbes=0;discovery.fallbackProbes=0;discovery.cpuPaused=false
  if not scan then return provider.ready(),discovery end
  maxWork=maxWork or 8
  if not integer(maxWork)or maxWork<1 or maxWork>32 then return false,discovery,'INVALID DISCOVERY BUDGET'end
  for _=1,maxWork do
   local usage=not syncRefresh and call(api.getUsage)or nil
   if finite(usage)and usage>=60 then discovery.cpuPaused=true;break end
   workItem();discovery.work=discovery.work+1;discovery.totalWork=discovery.totalWork+1
   if not scan then break end
   discovery.stage=scan.stage;discovery.index=scan.index
  end
  return provider.ready(),discovery
 end
 function provider.refresh()
  provider.beginRefresh();syncRefresh=true
  -- Synchronous compatibility is deliberately explicit. Widget callers use
  -- beginRefresh/refreshStep so no callback consumes an entire native iterator.
  while not provider.ready()do
   local old=discovery.totalWork;provider.refreshStep(32)
   if discovery.totalWork==old then syncRefresh=false;return inventory,'DISCOVERY PAUSED'end
  end
  syncRefresh=false;return inventory
 end
 function provider.inventory()return inventory end
 function provider.choices(role)if provider.ready()then return picker[role]end end
 function provider.predicate(field,predicate)
  if not provider.ready()then return nil,'INPUT DISCOVERY IN PROGRESS'end
  if type(field)~='string'or type(predicate)~='string'then return nil end
  local item=resolve('PRED:'..lower(field)..':'..predicate,'arm')
  return item and item.identity or nil
 end
 local function nativeValue(role,native)
  if type(native)~='table'or native.current~=true then return nil end
  local value=native[role]
  if role=='arm'and type(value)~='boolean'then value=native.armed end
  if percentages[role]then return finite(value)and value>=0 and value<=100 and value or nil end
  if type(value)=='boolean'then return value end
  local mode=native.mode
  if type(mode)~='string'then return nil end
  local category=mode=='ACRO'and'acro'or(mode=='ANGLE'or mode=='ANGL'or mode=='STAB')and'angle'or(mode=='HORIZON'or mode=='HOR')and'horizon'
  if category and(role=='acro'or role=='angle'or role=='horizon')then return role==category end
  if role=='air'and mode=='AIR'then return true end
  if role=='turtle'and mode=='TURT'then return true end
  if native.family=='INAV'or native.family=='IN'then
   if role=='rth'and(mode=='RTH'or mode=='WRTH')then return true end
   if role=='wrth'and mode=='WRTH'then return true end
  end
 end
 local function readBinding(role,binding,out,native)
   out.value=nil;out.raw=nil;out.state=binding.kind=='off'and'OFF'or'UNAVAILABLE'
   if not provider.ready()then return end
   local value
   if binding.kind=='native'then value=nativeValue(role,native)
   elseif binding.kind=='switchPosition'and binding.index then value=cached(cacheSwitch,binding.index,switchRead)
   elseif binding.kind=='logical'then
    local current;value,current=cached(cacheLogical,binding.ordinal,logicalRead)
    if not current then value=nil elseif binding.inverted then value=not value end
   elseif(binding.kind=='analog'or binding.kind=='predicate')and binding.index then
    local raw,current=cached(cacheValue,binding.index,analogRead)
    if current and finite(raw)then
     out.raw=raw
     if binding.kind=='analog'then value=(min(1024,max(-1024,raw))+1024)*100/2048;if binding.inverted then value=100-value end
     else value=sourcePredicate(raw,binding.predicate)end
    end
   end
   if value~=nil then out.value=value;out.state='LIVE'end
 end
 function provider.preview(role,identity,native)
  previewOut.error=nil
  if not provider.ready()then previewOut.state='UNAVAILABLE';previewOut.value=nil;previewOut.raw=nil;previewOut.identity=identity;previewOut.source=nil;previewOut.override=false;previewOut.error='INPUT DISCOVERY IN PROGRESS';return previewOut,previewOut.error end
  if not snapshot.roles[role]then
   previewOut.state='UNAVAILABLE';previewOut.value=nil;previewOut.raw=nil;previewOut.identity=identity;previewOut.source=nil;previewOut.override=false;previewOut.error='UNKNOWN INDICATOR ROLE'
   return previewOut,previewOut.error
  end
  if previewRole~=role or previewIdentity~=identity or not previewBinding then
   local err
   previewBinding,err=resolve(identity,role);previewIdentity=identity;previewRole=role
   if not previewBinding then
    previewOut.state='UNAVAILABLE';previewOut.value=nil;previewOut.raw=nil;previewOut.identity=identity;previewOut.source=nil;previewOut.override=false;previewOut.error=err
    return previewOut,err
   end
  end
  previewOut.identity=previewBinding.identity;previewOut.source=previewBinding.label;previewOut.override=previewBinding.kind~='off'and previewBinding.kind~='native'
  cycle();readBinding(role,previewBinding,previewOut,native)
  return previewOut
 end
 function provider.sample(native)
  cycle()
  for _,role in ipairs(roles)do
   readBinding(role,bindings[role],snapshot.roles[role],native)
  end
  local configured,unavailable,active=false,false,0
  local winner
  for _,role in ipairs(modePriority)do
   local item=snapshot.roles[role]
   if item.override then
    configured=true
    if item.state~='LIVE'then unavailable=true elseif item.value then active=active+1;if not winner then winner=role=='acro'and'ACRO'or role=='horizon'and'HOR'or'ANGL'end end
   end
  end
  snapshot.modeOverrideConfigured=configured;snapshot.modeOverrideState=not configured and'OFF'or unavailable and'UNAVAILABLE'or'LIVE'
  snapshot.modeOverride=not unavailable and winner or nil;snapshot.modeConflict=active>1
  return snapshot
 end
 function provider.snapshot()return snapshot end
 function provider.beginLearn(kind,now,timeout)
  if not provider.ready()then return false,'INPUT DISCOVERY IN PROGRESS'end
  if kind~='switch'and kind~='analog'and kind~='any'and kind~='logical'then return false,'INVALID LEARN KIND'end
  if not finite(now)or now<0 then return false,'INVALID LEARN CLOCK'end
  timeout=timeout or 1000
  if not finite(timeout)or timeout<50 or timeout>3000 then return false,'INVALID LEARN TIMEOUT'end
  cancelLearn('BASELINING');learnCandidates={};learnBaseline={};changed={};learnCursor=1;learnPhase='BASELINE';learnStart=now;lastLearn=now;learnTimeout=timeout
  if kind=='logical'then for _,item in ipairs(inventory.logical)do learnCandidates[#learnCandidates+1]=item end
  else
   for _,item in ipairs(inventory.sources)do
    if kind=='any'or(kind=='switch'and(item.kind=='switch'or item.kind=='sixpos'))or(kind=='analog'and item.kind~='switch')then learnCandidates[#learnCandidates+1]=item end
   end
  end
  learner.reads=0;learner.candidate=nil;learner.count=#learnCandidates
  if #learnCandidates==0 then cancelLearn('UNAVAILABLE');return false,'NO LEARNABLE INPUTS'end
  return true
 end
 local function learnRead(item)
  if item.kind=='logical'then return call(api.getLogicalSwitchValue,item.ordinal)end
  return analogRead(item.index)
 end
 local function found(item,identity,raw)
  learnPhase=nil;pending=nil;learner.status='FOUND';learner.candidate={identity=identity,label=item.label,kind=item.kind,raw=raw}
  return learner.candidate,learner.status
 end
 function provider.learn(now)
  learner.reads=0
  if not learnPhase then return learner.candidate,learner.status end
  if not finite(now)or now<learnStart or lastLearn and now<lastLearn then cancelLearn('CANCELLED');return nil,learner.status end
  lastLearn=now
  if now-learnStart>=learnTimeout then cancelLearn('TIMEOUT');return nil,learner.status end
  if pending then
   while pending.cursor<=#pending.item.positivePositions and learner.reads<budget do
    local position=pending.item.positivePositions[pending.cursor];pending.cursor=pending.cursor+1;learner.reads=learner.reads+1
    if call(api.getSwitchValue,position.index)==true then return found(pending.item,position.identity,pending.raw)end
   end
   if pending.cursor>#pending.item.positivePositions then
    local item,raw=pending.item,pending.raw
    if item.kind=='switch'then return found(item,'PRED:'..item.field..':'..(raw< -512 and'LOW'or raw>512 and'HIGH'or'MID'),raw)end
    cancelLearn('UNAVAILABLE');return nil,learner.status
   end
   return nil,learner.status
  end
  while learnCursor<=#learnCandidates and learner.reads<budget do
   local item=learnCandidates[learnCursor];local value=learnRead(item);learner.reads=learner.reads+1
   if learnPhase=='BASELINE'then learnBaseline[learnCursor]=value
   else
    local before=learnBaseline[learnCursor]
    local moved=type(value)=='boolean'and type(before)=='boolean'and value~=before
     or finite(value)and finite(before)and abs(value-before)>(item.kind=='trim'and 3 or 200)
    if moved then changed[#changed+1]={item=item,value=value}end
   end
   learnCursor=learnCursor+1
  end
  if learnCursor>#learnCandidates then
   learnCursor=1
   if learnPhase=='BASELINE'then learnPhase='MOVEMENT';learner.status='LEARNING'
   elseif #changed>1 then cancelLearn('AMBIGUOUS')
   elseif #changed==1 then
    local item,value=changed[1].item,changed[1].value
    if item.kind=='switch'or item.kind=='sixpos'then pending={item=item,raw=value,cursor=1};learner.status='RESOLVING'
    elseif item.kind=='logical'then return found(item,item.identity,value)
    else return found(item,'SRC:'..item.field,value)end
   end
  end
  return learner.candidate,learner.status
 end
 function provider.learnState()return learner end
 for _,role in ipairs(roles)do snapshot.roles[role]={identity='OFF',source='Off',state='OFF',value=nil,override=false};bindings[role]={identity='OFF',kind='off',label='Off'}end
 if options.deferRefresh==true then provider.beginRefresh()else provider.refresh()end
 return provider
end
return M
