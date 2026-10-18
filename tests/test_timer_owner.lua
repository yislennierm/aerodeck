-- Actual native timer ownership code; all timer/model APIs are in-memory mocks.
local M=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/timer-owner.lua'))()
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function clone(t)local r={};for k,v in pairs(t)do r[k]=v end;return r end
local function original()
 return {mode=5,value=67,start=120,countdownBeep=2,minuteBeep=true,persistent=2,name='Pilot',showElapsed=true,switch=-17,countdownStart=1,extraHaptic=2,unsupported='NEVER SET'}
end
local function rig()
 local r={model='model1.yml',reads={},writes={},resets={},faults={}}
 r.models={['model1.yml']={[0]=original(),[1]=original(),[2]=original()},['model2.yml']={[0]=original(),[1]=original(),[2]=original()}}
 function r.getModelId()
  if r.faults.modelThrow then error('model failure')end
  if r.faults.modelMissing then return nil end
  return r.model
 end
 function r.getTimer(index)
  r.reads[#r.reads+1]={model=r.model,index=index}
  if r.faults.readThrow then error('timer failure')end
  if r.faults.readNil then return nil end
  local t=clone(r.models[r.model][index])
  if r.faults.badConfig then t.minuteBeep=1 end
  if r.faults.missingConfig then t.start=nil end
  if r.faults.missingName then t.name=nil end
  if r.faults.longName then t.name='TOO LONG NAME'end
  if r.faults.changeDuringRead then r.model='model2.yml'end
  return t
 end
 function r.setTimer(index,config)
  r.writes[#r.writes+1]={model=r.model,index=index,config=clone(config)}
  if r.faults.writeThrow then error('setter failure')end
  if r.faults.writeFalse then return false end
  if config.mode~=nil and r.faults.configWriteThrow then error('configuration setter failure')end
  if config.mode~=nil and r.faults.configWriteFalse then return false end
  if config.mode~=nil and r.faults.partialConfigWrite then r.models[r.model][index].mode=config.mode;error('partial configuration setter')end
  for k,v in pairs(config)do if k~='name'or not r.faults.ignoreName then r.models[r.model][index][k]=v end end
  if config.name and not string.match(config.name,'^AD%x%x%x%x%x%x$')and r.faults.nameRestoreFalse then return false end
  return nil -- Native setTimer has no success return value.
 end
 function r.resetTimer(index)
  r.resets[#r.resets+1]={model=r.model,index=index}
  if r.faults.resetThrow then error('reset failure')end
  if r.faults.resetFalse then return false end
  r.models[r.model][index].value=r.models[r.model][index].start
  return nil
 end
 r.owner=M.new({getModelId=r.getModelId,getTimer=r.getTimer,setTimer=r.setTimer,resetTimer=r.resetTimer})
 return r
end
local r=rig();local o=r.owner;local s=o.snapshot()
check(o.configure({host='RADIO',timerIndex=1})==true and s.state=='RADIO' and not s.owned,'RADIO host stays explicitly read-only')
for i=1,500 do o.update(i%2==0)end
check(#r.writes==0 and #r.reads==0 and #r.resets==0 and r.models[r.model][0].value==67,'RADIO preserves native configuration/value with no warm API traffic')
check(o.reset()==false and o.release()==false and #r.writes==0,'RADIO cannot invoke native reset/release writes')
check(o.configure({host='AERODECK',timerIndex=0})==true and s.state=='DISABLED' and #r.writes==0,'disabled index0 cannot claim or reset a timer')
for _,cfg in ipairs({{host='APP',timerIndex=1},{host='AERODECK',timerIndex=-1},{host='AERODECK',timerIndex=4},{host='AERODECK',timerIndex=1.5},{host='AERODECK',timerIndex='1'}})do
 check(o.configure(cfg)==false and #r.writes==0,'invalid timer ownership selection has no native effects')
end
check(o.configure('AERODECK')==false and o.configure(false)==false and #r.writes==0,'non-table settings cannot execute accidental host handoff')
check(o.configure({host='AERODECK',timerIndex=1})==true and s.owned and s.state=='OWNED' and s.nativeIndex==0,'explicit selected timer1 claims native index0')
check(#r.reads==3 and #r.writes==2 and #r.resets==0,'claim reserves/read-verifies native name before changing original timer config without resetTimer')
local c=r.writes[2].config
check(c.mode==0 and c.value==0 and c.start==0 and c.countdownBeep==0 and c.minuteBeep==false and c.persistent==0,'claim sets original Toolbox zero-based count-up native configuration')
check(c.name==nil and c.switch==nil and c.showElapsed==nil and c.countdownStart==nil and c.extraHaptic==nil,'claim leaves unmentioned native timer settings untouched')
check(string.match(s.leaseName,'^AD%x%x%x%x%x%x$')and r.models[r.model][0].name==s.leaseName and r.models[r.model][0].switch==-17,'claim uses exact eight-character native lease and preserves unrelated switch config')
check(o.configure({host='AERODECK',timerIndex=1})==true and #r.reads==3 and #r.writes==2,'same model/host/index configuration is an idempotent claim')
check(o.update(false)==s and s.armed==false and s.mode==0 and #r.writes==2,'initial disarmed sample never emits redundant mode0 write')
o.update(true);check(s.armed==true and s.mode==1 and #r.writes==3 and r.writes[3].config.mode==1,'genuine armed boolean starts owned native timer')
for i=1,1000 do o.update(true,i%2==0 and 1 or -1)end
check(#r.writes==3 and #r.reads==4 and #r.resets==0,'unchanged armed state/clock/source-like extra arguments have no repeated reads/writes/reset')
o.update(nil);check(s.armed==nil and s.mode==0 and s.state=='PAUSED' and #r.writes==4,'unknown arm status pauses instead of falsely claiming armed')
o.update(nil);o.update('ARMED');o.update(1)
check(#r.writes==4 and s.armed==nil,'repeated/nonboolean unknown indications remain paused without writes')
o.update(true);o.update(false)
check(#r.writes==6 and s.mode==0 and s.armed==false,'true/false state changes issue only one mode write apiece')
r.models[r.model][0].value=39
check(o.reset()==true and #r.resets==1 and r.resets[1].index==0 and s.resetCount==1 and r.models[r.model][0].value==0,'only explicit owned reset calls selected native resetTimer')
check(#r.writes==6,'explicit reset does not rewrite preferences or invoke sensor/output changes')
r.models[r.model][0].value=47
check(o.release()==true and not s.owned and s.restored and s.state=='RELEASED','release restores selected timer ownership explicitly')
local restored=r.models[r.model][0];local release=r.writes[#r.writes-1].config;local releasedName=r.writes[#r.writes].config
check(restored.value==47 and release.value==nil,'restoration preserves current elapsed value rather than restoring stale claim-time value')
for _,k in ipairs({'mode','start','countdownBeep','minuteBeep','persistent','name','showElapsed','switch','countdownStart','extraHaptic'})do
 check(restored[k]==original()[k] and(k=='name'and releasedName[k]or release[k])==original()[k],'release restores official native config field '..k)
end
check(release.unsupported==nil,'unknown getTimer fields are never passed into the native setter')
local writes=#r.writes;o.update(true);check(o.release()==false and #r.writes==writes,'released ownership cannot resume/replay native updates')

-- Reconfiguration restores the former timer before claiming the new selected
-- one, then RADIO release keeps all radio-owned settings and elapsed values.
r=rig();o=r.owner;s=o.snapshot();o.configure({host='AERODECK',timerIndex=1});o.update(true)
r.models[r.model][0].value=99
check(o.configure({host='AERODECK',timerIndex=3})==true and s.nativeIndex==2,'timer3 reconfiguration restores old timer then claims native index2')
check(r.models[r.model][0].mode==5 and r.models[r.model][0].value==99 and r.models[r.model][2].mode==0,'switching timer selection preserves old elapsed value')
r.models[r.model][2].value=17
check(o.configure({host='RADIO',timerIndex=3})==true and s.state=='RADIO' and not s.owned and r.models[r.model][2].mode==5 and r.models[r.model][2].value==17,'explicit RADIO handoff restores original configuration but not elapsed value')
writes=#r.writes;o.update(false);o.update(true);check(#r.writes==writes,'RADIO handoff cannot retain hidden ownership')

-- Model identity is checked before every native write. Once the old model is
-- gone its original settings must never be applied to the new model's timer.
r=rig();o=r.owner;s=o.snapshot();o.configure({host='AERODECK',timerIndex=2});o.update(true)
writes=#r.writes;r.model='model2.yml';o.update(false)
check(not s.owned and s.state=='MODEL CHANGED' and s.ownershipLost and s.previousModelId=='model1.yml' and s.unrestoredTimer==2,'model switch drops stale ownership and reports unrestored previous timer')
check(#r.writes==writes and r.models['model2.yml'][1].mode==5 and r.models['model2.yml'][1].value==67,'model switch never restores or updates old owner settings in the new model')
check(o.reset()==false and o.release()==false and #r.resets==0,'new model cannot reset/release the lost previous owner')
o.update(true);check(#r.writes==writes,'old configured owner never automatically claims a newly active model')
check(o.configure({host='AERODECK',timerIndex=2})==true and s.modelId=='model2.yml' and s.owned,'explicit configure from new model settings can independently claim its timer')
check(s.ownershipLost and s.previousModelId=='model1.yml','new valid claim does not hide prior unrestored-model ownership event')
r.model='model1.yml';check(o.release()==false and #r.writes==writes+2,'even explicit release cannot apply model2 original configuration to model1')

-- Early release is the path that can restore the old model before a switch.
r=rig();o=r.owner;o.configure({host='AERODECK',timerIndex=1});o.update(true)
check(o.release()==true and r.models['model1.yml'][0].mode==5,'caller early model-change event can restore while previous model is still current')
r.model='model2.yml';writes=#r.writes;o.update(true);check(#r.writes==writes,'early released model switch has no stale writes')
r=rig();o=r.owner;s=o.snapshot();r.faults.changeDuringRead=true
check(o.configure({host='AERODECK',timerIndex=1})==false and not s.owned and s.state=='MODEL CHANGED' and #r.writes==0,'model changes during original config read are caught before claim write')

-- Temporary unknown identity suspends all native writes while retaining the
-- original config, allowing safe same-model recovery or explicit restoration.
r=rig();o=r.owner;s=o.snapshot();o.configure({host='AERODECK',timerIndex=1});o.update(true)
writes=#r.writes;r.faults.modelMissing=true;o.update(false)
check(s.owned and s.state=='IDENTITY UNKNOWN' and s.armed==nil and #r.writes==writes,'unknown model identity suspends writes and armed claims instead of writing into an unverified model')
check(o.release()==false and o.reset()==false and #r.writes==writes,'explicit release/reset also require verified matching model identity')
r.faults.modelMissing=nil;o.update(false)
check(s.owned and s.mode==0 and s.state=='OWNED' and #r.writes==writes+1,'same-model identity recovery resumes only the needed pending arm transition')

-- Native setters return no values on success; explicit false/throw are failures.
-- Failed writes cannot silently claim success or create a per-frame retry loop.
for _,fault in ipairs({'configWriteThrow','configWriteFalse'})do
 r=rig();o=r.owner;s=o.snapshot();r.faults[fault]=true
 check(o.configure({host='AERODECK',timerIndex=1})==false and s.owned and s.state=='ERROR' and s.mode==nil,'uncertain native claim retains restoration data and reports error: '..fault)
 writes=#r.writes;for i=1,100 do o.update(i%2==0)end
 check(#r.writes==writes and o.reset()==false,'native claim failure never retries writes in warm updates: '..fault)
 r.faults[fault]=nil;check(o.release()==true and r.models[r.model][0].mode==5,'explicit release restores original after uncertain failed claim: '..fault)
end
for _,fault in ipairs({'readThrow','readNil','badConfig','missingConfig','missingName','longName'})do
 r=rig();o=r.owner;s=o.snapshot();r.faults[fault]=true
 check(o.configure({host='AERODECK',timerIndex=1})==false and not s.owned and #r.writes==0,'invalid/unavailable original config prevents ownership before native writes: '..fault)
end
for _,fault in ipairs({'modelThrow','modelMissing'})do
 r=rig();o=r.owner;s=o.snapshot();r.faults[fault]=true
 check(o.configure({host='AERODECK',timerIndex=1})==false and not s.owned and s.state=='IDENTITY UNKNOWN' and #r.writes==0,'missing model identity prevents native claim: '..fault)
end
for _,fault in ipairs({'resetThrow','resetFalse'})do
 r=rig();o=r.owner;s=o.snapshot();o.configure({host='AERODECK',timerIndex=3});o.update(true);r.faults[fault]=true
 check(o.reset()==false and s.state=='ERROR' and s.error=='RESET TIMER FAILED','explicit native reset failure is honest: '..fault)
 writes=#r.writes;local resets=#r.resets;o.update(false);o.update(true)
 check(#r.writes==writes and #r.resets==resets,'reset failure is not retried or hidden by warm updates: '..fault)
 r.faults[fault]=nil;check(o.release()==true,'explicit release remains available after failed reset: '..fault)
end
r=rig();o=M.new({getModelId=r.getModelId,getTimer=r.getTimer,setTimer=r.setTimer})
check(o.configure({host='AERODECK',timerIndex=1})==true and o.reset()==false and o.snapshot().error=='RESET TIMER UNAVAILABLE','absent reset API never becomes a pretend native reset')
o=M.new({getModelId=r.getModelId,getTimer=r.getTimer});check(o.configure({host='AERODECK',timerIndex=1})==false and not o.snapshot().owned,'missing setter prevents ownership')
o=M.new({getModelId=r.getModelId,setTimer=r.setTimer});check(o.configure({host='AERODECK',timerIndex=1})==false and not o.snapshot().owned,'missing reader prevents destructive claim without original config')
o=M.new({});check(o.configure({host='RADIO',timerIndex=1})==true and o.configure({host='AERODECK',timerIndex=1})==false,'RADIO stays usable when native ownership APIs are unavailable')

local stringMeta=debug.getmetatable('');debug.setmetatable('',nil)
local strippedOK,strippedError=pcall(function()
 local native=rig();local owner=native.owner
 check(owner.configure({host='AERODECK',timerIndex=1})==true,'native stripped string library permits explicit timer claim')
 owner.update(true);owner.update(nil)
 check(owner.reset()==true and owner.release()==true,'native stripped string library permits arm pause/reset/restoration')
end)
debug.setmetatable('',stringMeta);check(strippedOK,'native string compatibility: '..tostring(strippedError))
-- Two genuinely independent factory loads share only native model timer data.
-- They cannot rely on a Lua module/global registry for mutual exclusion.
r=rig();local firstModule=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/timer-owner.lua'))()
local secondModule=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/timer-owner.lua'))()
local dependencies={getModelId=r.getModelId,getTimer=r.getTimer,setTimer=r.setTimer,resetTimer=r.resetTimer}
local first=firstModule.new(dependencies);local second=secondModule.new(dependencies)
check(first.snapshot().leaseName~=second.snapshot().leaseName,'independent live instances have distinct native lease tokens')
check(first.configure({host='AERODECK',timerIndex=1})and #r.models[r.model][0].name==8,'first independent owner installs native8char marker')
first.update(true);r.models[r.model][0].value=81
local leaseName=r.models[r.model][0].name;writes=#r.writes;local resets=#r.resets
check(second.configure({host='AERODECK',timerIndex=1})==false and second.snapshot().state=='IN USE'and not second.snapshot().owned,'second independent app rejects the existing native lease')
check(#r.writes==writes and #r.resets==resets and r.models[r.model][0].value==81 and r.models[r.model][0].name==leaseName,'rejected second claim preserves first elapsed/config/name exactly')
local reads=#r.reads;for i=1,1000 do first.update(true);second.update(false)end
check(#r.reads==reads and #r.writes==writes,'two-owner warm callbacks perform no extra native reads/writes or scans')
check(first.release()and r.models[r.model][0].name=='Pilot'and r.models[r.model][0].value==81,'first owner restores original name/config and retains elapsed after rejecting second')
check(second.configure({host='AERODECK',timerIndex=1})and second.snapshot().owned,'explicit later claim succeeds only after native lease release')
second.release()

-- A stale marker is intentionally not stolen after script termination. The
-- pilot must inspect native Timer setup and recover its name/settings explicitly.
r=rig();r.models[r.model][0].name='ADABCDEF';o=r.owner
check(not o.configure({host='AERODECK',timerIndex=1})and o.snapshot().error=='TIMER IN USE / CHECK NATIVE NAME'and #r.writes==0,'stale cross-VM lease fails closed without elapsed reset')
reads=#r.reads;for i=1,100 do o.update(true)end;check(#r.reads==reads and #r.writes==0,'blocked stale lease is not retried in warm sampling')
r=rig();o=r.owner;o.configure({host='AERODECK',timerIndex=1});o.update(true)
r.models[r.model][0].name='MANUAL';r.models[r.model][0].mode=7;r.models[r.model][0].start=300;r.models[r.model][0].value=92;writes=#r.writes
o.update(false)
check(not o.snapshot().owned and o.snapshot().state=='OWNERSHIP LOST'and o.snapshot().ownershipReason=='TIMER NAME CHANGED','manual native marker replacement revokes ownership')
check(not o.reset()and not o.release()and #r.writes==writes and #r.resets==0,'revoked instance never restores/reset-writes over a manual owner')
check(r.models[r.model][0].name=='MANUAL'and r.models[r.model][0].mode==7 and r.models[r.model][0].start==300 and r.models[r.model][0].value==92,'manual timer config/name/elapsed remain untouched')

-- Setter success without a usable name API cannot authorize a destructive reset.
r=rig();r.faults.ignoreName=true;o=r.owner
check(not o.configure({host='AERODECK',timerIndex=1})and not o.snapshot().owned and r.models[r.model][0].value==67 and r.models[r.model][0].mode==5,'ignored native name setter is detected before Toolbox reset/config writes')
for _,fault in ipairs({'writeThrow','writeFalse'})do
 r=rig();o=r.owner;r.faults[fault]=true
 check(not o.configure({host='AERODECK',timerIndex=1})and not o.snapshot().owned and r.models[r.model][0].name=='Pilot'and r.models[r.model][0].value==67,'failed initial reservation never claims or changes elapsed: '..fault)
end
r=rig();o=r.owner;o.configure({host='AERODECK',timerIndex=1});o.update(true);r.models[r.model][0].value=88
r.faults.partialConfigWrite=true;leaseName=r.models[r.model][0].name
check(not o.release()and o.snapshot().owned and r.models[r.model][0].name==leaseName and r.models[r.model][0].value==88,'partial settings restoration retains native lease and original metadata for retry')
r.faults.partialConfigWrite=nil
check(o.release()and r.models[r.model][0].name=='Pilot'and r.models[r.model][0].mode==5 and r.models[r.model][0].value==88,'explicit retry completes restoration before releasing native marker')
r=rig();o=r.owner;o.configure({host='AERODECK',timerIndex=1});r.models[r.model][0].value=93;r.faults.nameRestoreFalse=true
check(not o.release()and o.snapshot().owned and o.snapshot().restoringName and r.models[r.model][0].name=='Pilot','reported final-name failure retains completion metadata')
writes=#r.writes
check(o.release()and #r.writes==writes and r.models[r.model][0].value==93,'already restored original name is recognized without writing stale settings again')
r=rig();o=r.owner;o.configure({host='AERODECK',timerIndex=1});o.update(true);writes=#r.writes;r.faults.changeDuringRead=true;o.update(false)
check(not o.snapshot().owned and #r.writes==writes and r.models['model2.yml'][0].mode==5,'model switch inside lease read is rechecked before mode write')
print('timer-owner: '..checks..' checks passed')
