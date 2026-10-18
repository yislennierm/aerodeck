from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,subprocess,collections,importlib.util
H=Path(__file__).resolve().parent;R=Path('/Users/nene/Documents/fpv-1')
A=R/'radiomaster_tx16s_mkII/LUA';T=R/'toolbox2_source/APPS/TOOLBOX2'
O=H.parent/'toolbox-200-reference/fm2m-toolbox-200-edgetx/FM2M/APPS/TOOLBOX2'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((A/'development/build-POWER-LIVE-20261017.json').read_text())
assert sha(A/'sdcard/SCRIPTS/TOOLS/telem.lua')==m['sourceSha256']
assert sha(A/'sdcard/WIDGETS/AERODECK/main.lua')==m['widgetSha256']
files={}
for label,root in [('aerodeck-runtime',A/'sdcard'),('toolbox-recovered',T),('toolbox-original',O)]:
    picked=[root/name for name in m['runtimeSha256']] if label=='aerodeck-runtime' else [p for p in root.rglob('*') if p.is_file() and not p.name.startswith('._')]
    files[label]=[{ 'path':str(p.relative_to(root)),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(picked)]
# Module syntax is evidence only: passing decompilation does not prove equivalent control flow.
recovered=sorted(T.rglob('*.lua'));originals=sorted(O.rglob('*.luac'))
missing=[str(p.relative_to(O)) for p in originals if not (T/p.relative_to(O)).with_suffix('.lua').is_file()]
images={}
try:
 from PIL import Image
 for label,root in [('toolbox-original',O),('aerodeck-runtime',A/'sdcard')]:
  rows=[]
  for record in files[label]:
   p=root/record['path']
   if p.suffix.lower() in ('.png','.bmp','.jpg'):
    with Image.open(p) as im:rows.append({'file':record['path'],'width':im.width,'height':im.height,'mode':im.mode,'format':im.format,'bytes':record['bytes'],'sha256':record['sha256']})
  images[label]=rows
except ImportError:pass
snapshot={'createdAt':datetime.now(ZoneInfo('Europe/Stockholm')).isoformat(),'repoCommit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),'aerodeckBuild':m['build'],'aerodeckRoot':str(A),'toolboxRecoveredRoot':str(T),'toolboxOriginalRoot':str(O),'runtimeHashMap':m['runtimeSha256'],'files':files,'images':images,'counts':{'aerodeckRuntimeFiles':len(files['aerodeck-runtime']),'toolboxRecoveredLua':len(recovered),'toolboxOriginalBytecode':len(originals),'originalModulesWithoutRecoveredSource':missing},'scope':{'excluded':['Activation/licence enforcement mechanism only'],'included':['All functional capabilities, including Toolbox gated capabilities','All source-proven transports, FC variants, supported radio resolutions and lifecycle behaviors'],'firstHardwareAcceptanceTarget':'RadioMaster TX16S MkII /480x272 /EdgeTX2.12.4 /Betaflight /ELRS','referenceEdition':'Supplied fm2m-toolbox-200-edgetx, not an uninspected newer edition'},'claimBoundary':'Source and supplied bytecode/captures audit. Not a physical radio performance or live telemetry certification.'}
(H/'source-snapshot.json').write_text(json.dumps(snapshot,indent=2)+'\n')
print(json.dumps({'commit':snapshot['repoCommit'],'counts':snapshot['counts'],'imageCounts':{k:len(v) for k,v in images.items()}},indent=2))
