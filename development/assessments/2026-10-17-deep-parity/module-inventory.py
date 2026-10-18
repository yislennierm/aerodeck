from pathlib import Path
import json,hashlib,importlib.util,collections
H=Path(__file__).resolve().parent
O=H.parent/'toolbox-200-reference/fm2m-toolbox-200-edgetx/FM2M/APPS/TOOLBOX2'
spec=importlib.util.spec_from_file_location('dis53',H.parent/'toolbox-200-reference/disassemble53.py');d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
api={'getValue','getSourceValue','getSourceIndex','getFieldInfo','getTimer','setTimer','resetTimer','getInfo','getSensor','getOutput','getInput','getGlobalVariable','setGlobalVariable','getLogicalSwitch','setLogicalSwitch','getSwitchValue','getSwitchIndex','crossfireTelemetryPush','crossfireTelemetryPop','sportTelemetryPush','sportTelemetryPop','drawHudRectangle','drawBitmap','drawMask','drawLine','drawText','drawFilledTriangle','playTone','playHaptic','playFile','playNumber','playDuration','resetTelemetry','getUsage','getAvailableMemory','getVersion','getGeneralSettings','getTime','collectgarbage','loadScript','loadfile','open','read','write','close','setColor','mkdir','remove','rename'}
rows=[]
for p in sorted(O.rglob('*.luac')):
 parser=d.Dump(p.read_bytes());root=parser.f();assert parser.p==len(parser.raw)
 constants=[];functions=[]
 def walk(f,path='main'):
  constants.extend(v for v in f['k'] if isinstance(v,str));functions.append({'path':path,'firstLine':f['first'],'lastLine':f['last'],'instructions':len(f['code'])})
  for i,child in enumerate(f['protos']):walk(child,path+'/'+str(i))
 walk(root)
 rel=str(p.relative_to(O));parts=rel.split('/')
 domain='configuration' if rel.startswith('LIB/CFG/') else 'transport/control' if rel.startswith(('LIB/MSP/','LIB/VTX/','LIB/FC/')) else 'data/lifecycle' if rel.startswith(('LIB/TLM/','LIB/GPS/','LIB/RD/','LIB/TB/','LIB/FS/','LIB/OS/','WIDGET/')) else 'UI/rendering' if rel.startswith(('UI/','ASSETS/')) else 'root/lifecycle'
 rows.append({'file':rel,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size,'domain':domain,'functions':functions,'apiNameConstants':sorted(set(constants)&api),'stringConstants':constants})
result={'modules':rows,'countsByDomain':dict(collections.Counter(r['domain'] for r in rows)),'note':'API-name constants are an inventory/review aid, not proof of reachable calls. Detailed evidence traces control flow.'}
(H/'module-inventory.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'modules':len(rows),'countsByDomain':result['countsByDomain']},indent=2))
for r in rows:
 if r['domain'] in ['root/lifecycle','data/lifecycle'] and set(r['apiNameConstants'])&{'setTimer','resetTimer','setGlobalVariable','resetTelemetry','write','getGeneralSettings','playNumber'}:
  print(r['file'],','.join(r['apiNameConstants']))
