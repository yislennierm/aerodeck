from pathlib import Path
import shutil,json,hashlib,os
H=Path(__file__).resolve().parent;W=H.parent;P=Path(os.environ.get('QA_PROJECT','/Users/nene/Documents/fpv-1/radiomaster_tx16s_mkII/LUA'));case=os.environ.get('QA_CASE','baseline');R=H/('runtime-'+case);sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
if not R.exists():shutil.copytree(W/'replacement-native-qa/runtime-clean',R)
files=[P/'sdcard/SCRIPTS/TOOLS/telem.lua',P/'sdcard/WIDGETS/AERODECK/main.lua',*sorted((P/'sdcard/SCRIPTS/TOOLS/AERODECK').glob('*.lua')),*sorted((P/'sdcard/SCRIPTS/TOOLS/AERODECK/icons').rglob('*.png'))];runtime={str(f.relative_to(P)):sha(f)for f in files};assert len(runtime)>=64
for f in files:
 q=R/'sd'/f.relative_to(P/'sdcard');q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,q)
for a,b in [('main.lua','WIDGETS/AERODECK/main.lua'),('QAENV.lua','SCRIPTS/TOOLS/QAENV.lua'),('QAMSP.lua','SCRIPTS/TOOLS/QAMSP.lua')]:shutil.copy2(W/'current-preview-20261018/fixtures/warm'/a,R/'sd'/b)
trail=os.environ.get('QA_TRAIL');autoHome=os.environ.get('QA_AUTO_HOME')
q=R/'sd/SCRIPTS/TOOLS/QAENV.lua';env=q.read_text()
if trail:env=env.replace('autoHome=1\\n','autoHome=1\\ntrail='+trail+'\\n',1)
if autoHome:env=env.replace('autoHome=1\\n','autoHome='+autoHome+'\\n',1)
q.write_text(env)
for f in R.rglob('*.luac'):f.unlink()
shutil.copy2(W/'replacement-native-qa/host-pump.cjs',H/'host-pump.cjs')
j={'mainSHA256':runtime['sdcard/SCRIPTS/TOOLS/telem.lua'],'runtimeSHA256':runtime,'sourceFixture':'current-preview-20261018/fixtures/warm','productionMainUnmodified':True,'productionModulesUnmodified':True,'productionWidgetUnmodified':False,'syntheticDataOnly':True,'hardwareVerified':False,'nativeCallbackInstructionBudget':20000,'nativeBudgetHookModified':False,'forcedGC':False,'settingsOverrides':{'trail':trail,'autoHome':autoHome},'driverFiles':{a:sha(R/'sd'/b)for a,b in [('main.lua','WIDGETS/AERODECK/main.lua'),('QAENV.lua','SCRIPTS/TOOLS/QAENV.lua'),('QAMSP.lua','SCRIPTS/TOOLS/QAMSP.lua')]}}
(H/(case+'-inputs.json')).write_text(json.dumps(j,indent=2)+'\n');shutil.copy2(P/'sdcard/SCRIPTS/TOOLS/telem.lua',H/(case+'-main.lua'));print(j['mainSHA256'])
