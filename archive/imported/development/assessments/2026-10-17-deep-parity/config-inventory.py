from pathlib import Path
import json,re,hashlib,importlib.util
H=Path(__file__).resolve().parent;R=Path('/Users/nene/Documents/fpv-1');T=R/'toolbox2_source/APPS/TOOLBOX2'
O=H.parent/'toolbox-200-reference/fm2m-toolbox-200-edgetx/FM2M/APPS/TOOLBOX2'
spec=importlib.util.spec_from_file_location('dis53',H.parent/'toolbox-200-reference/disassemble53.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
modules=['CFGMDL','CFGRCL','CFGBAT','CFGBFV','CFGFC','CFGIND','CFGINDBF','CFGVTX','CFGVFV','CFGGPS','CFGUI','CFGAPP']
rows=[]
for name in modules:
 p=T/'LIB/CFG'/(name+'.lua');original=O/'LIB/CFG'/(name+'.luac');text=p.read_text()
 parser=module.Dump(original.read_bytes());proto=parser.f();assert parser.p==len(parser.raw)
 constants=[]
 def walk(f):
  constants.extend(v for v in f['k'] if isinstance(v,str))
  for child in f['protos']:walk(child)
 walk(proto)
 fields=[]
 for match in re.finditer(r'T\.cv\.([\w]+)\s*=\s*\{([^\n]+)',text):
  key=match.group(1);body=match.group(2);label=re.search(r'\bl\s*=\s*"((?:\\.|[^"\\])*)"',body)
  order=re.search(r'\bo\s*=\s*(\d+)',body);typ=re.search(r'\bt\s*=\s*"([^"]+)"',body)
  label=bytes(label.group(1),'utf8').decode('unicode_escape') if label else None
  fields.append({'key':key,'label':label,'order':int(order.group(1)) if order else None,'type':typ.group(1) if typ else None,'sourceLine':text[:match.start()].count('\n')+1,'fieldNameInOriginalConstants':key in constants,'labelInOriginalConstants':label in constants if label else None})
 rows.append({'module':name,'source':'toolbox2_source/APPS/TOOLBOX2/LIB/CFG/'+name+'.lua','sourceSha256':sha(p),'originalFile':str(original),'originalSha256':sha(original),'fields':fields,'originalStringConstants':constants,'dynamicFields':name in ['CFGBFV','CFGVFV','CFGUI']})
(H/'toolbox-config-declarations.json').write_text(json.dumps(rows,indent=2)+'\n')
print(json.dumps({'pages':len(rows),'literalFields':sum(len(x['fields']) for x in rows),'fieldNameVerified':sum(f['fieldNameInOriginalConstants'] for x in rows for f in x['fields']),'labelsVerified':sum(f['labelInOriginalConstants'] is True for x in rows for f in x['fields'])},indent=2))
