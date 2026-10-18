-- Actual application, actual common native API adapter and real telemetry/link
-- modules. Fixtures are synthetic input data only; never shipped to the SD card.
local realIO=io
local adapter=assert(loadfile('tests/test_ui_navigation.lua'))('adapter')
local fixture=dofile('tests/fixtures/msp_fixture.lua')
local E=adapter.events
local checks,scenarios=0,0
local function check(v,why)checks=checks+1;assert(v,why)end
local function drawn(app,text,predicate)
 for _,c in ipairs(app.commands())do if c.kind=='text'and c.text==text and(not predicate or predicate(c))then return c end end
end
local function scenario(name,fn)
 local ok,err=pcall(fn);io=realIO;assert(ok,name..': '..tostring(err));scenarios=scenarios+1
end
scenario('FrSky native RSSI has usable family defaults and primary metrics',function()
 local fields={{name='VFAS',value=24,unit=0},{name='Curr',value=12,unit=0},{name='Fuel',value=340,unit=0},
  {name='RSSI',value=5,unit=0},{name='RxBt',value=4.9,unit=0},{name='R9PW',value=500,unit=0},{name='Tmp1',value=0,unit=0}}
 local app=adapter.make({fields=fields,settings='ADCFG1\nrcProtocol=FrSky\nrcSubtype=R9\nfcType=Betaflight\nmspMode=0\n'})
 app.arrange(1);local d=app.snapshot()
 check(d.protocol.family=='FRSKY'and d.rssi==5 and d.rssiUnit=='%','actual profile reads native5% RSSI rather than interpreting dBm')
 check(app.config.get('thresholdMode')=='Profile defaults'and d.link=='LINK CRITICAL','default family thresholds actually warn at5% RSSI')
 check(d.lq==nil and d.snr==nil,'absent FrSky metrics stay unavailable rather than fabricated')
 check(drawn(app,'5',function(c)return c.x>=4 and c.x<74 and c.y>=35 and c.y<65 and c.flags%1024==MIDSIZE end),'Flight uses the available native RSSI in the primary large radio metric')
 check(not drawn(app,'SNR dB'),'FrSky Flight does not reserve a permanent unsupported SNR slot')
 app.arrange(9)
 check(drawn(app,'5')~=nil,'RC Link shows actual native RSSI5')
 check(drawn(app,'4.9')or drawn(app,'4.9 V'),'RC Link shows actual receiver voltage as available FrSky context')
 check(drawn(app,'500')or drawn(app,'500 mW'),'RC Link shows actual R9 transmitter power')
 check(not drawn(app,'LQ HISTORY / ')and not app.visible('LQ HISTORY'),'FrSky Link history is not falsely labelled as link quality')
 check(not app.visible('SIGNAL / NOISE'),'FrSky Link does not imply a native SNR feed')
 -- Currentness propagates through the same native source and warning path.
 app.setSensor('RSSI',5,false);app.arrange(1)
 check(app.snapshot().rssi==nil and app.snapshot().link==nil,'stale5% native RSSI is not kept as current or used for a new warning')
 check(not drawn(app,'5',function(c)return c.x>=4 and c.x<74 and c.y>=35 and c.y<65 end),'Flight primary value clears when actual RSSI becomes stale')
end)
scenario('legacy explicit custom RSSI thresholds retain their owner and values',function()
 local fields={{name='RSSI',value=5,unit=0},{name='Tmp1',value=0,unit=0}}
 local app=adapter.make({fields=fields,settings='ADCFG1\nrcProtocol=FrSky\nfcType=Betaflight\nrssiLow=40\nrssiCrit=30\nmspMode=0\n'})
 check(app.config.get('thresholdMode')=='Custom'and app.config.get('rssiLow')==40 and app.config.get('rssiCrit')==30,'legacy explicit custom values are not overwritten by default-profile migration')
 check(app.snapshot().link=='LINK CRITICAL','preserved percentage custom thresholds still have their real consumer')
end)
scenario('native TBS passive telemetry works without FC/FM while unknown arm blocks writes',function()
 local queue,sent={},{}
 local device={transport={push=function(kind,data)
  check(kind==0x32,'MSP disabled never emits an FC read or write')
  sent[#sent+1]={kind=kind,data=data};return true
 end,pop=function()if #queue>0 then local f=table.remove(queue,1);return f[1],f[2]end end},service=function()end}
 local fields={{name='RQly',value=99,unit=0},{name='1RSS',value=-56,unit=0}}
 local app=adapter.make({fields=fields,settings='ADCFG1\nrcProtocol=TBS Crossfire\nfcType=Off\nmspMode=0\nvtxMode=2\nvtxBackend=TBS native\nvtxHardware=1\n',device=device})
 queue[1]={0x10,{0xEC,20,22,168,0}};app.arrange(11)
 check(not app.fcState().active and #sent==0,'no FM/FC and explicit MSP Off never open FC transport')
 check(drawn(app,'5800',function(c)return c.x==16 and c.y>=64 and c.y<98 end),'actual native report reaches the large reported frequency')
 check(app.send(E.EVT_TOUCH_TAP,{x=40,y=126})==0,'native UI selects a different saved frequency')
 check(app.send(E.EVT_TOUCH_TAP,{x=260,y=231})==0,'native UI Apply dispatches explicit request')
 check(#sent==0 and app.visible('ARMED / UNKNOWN'),'current RF without arm knowledge never authorizes native setting writes')
 local oldSwitch=getSwitchValue;getSwitchValue=function()return false end
 app.send(0);getSwitchValue=oldSwitch
 check(not drawn(app,'5800',function(c)return c.x==16 and c.y>=64 and c.y<98 end),'loss of current RF clears reported native frequency, even with cached favourite labels')
end)
scenario('late native FM qualification and explicit deleted-source refresh',function()
 local fields={{name='RQly',value=99,unit=0},{name='1RSS',value=-56,unit=0}}
 local device=fixture.new({external=true,clock=function()return getTime()end})
 local app=adapter.make({fields=fields,settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\n',device=device})
 for _=1,30 do app.send(0)end
 check(#device.sent==0 and not app.fcState().active,'missing native FM cannot start MSP from generic RF metrics')
 fields[3]={name='FM',id=0x21,unit=UNIT_TEXT,value='ACRO*',current=true,sourceId=1009}
 for _=1,500 do app.send(0);if app.fcState().ready then break end end
 check(app.fcState().ready and device:count(2)>=1,'newly discovered native FM recovers qualified actual MSP without reopening app')
 local scans=app.sourceScans();for _=1,30 do app.send(0)end
 check(app.sourceScans()==scans,'stable native FM qualification does not scan all sensors per frame')
 fields[3].present=false;app.arrange(4)
 check(app.send(E.EVT_TOUCH_TAP,{x=300,y=231})==0,'Sensors Refresh rebuilds the real shared binding inventory')
 local before=#device.sent;for _=1,30 do app.send(0)end
 check(not app.fcState().active and not app.fcState().pendingCommand and #device.sent==before,'deleted native FM plus refresh cancels qualification and stops outgoing MSP')
 -- Same source index/name with a nonnative sensor cannot reuse old qualification.
 fields[3].present=true;fields[3].id=10;fields[3].value='ACRO*'
 check(app.send(E.EVT_TOUCH_TAP,{x=300,y=231})==0,'same-name replacement is explicitly refreshed')
 before=#device.sent;for _=1,30 do app.send(0)end
 check(not app.fcState().active and #device.sent==before,'generic same-name FM cannot inherit previous native0x21 proof')
end)
scenario('actual CRSF bindings normalize declared units and retain real zero',function()
 UNIT_VOLTS=11;UNIT_AMPS=12;UNIT_MILLIAMPS=13;UNIT_MAH=14;UNIT_AH=15
 UNIT_MILLIWATTS=16;UNIT_WATTS=17;UNIT_PERCENT=18;UNIT_DBM=19;UNIT_DB=20;UNIT_RAW=0
 local fields={{name='RxBt',value=24,unit=UNIT_VOLTS},{name='MilliCurrent',value=12345,unit=UNIT_MILLIAMPS},
  {name='ChargeAh',value=.34,unit=UNIT_AH},{name='TPWR',value=.5,unit=UNIT_WATTS},
  {name='RQly',value=99,unit=UNIT_PERCENT},{name='FM',id=0x21,unit=UNIT_TEXT,value='ACRO*'}}
 local app=adapter.make({fields=fields,settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nmspMode=0\ncurrent=MilliCurrent\nconsumed=ChargeAh\n'})
 app.arrange(3);local d=app.snapshot()
 check(d.a and math.abs(d.a-12.345)<.0001,'actual custom mA current binding converts to A before its consumers')
 check(d.mah and math.abs(d.mah-340)<.0001,'actual custom Ah consumption binding converts to mAh')
 check(d.power==500,'actual TPWR W telemetry converts to mW')
 check(app.visible('CURRENT / 296 W'),'Power chart derives watts from converted current and pack voltage')
 local _,state=app.sourceStatus({'Curr'});check(state=='LIVE','converted custom current has LIVE source diagnostics')
 app.setSensor('MilliCurrent',0,true);app.setSensor('ChargeAh',0,true);app.setSensor('TPWR',0,true);app.arrange(3);app.settle();d=app.snapshot()
 check(d.a==0 and d.mah==0 and d.power==0,'real current, consumption and transmitter-power zero remain valid')
 check(app.visible('CURRENT / 0 W'),'actual Power consumer renders real zero watts')
 app.setSensor('MilliCurrent',0,false);app.arrange(3);app.settle();d=app.snapshot()
 local _,stale=app.sourceStatus({'Curr'})
 check(d.a==nil and stale=='STALE'and not app.visible('CURRENT / 0 W'),'stale current clears watts and retains stale provenance')
 app.setSensor('MilliCurrent',12,true);fields[2].unit=UNIT_VOLTS;fields[3].unit=UNIT_WATTS;fields[4].unit=UNIT_AMPS
 app.send(E.EVT_TOUCH_TAP,{x=210,y=231});app.send(0);d=app.snapshot()
 local _,invalid=app.sourceStatus({'Curr'})
 check(d.a==nil and d.mah==nil and d.power==nil,'wrong declared unit classes are rejected through actual refreshed CRSF bindings')
 check(invalid=='INVALID'and not app.visible('CURRENT / 288 W'),'wrong-unit current is diagnosed and never produces watts')
 fields[2].unit=UNIT_RAW;fields[3].unit=UNIT_AH;fields[4].unit=UNIT_WATTS
 app.send(E.EVT_TOUCH_TAP,{x=210,y=231});app.send(0)
 check(app.snapshot().a==nil,'custom raw-number source cannot inherit a native Curr unit convention')
end)
scenario('INAV GPS course is distinct from heading and On-arm home locks current position',function()
 local fields={{name='GPS',value={lat=1,lon=2},unit=0},{name='Hdg',value=271,unit=UNIT_DEGREE},
  {name='0450',value=41.5,unit=UNIT_DEGREE},{name='0460',value=90,unit=UNIT_DEGREE},
  {name='0420',value=100,unit=UNIT_METERS},{name='GSpd',value=36,unit=UNIT_KMH},
  {name='GAlt',value=50,unit=UNIT_METERS},{name='0480',value=3013,unit=0},{name='0470',value=0,unit=0}}
 local app=adapter.make({fields=fields,settings='ADCFG1\nrcProtocol=FrSky\nfcType=INAV\nmspMode=0\nautoHome=2\nhomeSats=8\n'})
 local d=app.snapshot()
 check(d.course==41.5 and d.hdg==271,'actual INAV native0450 ground course and Hdg magnetic heading stay separate')
 check(d.fix==true and d.sats==13 and d.fcArmed==false and d.session.home==nil,'valid GPS while disarmed does not capture On-arm home')
 app.setSensor('GPS',{lat=1.001,lon=2.001},true);app.background(100);d=app.snapshot()
 check(d.session.current.lat==1.001 and d.session.home==nil,'moving current position before arm does not silently lock the initial point')
 app.setSensor('0470',4,true);app.background(100);d=app.snapshot()
 check(d.fcArmed==true and d.session.home and d.session.home.lat==1.001 and d.session.home.lon==2.001,'actual encoded INAV armed bit captures the current position at arm')
 check(d.session.home.source=='LOCAL AUTO','automatic home remains explicitly local rather than claiming FC-home provenance')
 app.setSensor('GPS',{lat=1.002,lon=2.002},true);app.background(100);d=app.snapshot()
 check(d.session.current.lat==1.002 and d.session.home.lat==1.001 and d.session.home.lon==2.001,'later movement updates current position but preserves the armed home reference')
 app.arrange(7);app.gpsScrollTo('GPS course')
 check(drawn(app,'42 deg',function(c)return c.x==468 and c.y>=64 and c.y<216 end),'GPS details displays the course feed, not magnetic heading')
 check(not drawn(app,'271 deg',function(c)return c.x==468 and c.y>=64 and c.y<216 end),'GPS course row does not fall back to unrelated Hdg')
end)
io=realIO
print('PASS: '..checks..' assertions in '..scenarios..' actual protocol UI scenarios: FrSky defaults, native guards, source qualification, declared-unit conversions and On-arm GPS home (synthetic only)')
