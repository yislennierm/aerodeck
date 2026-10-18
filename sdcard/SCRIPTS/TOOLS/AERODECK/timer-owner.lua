-- Explicit native model-timer ownership; RADIO never claims/configures timers.
-- Original Toolbox RD/TMR sets mode/value/start/beeps/persistent on host claim;
-- owned arm transitions use mode1/0. No outputs/sensors/transports/SD access.
-- Native EdgeTX v2.12.4 api_model.cpp:288-369 getTimer/setTimer fields below.
-- Only explicit reset() invokes resetTimer. Release restores original known
-- settings EXCEPT elapsed value, and only while the captured model is active.
-- Native eight-character timer.name is a cross-script/VM lease. An existing
-- ADxxxxxx marker prevents a second independent instance resetting elapsed.
-- Original name is restored last, retaining the lease across partial failures.
-- Forced termination leaves an explicit stale marker; recovery is manual in
-- EdgeTX Timer setup, including original configuration if it was not restored.
local M={}
local settingTypes={mode='number',start='number',countdownBeep='number',minuteBeep='boolean',persistent='number',name='string',showElapsed='boolean',switch='number',countdownStart='number',extraHaptic='number'}
local required={mode=true,start=true,countdownBeep=true,minuteBeep=true,persistent=true,name=true}
local function integer(v)return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge and v%1==0.0 end
local function validId(v)return (type(v)=='string' and #v>0 and #v<=256) or integer(v)end
function M.new(opts)
 opts=opts or {}
 local s={host='RADIO',timerIndex=0,state='RADIO',owned=false,restored=false}
 local api,original,restoreSettings,fault={},nil,nil,nil
 local address=string.match(tostring(api),'0x(%x+)')
 local token=address and string.upper(string.sub(address,-6))
 if token and #token<6 then token=string.rep('0',6-#token)..token end
 local lease=token and('AD'..token)
 s.leaseName=lease
 local function marked(name)return type(name)=='string'and string.match(string.upper(name),'^AD%x%x%x%x%x%x$')~=nil end
 local function modelId()
  if type(opts.getModelId)~='function'then return nil,'MODEL ID UNAVAILABLE'end
  local ok,id=pcall(opts.getModelId)
  if not ok or not validId(id)then return nil,'MODEL ID UNAVAILABLE'end
  return id
 end
 local function fail(err)
  fault=err;s.error=err;s.state='ERROR';return false,err
 end
 local function lost(id)
  s.previousModelId=s.modelId;s.unrestoredTimer=s.timerIndex;s.ownershipLost=true
  original=nil;restoreSettings=nil;fault=nil;s.owned=false;s.mode=nil;s.armed=nil;s.currentModelId=id;s.restored=false
  s.state='MODEL CHANGED';s.error='PREVIOUS MODEL TIMER NOT RESTORED'
  return false,s.error
 end
 local function checkOwner()
  local id,err=modelId();s.currentModelId=id
  if not id then s.state='IDENTITY UNKNOWN';s.error=err;return false,err end
  if id~=s.modelId then return lost(id)end
  if not fault then s.error=nil end
  return true
 end
 local function loseLease()
  original=nil;restoreSettings=nil;fault=nil;s.owned=false;s.mode=nil;s.armed=nil;s.restored=false;s.restoringName=false
  s.ownershipLost=true;s.ownershipReason='TIMER NAME CHANGED';s.state='OWNERSHIP LOST';s.error='TIMER NAME CHANGED / LEFT UNCHANGED'
  return false,s.error
 end
 local function checkLease(allowRestored)
  local ok,err=checkOwner();if not ok then return false,err end
  if type(opts.getTimer)~='function'then return fail('GET TIMER UNAVAILABLE')end
  local good,timer=pcall(opts.getTimer,s.nativeIndex)
  if not good or type(timer)~='table'then return fail('GET TIMER FAILED')end
  ok,err=checkOwner();if not ok then return false,err end
  if type(timer.name)~='string'or #timer.name>8 then return fail('TIMER NAME API UNAVAILABLE')end
  if timer.name~=lease then
   if allowRestored and s.restoringName and original and timer.name==original.name then return true,nil,true end
   return loseLease()
  end
  return true
 end
 local function write(config)
  if type(opts.setTimer)~='function'then return fail('SET TIMER UNAVAILABLE')end
  local success,result=pcall(opts.setTimer,s.nativeIndex,config)
  if not success or result==false then s.mode=nil;return fail('SET TIMER FAILED')end
  return true
 end
 local function set(config)
  local ok,err=checkLease();if not ok then return false,err end
  return write(config)
 end
 local function released()
  s.mode=original.mode;s.armed=nil;s.owned=false;s.restored=true;s.state='RELEASED';s.error=nil;s.restoringName=false
  original=nil;restoreSettings=nil;fault=nil
  return true
 end
 function api.snapshot()return s end -- Borrowed stable read-only view.
 function api.release()
  if not s.owned then return false,'NOT OWNED'end
  local ok,err,completed=checkLease(true);if not ok then return false,err end
  if completed then return released()end
  ok,err=set(restoreSettings);if not ok then return false,err end
  s.restoringName=true
  ok,err=set({name=original.name});if not ok then return false,err end
  return released()
 end
 function api.configure(cfg)
  if cfg==nil then cfg={}elseif type(cfg)~='table'then return false,'INVALID TIMER SETTINGS'end
  local host,index=cfg.host or 'RADIO',cfg.timerIndex or 0
  if (host~='RADIO' and host~='AERODECK') or not integer(index) or index<0 or index>3 then return false,'INVALID TIMER SETTINGS'end
  if s.owned then
   local same,err=checkOwner()
   if not same and s.owned then return false,err end -- Identity unknown: retain restoration metadata.
   if same and host==s.host and index==s.timerIndex then return not fault,fault end
   if same then local ok;ok,err=api.release();if not ok then return false,err end end
  end
  s.host=host;s.timerIndex=index;s.nativeIndex=index>0 and index-1 or nil;s.armed=nil;s.mode=nil;s.error=nil;s.restored=false;fault=nil
  local id,idError=modelId();s.modelId=id;s.currentModelId=id
  if host=='RADIO' or index==0 then s.state=host=='RADIO' and 'RADIO' or 'DISABLED';return true end
  if not id then s.state='IDENTITY UNKNOWN';s.error=idError;return false,idError end
  if type(opts.getTimer)~='function' or type(opts.setTimer)~='function'then s.state='UNAVAILABLE';s.error='TIMER API UNAVAILABLE';return false,s.error end
  if not lease then return fail('TIMER LEASE ID UNAVAILABLE')end
  local ok,timer=pcall(opts.getTimer,s.nativeIndex)
  if not ok or type(timer)~='table'then return fail('GET TIMER FAILED')end
  local preserved={}
  for key,kind in pairs(settingTypes)do
   local value=timer[key]
   if value~=nil then
    if type(value)~=kind or kind=='number' and not integer(value)or key=='name'and #value>8 then return fail('INVALID TIMER CONFIG')end
    preserved[key]=value
   elseif required[key]then return fail('INVALID TIMER CONFIG')end
  end
  if marked(preserved.name)then s.state='IN USE';s.error='TIMER IN USE / CHECK NATIVE NAME';return false,s.error end
  -- getTimer may fail/change the active model; verify again immediately before
  -- any write and never apply a saved config to a different current model.
  local current,err=modelId();s.currentModelId=current
  if not current then s.state='IDENTITY UNKNOWN';s.error=err;return false,err end
  if current~=id then s.state='MODEL CHANGED';s.error='MODEL CHANGED BEFORE CLAIM';return false,s.error end
  original=preserved;restoreSettings={};for key,value in pairs(preserved)do if key~='name'then restoreSettings[key]=value end end
  s.owned=true;s.restoringName=false
  local reserved,reserveError=write({name=lease})
  if not reserved then
   local good,current=pcall(opts.getTimer,s.nativeIndex)
   if good and type(current)=='table'and current.name~=lease then s.owned=false;original=nil;restoreSettings=nil end
   return false,reserveError
  end
  local verified,verifyError=checkLease();if not verified then return false,verifyError end
  local claimed,claimError=set({mode=0,value=0,start=0,countdownBeep=0,minuteBeep=false,persistent=0})
  if not claimed then return false,claimError end
  s.mode=0;s.state='OWNED';s.error=nil
  return true
 end
 function api.update(armed)
  if not s.owned then return s end
  local ok=checkOwner();if not ok then s.armed=nil;return s end
  s.armed=armed;if type(armed)~='boolean'then s.armed=nil end
  if fault then s.state='ERROR';s.error=fault;return s end
  local mode=armed==true and 1 or 0
  if mode~=s.mode then
   local written=set({mode=mode});if not written then return s end
   s.mode=mode
  end
  s.state=type(armed)=='boolean' and 'OWNED' or 'PAUSED';s.error=nil
  return s
 end
 function api.reset()
  if not s.owned then return false,'NOT OWNED'end
  local ok,err=checkLease();if not ok then return false,err end
  if fault then return false,fault end
  if type(opts.resetTimer)~='function'then return fail('RESET TIMER UNAVAILABLE')end
  local success,result=pcall(opts.resetTimer,s.nativeIndex)
  if not success or result==false then return fail('RESET TIMER FAILED')end
  s.error=nil;s.resetCount=(s.resetCount or 0)+1
  return true
 end
 return api
end
return M
