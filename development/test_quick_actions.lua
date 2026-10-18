local adapter=assert(loadfile('development/test_ui_navigation.lua'))('adapter')
local E=adapter.events;local checks=0
local function check(v,why)assert(v,why);checks=checks+1 end
local base='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nvtxMode=2\nresetNativeTelemetry=1\n'
local a=adapter.make({settings=base});a.arrange(3)
local writes=a.writes();a.send(E.EVT_SYS_LONG)
check(a.state().quickActive and a.visible('QUICK ACTIONS')and a.visible('READ VTX TABLES'),'hold SYS opens all five configured quick actions on any page')
a.send(E.EVT_SYS_BREAK);check(a.state().quickActive,'release of held key does not immediately dismiss its new menu')
a.send(E.EVT_TOUCH_TAP,{x=30,y=101})
check(not a.state().quickActive and a.snapshot().session.muted and a.writes()==writes,'Mute changes actual shared session without writing SD')
a.send(E.EVT_SYS_LONG);check(a.visible('ENABLE ALERTS'),'mute label reflects real current state')
a.send(E.EVT_VIRTUAL_EXIT);check(not a.state().quickActive and a.state().page==3,'RTN returns to exact originating page')
a.send(E.EVT_SYS_LONG);a.send(E.EVT_VIRTUAL_PREV)
check(a.state().quickFocus==6,'rotary wraps to visible Cancel after five actions')
a.send(E.EVT_VIRTUAL_ENTER);check(not a.state().quickActive,'Cancel has no action side effects')
-- An armed FC vetoes reset, even when the menu is globally available.
a.setFlightMode('ACRO');a.send(0);a.send(E.EVT_SYS_LONG);a.send(E.EVT_TOUCH_TAP,{x=30,y=126})
check(a.state().quickActive and #a.sensorResets==0 and a.visible('DISARM'),'global reset retains actual FC armed guard')
a.send(E.EVT_VIRTUAL_EXIT);a.setFlightMode('ACRO*');a.send(0);a.send(E.EVT_SYS_LONG)
a.send(E.EVT_TOUCH_TAP,{x=30,y=126})
check(a.visible('CONFIRM RESET FLIGHT DATA')and #a.sensorResets==0,'first reset click visibly confirms without reset effects')
a.send(E.EVT_TOUCH_TAP,{x=30,y=126});for i=1,5 do a.send(0)end
check(not a.state().quickActive and #a.sensorResets==64,'confirmed reset reaches actual batched native sensor reset exactly once')
for i=1,64 do check(a.sensorResets[i]==i-1,'reset visits correct native sensor slot')end
-- Read tables is a discovery action, not an apply.
local wire=assert(loadfile('development/msp_fixture.lua'))().new({external=true,clock=function()return getTime()end})
a=adapter.make({settings=base,device=wire});for i=1,80 do a.send(0)end
a.send(E.EVT_SYS_LONG);a.send(E.EVT_TOUCH_TAP,{x=30,y=176})
check(a.state().page==11 and not a.state().quickActive,'explicit Read VTX tables opens live discovery/results')
for i=1,200 do a.send(0)end
check(a.fcState().vtx.tablesReady,'global action discovers actual live tables through production client')
for _,sent in ipairs(wire.sent)do check(sent.cmd~=89 and sent.cmd~=250,'table discovery never applies or saves FC configuration')end
-- Only common actions when FC/MSP are explicitly off.
a=adapter.make({settings='ADCFG1\nrcProtocol=Off\nfcType=Off\nmspMode=0\n'})
a.send(E.EVT_SYS_LONG)
check(a.visible('MUTE ALERTS')and a.visible('RESET FLIGHT DATA')and a.visible('RELOAD AERODECK')and not a.visible('RESTART MSP SESSION')and not a.visible('READ VTX TABLES'),'conditional quick rows follow actual backend availability')
-- Genuine native radio warning routes to the visible thresholds and percentage.
a=adapter.make({radioVoltage=6.6,radioGeneral={battMin=6.6,battMax=8.4,battWarn=6.6}})
check(a.snapshot().radioStatus.percent==0 and a.snapshot().radioWarning==true and a.visible('RADIO BATTERY LOW'),'native range and inclusive radio threshold feed actual global warning')
a.send(E.EVT_VIRTUAL_ENTER);for i=1,3 do a.send(E.EVT_VIRTUAL_NEXT)end
-- Touch routes independently of changing context focus order.
a.send(E.EVT_TOUCH_TAP,{x=20,y=259})
check(a.state().page==12 and a.visible('RADIO BATTERY')and a.visible('Native warning threshold'),'radio warning details expose native limits without guessing')
print('PASS: '..checks..' actual global Quick Actions and native radio warning checks')
