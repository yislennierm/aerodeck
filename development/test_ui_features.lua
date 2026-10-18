-- Actual main quick-pack, raw-source extrema and system-page consumers.
local adapter=assert(loadfile('development/test_ui_navigation.lua'))('adapter')
local E=adapter.events;local checks=0
local function check(v,why)assert(v,why);checks=checks+1 end
local cfg='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nvtxMode=2\npack=1\ncells1=6\ncapacity1=6000\nchemistry2=0\ncells3=4\ncapacity3=2200\n'
local a=adapter.make({settings=cfg})
a.arrange(3);local writes=a.writes();a.send(E.EVT_TOUCH_TAP,{x=30,y=75})
check(a.packPicker()and a.packPicker().active()and a.visible('BATTERY PACK'),'Power pack header opens actual chooser')
a.send(E.EVT_TOUCH_TAP,{x=30,y=138})
check(a.packPicker().snapshot().pending==1 and a.config.get('pack')==1 and a.writes()==writes,'OFF pack cannot change pending or active selection')
a.send(E.EVT_TOUCH_TAP,{x=30,y=158})
check(a.packPicker().snapshot().pending==3 and a.config.get('pack')==1 and a.writes()==writes,'row selection remains pending without a write')
a.send(E.EVT_SYS_BREAK);a.send(E.EVT_VIRTUAL_NEXT_PAGE)
check(a.state().page==3 and a.packPicker().active(),'modal owns SYS/PAGE while choosing')
a.send(E.EVT_TOUCH_TAP,{x=455,y=15});a.send(E.EVT_TOUCH_TAP,{x=20,y=15})
check(a.state().page==3 and a.packPicker().active()and a.config.get('pack')==1 and a.writes()==writes,'pack proposal owns new Arm toolbar and Home touches without saving or changing pages')
a.send(E.EVT_VIRTUAL_EXIT)
check(not a.packPicker().active()and a.config.get('pack')==1 and a.writes()==writes,'RTN cancels with no profile/draft/SD effects')
a.send(E.EVT_TOUCH_TAP,{x=30,y=75});a.send(E.EVT_TOUCH_TAP,{x=30,y=158});a.send(E.EVT_TOUCH_TAP,{x=390,y=233})
check(not a.packPicker().active()and a.config.get('pack')==3 and a.writes()>writes and not a.config.hasAppChanges(),'explicit Use Pack saves only the validated active profile')
a.send(0);check(a.snapshot().capacity==2200 and a.snapshot().cells==4,'saved pack changes actual power calculation')
local other=a.config.get('rssiLow');a.send(E.EVT_TOUCH_TAP,{x=30,y=75});a.send(E.EVT_TOUCH_TAP,{x=180,y=233})
check(a.state().page==8 and a.visible('Pack 3')and a.config.get('rssiLow')==other,'Edit Packs opens actual settings without changing unrelated preferences')
a.send(E.EVT_VIRTUAL_EXIT);a.send(E.EVT_VIRTUAL_EXIT)
check(a.state().page==3,'Pack settings returns to its actual Power owner')
a.send(E.EVT_TOUCH_TAP,{x=30,y=75});a.background(100)
check(not a.packPicker().active(),'hidden callback cancels pack proposal')
-- Unknown sensor is still inspectable using real native raw extrema IDs.
a=adapter.make({extrema={UserTemp={min=-10.5,max=70.25}}})
a.addSensor('UserTemp',12.5,0,true);a.arrange(4)
for i=1,2 do a.send(E.EVT_TOUCH_TAP,{x=30,y=233})end
check(a.visible('UserTemp')and a.visible('12.50'),'raw inspector reaches a discovered sensor outside registered dashboard fields')
a.send(E.EVT_TOUCH_TAP,{x=30,y=73})
check(a.visible('-10.50')and a.visible('RAW MIN'),'generic inspector reads actual native minimum slots')
a.send(E.EVT_TOUCH_TAP,{x=30,y=73})
check(a.visible('70.25')and a.visible('RAW MAX'),'generic inspector reads actual native maximum slots')
-- About and actual RAM values are visible, not a hard-coded capacity claim.
a.arrange(12);for i=1,5 do a.send(E.EVT_TOUCH_TAP,{x=30,y=75})end
check(a.visible('ABOUT / SYSTEM')and a.visible('Lua RAM')and a.visible('no licence key'),'System view exposes current/peak memory and application identity')
print('PASS: '..checks..' actual Quick Pack, raw native source extrema and System UI checks')
