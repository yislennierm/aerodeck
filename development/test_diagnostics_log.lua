-- Real opt-in logger with native static IO signatures in RAM, never real SD.
local M=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/diagnostics-log.lua'))()
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function rig()
 local r={tick=0,files={},handles={},events={},faults={},clockCalls=0,dateCalls=0,reads=0,writes=0,maxRead=0,maxWrite=0}
 local fs={}
 function fs.open(path,mode)
  r.events[#r.events+1]={'open',path,mode}
  if r.faults.openThrow==path then error('open failure')end
  if r.faults.openFail==path or r.faults.noDirectory then return nil end
  if mode=='r' and not r.files[path]then return nil end
  if mode=='w'then r.files[path]=''end
  local f={path=path,mode=mode};r.handles[f]=true;return f
 end
 function fs.read(f,n)
  check(r.handles[f] and f.mode=='r','native read receives explicit open handle')
  r.reads=r.reads+1;r.maxRead=math.max(r.maxRead,n)
  if r.faults.readThrow==f.path then error('read failure')end
  if r.faults.readWrongType==f.path then return {}end
  return string.sub(r.files[f.path],1,n)
 end
 function fs.write(f,raw)
  check(r.handles[f] and f.mode=='w','native write receives explicit open handle')
  r.writes=r.writes+1;r.maxWrite=math.max(r.maxWrite,#raw)
  if r.faults.writeThrow==f.path then error('write failure')end
  if r.faults.writeFalse==f.path then return false end
  r.files[f.path]=r.faults.truncate==f.path and string.sub(raw,1,math.floor(#raw/2)) or raw
  if r.faults.duringWrite then r.faults.duringWrite();r.faults.duringWrite=nil end
  return nil
 end
 function fs.close(f)
  check(r.handles[f],'native opened handles are closed exactly once')
  r.handles[f]=nil
  if r.faults.closeThrow==f.path then error('close failure')end
  if r.faults.closeFalse==f.path then return false end
  return nil
 end
 function r.remove(path)
  r.events[#r.events+1]={'delete',path}
  if r.faults.removeFail==path then return 7 end
  if not r.files[path]then return 4 end
  r.files[path]=nil;return 0
 end
 function r.rename(from,to)
  r.events[#r.events+1]={'rename',from,to}
  if r.faults.renameFailFrom==from then return 7 end
  if not r.files[from]then return 4 end
  r.files[to]=r.files[from];r.files[from]=nil
  if r.faults.corruptPromote==to then r.files[to]='corrupt'end
  return 0
 end
 function r.clock()
  r.clockCalls=r.clockCalls+1
  if r.faults.clockThrow then error('clock failure')end
  if r.faults.clockMissing then return nil end
  return r.tick
 end
 function r.date()
  r.dateCalls=r.dateCalls+1
  if r.faults.dateThrow then error('date failure')end
  if r.faults.badDate then return {year=2026,mon=99}end
  return {year=2026,mon=10,day=17,hour=21,min=22,sec=23}
 end
 r.fs=fs
 r.log=M.new({io=fs,remove=r.remove,rename=r.rename,root='/LOG/',clock=r.clock,getDateTime=r.date})
 return r
end
local FILE='/LOG/errors.log'
local function noHandles(r)check(next(r.handles)==nil,'all IO handles are closed')end

-- Native simulator missing-file del=6 must not prevent the second explicit
-- Save Log, nor may it authorize deletion of an existing backup on failure.
local sim=rig();local simDeletes,simStats=0,0;local statFault,deleteFault
local simLog=M.new({io=sim.fs,root='/LOG/',rename=sim.rename,clock=sim.clock,getDateTime=sim.date,
 stat=function(path)
  simStats=simStats+1
  if statFault=='throw'then error('stat failure')end
  if statFault=='shape'then return false end
  if sim.files[path]~=nil then return{size=#sim.files[path]}end
 end,
 remove=function(path)
  simDeletes=simDeletes+1
  if deleteFault or sim.files[path]==nil then return 6 end
  return sim.remove(path)
 end})
check(simLog.configure(true,'sim.yml')and simLog.record('ERROR','first')and simLog.flush()==true,'native-style log first explicit save succeeds')
sim.tick=3000;simLog.record('ERROR','second')
check(simLog.flush()==true and simDeletes==0 and simStats==1,'second explicit Save Log skips missing backup without accepting delete6')
sim.tick=6000;simLog.record('ERROR','third')
check(simLog.flush()==true and simDeletes==1 and string.find(sim.files[FILE],'third',1,true)~=nil,'later log save deletes existing backup and verifies new payload')
local simPrimary,simBackup=sim.files[FILE],sim.files[FILE..'.bak'];deleteFault=true
sim.tick=9000;simLog.record('ERROR','failed')
check(simLog.flush()==false and simLog.snapshot().pending and sim.files[FILE]==simPrimary and sim.files[FILE..'.bak']==simBackup,'delete6 on existing log backup preserves both files and pending errors')
deleteFault=nil
for _,fault in ipairs({'throw','shape'})do
 statFault=fault;sim.tick=sim.tick+3000
 check(simLog.flush()==false and sim.files[FILE]==simPrimary and sim.files[FILE..'.bak']==simBackup,'invalid/failed stat cannot replace current log: '..fault)
end
statFault=nil;local beforeStats=simStats;local beforeWrites=sim.writes
simLog.configure(false,'sim.yml');check(simLog.flush()==false and simStats==beforeStats and sim.writes==beforeWrites,'disabled logging performs zero stat/write IO')
noHandles(sim)
local memo=rig();local memoLog=memo.log;memoLog.configure(true,'memo.yml');memoLog.record('ERROR','first');check(memoLog.flush(),'verified log memo fixture saves')
memo.files[FILE]=string.gsub(memo.files[FILE],'message=first','message=WRONG')
memo.tick=3000;memoLog.record('ERROR','second')
check(memoLog.flush()and string.find(memo.files[FILE],'message=second',1,true)and memo.files[FILE..'.bak']==nil,'external log changes invalidate memo and checksum-invalid primary never replaces backup')
noHandles(memo)

-- Explicit asynchronous transaction: begin is zeroIO, each step owns one
-- bounded cold phase, and no caller can continue it for an unknown/new model.
local async=rig();local al=async.log;al.configure(true,'async.yml');al.record('ERROR','first async')
local beforeIO=#async.events;local good,status=al.beginFlush()
check(good and status=='PENDING'and al.snapshot().flushing and al.snapshot().flushPhase==1 and al.snapshot().flushModelId=='async.yml'and #async.events==beforeIO,'begin reserves an explicit save without filesystem IO')
check(al.beginFlush()==false and #async.events==beforeIO,'duplicate begin cannot restart or repeat IO')
check(al.stepFlush('async.yml')and al.snapshot().flushPhase==2 and async.writes==0 and async.files[FILE]==nil,'first async step encodes and reads only; it cannot mutate current/temporary file')
async.tick=25;al.record('ERROR','after snapshot')
check(al.stepFlush('async.yml')and not al.snapshot().flushing and al.snapshot().pending and string.find(async.files[FILE],'first async',1,true)and not string.find(async.files[FILE],'after snapshot',1,true),'events after phase1 remain pending after immutable older snapshot commits')
beforeIO=#async.events;check(al.beginFlush()==false and #async.events==beforeIO,'completed async attempt keeps original30second retry bound')
async.tick=3025;check(al.beginFlush()and al.stepFlush('async.yml')and al.stepFlush('async.yml')and not al.snapshot().pending and string.find(async.files[FILE],'after snapshot',1,true),'next eligible async transaction persists the retained new revision')
noHandles(async)
for _,identity in ipairs({'new-model.yml',false})do
 local x=rig();local l=x.log;l.configure(true,'original.yml');l.record('ERROR','not yet saved');check(l.beginFlush(),'model guard async fixture begins')
 local n=#x.events
 local ok,why=l.stepFlush(identity==false and nil or identity)
 check(not ok and why=='MODEL CHANGED'and not l.snapshot().flushing and l.snapshot().pending and #x.events==n,'new or unavailable current model cannot start save IO')
end
for _,change in ipairs({'MODEL','OFF','CANCEL'})do
 local x=rig();local l=x.log;l.configure(true,'original.yml');l.record('ERROR','hold');l.beginFlush();l.stepFlush('original.yml');local n=#x.events
 if change=='MODEL'then l.configure(true,'new.yml')elseif change=='OFF'then l.configure(false,'original.yml')else l.cancelFlush('USER CANCELLED')end
 check(not l.snapshot().flushing and l.snapshot().pending and l.stepFlush('original.yml')==false and #x.events==n and x.files[FILE]==nil,'configuration/lifecycle cancellation between phases cannot promote old-model snapshot: '..change)
 noHandles(x)
end
local raced=rig();raced.log.configure(true,'race.yml');raced.log.record('ERROR','our snapshot');raced.log.beginFlush();raced.log.stepFlush('race.yml')
raced.files[FILE]='EXTERNAL FILE';local raceIO=#raced.events
local saved,raceError=raced.log.stepFlush('race.yml')
check(not saved and raceError=='PRIMARY CHANGED'and raced.files[FILE]=='EXTERNAL FILE'and raced.files[FILE..'.tmp']==nil and raced.log.snapshot().pending,'external primary change in callback gap aborts before any temporary write/rotation')
check(raced.writes==0 and #raced.events>raceIO,'phase2 uses fresh primary read to detect external changes')
noHandles(raced)
local faulted=rig();faulted.log.configure(true,'fault.yml');faulted.log.record('ERROR','cannot write');faulted.log.beginFlush();faulted.log.stepFlush('fault.yml');faulted.faults.truncate=FILE..'.tmp'
check(faulted.log.stepFlush('fault.yml')==false and not faulted.log.snapshot().flushing and faulted.log.snapshot().pending and faulted.files[FILE]==nil,'async temporary corruption fails closed and retains unsaved events')
noHandles(faulted)
local rolled=rig();rolled.tick=100;rolled.log.configure(true,'clock.yml');rolled.log.record('ERROR','clock');rolled.log.beginFlush();rolled.tick=0;beforeIO=#rolled.events
local clockOK,clockError=rolled.log.stepFlush('clock.yml')
check(not clockOK and clockError=='CLOCK CHANGED'and not rolled.log.snapshot().flushing and #rolled.events==beforeIO,'clock-epoch change before step aborts without filesystem IO')
local r=rig();local log=r.log;local s=log.snapshot();local events=s.events
for i=1,100 do check(log.record('ERROR','disabled')==false and log.flush()==false,'off logger does not accept or persist records')end
check(#r.events==0 and r.clockCalls==0 and r.dateCalls==0 and #s.events==0,'off means zero IO/time/date calls, not merely no final write')
check(log.configure(true,'model1.yml')==true and s.state=='READY' and #r.events==0,'enabling is explicit and never accesses SD')
check(log.flush()==true and #r.events==0,'empty unchanged log needs no SD IO')
check(log.configure('yes','model1.yml')==false and log.configure(true,'bad\nmodel')==false,'invalid enable/model identity cannot silently alter configuration')
check(log.record('ERROR','real error')==true and s.pending and #events==1,'first observed error creates a bounded RAM event')
check(events[1].modelId=='model1.yml' and events[1].tick==0 and events[1].date=='2026-10-17T21:22:23','record preserves actual model/tick/native wall-clock metadata')
check(#r.events==0 and r.writes==0,'record does not open/write SD')
local e=events[1]
for i=1,1000 do r.tick=i;log.record('ERROR','real error')end
check(#events==1 and e.repeats==1001 and s.repeated==1000 and e.lastTick==1000,'identical repeats coalesce rather than allocating unlimited RAM rows')
check(r.dateCalls==1 and #r.events==0,'repeat coalescing avoids recurring wall-clock reads and all SD IO')
r.tick=1025;log.record('ERROR','second error')
r.tick=1026;local ok,err=log.record('LINK','third too soon')
check(not ok and err=='RATE LIMITED' and #events==2 and s.dropped==1,'distinct event creation is rate bounded with explicit dropped count')
for i=3,12 do r.tick=1025+i*25;log.record('ERROR','event '..i)end
check(log.snapshot()==s and s.events==events and #events==8 and events[1].message=='event 5' and events[8].message=='event 12','last8 RAM events use stable bounded snapshot/order tables')
check(e.message=='event 9','evicted event objects are reused after the ring reaches capacity')
check(r.writes==0 and #r.events==0,'even filled/recycled event history performs zero SD writes')
check(log.flush()==true and s.state=='SAVED' and not s.pending and s.lastFlushAt==r.tick,'explicit flush writes/verifies pending log snapshot')
local first=r.files[FILE];local count=r.writes
check(first and #first<=4096 and string.sub(first,1,7)=='ADLOG1\n' and string.find(first,'model=model1.yml',1,true),'saved log is bounded inert readable data with per-event model identity')
check(r.maxRead==4097 and r.maxWrite<=4096 and count==1,'flush performs one bounded payload write with bounded readback')
local ioCount=#r.events;check(log.flush()==true and #r.events==ioCount,'unchanged flush never rereads or rewrites the SD')
r.tick=r.tick+25;log.record('MSP','new failure')
check(log.flush()==false and s.nextFlushAt==s.lastFlushAt+3000 and r.writes==count,'pending changed log cannot hammer SD within30s flush interval')
r.tick=s.nextFlushAt
check(log.flush()==true and r.files[FILE..'.bak']==first and r.files[FILE]~=first and r.writes==count+1,'next eligible flush rotates previous verified snapshot into backup')
noHandles(r)

-- Model switches retain truthful per-event identity and do not change paths.
r.tick=r.tick+25;log.configure(true,'model2.yml');log.record('ERROR','new model issue')
check(events[#events].modelId=='model2.yml' and events[#events-1].modelId=='model1.yml' and s.path==FILE,'shared log retains model-specific context without path/hash collisions')
count=#r.events;log.configure(false,'model2.yml');r.tick=r.tick+4000
check(log.flush()==false and log.record('ERROR','off again')==false and #r.events==count,'turning off pending logger performs zero IO')
log.configure(true,'model2.yml');check(log.flush()==true,'pending observed errors can be saved only after explicit reenable')

-- Fields are bounded/sanitized before use; no multiline/path injection or
-- executable data loading. Metadata/date failures remain explicit fallbacks.
r=rig();log=r.log;s=log.snapshot();log.configure(true,'model1.yml')
log.record(string.rep('K',1000),'return loadScript("evil")\n|\0'..string.rep('X',10000))
check(#s.events[1].kind==32 and #s.events[1].message==192 and not string.find(s.events[1].message,'[%c|]'),'kind/message work and output remain bounded/single-line')
check(log.flush()==true and #r.files[FILE]<=4096,'text resembling code is inert message data, never an evaluated script')
for _,fault in ipairs({'dateThrow','badDate'})do
 r=rig();log=r.log;r.faults[fault]=true;log.configure(true,'model1.yml');log.record('ERROR','date unavailable')
 check(log.snapshot().events[1].date=='--' and log.flush()==true,'unavailable/invalid native date is not fabricated: '..fault)
end
for _,fault in ipairs({'clockThrow','clockMissing'})do
 r=rig();log=r.log;r.faults[fault]=true;log.configure(true,'model1.yml')
 check(log.record('ERROR','clock unavailable')==false and log.snapshot().error=='CLOCK UNAVAILABLE' and #r.events==0,'missing clock fails rate-bound record honestly: '..fault)
end
r=rig();log=r.log;log.configure(true,'model1.yml');r.tick=9000;log.record('ERROR','first epoch');log.flush()
r.tick=0;log.record('ERROR','reset epoch')
check(log.snapshot().clockEpoch==1 and log.snapshot().events[2].epoch==1 and log.flush()==true,'clock rollback starts explicit new epoch without indefinite rate-limit suppression')

-- Full worst-case legal snapshot fits one4096-byte file even with all eight
-- maximum model/kind/message lengths and large native ticks/repeat counters.
r=rig();log=r.log;log.configure(true,string.rep('M',96));r.tick=2147483000
check(r.tick+25>r.tick,'worst-case native signed-int32 clock fixture actually advances by the rate interval')
for i=1,8 do log.record(string.rep('K',31)..i,string.rep('X',191)..i);r.tick=r.tick+25 end
check(log.flush()==true and #r.files[FILE]<=4096 and #log.snapshot().events==8,'maximum bounded eight-event snapshot is serializable under native file limit')
noHandles(r)

-- Errors in every native phase preserve the good primary or recoverable backup
-- and retain pending state. Failures also own30s cooldown to avoid retry storms.
for _,fault in ipairs({'truncate','writeThrow','writeFalse','closeThrow','closeFalse','openThrow','openFail'})do
 r=rig();log=r.log;s=log.snapshot();log.configure(true,'model1.yml');log.record('ERROR','first');log.flush()
 local good=r.files[FILE];r.tick=3000;log.record('ERROR','next');r.faults[fault]=FILE..'.tmp'
 check(log.flush()==false and s.pending and s.state=='ERROR' and r.files[FILE]==good,'failed temp stage preserves primary/pending: '..fault)
 count=#r.events;check(log.flush()==false and #r.events==count,'failed flush cannot retry IO until cooldown: '..fault);noHandles(r)
end
for _,fault in ipairs({'readThrow','readWrongType','closeThrow','closeFalse','openThrow'})do
 r=rig();log=r.log;log.configure(true,'model1.yml');log.record('ERROR','first');log.flush()
 local good=r.files[FILE];count=r.writes;r.tick=3000;log.record('ERROR','next');r.faults[fault]=FILE
 check(log.flush()==false and r.files[FILE]==good and r.writes==count,'transient primary read error prevents destructive overwrite: '..fault);noHandles(r)
end
for _,fault in ipairs({'backupDelete','backupRename','promotion','finalCorrupt'})do
 r=rig();log=r.log;s=log.snapshot();log.configure(true,'model1.yml');log.record('ERROR','first');log.flush()
 local good=r.files[FILE];r.tick=3000;log.record('ERROR','next')
 if fault=='backupDelete'then r.faults.removeFail=FILE..'.bak'
 elseif fault=='backupRename'then r.faults.renameFailFrom=FILE
 elseif fault=='promotion'then r.faults.renameFailFrom=FILE..'.tmp'
 else r.faults.corruptPromote=FILE end
 check(log.flush()==false and s.pending and (r.files[FILE]==good or r.files[FILE..'.bak']==good),'atomic promotion error preserves old validated primary/backup: '..fault);noHandles(r)
end
r=rig();log=r.log;log.configure(true,'model1.yml');log.record('ERROR','first');log.flush()
local backup=r.files[FILE];r.files[FILE]='truncated';r.files[FILE..'.bak']=backup;r.tick=3000;log.record('ERROR','recovered later')
check(log.flush()==true and r.files[FILE..'.bak']==backup,'replacing invalid prior primary preserves validated old backup')

-- Native APIs are required, no unsafe direct-overwrite fallback/implicit mkdir.
r=rig();log=M.new({io=r.fs,clock=r.clock,root='/LOG'});log.configure(true,'model1.yml');log.record('ERROR','atomic API absent')
check(log.flush()==false and #r.events==0 and log.snapshot().error=='ATOMIC IO UNAVAILABLE','missing rename/delete API fails closed before any SD IO')
log=M.new({io={},clock=r.clock});log.configure(true,'model1.yml');log.record('ERROR','IO absent');check(log.flush()==false,'missing native IO is nonfatal and explicit')
for _,root in ipairs({'relative','/bad/../root','/bad/./root','/bad\\root','/'})do
 log=M.new({io=r.fs,remove=r.remove,rename=r.rename,clock=r.clock,root=root});log.configure(true,'model1.yml');log.record('ERROR','bad root')
 check(log.flush()==false and log.snapshot().error=='INVALID LOG ROOT','invalid root never writes an arbitrary path')
end
r=rig();log=r.log;r.faults.noDirectory=true;log.configure(true,'model1.yml');log.record('ERROR','missing directory')
check(log.flush()==false,'missing log directory is nonfatal and never implicitly created')
for _,event in ipairs(r.events)do check(event[1]~='mkdir','logger never creates directories')end

-- A record arriving while explicit native IO is in progress must remain dirty,
-- rather than being lost when the older captured revision finishes saving.
r=rig();log=r.log;s=log.snapshot();log.configure(true,'model1.yml');log.record('ERROR','before flush')
r.faults.duringWrite=function()r.tick=25;log.record('ERROR','during flush')end
check(log.flush()==true and s.pending and s.state=='PENDING' and not string.find(r.files[FILE],'during flush',1,true),'new observed event during IO remains pending after older snapshot saves')
r.tick=3000;check(log.flush()==true and not s.pending and string.find(r.files[FILE],'during flush',1,true),'next explicit eligible flush preserves pending concurrent event')

local stringMeta=debug.getmetatable('');debug.setmetatable('',nil)
local strippedOK,strippedError=pcall(function()
 local native=rig();local l=native.log;l.configure(true,'model1.yml');l.record('ERROR','stripped string library')
 check(l.flush()==true,'native stripped string library supports inert verified logging')
 native.tick=3000;l.record('ERROR','next');check(l.flush()==true and native.files[FILE..'.bak']~=nil,'native stripped string library supports validated backup rotation')
 noHandles(native)
end)
debug.setmetatable('',stringMeta);check(strippedOK,'stripped native string compatibility: '..tostring(strippedError))
print('diagnostics-log: '..checks..' checks passed')
