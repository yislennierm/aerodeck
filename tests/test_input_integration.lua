-- Actual main/config/picker/provider regression. Run from the project root.
-- Only native input APIs are fixture-injected at the factory boundary. Main,
-- storage, picker, provider, protocol decoder and link service remain real code.
local realLoadfile=loadfile
local realLoadstring=loadstring
local lastMain
loadstring=function(source,name,...)
 local chunk,err=realLoadstring(source,name,...)
 if chunk and name=='@telem-under-test'then return function(...)local app=chunk(...);lastMain=app;return app end end
 return chunk,err
end
local lastFixture
local function inputFixture(original)
 local f={values={-1024,0,-1024,0},current={true,true,true,true},logical={},reads=0,bindCalls=0,guards={}}
 for i=0,63 do f.logical[i]=false end
 local fields={{id=1,name='sa'},{id=2,name='s1'},{id=3,name='thr'},{id=4,name='trim-thr'}}
 local names={string.char(194,140)..'SA',string.char(194,138)..'Gain',string.char(194,137)..'Thr',string.char(194,141)..'Thr'}
 local positions={{1,'SAUP'},{2,'SAMID'},{3,'SADOWN'},{-1,'!SAUP'},{-2,'!SAMID'},{-3,'!SADOWN'}}
 local api={};for k,v in pairs(original)do api[k]=v end
 function api.sources()local i=0;return function()i=i+1;if fields[i]then return i,names[i]end end end
 function api.switches()local i=0;return function()i=i+1;if positions[i]then return positions[i][1],positions[i][2]end end end
 function api.getFieldInfo(key)
  for _,field in ipairs(fields)do if key==field.id or type(key)=='string'and string.lower(key)==field.name then return field end end
  if original.getFieldInfo then return original.getFieldInfo(key)end
 end
 function api.getSourceName(index)if names[index]then return names[index]end;if original.getSourceName then return original.getSourceName(index)end end
 function api.getSwitchInfo(index)if index==1 then return{type=3}end end
 function api.getSwitchIndex(name)for _,p in ipairs(positions)do if p[2]==name then return p[1]end end;if original.getSwitchIndex then return original.getSwitchIndex(name)end end
 function api.getSwitchName(index)for _,p in ipairs(positions)do if p[1]==index then return p[2]end end end
 function api.getSwitchValue(index)
  if math.abs(index)>=1 and math.abs(index)<=3 then
   f.reads=f.reads+1;if not f.current[1]then return nil end
   local raw=f.values[1];local value=math.abs(index)==1 and raw< -512 or math.abs(index)==2 and raw>=-512 and raw<=512 or math.abs(index)==3 and raw>512
   if index<0 then return not value end;return value
  end
  if original.getSwitchValue then return original.getSwitchValue(index)end
 end
 function api.getLogicalSwitchValue(index)f.reads=f.reads+1;return f.logical[index]end
 function api.getSourceValue(index)
  if fields[index]then f.reads=f.reads+1;return f.values[index],f.current[index],f.current[index]end
  if original.getSourceValue then return original.getSourceValue(index)end
 end
 f.api=api;return f
end
-- Leave the shared adapter untouched; augment only its loaded factories.
loadfile=function(path,...)
 local chunk=realLoadfile(path,...);if not chunk then return chunk end
 if string.find(path,'/input-indicators.lua',1,true)then
  local real=chunk();return function()return{new=function(api,opts)
   local f=inputFixture(api);lastFixture=f;local provider=real.new(f.api,opts);f.provider=provider
   local bind=provider.bind;provider.bind=function(...)f.bindCalls=f.bindCalls+1;return bind(...)end
   return provider
  end}end
 elseif string.find(path,'/link.lua',1,true)then
  local real=chunk();return function()return{new=function(opts)
   local service=real.new(opts);local tick=service.tick;local f=lastFixture
   service.tick=function(self,now,enabled,current,disarmed,videoEnabled,guard)
    if f then f.guards={current=guard and guard.current,disarmed=guard and guard.disarmed,fcCurrent=current,fcDisarmed=disarmed}end
    return tick(self,now,enabled,current,disarmed,videoEnabled,guard)
   end
   return service
  end}end
 end
 return chunk
