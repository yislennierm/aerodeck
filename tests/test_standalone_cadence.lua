-- Actual standalone app: slow samples are bounded; attitude remains callback-fresh.
-- Synthetic time/counts establish scheduling, not physical FPS or CPU cost.
local adapter=assert(loadfile('tests/test_ui_navigation.lua'))('adapter')
local E=adapter.events
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function near(v,w,why)check(type(v)=='number'and math.abs(v-w)<.0001,why..': '..tostring(v))end
getUsage=nil
local a=adapter.make({settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nmspMode=0\nautoHome=1\nrenderHz=25\n'})
local now=getTime();getTime=function()return now end
local raw=getSourceValue;local reads={current=0,pitch=0,roll=0}
getSourceValue=function(id)
 if id==1006 then reads.current=reads.current+1 elseif id==1036 then reads.pitch=reads.pitch+1 elseif id==1039 then reads.roll=reads.roll+1 end
 return raw(id)
end
local function step(ticks,event,touch)now=now+ticks;return a.send(event or 0,touch)end
step(20)
local first={current=reads.current,pitch=reads.pitch,roll=reads.roll}
local serial=a.inputs.serviceSerial;local scans,writes=a.sourceScans(),a.writes()
local acquireAt,lastAcquire={},now
for i=1,100 do
 a.setAttitude(-i/1000,i/500);a.setSensor('Curr',i,true,true)
 local before=reads.current;step(4)
 near(a.hud().pitch,i/1000*180/math.pi,'horizon pitch is fresh on each rendered callback')
 near(a.hud().roll,i/500*180/math.pi,'horizon roll is fresh on each rendered callback')
 if reads.current>before then
  check(reads.current==before+1,'one native current read per slow sample')
  check(now-lastAcquire==20,'slow processing follows200ms rather than redraw cadence')
  lastAcquire=now;acquireAt[#acquireAt+1]=i
 end
 check(a.snapshot().a==math.floor(i/5)*5 or i<5 and a.snapshot().a==12,'cached power is the latest completed slow sample')
end
check(reads.current-first.current==20 and a.inputs.serviceSerial-serial==20,'100 redraws use20 full telemetry/session services, an80percent reduction')
check(reads.pitch-first.pitch==100 and reads.roll-first.roll==100,'both attitude sources are read exactly once per callback')
check(a.sourceScans()==scans and a.writes()==writes,'warm loop adds no SD writes or source enumeration')
-- Loss and recovery of either attitude axis must not wait for a slow sample.
a.setAttitudeCurrent(false);step(4)
check(a.snapshot().pitch==nil and a.snapshot().roll==nil and not a.hud(),'stale attitude clears at once between slow samples')
a.setAttitudeCurrent(true);a.setAttitude(-.3,.4);step(4)
near(a.hud().pitch,.3*180/math.pi,'pitch recovery is immediate');near(a.hud().roll,.4*180/math.pi,'roll recovery is immediate')
-- Both independent settings stores invalidate their cached sample immediately.
check(a.config.openSection(1,'current'),'current source setting is reachable')
a.config.input(E.EVT_VIRTUAL_ENTER);a.config.input(E.EVT_VIRTUAL_NEXT);a.config.input(E.EVT_VIRTUAL_ENTER);check(a.config.save(),'source change is really saved')
check(a.config.get('current')=='None','fixture disables current')
serial=a.inputs.serviceSerial;step(4)
check(a.inputs.serviceSerial==serial+1 and a.snapshot().a==nil,'source revision takes effect before the200ms deadline')
check(a.config.openSection(3),'battery limits are reachable')
a.config.input(E.EVT_VIRTUAL_ENTER);a.config.input(E.EVT_VIRTUAL_NEXT);a.config.input(E.EVT_VIRTUAL_ENTER)
a.config.input(E.EVT_TOUCH_TAP,{x=200,y=230});serial=a.inputs.serviceSerial;step(4)
check(a.inputs.serviceSerial==serial+1 and a.snapshot().cells==7,'battery revision takes effect before the200ms deadline')
-- Clock rollback cannot leave the service cache waiting for an old timestamp.
serial=a.inputs.serviceSerial;now=now-100;step(4)
check(a.inputs.serviceSerial==serial+1,'clock rollback reacquires immediately')
print('PASS: '..checks..' standalone cadence checks; full real app;100 redraws/20 slow services/100 attitude reads; synthetic time only')
