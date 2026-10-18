-- Actual application gate -> dispatcher -> real MSP client, no copied guard.
local adapter=assert(loadfile('development/test_ui_navigation.lua'))('adapter')
local fixture=dofile('development/msp_fixture.lua')
local checks=0;local function check(v,s)assert(v,s);checks=checks+1 end
local function app(settings,values,current)
 local h=fixture.new({external=true,clock=function()return getTime()end})
 local a=adapter.make({settings='ADCFG1\n'..(settings or ''),device=h,values=values,current=current})
 return a,h
end
local a,h=app();for i=1,100 do a.send(0);if #h.sent>0 then break end end
check(#h.sent==1 and h.sent[1].cmd==2,'Legacy empty model auto-detects the real native CRSF FM sensor and identifies FC')
for _,mode in ipairs({'ACRO','!FS!','FAILSAFE',''})do
 a.setSensor('FM',mode,true);a.send(0);check(not a.fcState().active and not a.fcState().pendingCommand,'armed/failsafe/unknown gates stop MSP: '..mode)
end
a.setSensor('FM','ACRO*',false);a.send(0);check(a.fcState().status=='NO CURRENT LINK','stale telemetry stops the actual client')
a,h=app('mspMode=0\n');a.send(0);check(a.fcState().status=='OFF'and #h.sent==0,'Disabled MSP never transmits')
a,h=app('rcProtocol=Other\nfcType=Other\n');a.send(0);check(not a.fcState().active and #h.sent==0,'Unsupported family never transmits')
a,h=app('rcProtocol=ELRS / CRSF\nfcType=INAV\n', {FM='OK'});for i=1,100 do a.send(0);if #h.sent>0 then break end end
check(a.fcState().family=='INAV'and #h.sent==1 and h.sent[1].cmd==2,'INAV has an explicit handshake rather than a blanket OFF gate')
a,h=app();for i=1,100 do a.send(0);if a.fcState().ready then break end end
check(a.fcState().ready,'Default auto model reaches actual BF handshake readiness')
a.background(100);check(not a.fcState().active and not a.fcState().pendingCommand,'Full to hidden cancels FC transaction while retaining app')
print('PASS: '..checks..' actual application auto/protocol/armed/failsafe/stale/off gates and retained hidden lifecycle checks')
