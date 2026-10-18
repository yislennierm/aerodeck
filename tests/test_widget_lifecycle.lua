-- Production widget + lifecycle contract; no native/hardware performance claim.
local hostio=io
local function read(path)local f=assert(hostio.open(path));local s=f:read('*a');f:close();return s end
local widgetSource=read(arg[1]or'sdcard/WIDGETS/AERODECK/main.lua')
local checks=0
local function check(value,message)assert(value,message);checks=checks+1 end
local function compile(source,environment)
 local chunk
 if setfenv then chunk=assert(loadstring(source));setfenv(chunk,environment)
 else chunk=assert(load(source,'widget-test','t',environment))end
 return chunk()
end
local function harness(factory)
 local h={loads=0,chunks=0,inits=0,backgrounds=0,runs=0,stops=0,exits=0,rgb=0,commands={},apps={},model='ONE',v=22.8,a=0,lq=100,pct=83}
 local e=setmetatable({SMLSIZE=0,MIDSIZE=1,TINSIZE=2,CUSTOM_COLOR=128,EVT_VIRTUAL_EXIT=99,LCD_W=480,LCD_H=272},{__index=_G})
 local function forbidden()error('Widget must not maintain a separate telemetry reader or settings parser')end
 e.io={open=forbidden};e.model={getInfo=forbidden,getSensor=forbidden};e.getFieldInfo=forbidden;e.getSourceIndex=forbidden;e.getSourceValue=forbidden;e.getValue=forbidden
 e.collectgarbage=function()error('No refresh-time session teardown/collection')end
 e.lcd={RGB=function()h.rgb=h.rgb+1;return h.rgb end,setColor=function(_,color)h.ink=color end,drawFilledRectangle=function()end,
  sizeText=function(s,size)return #tostring(s)*(size==1 and 14 or size==2 and 6 or 8),size==1 and 29 or size==2 and 13 or 17 end,
  drawText=function(x,y,s,flags)h.commands[#h.commands+1]={x=x,y=y,text=tostring(s),font=flags-128,color=h.ink}end,
  exitFullScreen=function()h.exits=h.exits+1 end}
 e.loadScript=function(path)
  if path=='/SCRIPTS/TOOLS/AERODECK/startup-screen.lua'then return nil end
  check(path=='/SCRIPTS/TOOLS/telem.lua','Widget loads the actual app path')
  h.loads=h.loads+1
  local loader
  if factory then loader=factory(h,e)else loader=function()
   local data={};local app={elapsed=0,history={},name=nil}
   function app.setRetained(value)app.retained=value end
   function app.init()assert(app.retained==true,'Widget must retain the native timer/session before app init');h.inits=h.inits+1 end
   function app.background()
    h.backgrounds=h.backgrounds+1
    if app.name~=h.model then app.name=h.model;app.elapsed=0;app.history={}end
    app.elapsed=app.elapsed+1;app.history[#app.history+1]=app.elapsed
    data.v=h.v;data.a=h.a;data.lq=h.lq;data.pct=h.pct;data.model=h.model;data.sessionError=h.sessionError;data.link=h.link;data.battery=h.battery;data.estimated=h.estimated;data.initializing=h.initializing
   end
   function app.snapshot()
    if h.snapshotFault=='throw'then error('snapshot failure')end
    if h.snapshotFault=='shape'then return 42 end
    if h.pendingSnapshot then return nil end
    return data
   end
   function app.run(event,touch)h.runs=h.runs+1;h.lastEvent=event;h.lastTouch=touch;return event==99 and 1 or 0 end
   function app.stop()h.stops=h.stops+1 end
   h.apps[#h.apps+1]=app;return app
  end end
  if type(loader)~='function'then return loader end
  return function(...)h.chunks=h.chunks+1;return loader(...)end
 end
 h.widget=compile(widgetSource,e);h.env=e
 function h.instance(zone)return h.widget.create(zone or{x=0,y=0,w=240,h=120},{})end
 function h.compact(w)h.commands={};h.widget.refresh(w,nil);return h.commands end
 function h.start(w,hidden)
  for i=1,4 do if hidden then h.widget.background(w)else h.compact(w)end end
  return h.commands
 end
 function h.has(s)for _,c in ipairs(h.commands)do if c.text==s then return true end end;return false end
 return h
end
local h=harness();local w=h.instance()
check(h.loads==0,'Create is lazy and reads no app/settings/sensors')
h.compact(w)
check(h.loads==1 and h.chunks==0 and h.inits==0 and h.backgrounds==0 and w.app==nil and h.has('LOADING APP'),'First callback only loads the app chunk and shows honest progress')
h.widget.update(w,{})
h.compact(w)
check(h.loads==1 and h.chunks==1 and h.inits==0 and h.backgrounds==0 and w.app==nil and h.has('STARTING SESSION'),'Second callback executes the app chunk once; healthy options update preserves pending bootstrap')
h.compact(w)
check(h.loads==1 and h.chunks==1 and h.inits==1 and h.backgrounds==0 and w.app~=nil and h.has('STARTING SESSION'),'Third callback initializes without running background or exposing a pre-service snapshot')
h.compact(w)
check(h.loads==1 and h.inits==1 and h.backgrounds==1,'Fourth callback samples the initialized shared app')
check(h.has('22.8 V')and h.has('0.0 A')and h.has('100% LQ'),'Compact reads the shared snapshot including a real zero current')
h.initializing='INPUT DISCOVERY';h.compact(w)
check(h.has('STARTING AERODECK')and h.has('INPUT DISCOVERY')and not h.has('22.8 V')and not h.has('100% LQ')and not h.has('LIVE'),'App-owned incremental startup shows its stage instead of prematurely claiming current values')
h.initializing=nil;h.compact(w)
check(h.has('22.8 V')and not h.has('STARTING AERODECK'),'Completed app-owned initialization resumes the shared snapshot')
local pending=harness();pending.pendingSnapshot=true;local pendingWidget=pending.instance();pending.start(pendingWidget)
check(pending.has('WAITING FOR DATA')and not pendingWidget.error and not pending.has('LIVE')and not pending.has('0.0 A'),'Successful nil first snapshot is pending data, never a latched error or live numeric claim')
for i=1,3 do pending.compact(pendingWidget)end
check(pending.loads==1 and pending.inits==1 and not pendingWidget.error,'Pending first data keeps its app and continues normal service without reload')
pending.pendingSnapshot=false;pending.compact(pendingWidget)
check(pending.has('22.8 V')and not pending.has('WAITING FOR DATA')and not pendingWidget.error,'First valid snapshot replaces the pending view')
for _,fault in ipairs({'throw','shape'})do
 pending.snapshotFault=fault;pending.compact(pendingWidget)
 check(pending.has('SESSION ERROR')and pendingWidget.snapshotFailed and not pending.has('22.8 V'),'Snapshot exception/invalid non-nil return remains explicit: '..fault)
 pending.snapshotFault=nil;pending.pendingSnapshot=true;pending.compact(pendingWidget)
 check(pending.has('SESSION ERROR')and pendingWidget.snapshotFailed,'Later nil cannot erase a genuine snapshot failure: '..fault)
 pending.pendingSnapshot=false;pending.compact(pendingWidget)
 check(pending.has('22.8 V')and not pendingWidget.error and not pendingWidget.snapshotFailed,'A later valid table clears only the recovered snapshot-level error: '..fault)
end
local app=w.app;local data=app.snapshot();local history=app.history
h.widget.refresh(w,0)
check(h.runs==1 and w.app==app,'Fullscreen uses the same initialized app')
h.compact(w)
check(h.loads==1 and h.inits==1 and w.app==app and app.snapshot()==data and app.history==history,'Fullscreen to compact keeps app, stable snapshot and history objects')
local elapsed=app.elapsed;local drawCount=#h.commands
for i=1,4 do h.widget.background(w)end
check(app.elapsed==elapsed+4 and app.history==history,'Hidden callbacks continue the same session')
check(#h.commands==drawCount,'Hidden callback performs no LCD rendering')
check(h.stops==0,'New background API does not call stop while compact/hidden')
h.widget.refresh(w,99)
check(h.exits==1 and w.app==app and h.stops==0,'Explicit fullscreen exit retains the app and uses additive background service')
h.widget.refresh(w,0);h.compact(w)
check(h.loads==1 and h.inits==1 and w.app==app,'Reopen after explicit exit does not restart the session')
h.widget.update(w,{})
check(w.app==app and h.loads==1,'Options update preserves an existing app')
h.model='TWO';h.v=16.4;h.widget.background(w);h.compact(w)
check(w.app==app and app.name=='TWO'and h.has('16.4 V'),'Model change is delegated to shared app, without widget recreation')
check(app.history~=history and app.elapsed==2 and h.inits==1,'App-owned model reset remains authoritative')
local w2=h.instance();h.start(w2)
check(w2.app~=w.app and h.loads==2,'Two widgets have independent app/session instances')
check(h.rgb==5,'Colors are cached across refreshes and widgets')
h.v=nil;h.a=nil;h.lq=nil;h.pct=nil;h.compact(w)
check(h.has('NO VALUES')and not h.has('22.8 V')and not h.has('16.4 V'),'Missing snapshot fields clear old values')
h.v=0;h.a=0;h.lq=0;h.pct=0;h.compact(w)
check(h.has('0.0 V')and h.has('0.0 A')and h.has('0% LQ')and h.has('0% LEFT'),'All four numeric zeros remain measured values')
h.link='LQ CRITICAL';h.battery='CELL LOW';h.estimated=true;h.compact(w)
local linkWarning,voltageWarning=false,false
for _,c in ipairs(h.commands)do
 if c.text=='0% LQ'then linkWarning=c.color==5 end
 if c.text=='0.0 V'then voltageWarning=c.color==5 end
end
check(linkWarning and voltageWarning and h.has('~0% LEFT'),'Compact consumes shared warning/estimate states instead of inventing another threshold policy')
h.link=nil;h.battery=nil;h.estimated=nil
for _,zone in ipairs({{x=7,y=9,w=40,h=28},{x=7,y=9,w=60,h=36},{x=7,y=9,w=120,h=60},{x=7,y=9,w=150,h=70},{x=7,y=9,w=190,h=95},{x=7,y=9,w=240,h=120},{x=7,y=9,w=480,h=272}})do
 local instance=h.instance(zone);h.v=999999.9;h.a=999999.9;h.lq=100;h.pct=100;h.start(instance)
 for _,c in ipairs(h.commands)do
  local width,height=h.env.lcd.sizeText(c.text,c.font)
  check(c.x>=zone.x and c.x+width<=zone.x+zone.w and c.y>=zone.y and c.y+height<=zone.y+zone.h,'Compact text fits zone '..zone.w..'x'..zone.h..': '..c.text)
 end
end
local old=harness(function(x)return function()
 local a={};function a.init()x.inits=x.inits+1 end
 function a.run(event)x.runs=x.runs+1;return event==99 and 1 or 0 end
 function a.stop()x.stops=x.stops+1 end
 return a
end end)
local ow=old.instance();old.start(ow)
check(old.has('UPDATE AERODECK')and old.loads==1,'Old compact API fails honestly without a parallel sensor reader')
old.widget.refresh(ow,0);old.widget.background(ow);old.widget.background(ow);old.compact(ow)
check(old.stops==1 and old.loads==1 and old.runs==1,'Old API pauses transport once at full to hidden transition and retains app')
old.widget.refresh(ow,99);old.compact(ow)
check(old.exits==1 and old.stops==2 and old.loads==1,'Old fullscreen exit retains app with one transition pause')
local missing=harness(function()return nil end);local mw=missing.instance();missing.compact(mw);missing.widget.background(mw);missing.compact(mw)
check(missing.loads==1 and missing.has('APP UNAVAILABLE'),'Missing module failure is cached instead of repeated SD reads')
missing.widget.update(mw,{});missing.compact(mw)
check(missing.loads==2,'Explicit widget update retries failed bootstrap')

-- Fullscreen entry/exit cannot accidentally advance two cold stages within
-- one native callback (its instruction allowance is shared by nested pcall).
local coldFull=harness();local fw=coldFull.instance()
coldFull.widget.refresh(fw,0)
check(coldFull.loads==0 and coldFull.runs==0,'Cold full-screen branding callback yields before app compilation')
coldFull.widget.refresh(fw,99)
check(coldFull.loads==1 and coldFull.chunks==0 and coldFull.inits==0 and coldFull.exits==1,'RTN during first fullscreen loading callback exits without executing another cold stage')
coldFull.widget.refresh(fw,0)
check(coldFull.chunks==1 and coldFull.inits==0 and coldFull.runs==0,'Cold fullscreen second callback only executes chunk')
coldFull.widget.refresh(fw,0)
check(coldFull.inits==1 and coldFull.runs==0 and coldFull.backgrounds==0,'Cold fullscreen initialization is isolated from app run/background')
coldFull.widget.refresh(fw,0)
check(coldFull.runs==1 and coldFull.loads==1 and coldFull.chunks==1 and coldFull.inits==1,'Fullscreen first live run follows the three independent cold callbacks')
-- App mode must show the real app without input focus. Fullscreen focus on
-- a smaller zone remains supported; blur/hidden/re-entry share one session.
local mode=harness();local aw=mode.instance({x=0,y=0,w=480,h=272})
mode.compact(aw)
check(mode.loads==0 and mode.runs==0,'App mode branding callback yields before app compilation')
mode.compact(aw)
check(mode.loads==1 and mode.chunks==0 and mode.runs==0,'App mode cold callback one only loads the widget-owned app')
mode.compact(aw)
check(mode.chunks==1 and mode.inits==0 and mode.runs==0,'App mode cold callback two only executes its chunk')
mode.compact(aw)
check(mode.inits==1 and mode.runs==0 and mode.backgrounds==0,'App mode init keeps its separate callback budget')
mode.compact(aw)
check(mode.runs==1 and mode.lastEvent==0 and mode.lastTouch==nil,'Unfocused full-display widget renders app with a neutral event')
check(not mode.has('FULL SCREEN: AERODECK')and not mode.has('22.8 V'),'App mode never substitutes the compact summary after bootstrap')
local modeApp=aw.app;local touch={x=300,y=150}
mode.widget.refresh(aw,0,touch)
check(mode.runs==2 and mode.lastTouch==touch and aw.app==modeApp,'Focused App mode forwards actual touch to the existing app')
mode.widget.refresh(aw,nil,touch)
check(mode.runs==3 and mode.lastEvent==0 and mode.lastTouch==nil and aw.app==modeApp,'Unfocused App mode discards touch not owned by the app')
local beforeHiddenRuns,beforeHiddenDraws=mode.runs,#mode.commands
mode.widget.background(aw)
local modeHistory=modeApp.history
check(mode.runs==beforeHiddenRuns and #mode.commands==beforeHiddenDraws and mode.backgrounds==1,'Hidden App mode services without rendering')
mode.compact(aw)
check(mode.runs==4 and aw.app==modeApp and modeApp.history==modeHistory and mode.loads==1 and mode.inits==1,'Returning without focus keeps full rendering, retained app and history')
mode.widget.refresh(aw,99)
check(mode.exits==1 and aw.app==modeApp and mode.stops==0,'Focused app exit releases focus without destroying its session')
mode.compact(aw)
check(mode.runs==6 and aw.app==modeApp and mode.lastEvent==0,'Released App mode remains a full dashboard')
mode.env.LCD_W=800;mode.env.LCD_H=480
local large=mode.instance({x=0,y=0,w=800,h=480});local oldRuns=mode.runs;mode.start(large)
check(mode.runs==oldRuns+1 and large.app~=modeApp,'App mode uses native display dimensions on larger radios')
local small=mode.instance({x=0,y=0,w=480,h=272});oldRuns=mode.runs;mode.start(small)
check(mode.runs==oldRuns and mode.has('22.8 V'),'A smaller ordinary widget keeps its compact presentation')
local offset=mode.instance({x=7,y=9,w=800,h=480});mode.start(offset)
check(mode.runs==oldRuns,'An offset widget cannot claim the full-display origin')
local chunkFailure=harness(function()return function()error('chunk failure')end end);local cw=chunkFailure.instance();chunkFailure.start(cw)
check(chunkFailure.loads==1 and chunkFailure.chunks==1 and chunkFailure.inits==0 and chunkFailure.has('APP LOAD FAILED'),'Chunk failure is explicit and cached across later callbacks')

-- Cold hidden bootstrap must not render/cache artwork; session failures are explicit.
local hidden=harness();local hw=hidden.instance();hidden.start(hw,true)
check(hidden.loads==1 and hidden.inits==1 and hidden.backgrounds==1 and #hidden.commands==0 and hidden.rgb==0,'Cold hidden bootstrap samples without LCD/color work')
h.sessionError='session module unavailable';h.compact(w)
check(h.has('SESSION UNAVAILABLE')and not h.has('0.0 A'),'Missing session module does not look like a healthy shared session')
h.sessionError=nil;h.compact(w)
check(not h.has('SESSION UNAVAILABLE'),'An app-owned recovered session clears its unavailable state')
local broken=harness(function()return function()return{background=function()error('broken')end,snapshot=function()return{v=22.8}end}end end)
local bw=broken.instance();broken.start(bw)
check(broken.has('SESSION ERROR')and not broken.has('22.8 V'),'Failed background cannot expose a stale successful-looking snapshot')
local initFailure=harness(function()return function()return{init=function()error('failed init')end}end end)
local iw=initFailure.instance();initFailure.start(iw);initFailure.widget.background(iw);initFailure.compact(iw)
check(initFailure.loads==1 and initFailure.has('APP INIT FAILED'),'Failed init is cached and explained without callback reload loops')

-- Error recovery uses the real native timer-owner module. A failed session
-- gets one controlled close attempt, then only explicit Update can retry.
local timerFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/timer-owner.lua'))()
local function recovering()
 return harness(function(x)
  x.closes=x.closes or 0;x.nativeWrites=x.nativeWrites or 0
  x.native=x.native or{mode=5,value=67,start=90,countdownBeep=2,minuteBeep=true,persistent=2,name='Pilot'}
  return function()
   local data={};local a={}
   local owner=timerFactory.new({getModelId=function()return'model1.yml'end,
    getTimer=function()local t={};for k,v in pairs(x.native)do t[k]=v end;return t end,
    setTimer=function(_,value)x.nativeWrites=x.nativeWrites+1;for k,v in pairs(value)do x.native[k]=v end end})
   a.owner=owner
   function a.setRetained(value)a.retained=value end
   function a.init()x.inits=x.inits+1;assert(a.retained);assert(owner.configure({host='AERODECK',timerIndex=1}))end
   function a.background()
    x.backgrounds=x.backgrounds+1
    if x.failBackground then x.native.value=41;error('transient native read failure')end
    owner.update(false);data.v=22.8
   end
   function a.close()
    x.closes=x.closes+1
    if x.closeFault=='throw'then error('close failed')elseif x.closeFault=='false'then return false,'restore rejected'end
    if owner.snapshot().owned then return owner.release()end;return true
   end
   function a.snapshot()return data end
   function a.run()x.runs=x.runs+1;return 0 end
   x.apps[#x.apps+1]=a;return a
  end
 end)
end
local recovered=recovering();recovered.failBackground=true;local recoveredWidget=recovered.instance();recovered.start(recoveredWidget)
local closedApp=recoveredWidget.app
check(recovered.closes==1 and recoveredWidget.backgroundFailed and recoveredWidget.closed and not closedApp.owner.snapshot().owned,'caught background exception closes real app once and releases native owner')
check(recovered.native.name=='Pilot'and recovered.native.mode==5 and recovered.native.start==90 and recovered.native.value==41,'controlled failure restores original timer name/config while retaining current elapsed')
local closeWrites=recovered.nativeWrites
for i=1,10 do recovered.widget.background(recoveredWidget);recovered.compact(recoveredWidget)end
check(recovered.closes==1 and recovered.loads==1 and recovered.nativeWrites==closeWrites,'warm failed callbacks never retry close/restart/native writes')
recovered.widget.refresh(recoveredWidget,0);check(recovered.runs==0,'failed session cannot resume fullscreen without explicit recovery')
recovered.widget.refresh(recoveredWidget,99);check(recovered.exits==1,'failed fullscreen remains escapable')
recovered.failBackground=false;recovered.widget.update(recoveredWidget,{})
check(recoveredWidget.app==nil and not recoveredWidget.backgroundFailed,'explicit Update discards only a confirmed closed failed app')
recovered.start(recoveredWidget)
check(recovered.loads==2 and recoveredWidget.app~=closedApp and recovered.has('22.8 V')and not recoveredWidget.error,'explicit Update recovers transient failure through a fresh app without stale error')
for _,fault in ipairs({'false','throw'})do
 local blocked=recovering();blocked.failBackground=true;blocked.closeFault=fault;local bw=blocked.instance();blocked.start(bw)
 local held=bw.app;local marker=blocked.native.name;local writes=blocked.nativeWrites
 check(blocked.closes==1 and bw.closeFailed and held.owner.snapshot().owned and blocked.has('CLOSE FAILED / UPDATE TO RETRY'),'failed controlled close stays visible and retains real owner metadata: '..fault)
 for i=1,10 do blocked.widget.background(bw)end
 check(blocked.closes==1 and blocked.nativeWrites==writes and bw.app==held,'failure never retries close or discards owner during warm callbacks: '..fault)
 blocked.widget.update(bw,{})
 check(blocked.closes==2 and blocked.loads==1 and bw.app==held and blocked.native.name==marker and blocked.native.value==41,'explicit failed retry cannot bootstrap/reset another native owner: '..fault)
 blocked.closeFault=nil;blocked.failBackground=false;blocked.native.value=73;blocked.widget.update(bw,{})
 check(blocked.closes==3 and bw.app==nil and not held.owner.snapshot().owned and blocked.native.name=='Pilot'and blocked.native.mode==5 and blocked.native.value==73,'successful explicit retry restores old owner before discarding it: '..fault)
 blocked.start(bw);check(blocked.loads==2 and bw.app~=held and blocked.has('22.8 V'),'new app claim occurs only after verified old restoration: '..fault)
end
local legacyFailure=harness(function(x)return function()return{background=function()error('legacy failure')end,stop=function()x.stops=x.stops+1 end}end end)
local lw=legacyFailure.instance();legacyFailure.start(lw)
check(legacyFailure.stops==1 and lw.closeFailed and legacyFailure.has('CLOSE UNAVAILABLE / UPDATE APP'),'legacy stop is used once but never presented as verified timer restoration')
legacyFailure.widget.update(lw,{});legacyFailure.widget.background(lw)
check(legacyFailure.loads==1 and legacyFailure.stops==1 and lw.app~=nil,'missing close API cannot silently discard possible restoration metadata or create a new owner')

-- A thin shared-app adapter runs the real production telemetry resolver. This
-- preserves qualified identity/manual/None/stale coverage, not full main lifecycle.
local main=read('sdcard/SCRIPTS/TOOLS/telem.lua')
local prefix=main:sub(1,assert(main:find('local batteryConfig=',1,true))-1)
local ca=assert(main:find('local configuration=(function()',1,true));local cb=assert(main:find('function fcLink.update',ca,true))
local ta=assert(main:find('local telemetry=(function()',1,true));local tb=assert(main:find('fcLink.guard=',ta,true))
local readerSource=prefix..'\nlocal fcLink={state={}};local batteryConfig={check=function()return nil,6 end,isEditing=function()return false end,hasChanges=function()return false end}\n'..main:sub(ca,cb-1)..main:sub(ta,tb-1)..'\nreturn {t=telemetry,c=configuration}'
local function actualReader(settings,current,currentFlag)
 return harness(function(h,e)
  local qualified,inputLookups=0,0
  e._G=e
  local appLoader=e.loadScript
  local protocols=compile(read('sdcard/SCRIPTS/TOOLS/AERODECK/protocols.lua'),e)
  e.loadScript=function(path)if path=='/SCRIPTS/TOOLS/AERODECK/protocols.lua'then return function()return protocols end end;if string.find(path,'/SCRIPTS/TOOLS/AERODECK/',1,true)then return nil end;return appLoader(path)end
  e.UNIT_VOLTS=10;e.UNIT_AMPS=11;e.UNIT_MAH=12;e.UNIT_PERCENT=13;e.CHAR_TELEMETRY='T:';e.getTime=function()return 0 end
  e.getValue=function(name)assert(name=='tx-voltage','Only built-in transmitter voltage may use getValue');return 8.1 end
  e.EVT_VIRTUAL_ENTER=101;e.EVT_VIRTUAL_NEXT=102;e.EVT_VIRTUAL_PREV=103;e.EVT_TOUCH_TAP=104
  local values={[1]={name='Curr',unit=11,value=999,current=true},[2]={name='Curr',unit=11,value=current,current=currentFlag},[3]={name='RxBt',unit=10,value=25.2,current=true},[4]={name='RQly',unit=13,value=99,current=true}}
  e.model={getInfo=function()return{name='WIDGET TEST'}end,getSensor=function(i)return values[i+2]end}
  e.getSourceIndex=function(name)qualified=qualified+1;return({['T:Curr']=2,['T:RxBt']=3,['T:RQly']=4})[name]or 0 end
  e.getFieldInfo=function(id)if type(id)~='number'then inputLookups=inputLookups+1;return{id=1}end;return values[id]end
  e.getSourceValue=function(id)local v=values[id];return v and v.value,v and v.current,v and v.current end
  e.io={open=function()return{}end,read=function()return settings end,close=function()end}
  return function()
   local reader=compile(readerSource,e);local shared={}
   return{init=function()reader.c.init();reader.t.init()end,background=function()shared=reader.t.sample();h.qualified=qualified;h.inputLookups=inputLookups end,snapshot=function()return shared end,run=function()return 0 end}
  end
 end)
end
local real=actualReader('ADCFG1\n',0,true);local rw=real.instance();real.start(rw)
check(real.has('0.0 A')and not real.has('999.0 A')and real.inputLookups==0 and real.qualified>0,'Shared production reader resolves qualified Curr, not same-named input alias')
real=actualReader('ADCFG1\nvoltage=None\n',12,true);rw=real.instance();real.start(rw)
check(real.has('--')and real.has('12.0 A'),'Shared production mapping honors voltage None without disabling current')
real=actualReader('ADCFG1\n',123,false);rw=real.instance();real.start(rw)
check(real.has('--')and not real.has('123.0 A'),'Shared production reader cannot expose stale current in compact mode')
print('PASS: '..checks..' widget lifecycle, shared-reader identity/currentness, zero/missing, compatibility and compact bounds checks')
