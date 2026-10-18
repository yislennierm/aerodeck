-- Development-only actual-native model timer probe. Never ship on radio SD.
local phase,checks,failed=0,0,0
local first,second,original,staged,beforeSecond,leaseName
local function check(name,pass,detail)
 checks=checks+1;if not pass then failed=failed+1 end
 print('LEASECHECK|'..name..'|'..(pass and'PASS'or'FAIL')..'|'..tostring(detail or''))
end
local function nativeTimer()
 local timer=model.getTimer(0)
 if type(timer)=='table'then return timer end
 return{}
end
local function emit(tag,timer)
 print('LEASETIMER|'..tag..'|'..tostring(timer.name)..'|'..tostring(timer.value)..'|'..tostring(timer.mode)..'|'..tostring(timer.start))
end
local function fresh()
 local factory=assert(loadScript('/SCRIPTS/TOOLS/AERODECK/timer-owner.lua'))()
 return factory.new({getTimer=model.getTimer,setTimer=model.setTimer,resetTimer=model.resetTimer,getModelId=function()
  local info=model.getInfo();return info.filename or info.id or info.name
 end})
end
local function run()
 if phase==0 then
  original=nativeTimer();check('native timer API',type(model.getTimer)=='function'and type(model.setTimer)=='function'and type(original.name)=='string',original.name)
  model.setTimer(0,{mode=0,start=123,value=17,countdownBeep=0,minuteBeep=false,persistent=0,name='QAORIG'})
  staged=nativeTimer();emit('staged',staged);check('native stage name and elapsed',staged.name=='QAORIG'and staged.value==17,staged.name)
 elseif phase==1 then
  first=fresh();local ok,why=first.configure({host='AERODECK',timerIndex=1});check('first independent factory claims',ok,why)
  local timer=nativeTimer();leaseName=timer.name;emit('claimed',timer)
  check('native lease name eight characters',type(leaseName)=='string'and#leaseName==8,leaseName)
  check('claim resets once and pauses',timer.value==0 and timer.mode==0,timer.value)
 elseif phase==2 then
  model.setTimer(0,{value=37});beforeSecond=nativeTimer();emit('before-second',beforeSecond)
  second=fresh();local ok,why=second.configure({host='AERODECK',timerIndex=1});check('second factory rejects occupied native lease',not ok,why)
  local timer=nativeTimer();emit('after-second',timer)
  check('second cannot reset elapsed',timer.value==37,timer.value)
  check('second cannot replace lease',timer.name==leaseName,timer.name)
  check('second is not owner',second.snapshot().owned==false,second.snapshot().state)
 elseif phase==3 then
  local ok,why=first.release();check('first releases own native lease',ok,why)
  local timer=nativeTimer();emit('released',timer)
  check('original name restored',timer.name=='QAORIG',timer.name)
  check('elapsed preserved across restore',timer.value==37,timer.value)
  check('original settings restored',timer.mode==staged.mode and timer.start==staged.start and timer.countdownBeep==staged.countdownBeep and timer.minuteBeep==staged.minuteBeep and timer.persistent==staged.persistent,timer.start)
 elseif phase==4 then
  local ok,why=first.configure({host='AERODECK',timerIndex=1});check('owner can explicitly reclaim',ok,why)
  model.setTimer(0,{name='MANUAL',value=41});emit('manual-marker-loss',nativeTimer())
 elseif phase==5 then
  local ok,why=first.release();check('manual marker loss blocks restore',not ok,why)
  local timer=nativeTimer();emit('after-blocked-restore',timer)
  check('manual name preserved',timer.name=='MANUAL',timer.name)
  check('manual elapsed preserved',timer.value==41,timer.value)
 elseif phase==6 then
  local invalid=fresh();local ok,why=invalid.configure({host='AERODECK',timerIndex=1.5});check('fractional positive timer index rejected',not ok,why)
  ok,why=invalid.configure({host='AERODECK',timerIndex=-0.5});check('fractional negative timer index rejected',not ok,why)
  check('invalid requests do not write native timer',nativeTimer().name=='MANUAL'and nativeTimer().value==41,nativeTimer().value)
 elseif phase==7 then
  model.setTimer(0,original);emit('fixture-cleanup',nativeTimer());print('LEASEDONE|'..checks..'|'..failed)
 end
 phase=phase+1
 lcd.clear();lcd.drawText(10,30,'NATIVE TIMER LEASE QA',SMLSIZE)
 lcd.drawText(10,60,'Development fixture / not radio data',SMLSIZE)
 lcd.drawText(10,90,'Checks '..checks..' / failed '..failed,SMLSIZE)
 return 0
end
return{init=function()end,run=run}
