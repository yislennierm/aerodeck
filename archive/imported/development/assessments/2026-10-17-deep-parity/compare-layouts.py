from pathlib import Path
import importlib.util,hashlib,json,collections
O=Path(__file__).parent;T=Path('/Users/nene/Documents/Codex/2026-10-12/i-x20/work/edgetx/toolbox-200-reference/fm2m-toolbox-200-edgetx/FM2M/APPS/TOOLBOX2')
spec=importlib.util.spec_from_file_location('lua53',str(O.parent/'toolbox-200-reference/disassemble53.py'));mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
def flatten(f):
 yield f
 for q in f['protos']:yield from flatten(q)
def semantic(f,numeric=False):
 d={k:f[k] for k in ['params','vararg','stack','code','k','upvalues']}
 if numeric:d['k']=['<NUMBER>' if type(v)in[int,float] else v for v in f['k']]
 d['protos']=[semantic(q,numeric) for q in f['protos']];return d
def sha(d):return hashlib.sha256(json.dumps(d,sort_keys=True).encode()).hexdigest()
res=['480X272','480X320','800X480'];families=sorted({str(p.relative_to(T/'UI'/r)) for r in res for p in (T/'UI'/r).rglob('*.luac')});rows=[]
for rel in families:
 parts={};funs={}
 for r in res:
  p=T/'UI'/r/rel
  if not p.exists():parts[r]={'missing':True};continue
  d=mod.Dump(p.read_bytes());f=d.f();assert d.p==len(d.raw)
  fs=list(flatten(f));ss=sorted({s for q in fs for s in q['k'] if isinstance(s,str)});numbers=[v for q in fs for v in q['k'] if type(v)in[int,float]]
  parts[r]=dict(file=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),byteSize=p.stat().st_size,functionCount=len(fs),instructionCount=sum(len(q['code'])for q in fs),stringConstants=ss,numberConstants=numbers,semanticFingerprint=sha(semantic(f)),numericWildcardFingerprint=sha(semantic(f,True)),opcodeSequenceFingerprint=sha([[w&63 for w in q['code']]for q in fs]),opcodeCounts=dict(collections.Counter(mod.OPS[w&63] for q in fs for w in q['code'])))
  funs[r]=f
 base=parts[res[0]];comparisons=[]
 for r in res[1:]:
  p=parts[r]
  if p.get('missing'):comparisons.append(dict(resolution=r,missing=True));continue
  comparisons.append(dict(resolution=r,semanticExact=base['semanticFingerprint']==p['semanticFingerprint'],numericWildcardMatch=base['numericWildcardFingerprint']==p['numericWildcardFingerprint'],opcodeSequenceMatch=base['opcodeSequenceFingerprint']==p['opcodeSequenceFingerprint'],stringsOnlyIn272=sorted(set(base['stringConstants'])-set(p['stringConstants'])),stringsOnlyInAlternative=sorted(set(p['stringConstants'])-set(base['stringConstants'])),instructionDelta=p['instructionCount']-base['instructionCount'],functionDelta=p['functionCount']-base['functionCount']))
 rows.append(dict(family=rel,variants=parts,comparisonsTo480x272=comparisons,reviewScope='Parsed all original prototype constants, complete instruction words and recursive opcode sequence. Does not establish runtime/semantic equivalence; numeric constants can affect behavior, not just geometry.'))
(O/'layout-family-coverage.json').write_text(json.dumps(dict(originalRoot=str(T),resolutions=res,layoutFamilyCount=len(rows),rows=rows,limitations=['Numeric-normalized fingerprints are not a proof of functional equivalence.','String/symbol identity does not prove identical branches, numerical bounds or runtime behavior.','All variants require actual native layout/platform input verification.']),indent=2)+'\n')
for row in rows:
 print(row['family'],json.dumps(row['comparisonsTo480x272']))
