local project=arg[1]or'.'
local stringMeta=debug.getmetatable('');debug.setmetatable('',nil)
local chunk=assert(loadfile(project..'/sdcard/SCRIPTS/TOOLS/AERODECK/input-indicators.lua'))
local safe={type=type,tonumber=tonumber,tostring=tostring,ipairs=ipairs,pairs=pairs,pcall=pcall,math=math,string=string,table=table}
setmetatable(safe,{__index=function(_,name)error('Forbidden input module global: '..name)end})
if setfenv then setfenv(chunk,safe)end
local module=chunk()
local checks=0
local function check(v,message)checks=checks+1;assert(v,message or('check '..checks))end
local function eq(a,b,message)check(a==b,(message or'Unexpected value')..': '..tostring(a)..' ~= '..tostring(b))end
local function contains(list,value)for _,v in ipairs(list)do if v==value then return true end end;return false end
local function fixture(offset)
 offset=offset or 0
 local f={api={},values={},current={},names={},fields={},types={},position={},switchNames={},switchIndex={},logical={},calls={},positions={}}
 local function count(name)f.calls[name]=(f.calls[name]or 0)+1 end
 local function source(n,field,label,value,switchType,unit)
  local id=n+offset;f.fields[field]={id=id,name=field,unit=unit};f.fields[id]=f.fields[field];f.names[id]=label;f.values[id]=value;f.current[id]=true;f.types[id]=switchType
  return id
 end
 f.sa=source(1,'sa','Gear',-1024,3);f.sh=source(2,'sh','SH',-1024,2)
 f.six=source(3,'6pos','6POS',-1024);f.s1=source(4,'s1','Gain',0)
 f.ls=source(5,'ls','LS',1024);f.trim=source(6,'trim-thr','TrimT',0);f.thr=source(7,'thr','Thr',-1024)
 f.alias=source(8,'sa','sa',100,nil,1) -- Telemetry name collides with physical alias; not a physical input.
 f.fields['sa']=f.fields[f.sa]
 source(9,'ch1','CH1',0);source(10,'input1','I1',0);source(11,'timer1','Timer1',0)
 local ghost={id=12+offset,name='sb'};f.fields.sb=ghost;f.fields[ghost.id]=ghost;f.values[ghost.id]=-1024;f.current[ghost.id]=false
 local function position(index,name,sourceId,test)
  index=index+offset*2;f.positions[#f.positions+1]={index,name};f.switchNames[index]=name;f.switchIndex[name]=index;f.position[index]={source=sourceId,test=test}
  f.positions[#f.positions+1]={-index,'!'..name};f.switchNames[-index]='!'..name;f.switchIndex['!'..name]=-index
 end
 position(1,'GearUP',f.sa,function(v)return v< -512 end)
 position(2,'GearMID',f.sa,function(v)return v>=-512 and v<=512 end)
 position(3,'GearDOWN',f.sa,function(v)return v>512 end)
 position(4,'SHUP',f.sh,function(v)return v<0 end);position(5,'SHDOWN',f.sh,function(v)return v>=0 end)
 for i=1,6 do position(10+i,'6POS'..i,f.six,function(v)return v==(-1024+(i-1)*400)end)end
 position(20,'TrimT+',f.trim,function(v)return v>0 end)
 f.positions[#f.positions+1]={1000,'Tele'};f.switchNames[1000]='Tele';f.switchIndex.Tele=1000
 f.positions[#f.positions+1]={1001,'L01'};f.switchNames[1001]='L01';f.switchIndex.L01=1001
 f.switchIndex['GhostUP']=2000 -- Resolves, but does not exist according to getSwitchName.
 for i=0,63 do f.logical[i]=false end
 function f.api.sources()
  count('sources');local keys={};for id in pairs(f.names)do keys[#keys+1]=id end;table.sort(keys)
  local cursor=0;return function()cursor=cursor+1;local id=keys[cursor];if id then return id,f.names[id]end end
 end
 function f.api.switches()
  count('switches');local cursor=0;return function()cursor=cursor+1;local p=f.positions[cursor];if p then return p[1],p[2]end end
 end
 function f.api.getFieldInfo(key)count('getFieldInfo');return f.fields[key]end
 function f.api.getSourceName(id)count('getSourceName');return f.names[id]end
 function f.api.getSourceIndex(name)count('getSourceIndex');for id,label in pairs(f.names)do if label==name then return id end end end
 function f.api.getSwitchInfo(id)count('getSwitchInfo');if f.types[id]then return{type=f.types[id],name='UNTRUSTED NAME'}end end
 function f.api.getSwitchIndex(name)count('getSwitchIndex');return f.switchIndex[name]end
 function f.api.getSwitchName(index)count('getSwitchName');return f.switchNames[index]end
 function f.api.getSwitchValue(index)
  count('getSwitchValue');local pos=f.position[math.abs(index)];if not pos or not f.current[pos.source]then return end
  local value=pos.test(f.values[pos.source]);if index<0 then return not value end;return value
 end
 function f.api.getLogicalSwitchValue(index)count('getLogicalSwitchValue');f.lastLogical=index;return f.logical[index]end
 function f.api.getSourceValue(id)count('getSourceValue');return f.values[id],f.current[id],f.current[id]end
 function f.api.getValue()error('Freshness must not be bypassed')end
 return f
end

local roles={'arm','cut','acro','angle','horizon','air','turtle','rth','wrth','throttle','limiter'}
local function instrument(f)
 f.probes={source=0,switch=0};local sources,switches=f.api.sources,f.api.switches
 function f.api.sources()local next,state,previous=sources();return function(...)f.probes.source=f.probes.source+1;return next(...)end,state,previous end
 function f.api.switches()local next,state,previous=switches();return function(...)f.probes.switch=f.probes.switch+1;return next(...)end,state,previous end
 return f
end
local function finish(p,f,budget)
 local steps=0;local progress=p.refreshState()
 while not p.ready()do
  local a,b=f.probes.source,f.probes.switch
  local ready,state=p.refreshStep(budget or 8);eq(state,progress,'Progress view is stable');eq(ready,p.ready())
  check(state.work<=(budget or 8));check(f.probes.source-a<=(budget or 8));check(f.probes.switch-b<=(budget or 8));check(state.sourceProbes+state.switchProbes+state.fallbackProbes<=state.work)
  steps=steps+1;check(steps<4000,'Discovery terminates at iterator caps')
 end
 return steps
end
local f=instrument(fixture());local p=module.new(f.api,{deferRefresh=true})
eq(f.calls.sources,nil,'Deferred constructor does not call native APIs');eq(f.calls.getFieldInfo,nil);eq(p.ready(),false);eq(p.refreshState().state,'DISCOVERING');eq(p.choices('arm'),nil)
check(not p.bind('arm','NATIVE'));check(not p.beginLearn('analog',0));local preview,why=p.preview('arm','NATIVE',{current=true,armed=false});eq(preview.state,'UNAVAILABLE');eq(why,'INPUT DISCOVERY IN PROGRESS')
finish(p,f,1);eq(p.refreshState().state,'READY');eq(#p.inventory().logical,64);check(not p.inventory().discoveryPending)
local syncF=fixture();local reference=module.new(syncF.api)
for _,role in ipairs(roles)do
 local actual,expected=p.choices(role),reference.choices(role);eq(#actual,#expected,'Complete catalogue preserved for '..role)
 for i,id in ipairs(expected)do eq(actual[i],id);eq(actual.labels[i],expected.labels[i]);eq(actual.items[i].kind,expected.items[i].kind);eq(actual.items[i].available,expected.items[i].available)end
end
for number=1,64 do local name=string.format('L%02d',number);check(contains(p.choices('arm'),'LS:'..name));check(contains(p.choices('arm'),'LS:!'..name))end
check(p.bind('arm','LS:!L64'));check(p.bind('limiter','SRC:s1'));p.sample();eq(p.snapshot().roles.arm.value,true);eq(p.snapshot().roles.limiter.value,50)
local beforeSource,beforeSwitch,beforeFields=f.calls.sources,f.calls.switches,f.calls.getFieldInfo
for _=1,100 do p.sample({current=true,armed=false});p.refreshStep(8)end
eq(f.calls.sources,beforeSource,'Warm sampling never rescans sources');eq(f.calls.switches,beforeSwitch);eq(f.calls.getFieldInfo,beforeFields)
-- Refresh does not present values from the previous inventory or replace bindings.
p.beginRefresh();eq(p.snapshot().roles.arm.identity,'LS:!L64');eq(p.snapshot().roles.arm.state,'UNAVAILABLE');p.sample({current=true,armed=false});eq(p.snapshot().roles.arm.state,'UNAVAILABLE');eq(p.snapshot().roles.arm.value,nil)
check(not p.bind('arm','OFF'));eq(p.snapshot().roles.arm.identity,'LS:!L64');eq(p.choices('arm'),nil)
p.refreshStep(3);check(p.cancelRefresh());eq(p.refreshState().state,'CANCELLED');beforeSource=f.probes.source;beforeSwitch=f.probes.switch
for _=1,10 do p.refreshStep(32);p.sample()end
eq(f.probes.source,beforeSource);eq(f.probes.switch,beforeSwitch);eq(p.ready(),false)
p.beginRefresh();finish(p,f,8);p.sample();eq(p.snapshot().roles.arm.identity,'LS:!L64');eq(p.snapshot().roles.arm.value,true);eq(p.snapshot().roles.limiter.value,50)
-- Caller CPU headroom and explicit max-work limits apply to every stage.
local cpu=instrument(fixture());local usage=60;cpu.api.getUsage=function()return usage end
local limited=module.new(cpu.api,{deferRefresh=true});local ready,state=limited.refreshStep(32);eq(ready,false);eq(state.work,0);check(state.cpuPaused);eq(cpu.calls.sources,nil)
usage=0;limited.refreshStep(2);eq(state.work,2);local total=state.totalWork
for _,invalid in ipairs({0,33,1.5,-1})do local ok,st,err=limited.refreshStep(invalid);eq(ok,false);eq(st.totalWork,total);eq(err,'INVALID DISCOVERY BUDGET')end
local calls=0;cpu.api.getUsage=function()calls=calls+1;return calls>=4 and 60 or 0 end
limited.refreshStep(32);eq(state.work,3);check(state.cpuPaused)
cpu.api.getUsage=function()return 0 end;finish(limited,cpu,32)
-- Explicit synchronous compatibility remains synchronous even with a CPU API.
local eager=fixture();eager.api.getUsage=function()return 100 end;check(module.new(eager.api).ready())
-- Never consume unbounded native iterators in one call or beyond their cap.
local endless=instrument(fixture());local sourceN,switchN=0,0
endless.api.sources=function()return function()sourceN=sourceN+1;endless.probes.source=endless.probes.source+1;return sourceN,'Native'..sourceN end end
endless.api.switches=function()return function()switchN=switchN+1;endless.probes.switch=endless.probes.switch+1;return switchN,'System position' end end
local capped=module.new(endless.api,{deferRefresh=true});finish(capped,endless,8);eq(sourceN,1024);eq(switchN,1024);check(capped.inventory().partial);eq(#capped.inventory().logical,64);check(contains(capped.choices('arm'),'LS:!L64'))
-- Cached longest-prefix matching preserves custom labels and first-source ties.
local long=instrument(fixture());long.names[20]='GearExtra';long.fields[20]={id=20,name='sb'};long.fields.sb=long.fields[20];long.values[20]=-1024;long.current[20]=true;long.types[20]=3;long.positions[#long.positions+1]={301,'GearExtraUP'}
local names=module.new(long.api,{deferRefresh=true});finish(names,long,8)
local found
for _,item in ipairs(names.inventory().predicates)do if item.identity=='SW:GearExtraUP'then found=item;break end end
check(found~=nil);eq(found.source.field,'sb');check(contains(names.choices('arm'),'SW:GearUP'))
-- Restart during scanning resets the iterator without retaining duplicate rows.
names.beginRefresh();names.refreshStep(32);names.beginRefresh();finish(names,long,8);eq(#names.inventory().sources,8);eq(#names.inventory().logical,64)
if stringMeta then debug.setmetatable('',stringMeta)end
print('input discovery: '..checks..' checks PASS')
