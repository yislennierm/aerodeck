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
local function bind(p,role,id)local ok,normalized=p.bind(role,id);check(ok,'Could not bind '..role..' to '..id);return normalized end
local f=fixture();local p=module.new(f.api);local inv=p.inventory()
eq(#inv.sources,7,'Physical inventory excludes telemetry/model outputs/ghosts');eq(#inv.switches,2);eq(#inv.analogs,5);eq(#inv.logical,64)
check(not inv.partial);eq(inv.logical[64].identity,'LS:L64');eq(inv.logical[64].ordinal,63)
check(contains(p.choices('arm'),'SW:GearUP')and contains(p.choices('arm'),'SW:!GearUP'),'Native custom labels and inverses are preserved')
check(contains(p.choices('arm'),'SW:6POS6'),'Six actual native positions are offered')
check(not contains(p.choices('arm'),'SW:Tele')and not contains(p.choices('arm'),'SW:L01'),'System and logical selectors are not mistaken for physical positions')
check(contains(p.choices('arm'),'LS:L64')and contains(p.choices('arm'),'LS:!L64'))
check(contains(p.choices('limiter'),'SRC:s1')and contains(p.choices('limiter'),'SRC!:trim-thr'))
check(not contains(p.choices('limiter'),'SRC:ch1')and not contains(p.choices('limiter'),'SRC:sa'))
eq(p.choices('arm'),p.choices('cut'),'Pickers are stable shared arrays');eq(p.inventory(),inv)
for i,id in ipairs(p.choices('arm'))do eq(p.choices('arm').items[i].identity,id);check(type(p.choices('arm').labels[i])=='string')end
local glyph=fixture()
glyph.names[glyph.sa]=string.char(194,140)..'Gear'
glyph.names[glyph.thr]=string.char(194,137)..'Thr'
glyph.names[glyph.trim]=string.char(194,141)..'Thr'
for _,position in ipairs(glyph.positions)do
 if position[2]=='TrimT+'then position[2]='Thr+';glyph.switchNames[position[1]]='Thr+';glyph.switchIndex['Thr+']=position[1]end
 if position[2]=='!TrimT+'then position[2]='!Thr+';glyph.switchNames[position[1]]='!Thr+';glyph.switchIndex['!Thr+']=position[1]end
end
local gp=module.new(glyph.api);local gc=gp.choices('arm')
check(contains(gc,'SW:GearUP'),'Verified native source-icon prefixes do not break custom switch names')
local trimPositions=0
for _,position in ipairs(gp.inventory().predicates)do
 if position.identity=='SW:Thr+'or position.identity=='SW:!Thr+'then eq(position.source.field,'trim-thr','Trim predicates are not attributed to identically named gimbal');trimPositions=trimPositions+1 end
end
eq(trimPositions,2)
for _,source in ipairs(gp.inventory().sources)do if source.field=='sa'then eq(source.label,'Gear')end end
local state=p.snapshot();for _,role in ipairs({'arm','cut','acro','angle','horizon','air','turtle','rth','wrth','throttle','limiter'})do eq(state.roles[role].state,'OFF');eq(state.roles[role].value,nil)end
bind(p,'arm','SW:GearDOWN');bind(p,'cut','SW:!GearDOWN')
p.sample();eq(state.roles.arm.state,'LIVE');eq(state.roles.arm.value,false,'False native switch value is not missing');eq(state.roles.cut.value,true)
f.values[f.sa]=1024;p.sample();eq(state.roles.arm.value,true);eq(state.roles.cut.value,false)
f.current[f.sa]=false;p.sample();eq(state.roles.arm.state,'UNAVAILABLE');eq(state.roles.cut.value,nil,'Inverse of missing is not true')
f.current[f.sa]=true
bind(p,'arm','SW:GhostUP');p.sample();eq(state.roles.arm.identity,'SW:GhostUP');eq(state.roles.arm.state,'UNAVAILABLE')
bind(p,'arm','OFF');p.sample();eq(state.roles.arm.state,'OFF');eq(state.roles.arm.value,nil)
check(not p.bind('nonsense','OFF'));check(not p.bind('arm','LS:L00'));check(not p.bind('arm','LS:L65'));check(not p.bind('arm','PRED:sa:BOGUS'))
check(not p.bind('limiter','SW:GearUP'));check(not p.bind('arm','SRC:s1'));check(not p.bind('limiter','SRC:sa'));check(not p.bind('arm','PRED:s1:HIGH'))
eq(p.predicate('SA','NOT_MID'),'PRED:sa:NOT_MID');eq(p.predicate('sa','bad'),nil)
for n=1,64 do
 local identity=string.format('LS:L%02d',n);bind(p,'arm',identity);bind(p,'cut','LS:!'..string.format('L%02d',n))
 f.logical[n-1]=false;p.sample();eq(f.lastLogical,n-1);eq(state.roles.arm.value,false);eq(state.roles.cut.value,true)
 f.logical[n-1]=true;p.sample();eq(state.roles.arm.value,true);eq(state.roles.cut.value,false)
 f.logical[n-1]=nil;p.sample();eq(state.roles.arm.state,'UNAVAILABLE');eq(state.roles.cut.value,nil);f.logical[n-1]=false
end
for _,predicate in ipairs({'LOW','MID','HIGH','NOT_LOW','NOT_MID','NOT_HIGH'})do
 bind(p,'arm','PRED:sa:'..predicate)
 for _,raw in ipairs({-1024,-513,-512,0,512,513,1024})do
  f.values[f.sa]=raw;p.sample();local expected=predicate=='LOW'and raw< -512 or predicate=='MID'and raw>=-512 and raw<=512 or predicate=='HIGH'and raw>512
  if string.sub(predicate,1,4)=='NOT_'then local positive=string.sub(predicate,5);expected=not(positive=='LOW'and raw< -512 or positive=='MID'and raw>=-512 and raw<=512 or positive=='HIGH'and raw>512)end
  eq(state.roles.arm.value,expected,predicate..' at '..raw)
 end
 f.current[f.sa]=false;p.sample();eq(state.roles.arm.value,nil);f.current[f.sa]=true
end
bind(p,'arm','SW:6POS4');f.values[f.six]=176;p.sample();eq(state.roles.arm.value,true);f.values[f.six]=576;p.sample();eq(state.roles.arm.value,false)
bind(p,'throttle','SRC:thr');bind(p,'limiter','SRC!:thr')
for _,pair in ipairs({{-2000,0},{-1024,0},{0,50},{1024,100},{2000,100}})do f.values[f.thr]=pair[1];p.sample();eq(state.roles.throttle.value,pair[2]);eq(state.roles.limiter.value,100-pair[2]);eq(state.roles.throttle.raw,pair[1])end
f.current[f.thr]=false;p.sample();eq(state.roles.throttle.value,nil);eq(state.roles.limiter.state,'UNAVAILABLE');f.current[f.thr]=true
f.values[f.thr]=0/0;p.sample();eq(state.roles.throttle.value,nil);f.values[f.thr]=0
bind(p,'throttle','SRC:trim-thr');f.values[f.trim]=8;p.sample();eq(state.roles.throttle.value,50.390625,'Trim source has native calibrated scale, not step units')
for _,role in ipairs({'arm','cut','acro','angle','horizon','air','turtle','rth','wrth','throttle','limiter'})do bind(p,role,'NATIVE')end
p.sample({current=true,armed=false,cut=false,mode='ACRO',throttle=0,limiter=100})
eq(state.roles.arm.value,false);eq(state.roles.cut.value,false);eq(state.roles.acro.value,true);eq(state.roles.angle.value,false);eq(state.roles.horizon.value,false)
eq(state.roles.air.state,'UNAVAILABLE');eq(state.roles.turtle.state,'UNAVAILABLE');eq(state.roles.throttle.value,0);eq(state.roles.limiter.value,100)
for _,mode in ipairs({'!','?','*','OK','WAIT','0','AIR*','TURT*','AIRM','ACRO*',''})do
 p.sample({current=true,mode=mode});eq(state.roles.arm.value,nil,'Mode text cannot imply armed');eq(state.roles.air.value,nil,'Unknown/shortened AIR cannot imply false or true');eq(state.roles.turtle.value,nil)
end
for _,mode in ipairs({'ANGLE','ANGL','STAB','HORIZON','HOR','ACRO'})do p.sample({current=true,mode=mode});eq(state.roles.acro.state,'LIVE');eq(state.roles.angle.state,'LIVE');eq(state.roles.horizon.state,'LIVE')end
p.sample({current=true,mode='AIR'});eq(state.roles.air.value,true);eq(state.roles.acro.value,nil)
p.sample({current=true,mode='TURT'});eq(state.roles.turtle.value,true)
p.sample({current=true,family='INAV',mode='RTH'});eq(state.roles.rth.value,true);eq(state.roles.wrth.value,nil,'RTH does not establish WRTH=false')
p.sample({current=true,family='INAV',mode='WRTH'});eq(state.roles.rth.value,true,'Original RTH indicator includes WRTH');eq(state.roles.wrth.value,true)
p.sample({current=true,family='IN',mode='WRTH'});eq(state.roles.rth.value,true);eq(state.roles.wrth.value,true)
for _,family in ipairs({'BTFL','BF','UNKNOWN',''})do
 for _,mode in ipairs({'RTH','WRTH'})do p.sample({current=true,family=family,mode=mode});eq(state.roles.rth.value,nil);eq(state.roles.wrth.value,nil)end
end
for _,mode in ipairs({'ACRO','ANGLE','OK','WAIT','RTH*','WRTH*','RTH ','RTH?'})do
 p.sample({current=true,family='INAV',mode=mode});eq(state.roles.rth.value,nil,'No inferred inactive navigation state');eq(state.roles.wrth.value,nil)
end
p.sample({current=true,family='INAV',mode='WRTH',rth=false,wrth=false});eq(state.roles.rth.value,false);eq(state.roles.wrth.value,false)
p.sample({current=false,family='INAV',mode='WRTH',rth=true,wrth=true});eq(state.roles.rth.value,nil);eq(state.roles.wrth.value,nil)
bind(p,'rth','LS:!L64');bind(p,'wrth','PRED:sa:HIGH');f.logical[63]=false;f.values[f.sa]=1024;p.sample();eq(state.roles.rth.value,true);eq(state.roles.wrth.value,true)
f.logical[63]=nil;f.current[f.sa]=false;p.sample();eq(state.roles.rth.state,'UNAVAILABLE');eq(state.roles.wrth.state,'UNAVAILABLE');f.logical[63]=false;f.current[f.sa]=true
bind(p,'rth','NATIVE');bind(p,'wrth','NATIVE');eq(p.choices('rth'),p.choices('arm'));eq(p.choices('wrth'),p.choices('arm'))
p.sample({current=true,mode='ACRO',air=false,turtle=false,angle=true});eq(state.roles.air.value,false);eq(state.roles.turtle.value,false);eq(state.roles.angle.value,true,'Explicit independent booleans take precedence')
p.sample({current=false,armed=true,air=true,mode='ACRO',throttle=100});for _,r in pairs(state.roles)do eq(r.state,'UNAVAILABLE')end
p.sample({armed=true,air=true});eq(state.roles.arm.state,'UNAVAILABLE')
bind(p,'acro','PRED:sa:HIGH');bind(p,'horizon','PRED:sh:HIGH');bind(p,'angle','LS:L64')
f.values[f.sa]=1024;f.values[f.sh]=1024;f.logical[63]=true;p.sample({current=true,mode='ANGLE'})
eq(state.modeOverride,'ACRO');eq(state.modeConflict,true);eq(state.modeOverrideState,'LIVE');eq(state.modeOverrideConfigured,true)
f.values[f.sa]=-1024;p.sample();eq(state.modeOverride,'HOR');f.values[f.sh]=-1024;p.sample();eq(state.modeOverride,'ANGL')
f.logical[63]=false;p.sample();eq(state.modeOverride,nil);eq(state.modeOverrideState,'LIVE','All known inactive overrides are not missing')
f.current[f.sa]=false;p.sample();eq(state.modeOverrideState,'UNAVAILABLE');eq(state.modeOverride,nil)
for _,role in ipairs({'acro','horizon','angle'})do bind(p,role,'NATIVE')end;p.sample({current=true,mode='ACRO'});eq(state.modeOverrideConfigured,false);eq(state.modeOverrideState,'OFF')
-- Saving only identities survives numeric ID changes and refresh/model changes.
local saved=bind(p,'limiter','SRC!:s1');local f2=fixture(100);local p2=module.new(f2.api);bind(p2,'limiter',saved)
f2.values[f2.s1]=1024;eq(p2.sample().roles.limiter.value,0);eq(p2.snapshot().roles.limiter.identity,saved)
bind(p2,'arm','SW:GearUP');f2.values[f2.sa]=-1024;eq(p2.sample().roles.arm.value,true)
f2.names[f2.s1]=nil;f2.current[f2.s1]=false;p2.refresh();eq(p2.snapshot().roles.limiter.identity,saved);eq(p2.sample().roles.limiter.state,'UNAVAILABLE')
f2.names[f2.s1]='New gain';f2.current[f2.s1]=true;p2.refresh();eq(p2.sample().roles.limiter.state,'LIVE');eq(p2.snapshot().roles.limiter.source,'New gain')
-- Warm sampling does not bind names or enumerate, and duplicate roles read once.
local warm=fixture();local wp=module.new(warm.api)
for _,role in ipairs({'arm','cut','acro','angle','horizon','air','turtle'})do bind(wp,role,'SW:GearUP')end
bind(wp,'throttle','SRC:s1');bind(wp,'limiter','SRC!:s1')
local cold={};for name,count in pairs(warm.calls)do cold[name]=count end
local out=wp.snapshot();for i=1,100 do eq(wp.sample(),out)end
eq(warm.calls.getSwitchValue,100);eq(warm.calls.getSourceValue,100)
for _,name in ipairs({'sources','switches','getFieldInfo','getSourceName','getSourceIndex','getSwitchIndex','getSwitchName','getSwitchInfo'})do eq(warm.calls[name],cold[name],'No warm '..name)end
-- Missing optional APIs report unavailable; legacy getValue fallback is physical only.
local empty=module.new({});eq(#empty.inventory().sources,0);eq(#empty.inventory().logical,64);check(empty.inventory().partial)
bind(empty,'arm','LS:!L64');eq(empty.sample().roles.arm.state,'UNAVAILABLE');bind(empty,'limiter','SRC:unplugged');eq(empty.sample().roles.limiter.state,'UNAVAILABLE')
check(not empty.beginLearn('switch',0));eq(empty.learnState().status,'UNAVAILABLE')
local legacy=fixture();legacy.api.getSourceValue=nil;legacy.api.getValue=function(id)return legacy.values[id]end
local lp=module.new(legacy.api);bind(lp,'limiter','SRC:s1');eq(lp.sample().roles.limiter.value,50)
local ghostOnly=module.new({getFieldInfo=function(name)if name=='s1'then return{id=10,name='s1'}end end,getValue=function()return 0 end})
eq(#ghostOnly.inventory().sources,0,'Legacy nonexistent zero is not evidence of a physical input')
-- Candidate preview is read-only with respect to active bindings and snapshots.
local previewFixture=fixture();local previewProvider=module.new(previewFixture.api)
bind(previewProvider,'arm','SW:GearUP');bind(previewProvider,'acro','PRED:sa:LOW')
local active=previewProvider.sample();eq(active.roles.arm.value,true);eq(active.modeOverride,'ACRO')
local preview=previewProvider.preview('arm','SW:GearDOWN');eq(preview.value,false);eq(preview.state,'LIVE');eq(preview.identity,'SW:GearDOWN')
eq(active.roles.arm.identity,'SW:GearUP');eq(active.roles.arm.value,true);eq(active.modeOverride,'ACRO','Preview cannot change active mode summary')
for _,id in ipairs({'OFF','NATIVE','LS:L64','LS:!L64','PRED:sa:HIGH','SW:GhostUP','SW:GearUP'})do
 eq(previewProvider.preview('arm',id,{current=true,armed=false}),preview,'Preview result is stable across candidates')
 eq(active.roles.arm.identity,'SW:GearUP');eq(active.roles.arm.value,true)
end
eq(previewProvider.preview('arm','NATIVE',{current=true,armed=false}).value,false,'Native false preview is live')
eq(previewProvider.preview('limiter','SRC!:s1').value,50)
eq(previewProvider.preview('arm','INVALID').state,'UNAVAILABLE');eq(preview.error,'INVALID INPUT IDENTITY');eq(preview.source,nil)
eq(previewProvider.preview('INVALID','OFF').error,'UNKNOWN INDICATOR ROLE')
previewProvider.preview('arm','SW:GhostUP');local previousNameReads=previewFixture.calls.getSwitchIndex
for i=1,20 do previewProvider.preview('arm','SW:GhostUP')end
eq(previewFixture.calls.getSwitchIndex,previousNameReads,'Preview reuses missing descriptor instead of scanning repeatedly')
previewProvider.refresh();eq(preview.state,'UNAVAILABLE');eq(preview.value,nil);eq(active.roles.arm.identity,'SW:GearUP')
eq(previewProvider.preview('arm','SW:GearUP').value,true);eq(previewProvider.sample().roles.arm.value,true)
-- Learning baseline and movement are bounded, deterministic, and never bind.
local function learner(kind,budget)
 local fx=fixture();local pr=module.new(fx.api,{learnBudget=budget or 2});check(pr.beginLearn(kind,100,1000));local clock=100
 while pr.learnState().status=='BASELINING'do clock=clock+1;pr.learn(clock);check(pr.learnState().reads<=(budget or 2))end
 return fx,pr,function(limit)
  for i=1,limit or 100 do clock=clock+1;local candidate,status=pr.learn(clock);check(pr.learnState().reads<=(budget or 2),'Learning exceeds per-callback read budget');if status~='LEARNING'and status~='RESOLVING'then return candidate,status end end
 end
end
local lf,lpr,advance=learner('switch');lf.values[lf.sa]=1024;local candidate,status=advance();eq(status,'FOUND');eq(candidate.identity,'SW:GearDOWN');eq(lpr.snapshot().roles.arm.identity,'OFF','Learning never auto-binds')
lf,lpr,advance=learner('switch',1);lf.values[lf.six]=176;candidate,status=advance();eq(status,'FOUND');eq(candidate.identity,'SW:6POS4','Six-position learning resolves actual native predicate')
lf,lpr,advance=learner('analog');lf.values[lf.trim]=8;candidate,status=advance();eq(status,'FOUND');eq(candidate.identity,'SRC:trim-thr','One native trim step is learnable')
lf,lpr,advance=learner('analog');lf.values[lf.s1]=200;eq(advance(10),nil,'At-threshold noise is ignored');lf.values[lf.s1]=201;candidate,status=advance();eq(candidate.identity,'SRC:s1','Fixed baseline detects slow cumulative motion')
lf,lpr,advance=learner('any');lf.values[lf.s1]=500;lf.values[lf.sa]=1024;candidate,status=advance();eq(status,'AMBIGUOUS');eq(candidate,nil)
lf,lpr,advance=learner('logical',8);lf.logical[63]=true;candidate,status=advance();eq(status,'FOUND');eq(candidate.identity,'LS:L64')
lf,lpr,advance=learner('switch');lpr.cancelLearn();eq(lpr.learnState().status,'CANCELLED');eq(lpr.learn(150),nil)
check(lpr.beginLearn('switch',0,50));lpr.learn(50);eq(lpr.learnState().status,'TIMEOUT')
check(lpr.beginLearn('switch',100));lpr.learn(101);lpr.learn(100);eq(lpr.learnState().status,'CANCELLED','Clock reversal does not make a stale candidate')
check(not lpr.beginLearn('anything',0));check(not lpr.beginLearn('switch',-1));check(not lpr.beginLearn('switch',0,49))
for _,budget in ipairs({0,17,-1,1.5})do local x=module.new({}, {learnBudget=budget});eq(x.learnState().budget,8)end
local missing=fixture();local mp=module.new(missing.api,{learnBudget=16});missing.current[missing.sa]=false;check(mp.beginLearn('switch',0));mp.learn(1);missing.current[missing.sa]=true;missing.values[missing.sa]=1024;mp.learn(2);eq(mp.learnState().status,'LEARNING','Unavailable baseline cannot become a guessed movement')
debug.setmetatable('',stringMeta)
print('input-indicators: '..checks..' checks PASS')
