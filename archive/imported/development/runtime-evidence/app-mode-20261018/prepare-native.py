from pathlib import Path
import hashlib,json,shutil,sys,re
W=Path(__file__).resolve().parent;H=W.parent/'current-preview-20261018';P=Path('/Users/nene/Documents/fpv-1/radiomaster_tx16s_mkII/LUA');R=W/'runtime'
sys.path.insert(0,str(H));from runtime_inventory import inventory
if not R.exists():shutil.copytree(H/'runtime',R)
m=inventory(P)
for n,h in m.items():
 p=R/'sd'/n.removeprefix('sdcard/');p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(P/n,p)
for name in ['QAENV.lua','QAMSP.lua']:shutil.copy2(H/'fixtures/warm'/name,R/'sd/SCRIPTS/TOOLS'/name)
# Bind the true production widget under a private alias; no source injection.
shutil.copy2(P/'sdcard/WIDGETS/AERODECK/main.lua',R/'sd/SCRIPTS/TOOLS/QAWIDGET.lua')
s=(H.parent/'replacement-native-qa/dev-driver/main.template.lua').read_text().replace('__CASE__','animated')
s=s.replace('APP LOAD','WIDGET LOAD').replace('APP CHUNK','WIDGET CHUNK').replace('APP INIT','WIDGET CREATE')
s=s.replace("w.env.loadScript,'/SCRIPTS/TOOLS/telem.lua','t'", "w.env.loadScript,'/SCRIPTS/TOOLS/QAWIDGET.lua','t'")
s=s.replace('w.app=a;w.appLoader=nil','w.widget=a;w.appLoader=nil')
a=s.index(' elseif n==13 then');b=s.index(" print('QA_DEV_STAGE|",a)
s=s[:a]+''' elseif n==13 then
  w.inner=w.widget.create(w.zone,{})
 end
'''+s[b:]
a=s.index('local function service(w)');b=s.index('local function draw(w)',a)
s=s[:a]+'''local function service(w)
 if w.error then return end
 if w.stage then advance(w);return end
 w.env.qaTick()
 call(w,'WIDGET BACKGROUND',w.widget.background,w.inner)
end
'''+s[b:]
a=s.index('local function refresh(w,event,touch)');b=s.index('local function update(w,options)',a)
s=s[:a]+'''local function refresh(w,event,touch)
 if w.stage or not w.widget or w.error then
  if w.stage then advance(w)end;draw(w);return
 end
 w.env.qaTick()
 call(w,'WIDGET REFRESH',w.widget.refresh,w.inner,event,touch)
 local focus=event~=nil
 if w.lastFocus~=focus then print('QA_NATIVE_FOCUS|'..tostring(focus));w.lastFocus=focus end
 if w.inner.app and not w.verified then
  print('QA_NATIVE_WIDGET_STARTED|'..tostring(w.zone.x)..','..tostring(w.zone.y)..','..tostring(w.zone.w)..','..tostring(w.zone.h)..'|event='..tostring(event));w.verified=true
 end
end
'''+s[b:]
(R/'sd/WIDGETS/AERODECK/main.lua').write_text(s)
model=R/'settings/MODELS/model1.yml';s=model.read_text();a=s.index('screenData:');b=s.index('topbarData:',a)
s=s[:a]+'''screenData:
   0:
      LayoutId: Layout1x1AM
      layoutData:
         zones:
            0:
               widgetName: AERODECK
               widgetData:
'''+s[b:];model.write_text(s)
for p in R.rglob('*.luac'):p.unlink()
shutil.copy2(H/'host-pump.cjs',W/'host-pump.cjs')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(R/'sd/SCRIPTS/TOOLS/QAWIDGET.lua')==m['sdcard/WIDGETS/AERODECK/main.lua']
for n,h in m.items():
 if n!='sdcard/WIDGETS/AERODECK/main.lua':assert sha(R/'sd'/n.removeprefix('sdcard/'))==h
j={'build':'APP-MODE-20261018','runtimeSHA256':m,'layout':'Layout1x1AM','sampleTelemetry':True,'nativeCallbackInstructionBudget':20000,'nativeBudgetHookModified':False,'productionWidgetAlias':'SCRIPTS/TOOLS/QAWIDGET.lua','productionWidgetByteExact':True,'fixtureFiles':{n:sha(R/'sd'/n)for n in ['WIDGETS/AERODECK/main.lua','SCRIPTS/TOOLS/QAENV.lua','SCRIPTS/TOOLS/QAMSP.lua']}}
(W/'inputs.json').write_text(json.dumps(j,indent=2)+'\n');print('Private native App mode fixture ready; production widget is byte-exact.')
