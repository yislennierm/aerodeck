local project=arg[1]or'.';local dependencies=arg[2]or project
local stringMeta=debug.getmetatable('');debug.setmetatable('',nil)
local function loadModule(path)
 local chunk=assert(loadfile(path));local env={type=type,tonumber=tonumber,tostring=tostring,ipairs=ipairs,pairs=pairs,pcall=pcall,math=math,string=string,table=table}
 setmetatable(env,{__index=function(_,key)error('Forbidden picker global: '..key)end})
 if setfenv then setfenv(chunk,env)end;return chunk()
end
local factory=loadModule(project..'/sdcard/SCRIPTS/TOOLS/AERODECK/input-picker.lua')
local inputs=loadModule(dependencies..'/sdcard/SCRIPTS/TOOLS/AERODECK/input-indicators.lua')
local checks=0
local function check(v,message)checks=checks+1;assert(v,message or('check '..checks))end
local function eq(a,b,message)check(a==b,(message or'Unexpected value')..': '..tostring(a)..' ~= '..tostring(b))end
local colors={black=1,tape=2,white=3,muted=4,green=5,cyan=6,orange=7}
local function fixture()
 local f={fields={},names={},types={},values={},current={},positions={},switches={},switchIndex={},logical={},reads=0,events={}}
 local function source(field,label,kind,value)
  local index=#f.names+1;f.names[index]=label;f.fields[index]={id=index,name=field};f.fields[field]=f.fields[index];f.values[index]=value or 0;f.current[index]=true;f.types[index]=kind;return index
 end
 source('rud','Rud');source('ele','Ele');source('thr','Thr');source('ail','Ail')
 f.s1=source('s1','Gain');f.six=source('6pos','6POS',nil,-1024);source('s2','S2');source('ls','LS');source('rs','RS')
 for _,name in ipairs({'rud','ele','thr','ail','t5','t6'})do source('trim-'..name,string.upper(name))end
 local function position(index,label,sourceId,expected)
  f.positions[index]={source=sourceId,expected=expected};f.switches[#f.switches+1]={index,label};f.switches[#f.switches+1]={-index,'!'..label};f.switchIndex[label]=index;f.switchIndex['!'..label]=-index
 end
 for i=1,8 do
  local field='s'..string.char(96+i);local label=i==1 and'ARM'or string.upper(field);local kind=i==6 and 2 or i==8 and 1 or 3
  local id=source(field,string.char(194,140)..label,kind,-1024);if i==1 then f.sa=id end
  position((i-1)*3+1,label..'UP',id,-1024)
  if kind==3 then position((i-1)*3+2,label..'MID',id,0)end
  position((i-1)*3+3,label..'DOWN',id,1024)
 end
 for i=1,6 do position(66+i,'6POS'..i,f.six,-1024+(i-1)*400)end
 for i,name in ipairs({'rud','ele','thr','ail','t5','t6'})do
  local id=f.fields['trim-'..name].id;position(155+i*2,string.upper(name)..'-',id,-8);position(156+i*2,string.upper(name)..'+',id,8)
 end
 for i=0,63 do f.logical[i]=false end
 table.sort(f.switches,function(a,b)return a[1]<b[1]end)
 local api={}
 function api.sources()local n=0;return function()n=n+1;if f.names[n]then return n,f.names[n]end end end
 function api.switches()local n=0;return function()n=n+1;local p=f.switches[n];if p then return p[1],p[2]end end end
 function api.getFieldInfo(key)return f.fields[key]end
 function api.getSourceName(id)return f.names[id]end
 function api.getSwitchInfo(id)if f.types[id]then return{type=f.types[id]}end end
 function api.getSwitchIndex(name)return f.switchIndex[name]end
 function api.getSwitchName(id)for _,p in ipairs(f.switches)do if p[1]==id then return p[2]end end end
 function api.getSourceValue(id)f.reads=f.reads+1;return f.values[id],f.current[id],f.current[id]end
 function api.getSwitchValue(index)
  f.reads=f.reads+1;local p=f.positions[math.abs(index)];if not p or not f.current[p.source]then return nil end
  local result=f.values[p.source]==p.expected;if index<0 then return not result end;return result
 end
 function api.getLogicalSwitchValue(index)f.reads=f.reads+1;return f.logical[index]end
 f.provider=inputs.new(api);f.provider.bind('arm','SW:ARMUP');f.active=f.provider.sample()
 f.provider.bind=function()error('Picker must not mutate active bindings')end
 return f
end
local function ui(f)
 local records,current={},nil
 local lcd={}
 function lcd.sizeText(s,font)return #tostring(s)*(font==0x200 and 6 or 8),font==0x200 and 12 or 17 end
 function lcd.setColor(_,color)current=color end
 function lcd.drawFilledRectangle(x,y,w,h)records[#records+1]={kind='rect',x=x,y=y,w=w,h=h,color=current}end
 function lcd.drawText(x,y,s,flags)local font=flags%65536;local w,h=lcd.sizeText(s,font);records[#records+1]={kind='text',x=x,y=y,w=w,h=h,text=s,color=current}end
 local picker=assert(factory.new({provider=f.provider,lcd=lcd,palette=function()return colors end,fonts={tiny=0x200,small=0x300},colorFlag=0x1000000}))
 local function draw()
  for i=#records,1,-1 do records[i]=nil end;picker.draw()
  for _,r in ipairs(records)do check(r.x>=5 and r.y>=62 and r.x+r.w<=475.01 and r.y+r.h<=244.01,'Body ownership/fit: '..tostring(r.text or r.kind))end
  eq(f.active.roles.arm.identity,'SW:ARMUP');eq(f.active.roles.arm.value,true,'Browsing never changes active arm value')
  return records
 end
 return picker,draw,records
end
local function has(records,text)for _,r in ipairs(records)do if r.text==text then return true end end;return false end
local f=fixture();local p,draw,records=ui(f);local state=p.snapshot()
eq(#f.provider.choices('arm'),256,'Exercise the actual TX16S-sized inventory')
check(p.open('arm','SW:ARMUP'));eq(p.snapshot(),state);eq(state.groupName,'SWITCH POSITIONS');eq(state.identity,'SW:ARMUP');eq(state.page,1);eq(state.pages,7)
check(not p.enabled('pickerUse'),'No use before a current preview is available');p.tick(0);check(p.enabled('pickerUse'));eq(state.preview.state,'LIVE');eq(state.preview.value,true)
draw();check(has(records,'LIVE / ACTIVE'));check(has(records,'SAVED'));check(has(records,'ARMUP'))
local identity,status=p.result();eq(identity,nil);eq(status,'OPEN')
-- Touch targets agree with paint and do not extend into caller header/footer.
for _,control in ipairs(p.controls)do
 if p.enabled(control[1])then
  eq(p.hit(control[2],control[3]),control[1]);eq(p.hit(control[2]+control[4]-1,control[3]+control[5]-1),control[1])
 end
end
eq(p.hit(480,250),nil);eq(p.hit(20,60),nil);eq(p.hit(20,245),nil);eq(p.hit(0/0,100),nil)
-- All256 choices can be reached via group/page/row actions, including inverse64.
local reached={};local groups=state.groupCount
for group=1,groups do
 local expectedName=state.groupName
 repeat
  for row=1,6 do
   local name='pickerRow'..row
   if p.enabled(name)then check(p.action(name));p.tick(group*1000+state.page*20+row);reached[state.identity]=true;draw();check(p.enabled('pickerUse'));eq(state.groupName,expectedName)end
  end
  local nextEnabled=p.enabled('pickerNext')
  if nextEnabled then check(p.action('pickerNext'))end
 until not nextEnabled
 check(p.action('pickerGroupNext'));p.tick(group*1000+999)
end
local count=0;for _ in pairs(reached)do count=count+1 end
eq(count,256);check(reached['LS:L64']and reached['LS:!L64']);eq(state.groupCount,groups)
-- Opening selects the exact saved group/page; row ENTER focuses explicit USE.
check(p.open('air','LS:!L64'));p.tick(0);eq(state.groupName,'LOGICAL / INVERTED');eq(state.page,11);eq(state.selected,64);eq(state.preview.value,true)
draw();check(has(records,'11/11'),'Last-page location is visible, not just category number')
check(p.action('pickerRow4'));eq(state.identity,'LS:!L64');eq(state.focusName,'pickerUse');p.tick(1);check(p.activate());identity,status=p.result();eq(identity,'LS:!L64');eq(status,'CHOSEN');check(not state.active)
eq(f.active.roles.arm.identity,'SW:ARMUP');eq(f.active.roles.arm.value,true)
check(not p.action('pickerUse'));eq(p.hit(20,100),nil)
-- Explicit Cancel retains unavailable current selection without a forced replacement.
check(p.open('arm','SW:RenamedSwitchUP'));p.tick(0);eq(state.groupName,'SAVED / UNAVAILABLE');eq(state.identity,'SW:RenamedSwitchUP');eq(state.preview.state,'UNAVAILABLE');check(p.enabled('pickerUse'));draw();check(has(records,'UNAVAILABLE / no current value'))
check(p.action('pickerCancel'));identity,status=p.result();eq(identity,nil);eq(status,'CANCELLED')
check(p.open('arm','INVALID'));p.tick(0);check(not p.enabled('pickerUse'));draw();check(has(records,'INVALID INPUT IDENTITY'));p.action('pickerCancel')
-- Numeric source/reversal and native freshness preview are independent of arm.
check(p.open('limiter','SRC!:s1'));p.tick(0);eq(state.groupName,'ANALOG / REVERSED');eq(state.preview.value,50);draw();check(has(records,'LIVE / 50%'))
check(p.action('pickerGroupNext'));p.tick(1);eq(state.groupName,'OFF / NATIVE');eq(state.identity,'OFF');eq(state.preview.state,'OFF');draw();check(has(records,'OFF / NOT CONFIGURED'))
check(p.action('pickerRow2'));p.tick(2,{current=false,limiter=100});eq(state.preview.state,'UNAVAILABLE')
p.tick(3,{current=true,limiter=0});eq(state.preview.value,0);draw();check(has(records,'LIVE / 0%'));p.action('pickerCancel')
-- Rotary focus only activates visible controls; bounds and empty rows are skipped.
check(p.open('arm','OFF'));p.tick(0);local focusSeen={}
for i=1,30 do check(p.move(1));focusSeen[state.focusName]=true;check(p.enabled(state.focusName));p.tick(i);draw()end
check(not focusSeen.pickerRow3 and not focusSeen.pickerPrevious and not focusSeen.pickerNext)
check(p.move(-1));check(not p.move(0));check(not p.move(0/0));p.action('pickerCancel')
-- Learning uses the provider's budget alone, proposes a source, never applies it.
check(p.open('limiter','SRC:s1'));p.tick(100);check(p.action('pickerLearn'));eq(state.learnStatus,'BASELINING');check(state.learning);draw();check(has(records,'KEEP ALL CONTROLS STILL'))
for _,control in ipairs(p.controls)do if control[1]~='pickerLearn'and control[1]~='pickerCancel'then check(not p.enabled(control[1]),'Learning cannot leave hidden row actions active')end end
local now=100
while state.learnStatus=='BASELINING'do now=now+1;local before=f.reads;p.tick(now);check(f.reads-before<=8);draw()end
eq(state.learnStatus,'LEARNING');draw();check(has(records,'MOVE ONE INPUT'))
f.values[f.s1]=700
for i=1,20 do now=now+1;local before=f.reads;p.tick(now);check(f.reads-before<=8);if not state.learning then break end end
eq(state.learnStatus,'FOUND');eq(state.identity,'SRC:s1');eq(state.focusName,'pickerUse');eq(f.active.roles.arm.identity,'SW:ARMUP');eq(f.active.roles.arm.value,true)
check(not p.enabled('pickerUse'),'FOUND waits for a current preview');p.tick(now+1);check(p.enabled('pickerUse'));eq(state.preview.state,'LIVE');draw();check(p.action('pickerUse'));eq(p.result(),'SRC:s1')
-- Cancel/stop/timeout/failure paths display readable explanations with normal list actions.
check(p.open('limiter','SRC:s1'));p.tick(200);p.action('pickerLearn');check(p.action('pickerLearn'));eq(state.learnStatus,'CANCELLED');check(not state.learning);p.tick(201);draw();check(has(records,'LEARNING CANCELLED / binding unchanged'))
check(p.action('pickerLearn'));p.tick(1201);eq(state.learnStatus,'TIMEOUT');p.tick(1202);draw();check(has(records,'TIMED OUT / retry LEARN'))
check(p.enabled('pickerRow1'));check(p.action('pickerRow1'));eq(state.learnStatus,'IDLE');p.tick(1203);draw();p.action('pickerCancel')
check(p.open('arm','SW:ARMUP'));p.tick(2000);p.action('pickerLearn');now=2000;while state.learnStatus=='BASELINING'do now=now+1;p.tick(now)end
f.values[f.sa]=1024;local second=f.fields.sb.id;f.values[second]=1024
for i=1,10 do now=now+1;p.tick(now);if not state.learning then break end end
eq(state.learnStatus,'AMBIGUOUS');p.tick(2200);draw();check(has(records,'SEVERAL INPUTS MOVED / retry LEARN'));p.action('pickerCancel')
-- A logical group selects logical learning, which resolves the final entry.
f.values[f.sa]=-1024;f.values[second]=-1024
check(p.open('turtle','LS:L64'));p.tick(3000);check(p.action('pickerLearn'));for i=1,8 do p.tick(3000+i)end;eq(state.learnStatus,'LEARNING');f.logical[63]=true
for i=1,8 do p.tick(3010+i)end;eq(state.learnStatus,'FOUND');eq(state.identity,'LS:L64');p.tick(3020);draw();p.action('pickerCancel')
-- Clock reversal and malformed current IDs do not preserve a stale candidate.
check(p.open('arm','OFF'));p.tick(4000);p.action('pickerLearn');p.tick(3999);eq(state.learnStatus,'CANCELLED');check(not state.learning);p.tick(4001);draw();p.action('pickerCancel')
-- Extremely long labels fit measured columns, preserving UTF-8 boundaries.
local long=string.rep('W',100)..string.char(194,130)
local oldChoices=f.provider.choices
f.provider.choices=function()return{'SW:long',labels={long},items={{identity='SW:long',label=long}}}end
check(p.open('arm','SW:long'));p.tick(0);draw();eq(state.currentIdentity,'SW:long');eq(state.groupCount,1);check(not p.enabled('pickerGroupNext'))
for _,r in ipairs(records)do if r.kind=='text'then check(not string.match(r.text,'[\194]$'),'Truncation cannot leave a UTF-8 lead byte')end end
p.action('pickerCancel');f.provider.choices=oldChoices
-- Missing optional preview/learning support fails honestly and cannot USE an invalid proposal.
local oldPreview,oldBegin=f.provider.preview,f.provider.beginLearn;f.provider.preview=nil;f.provider.beginLearn=nil
check(p.open('arm','OFF'));p.tick(0);check(not p.enabled('pickerUse'));check(not p.enabled('pickerLearn'));draw();check(has(records,'PREVIEW UNAVAILABLE'));p.action('pickerCancel')
f.provider.preview=oldPreview;f.provider.beginLearn=oldBegin
-- An unlisted learned proposal cannot replace the retained unavailable saved item.
local realLearn=f.provider.learn
f.provider.learn=function()return{identity='SW:UnlistedUP',label='Unlisted native input'},'FOUND'end
check(p.open('arm','SW:OriginalMissingUP'));p.tick(5000);check(p.action('pickerLearn'));p.tick(5001);eq(state.identity,'SW:UnlistedUP');p.tick(5002)
check(p.action('pickerGroupPrevious'));p.tick(5003);eq(state.groupName,'SAVED / UNAVAILABLE');eq(state.identity,'SW:OriginalMissingUP');p.action('pickerCancel')
f.provider.learn=realLearn
check(not factory.new({provider=f.provider,lcd={}}));check(not factory.new({lcd={}}))
eq(f.active.roles.arm.identity,'SW:ARMUP');eq(f.active.roles.arm.value,true)
debug.setmetatable('',stringMeta)
print('input-picker: '..checks..' checks PASS')