end
local adapter=assert(loadfile('tests/test_ui_navigation.lua'))('adapter')
loadfile=realLoadfile
local E=adapter.events
local checks=0
local function check(value,message)checks=checks+1;assert(value,message or('check '..checks))end
local function eq(a,b,message)check(a==b,(message or'Unexpected value')..': '..tostring(a)..' ~= '..tostring(b))end
local function make(extra)
 local options={settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nvtxMode=2\n'..(extra or'')}
 local app=adapter.make(options);return app,lastFixture
end
local function send(a,event,touch)eq(a.send(event,touch),0)end
local function tap(a,x,y)send(a,E.EVT_TOUCH_TAP,{x=x,y=y})end
local function open(a,role)
 a.arrange(8);check(a.config.openSection((role=='arm'or role=='cut'or role=='throttle'or role=='limiter')and 6 or 7,role..'Binding'))
 send(a,0);send(a,E.EVT_VIRTUAL_ENTER)
 check(a.inputs.active());eq(a.inputs.pickerState().role,role);check(a.state().editing)
end
local function group(a,name)
 for i=1,10 do if a.inputs.pickerState().groupName==name then return end;tap(a,20,74)end
 error('Could not select picker group '..name)
end
local function choose(a,row)
 tap(a,20,88+(row-1)*18+9);eq(a.inputs.pickerState().focusName,'pickerUse');send(a,E.EVT_VIRTUAL_ENTER);check(not a.inputs.active());check(not a.state().editing)
end
local function save(a)tap(a,210,232);check(not a.state().appDirty)end
-- Browsing, proposing and cancelling are separate from applying settings.
local a,f=make();eq(a.config.get('armBinding'),'NATIVE');eq(a.inputs.state.roles.arm.state,'LIVE');eq(a.inputs.state.roles.arm.value,false)
local binds=f.bindCalls;local writes=a.writes();open(a,'arm');group(a,'OFF / NATIVE');tap(a,20,97)
eq(a.inputs.pickerState().identity,'OFF');eq(a.inputs.state.roles.arm.identity,'NATIVE');eq(a.inputs.state.roles.arm.value,false);eq(f.bindCalls,binds);eq(a.writes(),writes)
-- Modal preempts global navigation and the footer while the proposal is open.
for _,event in ipairs({E.EVT_SYS_BREAK,E.EVT_VIRTUAL_MENU,E.EVT_VIRTUAL_NEXT_PAGE,E.EVT_VIRTUAL_PREV_PAGE})do if event then send(a,event);eq(a.state().page,8);check(a.inputs.active());eq(a.state().navFocus,nil)end end
tap(a,140,15);tap(a,456,259);eq(a.state().page,8);check(a.inputs.active())
send(a,E.EVT_VIRTUAL_EXIT);check(not a.inputs.active());check(not a.state().editing);check(not a.state().appDirty);eq(a.config.get('armBinding'),'NATIVE');eq(f.bindCalls,binds);eq(a.writes(),writes)
-- Explicit USE changes a draft only; SAVE is the first active bind/write.
open(a,'arm');group(a,'OFF / NATIVE');choose(a,1)
check(a.state().appDirty);eq(a.config.get('armBinding'),'NATIVE');eq(a.inputs.state.roles.arm.identity,'NATIVE');eq(f.bindCalls,binds);eq(a.writes(),writes)
open(a,'arm');eq(a.inputs.pickerState().identity,'OFF','Reopen sees draft proposal');tap(a,20,115);send(a,E.EVT_VIRTUAL_EXIT)
check(a.state().appDirty,'Cancel retains an earlier completed draft');eq(a.config.get('armBinding'),'NATIVE');eq(a.writes(),writes)
save(a);eq(a.config.get('armBinding'),'OFF');eq(a.inputs.state.roles.arm.state,'OFF');check(f.bindCalls>binds);eq(a.writes(),writes+2)
local saved=a.savedSettings();check(string.find(saved,'armBinding=OFF',1,true));local reopened=adapter.make({settings=saved});eq(reopened.config.get('armBinding'),'OFF');eq(reopened.inputs.state.roles.arm.state,'OFF')
-- Every role has the practical picker, not the old one-detent spinner.
for _,role in ipairs({'cut','throttle','limiter','acro','angle','horizon','air','turtle','rth','wrth'})do
 local app,fx=make();local count=fx.bindCalls;open(app,role);check(app.inputs.pickerState().count>0);send(app,E.EVT_VIRTUAL_EXIT);eq(fx.bindCalls,count);eq(app.writes(),0)
end
-- Trim grammar persists and reopens, with live physical preview but no early bind.
a,f=make();open(a,'limiter');group(a,'ANALOG CONTROLS')
local ps=a.inputs.pickerState();local row
for i=1,6 do tap(a,20,88+(i-1)*18+9);if a.inputs.pickerState().identity=='SRC:trim-thr'then row=i;break end end
check(row~=nil);eq(a.inputs.pickerState().preview.state,'LIVE');eq(a.inputs.state.roles.limiter.state,'OFF');send(a,E.EVT_VIRTUAL_ENTER);check(a.state().appDirty);eq(a.config.get('limiterBinding'),'OFF');save(a)
eq(a.config.get('limiterBinding'),'SRC:trim-thr');eq(a.inputs.state.roles.limiter.value,50);saved=a.savedSettings();check(string.find(saved,'limiterBinding=SRC:trim-thr',1,true))
reopened=adapter.make({settings=saved});eq(reopened.config.get('limiterBinding'),'SRC:trim-thr');eq(reopened.inputs.state.roles.limiter.state,'LIVE')
-- A learned native position still needs explicit USE and Settings Save.
a,f=make();binds=f.bindCalls;open(a,'arm');group(a,'SWITCH POSITIONS');tap(a,180,232)
for i=1,6 do if a.inputs.pickerState().learnStatus=='LEARNING'then break end;send(a,0)end
eq(a.inputs.pickerState().learnStatus,'LEARNING');f.values[1]=1024
for i=1,10 do if not a.inputs.pickerState().learning then break end;send(a,0)end
eq(a.inputs.pickerState().learnStatus,'FOUND');eq(a.inputs.pickerState().identity,'SW:SADOWN');send(a,0)
eq(a.inputs.pickerState().preview.value,true);eq(a.inputs.state.roles.arm.identity,'NATIVE');eq(a.inputs.state.roles.arm.value,false);eq(f.bindCalls,binds);eq(a.writes(),0)
send(a,E.EVT_VIRTUAL_ENTER);check(not a.inputs.active());check(a.state().appDirty);eq(a.config.get('armBinding'),'NATIVE');eq(f.bindCalls,binds);eq(a.writes(),0)
save(a);eq(a.config.get('armBinding'),'SW:SADOWN');eq(a.inputs.state.roles.arm.value,true);eq(a.snapshot().fcArmed,false,'Radio arm indication remains separate from decoded FC armed truth')
-- Renamed/missing valid source preserves all other settings and original identity.
a,f=make('armBinding=SW:MissingUP\nrenderHz=13\n');eq(a.config.get('armBinding'),'SW:MissingUP');eq(a.config.get('renderHz'),13);eq(a.inputs.state.roles.arm.state,'UNAVAILABLE')
open(a,'arm');eq(a.inputs.pickerState().groupName,'SAVED / UNAVAILABLE');eq(a.inputs.pickerState().identity,'SW:MissingUP');send(a,E.EVT_VIRTUAL_EXIT);eq(a.config.get('armBinding'),'SW:MissingUP');eq(a.writes(),0)
-- Full logical catalogue works through the actual main and qualified false values.
a,f=make('turtleBinding=LS:!L64\n');eq(a.inputs.state.roles.turtle.state,'LIVE');eq(a.inputs.state.roles.turtle.value,true);open(a,'turtle');eq(a.inputs.pickerState().page,11);eq(a.inputs.pickerState().identity,'LS:!L64');send(a,E.EVT_VIRTUAL_EXIT)
-- Legacy switch/position migration is inert until Save, preserving a live predicate.
a,f=make('armSource=SA\narmPosition=1\n');eq(a.config.get('armBinding'),'PRED:sa:HIGH');eq(a.inputs.state.roles.arm.value,false);eq(a.writes(),0)
-- Lifecycle cancellation cannot apply an in-progress proposal or leak a learner.
a,f=make();open(a,'arm');group(a,'SWITCH POSITIONS');tap(a,180,232);check(a.inputs.pickerState().learning)
a.background();check(not a.inputs.active());check(not a.state().editing);check(not a.state().appDirty);eq(a.config.get('armBinding'),'NATIVE');eq(f.provider.learnState().status,'CANCELLED');eq(a.writes(),0)
a,f=make();open(a,'arm');group(a,'OFF / NATIVE');tap(a,20,97);a.setModelInfo({name='OTHER',filename='other.yml'});send(a,0);check(not a.inputs.active());check(not a.state().editing);eq(a.config.get('armBinding'),'NATIVE');eq(a.writes(),0)
a,f=make();local nativeApp=lastMain;open(a,'arm');group(a,'SWITCH POSITIONS');tap(a,180,232);check(a.inputs.pickerState().learning)
nativeApp.stop();check(not a.inputs.active());check(not a.state().editing);check(not a.state().appDirty);eq(f.provider.learnState().status,'CANCELLED');eq(a.config.get('armBinding'),'NATIVE');eq(a.writes(),0)
-- Native INAV navigation evidence remains positive-only and family-qualified.
a=adapter.make({settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=INAV\nvtxMode=2\n',values={FM='WRTH'}})
eq(a.inputs.state.roles.rth.value,true);eq(a.inputs.state.roles.wrth.value,true);a.setFlightMode('ACRO');send(a,0);eq(a.inputs.state.roles.rth.state,'UNAVAILABLE');eq(a.inputs.state.roles.wrth.state,'UNAVAILABLE')
a,f=make();eq(a.inputs.state.roles.arm.value,false);a.setSensor('FM',nil,false);send(a,0);eq(a.inputs.state.roles.arm.state,'UNAVAILABLE');eq(a.inputs.state.roles.arm.value,nil,'Lost current FM cannot preserve a false armed claim')
-- A radio arm indicator must not veto known current FC armed/failsafe truth.
a,f=make('armBinding=PRED:sa:HIGH\nvtxBackend=TBS native\n');eq(a.inputs.state.roles.arm.value,false)
a.setFlightMode('ACRO');send(a,0);send(a,0);eq(f.guards.disarmed,false,'Known armed FC cannot be overridden by an inactive radio arm switch')
a.setFlightMode('FS!');send(a,0);send(a,0);eq(f.guards.disarmed,false,'Known failsafe cannot be overridden by local arm indication')
a.setFlightMode('ACRO*');send(a,0);eq(f.guards.disarmed,true)
a.setSensor('FM',nil,false);send(a,0);send(a,0);eq(f.guards.current,true,'Current RF reception is independent of missing FM');eq(f.guards.disarmed,true,'Explicit current local indication can serve the separate native backend when FC state is unavailable')
f.values[1]=1024;send(a,0);send(a,0);eq(f.guards.disarmed,false,'An active local arm indication never permits a disarmed-only operation')
-- Physical mode override is a separate display value, never the FC truth.
a,f=make('acroBinding=PRED:sa:HIGH\n');local data=a.snapshot();eq(data.displayFlight,'R:--');eq(data.flight,'ACRO');eq(data.fcArmed,false);f.values[1]=1024;send(a,0);eq(a.snapshot().displayFlight,'R:ACRO');eq(a.snapshot().flight,'ACRO');eq(a.snapshot().fcArmed,false)
-- The operational Radio Inputs page makes current false/missing/zero visible.
local function inputValue(app,column,row)
 local right=column==1 and 228 or 464;local y=91+(row-1)*20
 for _,command in ipairs(app.commands())do if command.kind=='text'and command.x==right and command.y>=y and command.y<y+20 then return command.text,command end end
end
a,f=make('cutBinding=SW:MissingUP\nlimiterBinding=SRC:s1\n');a.arrange(1);check(a.visible('T0 / L50')or a.visible('T0 L50'),'PFD input strip shows both complete current throttle and limiter values');f.values[2]=1024;f.values[3]=1024;a.settle();check(a.visible('T100 L100'),'Maximum current throttle and limiter values remain complete in the compact strip');eq(a.inputs.state.roles.throttle.value,100);eq(a.inputs.state.roles.limiter.value,100);f.values[2]=0;f.values[3]=-1024;a.settle();tap(a,230,233);eq(a.state().page,13)
eq(inputValue(a,1,1),'FC OFF','Known native false is visibly inactive and reported');eq(inputValue(a,1,2),'--','Unavailable is not shown as false');eq(inputValue(a,2,4),'0%','Current zero throttle remains a number');eq(inputValue(a,2,5),'50%','Limiter displays its calibrated percentage')
check(a.visible('ARM INDICATOR')and a.visible('PHYSICAL THROTTLE'))
tap(a,120,232);eq(a.state().page,8);check(a.visible('INDICATORS / TIMERS'));send(a,E.EVT_VIRTUAL_EXIT);send(a,E.EVT_VIRTUAL_EXIT);eq(a.state().page,13)
tap(a,360,232);eq(a.state().page,8);check(a.visible('FC MODE INDICATORS'));send(a,E.EVT_VIRTUAL_EXIT);send(a,E.EVT_VIRTUAL_EXIT);eq(a.state().page,13);send(a,E.EVT_VIRTUAL_EXIT);eq(a.state().page,1)
a,f=make('acroBinding=PRED:sa:LOW\nangleBinding=PRED:sa:LOW\n');a.arrange(1);check(a.visible('R:ACRO'),'Footer consumes the radio override display mode');tap(a,230,233);eq(a.state().page,13);check(a.visible('MODE CONFLICT'));check(a.visible('FC ACRO')and a.visible('DISPLAY R:ACRO'),'FC truth and radio display override are labelled separately')
local conflict
for _,command in ipairs(a.commands())do if command.kind=='text'and command.text=='MODE CONFLICT'then conflict=command;break end end
check(conflict~=nil);eq(conflict.flags%1024,SMLSIZE,'Conflict warning uses primary readable17px font')
a,f=make('cutBinding=OFF\n');a.arrange(1);tap(a,230,233)
eq(inputValue(a,1,1),'FC OFF');eq(inputValue(a,1,2),'NONE','Unconfigured input differs textually from LIVE false')
a,f=make('armBinding=PRED:sa:HIGH\n');a.arrange(1);tap(a,230,233);eq(inputValue(a,1,1),'R OFF','Radio false is labelled separately from reported FC false')
f.values[1]=1024;a.settle();eq(inputValue(a,1,1),'R ON')
loadstring=realLoadstring
print('input integration: '..checks..' checks PASS')
