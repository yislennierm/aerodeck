-- Actual dispatcher, real MSP/native clients and the independent fake FC.
local files={['link']=dofile('sdcard/SCRIPTS/TOOLS/AERODECK/link.lua'),['msp-adapters']=dofile('sdcard/SCRIPTS/TOOLS/AERODECK/msp-adapters.lua'),['crsf-msp']=dofile('sdcard/SCRIPTS/TOOLS/AERODECK/crsf-msp.lua'),['vtx-native']=dofile('sdcard/SCRIPTS/TOOLS/AERODECK/vtx-native.lua'),['vtx-cache']=dofile('sdcard/SCRIPTS/TOOLS/AERODECK/vtx-cache.lua')}
local fixture=dofile('development/msp_fixture.lua')
local checks=0;local function check(v,s)assert(v,s);checks=checks+1 end
local h=fixture.new({external=true});local frames,popCount,pushCount={},0,0
local link=files.link.new({load=function(path)local name=path:match('/([^/]+)%.lua$');return files[name]and function()return files[name]end end,
 crsfPush=function(kind,data)pushCount=pushCount+1;if kind==0x32 then return true end;return h.transport.push(kind,data)end,
 crsfPop=function()popCount=popCount+1;if #frames>0 then local f=table.remove(frames,1);return f[1],f[2]end;return h.transport.pop()end})
local settings={vtxMode=2,video=true,vtxBackend='TBS native',vtxHardware=1,gps=false,statusInterval=3,vtxPolling=5}
link:configure({family='CRSF',fcType='BF'},settings)
local function tick(t,current,disarmed)
 popCount=0;pushCount=0;link:tick(t,true,current~=false,disarmed~=false,true);h:service(t)
 check(popCount<=4,'one callback may pop at most four frames')
 check(pushCount<=1,'one callback may push at most one CRSF frame')
end
for t=0,1000,10 do
 if t%100==0 then frames[#frames+1]={0x10,{0xEC,20,22,168,0}}end
 tick(t)
end
check(link.state.ready and link.state.uid==nil,'MSP status completes beside passive native video; optional identity remains opt-in')
check(link:videoState().reported.frequency==5800 and link:videoState().reported.power==3,'native reports reach the same dispatcher without stealing MSP replies')
local native=link:videoClient();local ok,why=native:applyVtx({frequency=5865,power=3,pit=false});check(ok,why)
for t=1010,1080,10 do tick(t)end
frames[#frames+1]={0x10,{0xEC,20,22,233,0}};tick(1090)
check(link:videoState().operation.state=='SUCCEEDED','native success requires a later matching source report')
-- Native report collection continues with MSP paused/armed, but no setting writes.
frames[#frames+1]={0x10,{0xEC,20,22,168,0}};tick(1100,true,false)
check(not link.state.active and link:videoState().reported.frequency==5800,'armed status pauses MSP but retains passive native video')
ok,why=native:applyVtx({frequency=5865});check(not ok and why=='ARMED / UNKNOWN','native writes cannot bypass the shared arm guard')
tick(1110,false,false);check(link:videoState().reported==nil,'loss of current telemetry clears native reported state')
link:stop();check(not link.state.active and link:videoState().reported==nil,'explicit stop cancels clients and clears queued status')
-- An invalid/missing transport produces an explicit status, not a fake connection.
local missing=files.link.new({});missing:configure({family='FRSKY',fcType='INAV'},{});check(not missing.client and missing.state.status=='TRANSPORT / MODULE UNAVAILABLE','missing S.Port is explicit')


-- Actual inert-cache module with native EdgeTX file handles and FRESULT values.
local function memory()
 local store,events,handles={},{},{}
 local faults={};local stats={reads=0,writes=0,maxRead=0,maxWrite=0,closes=0}
 local fs={}
 function fs.open(path,mode)
  events[#events+1]={'open',path,mode}
  if faults.directoryMissing then return nil end
  if faults.openThrow==path then error('open failed')end
  if faults.openFail==path then return nil end
  if mode=='r' and store[path]==nil then return nil end
  if mode=='w' then store[path]=''end
  local f={path=path,mode=mode};handles[f]=true;return f
 end
 function fs.read(f,n)
  check(handles[f] and f.mode=='r','io.read receives the explicit native file handle')
  stats.reads=stats.reads+1;stats.maxRead=math.max(stats.maxRead,n)
  if faults.readThrow==f.path then error('read failed')end
  if faults.readWrongType==f.path then return {}end
  return string.sub(store[f.path]or'',1,n)
 end
 function fs.write(f,raw)
  check(handles[f] and f.mode=='w','io.write receives the explicit native file handle')
  stats.writes=stats.writes+1;stats.maxWrite=math.max(stats.maxWrite,#raw)
  if faults.writeThrow==f.path then error('write failed')end
  if faults.writeFalse==f.path then return false end
  store[f.path]=faults.truncate==f.path and string.sub(raw,1,math.floor(#raw/2)) or raw
  return nil -- Native EdgeTX write has no required boolean success result.
 end
 function fs.close(f)
  check(handles[f],'all native close calls receive an open handle')
  handles[f]=nil;stats.closes=stats.closes+1
  if faults.closeThrow==f.path then error('close failed')end
  if faults.closeFalse==f.path then return false end
 end
 local function remove(path)
  events[#events+1]={'remove',path}
  if faults.removeFail==path then return 7 end
  if store[path]==nil then return 4 end
  store[path]=nil;return 0 -- FRESULT0 is success, not a boolean.
 end
 local function rename(from,to)
  events[#events+1]={'rename',from,to}
  if faults.renameFailFrom==from or faults.renameFailTo==to then return 7 end
  if store[from]==nil then return 4 end
  if store[to]~=nil then return 8 end
  store[to]=store[from];store[from]=nil
  if faults.corruptPromote==to then store[to]='corrupted after rename'end
  return 0
 end
 local cache=files['vtx-cache'].new({io=fs,root='/CACHE',remove=remove,rename=rename})
 return {store=store,events=events,handles=handles,faults=faults,stats=stats,fs=fs,remove=remove,rename=rename,cache=cache}
end

local cold=fixture.ready();local coldState=cold.c:snapshot();local UID=coldState.uid
local function seeded()
 local m=memory();check(m.cache:save(UID,coldState.vtx),'preload valid real cache into RAM only');return m
end
local function cached(m,extra)
 local h=fixture.new({external=true});local cacheCalls={};local l=files.link.new({
  load=function(path)local name=string.match(path,'/([^/]+)%.lua$')
   if name=='vtx-cache'then return function()return{new=function(options)
    local actual=files['vtx-cache'].new(options)
    for _,method in ipairs({'load','save'})do local original=actual[method];actual[method]=function(self,...)
     cacheCalls[#cacheCalls+1]={kind=string.upper(method),at=h.now};return original(self,...)
    end end
    return actual
   end}end end
   return files[name]and function()return files[name]end end,
  crsfPush=h.transport.push,crsfPop=h.transport.pop,cacheIO=m.fs,cacheRoot='/CACHE',cacheRemove=m.remove,cacheRename=m.rename})
 local s={vtxMode=2,video=true,vtxBackend='FC MSP',vtxCache=1,statusInterval=3,vtxPolling=5}
 for k,v in pairs(extra or{})do s[k]=v end
 l:configure({family='CRSF',fcType='BF'},s)
 local import=l.client.useCachedTables
 l.client.useCachedTables=function(self,record)cacheCalls[#cacheCalls+1]={kind='IMPORT',at=h.now};return import(self,record)end
 local x={h=h,l=l,m=m,now=0,settings=s,cacheCalls=cacheCalls}
 function x:tick(t,current,disarmed)
  self.now=t;h.now=t;local n=#h.sent;local pops=h.pops;local calls=#cacheCalls
  l:tick(t,true,current~=false,disarmed~=false,true);h:service(t)
  check(#h.sent-n<=1 and h.pops-pops<=4,'cached dispatcher retains shared RF callback budgets')
  if #cacheCalls>calls then
   check(#cacheCalls==calls+1,'one callback performs at most one cache load/import/save')
   check(#h.sent==n and h.pops==pops,'cache work has an exclusive callback with zero transport pushes/pops')
  end
 end
 function x:pump(predicate,limit)
  local deadline=self.now+(limit or 6000)
  repeat self:tick(self.now+10)until(predicate(l.state)and not l.cacheJob)or self.now>=deadline
  check(predicate(l.state)and not l.cacheJob,'cached link scenario completed before deadline: '..tostring(l.cacheStatus))
 end
 return x
end
local m=seeded();local baselineWrites=m.stats.writes;local x=cached(m)
x:pump(function(s)return s.vtx.tablesReady end)
check(x.l:videoState().tableSource=='SD CACHE'and x.l:videoState().tablesFresh==false,'dispatcher imports validated cache with honest provenance')
check(x.h:count(137)==0 and x.h:count(138)==0,'warm dispatcher eliminates all initial indexed RF table reads')
local reads=m.stats.reads
for i=1,100 do x:tick(x.now+10)end
check(m.stats.writes==baselineWrites and m.stats.reads==reads,'cached redraws neither rewrite stale data nor reread SD each frame')
check(next(m.handles)==nil,'warm cache leaves no native file handles open')
-- Writes remain real selected-entry transactions through the exact dispatcher.
x.h.bands[1].frequencies[1]=5700
check(x.l:videoClient():applyVtx({band=1,channel=1,power=1,pit=false}),'cached dispatcher queues a real apply')
x:pump(function(s)return s.vtx.operation.state=='FAILED'end)
check(x.h:count(137)==1 and x.h:count(89)==0 and x.h:count(250)==0,'fresh selected mismatch refuses before any write/save through dispatcher')
check(x.l:videoState().operation.error=='CACHED CHANNEL CHANGED','selected failure reason reaches UI state')
-- Valid cached transaction does not promote the entire table to fresh or persist it.
m=seeded();baselineWrites=m.stats.writes;x=cached(m);x:pump(function(s)return s.vtx.tablesReady end)
check(x.l:videoClient():applyVtx({band=2,channel=3,power=1,pit=false}),'cached dispatcher valid apply queued')
x:pump(function(s)return s.vtx.operation.state=='APPLIED'end)
check(x.h:count(89)==1 and x.h:count(250)==1 and x.l:videoState().reported.frequency==5900,'wire write/save/readback completes through dispatcher')
check(x.h:count(137)==1 and x.h:count(138)==1 and m.stats.writes==baselineWrites and not x.l:videoState().tablesFresh,'only selected reads; a successful cached write does not recertify SD table')
-- Explicit refresh bypasses a cache even if native deletion fails. Otherwise
-- a failed delete could silently turn an RF refresh into another SD import.
m=seeded();x=cached(m);x:pump(function(s)return s.vtx.tablesReady end)
m.faults.removeFail='/CACHE/vtx-'..UID..'.cache.bak'
check(x.l:refreshVideo(),'refresh still schedules real RF discovery when delete fails')
x:pump(function(s)return s.vtx.tablesReady and s.vtx.tablesFresh end)
check(x.h:count(137)==2 and x.h:count(138)==2 and x.l:videoState().tableSource=='FC LIVE','explicit refresh cannot reimport undeleted old cache')
check(next(m.handles)==nil,'refresh leaves no native handles')
-- Corrupt data, native read errors and failed atomic writes safely fall back.
for _,fault in ipairs({'corrupt','read','write','rename'})do
 m=memory()
 if fault=='corrupt'then m.store['/CACHE/vtx-'..UID..'.cache']='ADVT1\nCORRUPTED'
 elseif fault=='read'then m=seeded();m.faults.readThrow='/CACHE/vtx-'..UID..'.cache'
 elseif fault=='write'then m.faults.writeFalse='/CACHE/vtx-'..UID..'.cache.tmp'
 else m.faults.renameFailTo='/CACHE/vtx-'..UID..'.cache'end
 x=cached(m);x:pump(function(s)return s.vtx.tablesReady end)
 check(x.h:count(137)==2 and x.h:count(138)==2 and x.l:videoState().tablesFresh,'native cache fault falls back to actual full RF discovery: '..fault)
 check(x.h:count(89)==0 and x.h:count(250)==0,'cache storage failures cannot initiate FC writes: '..fault)
 local before=m.stats.reads;for i=1,20 do x:tick(x.now+10)end
 check(m.stats.reads==before and next(m.handles)==nil,'failure does not create per-frame SD retries or leak handles: '..fault)
 if fault=='write'then check(x.l.cacheStatus=='WRITE ERROR','native write failure remains visible')end
 if fault=='rename'then check(x.l.cacheStatus=='RENAME FAILED','native promotion failure remains visible')end
end
-- Metadata must be freshly associated with the UID before the first SD read.
m=seeded();x=cached(m);x.h.dropped[88]=true
x:pump(function(s)return s.uidAt~=nil and x.now-s.uidAt>810 end,3000)
local before=m.stats.reads;x.h.dropped[88]=nil
x:pump(function(s)return s.vtx.reportedAt~=nil end)
check(m.stats.reads==before and x.l.cacheStatus=='WAITING FOR FRESH IDENTITY','old UID plus new metadata cannot load a cache')
local oldUidAt=x.l.state.uidAt
x:pump(function(s)return s.uidAt>oldUidAt end)
check(x.h:count(160)==2,'expired UID gets one bounded actual identity refresh')
x:pump(function(s)return s.vtx.tablesReady end)
check(x.l:videoState().tableSource=='SD CACHE'or x.l:videoState().tablesFresh,'refreshed UID permits validated import or an already completed actual live discovery')
-- Explicitly leaving/returning the page must not reread a validated same-session
-- cache, whereas link loss destroys the binding and requires fresh metadata.
m=seeded();x=cached(m);x:pump(function(s)return s.vtx.tablesReady end);reads=m.stats.reads
x.settings.video=false;x.l:configure({family='CRSF',fcType='BF'},x.settings);x:tick(x.now+10)
x.settings.video=true;x.l:configure({family='CRSF',fcType='BF'},x.settings);x:tick(x.now+10)
check(m.stats.reads==reads,'page-only configuration changes do not reload same-session SD')
x:tick(x.now+10,false,false);check(not x.l.state.active,'current-link loss cancels cache session')
x:pump(function(s)return s.vtx.tablesReady end)
check((x.l:videoState().tableSource=='RAM CACHE'or x.l:videoState().tableSource=='SD CACHE')and not x.l:videoState().tablesFresh and m.stats.reads>reads,'new session validates fresh metadata before RAM/SD cached readiness, never claims live')
-- Maximum inert8x8x8 tables must be loaded/imported/saved in dedicated
-- callbacks, not combined with a transport tick or another storage phase.
local function maximum(hardware)
 local t={uid=UID,signature=hardware..':8:8:8',bands={},powers={}}
 for i=1,8 do
  local frequencies={};for j=1,8 do frequencies[j]=5700+i*10+j end
  t.bands[i]={index=i,name=string.rep('B',63)..i,letter='R',factory=true,frequencies=frequencies}
  t.powers[i]={index=i,value=i*10,label=string.rep('P',63)..i}
 end
 return t
end
local function liveMaximum(device)
 device.bands={};device.powers={}
 for i=1,8 do
  local frequencies={};for j=1,8 do frequencies[j]=5700+i*10+j end
  device.bands[i]={name='BAND000'..i,letter='R',factory=1,frequencies=frequencies}
  device.powers[i]={value=i*25,label='P0'..i}
 end
end
for _,hardware in ipairs({3,4})do
 local mm=memory();check(mm.cache:save(UID,maximum(hardware)),'max cache fixture seeds actual inert module')
 check(#mm.store['/CACHE/vtx-'..UID..'.cache']==2562,'max inert fixture uses all2562bytes')
 local xx=cached(mm);liveMaximum(xx.h)
 xx:pump(function(st)return st.vtx.tablesReady and(hardware==3 or xx.l.cacheStatus=='LIVE TABLES SAVED')end,12000)
 if hardware==3 then
  check(xx.l:videoState().tableSource=='SD CACHE'and xx.h:count(137)==0 and xx.h:count(138)==0,'max matching cache imports before RF enumeration')
  check(#xx.cacheCalls==2 and xx.cacheCalls[1].kind=='LOAD'and xx.cacheCalls[2].kind=='IMPORT'and xx.cacheCalls[1].at<xx.cacheCalls[2].at,'maximum LOAD and strict IMPORT occupy different callbacks')
 else
  check(xx.l:videoState().tablesFresh and xx.l.cacheStatus=='LIVE TABLES SAVED'and xx.h:count(137)==8 and xx.h:count(138)==8,'max mismatch falls back to real8x8x8 discovery and persists fresh tables')
  local last=xx.cacheCalls[#xx.cacheCalls]
  check(#xx.cacheCalls<=3 and xx.cacheCalls[1].kind=='LOAD'and last.kind=='SAVE'and xx.cacheCalls[1].at<last.at,'mismatched LOAD and verified fresh SAVE occupy different callbacks; one aged-identity renewal stays bounded')
  check(mm.cache:load(UID,{hardware=3,bandCount=8,channelCount=8,powerCount=8}).bands[1].name=='BAND0001','mismatch save persists actual newly reported table names')
 end
 check(next(mm.handles)==nil,'maximum cache jobs leave no native handle open')
end
local function waitJob(xx,kind)
 for i=1,300 do xx:tick(xx.now+10);if xx.l.cacheJob==kind then return end end
 error('cache phase not scheduled: '..kind)
end
for _,kind in ipairs({'LOAD','IMPORT','SAVE'})do
 for _,change in ipairs({'ARMED','LOST','LEAVE','STOP','UID','METADATA','AGE','RECONFIGURE'})do
  local mm=kind=='SAVE'and memory()or seeded();local xx=cached(mm);waitJob(xx,kind)
  local calls,beforeReads,beforeWrites=#xx.cacheCalls,mm.stats.reads,mm.stats.writes
  if change=='ARMED'then xx:tick(xx.now+10,true,false)
  elseif change=='LOST'then xx:tick(xx.now+10,false,false)
  elseif change=='LEAVE'then xx.settings.video=false;xx.l:configure({family='CRSF',fcType='BF'},xx.settings);xx:tick(xx.now+10)
  elseif change=='STOP'then xx.l:stop();xx:tick(xx.now+10,false,false)
  elseif change=='UID'then xx.l.state.uid=string.rep('A',24);xx:tick(xx.now+10)
  elseif change=='METADATA'then xx.l.state.vtx.reported.hardware=4;xx:tick(xx.now+10)
  elseif change=='AGE'then xx:tick(xx.now+801)
  else xx.l:configure({family='CRSF',fcType='BF'},xx.settings);xx:tick(xx.now+10)end
  check(#xx.cacheCalls==calls and mm.stats.reads==beforeReads and mm.stats.writes==beforeWrites,'queued '..kind..' cannot perform storage/import after '..change)
  check(next(mm.handles)==nil,'cancelled '..kind..' leaves no handles after '..change)
 end
end
-- Info polling is remembered between configure calls. This real INAV backend
-- needs repeated requestInfo calls to refresh151; configure runs only on pages.
local hi=fixture.new({external=true});local originalBody=hi.body
function hi:body(cmd,index)
 if cmd==2 then return {73,78,65,86}elseif cmd==1 then return {0,2,5}elseif cmd==3 then return {9,1,0}
 elseif cmd==8192 then local t={};for i=1,22 do t[i]=0 end;return t
 elseif cmd==151 then return {1,1,1,1,1,1,1,1,1}end
 return originalBody(self,cmd,index)
end
local li=files.link.new({load=function(path)local n=string.match(path,'/([^/]+)%.lua$');return files[n]and function()return files[n]end end,crsfPush=hi.transport.push,crsfPop=hi.transport.pop})
local si={info=true,statusInterval=3,vtxMode=0}
li:configure({family='CRSF',fcType='INAV'},si)
for t=0,1800,10 do hi.now=t;li:tick(t,true,true,true,false);hi:service(t)end
check(hi:count(151)>=3,'remembered FC details flag refreshes actual INAV151 health without reconfigure')
local last
for _,q in ipairs(hi.sent)do if q.cmd==151 then check(not last or q.at-last>=300,'health reads remain at least300 ticks apart');last=q.at end end
si.info=false;li:configure({family='CRSF',fcType='INAV'},si)
for t=1810,2100,10 do hi.now=t;li:tick(t,true,true,true,false);hi:service(t)end
local n=hi:count(151)
for t=2110,3000,10 do hi.now=t;li:tick(t,true,true,true,false);hi:service(t)end
check(hi:count(151)==n,'leaving FC details stops health refresh scheduling')
-- Full real Video UI -> shared dispatcher -> client -> selected RF read. The
-- only injected dependencies are RAM filesystem and protocol-valid fake FC.
local realIO,realLoadfile=io,loadfile
-- The existing UI harness captures its load function at initialization. Inject
-- only the cache's filesystem through the real link factory, before that capture.
loadfile=function(path,...)
 if path=='sdcard/SCRIPTS/TOOLS/AERODECK/link.lua'then return function()return {new=function(opts)
  local originalLoad=opts.load;local memory=m
  opts.load=function(file)
   if string.find(file,'/vtx-cache.lua',1,true)then return function()return {new=function(options)
    options.io=memory.fs;options.root='/CACHE';options.remove=memory.remove;options.rename=memory.rename
    return files['vtx-cache'].new(options)
   end}end end
   return originalLoad(file)
  end
  return files.link.new(opts)
 end}end end
 return realLoadfile(path,...)
end
local ui=assert(realLoadfile('development/test_ui_navigation.lua'))('adapter')
loadfile=realLoadfile
for _,changed in ipairs({false,true})do
 m=seeded();local device=fixture.new({external=true,clock=function()return getTime()end})
 local app=ui.make({settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nvtxMode=2\nvtxCache=1\n',device=device})
 app.arrange(11)
 for i=1,200 do app.send(0);if app.fcState().vtx.tablesReady then break end end
 check(app.fcState().vtx.tableSource=='SD CACHE'and device:count(137)==0 and device:count(138)==0,'actual Video UI uses warm cache without initial RF enumeration')
 check(app.visible('CACHED TABLES / VERIFY ON APPLY'),'actual Video states cache provenance and selected verification')
 check(app.send(ui.events.EVT_TOUCH_TAP,{x=390,y=199})==0,'actual UI switches to channels')
 check(app.send(ui.events.EVT_TOUCH_TAP,{x=40,y=126})==0,'actual UI selects first cached channel')
 check(device:count(89)==0,'selection alone never sends an FC write')
 if changed then device.bands[1].frequencies[1]=5700 end
 check(app.send(ui.events.EVT_TOUCH_TAP,{x=260,y=231})==0,'actual UI Apply queues actual backend transaction')
 for i=1,500 do app.send(0);local st=app.fcState().vtx.operation.state;if st=='FAILED'or st=='APPLIED'then break end end
 local v=app.fcState().vtx
 if changed then check(v.operation.state=='FAILED'and v.operation.error=='CACHED CHANNEL CHANGED'and device:count(89)==0,'UI cached selection changed on FC is refused before write')
 else check(v.operation.state=='APPLIED'and device:count(89)==1 and device:count(250)==1 and v.reported.frequency==5658,'UI Apply reaches real89/250/readback only after selected verification')end
 check(device:count(137)==1,'UI transaction rereads selected band exactly once')
 check(next(m.handles)==nil,'actual UI cache path closes all native handles')
end
-- Native RF reports exist independently of FC/FM and may remain useful while
-- MSP is explicitly disabled. Explicit arm knowledge is still required to write.
do
 local frames,writes={},{}
 local radio=files.link.new({load=function(path)local n=string.match(path,'/([^/]+)%.lua$');return files[n]and function()return files[n]end end,
  crsfPush=function(kind,data)writes[#writes+1]={kind=kind,data=data};return true end,
  crsfPop=function()if #frames==0 then return nil end;local v=table.remove(frames,1);return v[1],v[2]end})
 radio:configure({family='CRSF',fcType='BF'},{vtxMode=2,video=true,vtxBackend='TBS native',vtxHardware=1})
 local guard={current=true,disarmed=false}
 frames[1]={0x10,{0xEC,20,22,168,0}}
 radio:tick(100,false,false,false,true,guard)
 check(not radio.state.active and #writes==0 and radio:videoState().reported.frequency==5800,'no FC/FM and MSP OFF still permit real passive native VTX reports on current RF link')
 local ok,why=radio:videoClient():applyVtx({frequency=5865})
 check(not ok and why=='ARMED / UNKNOWN'and #writes==0,'current RF link alone never authorizes a setting write')
 -- An invalid/missing arm field is not allowed to fall back to the old FC guard.
 radio:tick(110,false,true,true,true,{current=true})
 ok,why=radio:videoClient():applyVtx({frequency=5865})
 check(not ok and why=='ARMED / UNKNOWN','explicit native guard with unknown arm remains blocked even if old FC args say disarmed')
 guard.disarmed=true;radio:tick(120,false,false,false,true,guard)
 check(radio:videoClient():applyVtx({frequency=5865}),'explicit configured disarmed arm indication permits native operation without FC')
 for t=130,160,10 do radio:tick(t,false,false,false,true,guard)end
 check(#writes==1 and writes[1].kind==0x32,'no-FC native operation sends exactly one real setting frame and zero MSP commands')
 local wire=writes[1].data
 check(#wire==6 and wire[1]==0xCE and wire[2]==0xEA and wire[3]==8 and wire[4]==2 and wire[5]*256+wire[6]==5865,'no-FC native frequency uses the verified native wire command')
 frames[1]={0x10,{0xEC,20,22,233,0}};radio:tick(170,false,false,false,true,guard)
 check(radio:videoState().operation.state=='SUCCEEDED'and radio:videoState().reported.frequency==5865,'native no-FC success still requires a subsequent matching RF report')
 guard.disarmed=false;radio:tick(180,false,false,false,true,guard)
 check(radio:videoState().reported.frequency==5865 and not radio:videoClient():applyVtx({frequency=5800}),'armed/unknown pauses native writes while passive reported state remains useful')
 guard.current=false;radio:tick(190,false,false,false,true,guard)
 check(radio:videoState().reported==nil,'loss of the independently current RF link clears native reported state')
end
io=realIO
print('PASS: '..(checks+fixture.checks())..' actual dispatcher, native queue, cache RF reduction/native IO failures/fresh identity, guarded selected writes, remembered health and actual Video UI integration checks (synthetic only)')
