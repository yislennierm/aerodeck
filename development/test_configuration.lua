-- Behavioral regression tests for this project's actual configuration and battery closures.
-- The fake filesystem implements EdgeTX io signatures, not host io signatures.
local hostio=io
local scriptPath=(arg and arg[0])or ''
local scriptDirectory=scriptPath:match('^(.*)/[^/]+$')or '.'
local f=assert(hostio.open(scriptDirectory..'/../sdcard/SCRIPTS/TOOLS/telem.lua','r'));local main=f:read('*a');f:close()
local a=assert(string.find(main,'local batteryConfig=(function()',1,true));local b=assert(string.find(main,'-- One dispatcher owns',a,true))
local batterySource=string.sub(main,a,b-1)
a=assert(string.find(main,'local configuration=(function()',1,true));b=assert(string.find(main,'function fcLink.update',a,true))
local configurationSource=string.sub(main,a,b-1)
local files={};local failWrite=false
io={open=function(path,mode)if mode=='r' and not files[path]then return nil end;if mode=='w' and failWrite then return nil end;return {path=path,mode=mode}end,
 read=function(f,n)return files[f.path]:sub(1,n)end,write=function(f,s)files[f.path]=s end,close=function()end}
model={getInfo=function()return {name='UX TEST'}end,getSensor=function(i)if i==0 then return {name='GPS'}end end}
EVT_VIRTUAL_ENTER=1;EVT_VIRTUAL_NEXT=2;EVT_VIRTUAL_PREV=3;EVT_TOUCH_TAP=4;EVT_VIRTUAL_EXIT=5;EVT_VIRTUAL_NEXT_PAGE=6
CUSTOM_COLOR=0;SMLSIZE=0;RIGHT=0
local texts,textColors,textPositions,currentColor={},{},{},nil
lcd={RGB=function(r,g,b)return r*65536+g*256+b end,setColor=function(_,color)currentColor=color end,drawFilledRectangle=function()end,drawText=function(x,y,s)texts[#texts+1]=tostring(s);textColors[tostring(s)]=currentColor;textPositions[tostring(s)]={x,y} end}
getTime=function()return 100 end;playTone=function()end;playHaptic=function()end
local source='local fcLink={state={status="DISARMED",firmware="BF"}}\nlocal function cachedTelemetryField()return nil end\nlocal function cachedField()return nil end\n'..batterySource..configurationSource..'\nreturn batteryConfig,configuration'
local factory,why=loadstring(source,'@config-closures');assert(factory,why)
local battery,config=factory()
local function event(e)assert(config.input(e),'expected handled event '..e)end
local function touch(x,y)assert(config.input(EVT_TOUCH_TAP,{x=x,y=y}),'expected handled touch')end
local function contains(value)for _,v in ipairs(texts)do if v==value then return true end end;return false end
local function draw()texts={};textColors={};textPositions={};config.draw()end
local function nextN(n)for _=1,n do event(EVT_VIRTUAL_NEXT)end end
local function saveApp()touch(190,230)end
local function editFirst(delta)
 event(EVT_VIRTUAL_ENTER)
 for _=1,math.abs(delta)do event(delta>0 and EVT_VIRTUAL_NEXT or EVT_VIRTUAL_PREV)end
 event(EVT_VIRTUAL_ENTER)
end
local assertions=0
local function check(ok,label)assert(ok,label);assertions=assertions+1 end
battery.init();config.init()
check(config.isList(),'setup starts on category list')
check(#config.visible()==10,'Auto exposes every active default provider category')
draw();check(contains('PREVIOUS')and contains('NEXT'),'active Auto categories have bounded paging controls')
check(not config.hasChanges(),'new defaults are clean')
check(config.get('rcProtocol')=='Auto' and config.get('fcType')=='Auto' and config.get('mspMode')==1,'None-as-auto and enabled MSP defaults preserved')
check(not config.input(EVT_VIRTUAL_NEXT_PAGE),'global PAGE is not consumed by setup')
check(not config.input(EVT_VIRTUAL_EXIT),'root owns RTN dispatch')
check(not config.back(),'list back delegates to root')

assert(config.openSection(1));event(EVT_VIRTUAL_ENTER);event(EVT_VIRTUAL_NEXT)
check(config.isEditing() and config.hasChanges(),'editing creates pending draft')
check(config.get('rcProtocol')=='Auto','draft has no runtime effect')
check(config.back(),'RTN cancels only current edit')
check(not config.isEditing() and not config.hasChanges(),'cancel restores original single value')
editFirst(1)
check(config.get('rcProtocol')=='Auto' and config.hasChanges(),'accepting value still requires Settings save')
event(EVT_VIRTUAL_ENTER);event(EVT_VIRTUAL_NEXT);check(config.back() and config.hasChanges(),'cancelling a later edit preserves the previously accepted draft value')
check(config.back() and config.isList() and config.hasChanges(),'category back retains staged Settings changes')
draw();check(contains('SETTINGS* '),'category list exposes pending Settings store')
config.openSection(1);saveApp()
check(config.get('rcProtocol')=='ELRS / CRSF' and not config.hasChanges(),'Save App activates staged values')
local appPath='/SCRIPTS/TOOLS/AERODECK/settings-55582054455354.cfg'
local batPath='/SCRIPTS/TOOLS/AERODECK/battery-55582054455354.cfg'
check(files[appPath] and files[appPath]:sub(1,7)=='ADCFG1\n' and files[appPath..'.bak'],'existing Settings format and backup preserved')

-- The duplicated Application connection setting is functional even when FC list is hidden.
config.openSection(12);editFirst(-1)
check(config.get('mspMode')==1 and config.hasChanges(),'shared MSP edit remains staged')
event(EVT_VIRTUAL_NEXT);event(EVT_VIRTUAL_NEXT);event(EVT_VIRTUAL_ENTER)
check(config.get('mspMode')==0 and not config.hasChanges(),'rotary skips informational rows, passes Error Log and reaches Save Settings')

-- Enable the remaining conditional lists without changing the stored schema.
config.openSection(1);event(EVT_VIRTUAL_NEXT);editFirst(1);event(EVT_VIRTUAL_NEXT);editFirst(2);saveApp()
check(config.get('fcType')=='Betaflight' and config.get('vtxMode')==2 and #config.visible()==12,'all twelve existing categories remain available under their conditions')
config.openSection(5);editFirst(1);saveApp()
config.openSection(12);draw();check(contains('Auto / protocol'),'Flight Controller and Application share the same MSP value')
touch(100,70);check(not config.isEditing(),'touching an informational note does not enter editing')
config.openSection(1,'baro');draw()
check(contains('Barometric altitude'),'barometer source is a real selectable field')
config.openSection(1,'airspeed');draw()
check(contains('Airspeed'),'pitot source is a real selectable field')
for id=1,12 do check(config.openSection(id) and not config.isList(),'category '..id..' opens');check(config.back() and config.isList(),'category '..id..' returns to list')end
-- Paging buttons are visibly disabled at the bounds and never wrap.
config.openSection(1);config.back();draw()
check(textColors.PREVIOUS==lcd.RGB(144,165,178) and textColors.NEXT==lcd.RGB(164,227,125),'first page disables Previous and enables Next')
touch(100,230);event(EVT_VIRTUAL_PREV);event(EVT_VIRTUAL_ENTER);draw();check(contains('MODEL SETUP'),'first-page touch and rotary stay bounded at first category')
config.back();touch(300,230);draw()
check(textColors.PREVIOUS==lcd.RGB(164,227,125) and textColors.NEXT==lcd.RGB(144,165,178),'last page enables Previous and disables Next')
touch(300,230);event(EVT_VIRTUAL_ENTER);draw();check(contains('VTX'),'disabled Next does not wrap or move category selection')
config.back();config.openSection(12);config.back();event(EVT_VIRTUAL_NEXT);event(EVT_VIRTUAL_ENTER);draw();check(contains('APPLICATION'),'rotary remains bounded at last category')
-- Touch the second list page and open its first entry (category8).
config.openSection(1);config.back();touch(300,230);touch(100,70);draw()
for _,label in ipairs({'Video connection','FC MSP','Status read interval (s)'})do check(contains(label),'functional VTX setup renders '..label)end
check(contains('SAVE SETTINGS') and contains('REVERT SETTINGS'),'VTX interval has actual save/revert controls')
config.openSection(8,'vtxPolling');event(EVT_VIRTUAL_ENTER);event(EVT_VIRTUAL_NEXT);event(EVT_VIRTUAL_ENTER)
check(config.get('vtxPolling')==5 and config.hasChanges(),'VTX interval remains draft until Save')
touch(200,230);check(config.get('vtxPolling')==6 and not config.hasChanges(),'VTX interval Save activates actual scheduler setting')

-- Battery is a separate file/store, with independent cancellation and physical actions.
config.openSection(3);event(EVT_VIRTUAL_ENTER);event(EVT_VIRTUAL_NEXT)
local _,cells=battery.check(16,false)
check(cells==0 and battery.hasChanges(),'battery draft does not affect active thresholds')
check(config.back() and not battery.hasChanges() and not config.isList(),'battery RTN cancels value before leaving category')
editFirst(1);nextN(8);event(EVT_VIRTUAL_ENTER)
_,cells=battery.check(16,false)
check(cells==1 and not battery.hasChanges(),'rotary can reach Save Battery')
check(files[batPath] and files[batPath]:sub(1,7)=='ADBAT1 ' and files[batPath..'.bak'],'existing battery format and backup preserved')
config.openSection(3);editFirst(1);event(EVT_VIRTUAL_PREV);event(EVT_VIRTUAL_ENTER)
check(not battery.hasChanges(),'rotary can reach Revert Battery')
_,cells=battery.check(16,false);check(cells==1,'battery revert preserves runtime value')

config.openSection(1);editFirst(1)
config.openSection(3);editFirst(1);touch(190,230)
check(config.hasAppChanges() and not battery.hasChanges(),'Save Battery does not apply Settings draft')
config.back();draw();check(contains('SETTINGS* '),'dirty Settings badge survives saving battery')
config.openSection(1);saveApp()
config.openSection(3);editFirst(1)
config.openSection(1);editFirst(1);saveApp()
check(battery.hasChanges() and not config.hasAppChanges(),'Save Settings does not apply battery draft')
config.openSection(nil);draw();check(contains('BATTERY*'),'pending battery badge appears on category list')
config.discardAll()
check(not config.hasChanges() and not config.isEditing(),'exit guard can explicitly discard both drafts')

-- Linked threshold editing preserves a strict feasible order and full RTN rollback.
config.openSection(3);nextN(3);editFirst(-4)
check(battery.save() and not battery.hasChanges(),'neighbor coupling keeps edited threshold order valid')
local thresholds=battery.values();for i=2,5 do check(thresholds[i]<thresholds[i+1],'coupled battery thresholds remain strictly increasing')end
battery.open();nextN(3);event(EVT_VIRTUAL_ENTER);for i=1,10 do event(EVT_VIRTUAL_PREV)end
check(battery.back() and not battery.hasChanges(),'RTN cancels the complete linked threshold edit')
config.openSection(1);local oldProtocol=config.get('rcProtocol');editFirst(1);failWrite=true
check(not config.save() and config.get('rcProtocol')==oldProtocol and config.hasChanges(),'failed Settings storage write leaves active values unchanged and draft available')
failWrite=false;config.discardAll()

-- Reopening preserves both successful stores and starts at the category list.
battery.init();config.init()
check(config.isList() and not config.hasChanges(),'reinit starts clean on list')
check(config.get('rcProtocol')==oldProtocol,'Settings saved state reloads')
_,cells=battery.check(16,false);check(cells==2,'battery saved state reloads independently')
local measurements=0
lcd.sizeText=function()measurements=measurements+1;return 20,19 end
config.openSection(nil);draw()
check(measurements==1,'category list measures font height once per draw')
check(textPositions['SETUP CATEGORIES'][2]==38,'category header centers measured19px font inside26px header')
check(textPositions['MODEL SETUP'][2]==63,'category row centers measured19px font inside18px row')
check(textPositions.NEXT[2]==223,'category paging centers measured19px font inside21px action')
measurements=0;config.openSection(3);draw()
check(measurements==2,'battery view measures once in each of its two local draw functions')
check(textPositions['MODEL BATTERY'][2]==38 and textPositions['Pack cell count'][2]==63,'battery header and first row use measured height')
check(textPositions['SAVE BATTERY'][2]==223,'battery action uses measured height')
lcd.sizeText=function()return 20,17 end
config.openSection(1);draw()
check(textPositions['RC protocol profile'][2]==64,'native17px settings row has zero extra top padding')
check(textPositions['SAVE SETTINGS'][2]==224,'native17px settings action centers in21px box')
lcd.sizeText=nil

-- Native Lua uses float32. A valid full 6S pack can arrive slightly above 25.2
-- when represented in that format; the previous direct comparison called it overcharged.
files[batPath]='ADBAT1 6,27,30,34,36,42,0,0\n'
battery.init()
local nativeFullPack=25.200000762939453
check(nativeFullPack/6*10>42,'the old unquantized comparison reproduces the native false-maximum warning')
local tones,haptics=0,0
playTone=function()tones=tones+1 end;playHaptic=function()haptics=haptics+1 end
local boundaryCases={
 -- No power includes its exact limit; the next interval is below minimum.
 {16.194,'NO PACK POWER','below no-power'},
 {16.2,'NO PACK POWER','exact no-power'},
 {16.206,'BELOW MINIMUM','above no-power'},
 -- Minimum uses strict<; its exact limit already belongs to critical.
 {17.994,'BELOW MINIMUM','below minimum'},
 {18,'BATTERY CRITICAL','exact minimum'},
 {18.006,'BATTERY CRITICAL','above minimum'},
 -- Critical and low retain their inclusive upper bounds.
 {20.394,'BATTERY CRITICAL','below critical'},
 {20.4,'BATTERY CRITICAL','exact critical'},
 {20.406,'BATTERY LOW','above critical'},
 {21.594,'BATTERY LOW','below low'},
 {21.6,'BATTERY LOW','exact low'},
 {21.606,nil,'above low'},
 -- Maximum uses strict>; a meaningful 1 mV/cell increase must still warn.
 {25.194,nil,'below maximum'},
 {25.2,nil,'exact maximum'},
 {25.206,'ABOVE MAXIMUM','above maximum'},
 -- Explicit float32 encodings exercise the actual radio representation.
 {16.200000762939453,'NO PACK POWER','native no-power'},
 {20.399999618530273,'BATTERY CRITICAL','native critical'},
 {21.600000381469727,'BATTERY LOW','native low'},
 {nativeFullPack,nil,'native maximum'},
 {0,'NO PACK POWER','real zero pack voltage'},
}
for _,case in ipairs(boundaryCases)do
 local status,count=battery.check(case[1],false,6)
 check(status==case[2],case[3]..' preserves the existing battery boundary policy; got '..tostring(status))
 check(count==6,case[3]..' uses the explicit 6-cell override')
end
local missingStatus,missingCells=battery.check(nil,false,6)
check(missingStatus==nil and missingCells==6,'missing voltage cannot produce a synthetic battery warning')
check(tones==0 and haptics==0,'the visual-only saved profile remains silent across all boundary checks')
io=hostio
print('PASS: '..assertions..' configuration UX and native battery-boundary assertions')

config.refreshSensorChoices({'GPS','VFAS','Tmp1'});config.openSection(2,'rcSubtype');event(EVT_VIRTUAL_ENTER);event(EVT_VIRTUAL_NEXT);event(EVT_VIRTUAL_ENTER);draw()
check(contains('ELRS 2.x'),'sensor-choice refresh preserves protocol subtype choices')
