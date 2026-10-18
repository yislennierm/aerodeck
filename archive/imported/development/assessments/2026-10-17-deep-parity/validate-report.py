from pathlib import Path
import json,hashlib,collections,re,urllib.parse,datetime
H=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
d=json.loads((H/'assessment.json').read_text())
checks={};errors=[]
checks['rows']=len(d['rows']);checks['uniqueIDs']=len(set(r['id'] for r in d['rows']))
refs=0
for r in d['rows']:
    for k in ['id','feature','toolbox','aerodeck','status','evidence','dependencies','userImpact','acceptance','priority','confidence']:
        if k not in r:errors.append(r['id']+' missing '+k)
    if r['status'] not in ['equivalent','partial','missing','unverified','addition']:errors.append('Bad status '+r['id'])
    for e in r['evidence']:
        refs+=1;p=H/e['portableFile']
        if not p.exists():errors.append('Missing portable file '+str(p));continue
        if sha(p)!=e['sha256']:errors.append('Bad pinned evidence hash '+str(p))
        if not 1<=e['line']<=max(1,len(p.read_text(errors='replace').splitlines())):errors.append('Bad evidence line '+str(p))
checks['evidenceReferences']=refs
checks['scope']=d['scope']
s=json.loads((H/'source-snapshot.json').read_text());root=Path(s['aerodeckRoot'])/'sdcard'
changed=[]
for rel,want in s['runtimeHashMap'].items():
    p=root/rel
    if not p.exists() or sha(p)!=want:changed.append(rel)
checks['productionRuntimeFilesChecked']=len(s['runtimeHashMap']);checks['changedProductionFiles']=changed
if changed:errors.append('Production baseline changed')
text=(H/'index.html').read_text()
inline=json.loads(re.search(r'<script id="data" type="application/json">(.*?)</script>',text,re.S).group(1))
checks['embeddedRows']=len(inline['report']['rows'])
links=re.findall(r'(?:href|src)="([^"]+)"',text)
missing=[]
for a in links:
    if a.startswith(('#','http:','https:','data:')):continue
    if not (H/urllib.parse.unquote(a.split('#')[0])).is_file():missing.append(a)
checks['staticLinksChecked']=len(links);checks['missingStaticLinks']=missing
errors+=['Missing static link '+f for f in missing if f!='validation.json']
checks['moduleInventory']=len(json.loads((H/'module-inventory.json').read_text())['modules'])
checks['coverageRows']=len(json.loads((H/'coverage.json').read_text())['modules'])
checks['configurationFieldRows']=sum('referenceField' in r for r in d['rows'])
checks['configurationWorkflowRows']=sum(r['id'].startswith('CFG-X') for r in d['rows'])
checks['physicalHardwareTestPerformed']=False
checks['browserVisualVerification']='Unavailable: computer-use browser inventory is empty. Static links,embedded data and JS behavior checked separately; no report-browser screenshot claimed.'
checks['errors']=errors;checks['passed']=not errors
checks['checkedAt']=datetime.datetime.now().astimezone().isoformat()
(H/'validation.json').write_text(json.dumps(checks,indent=2)+'\n')
print(json.dumps(checks,indent=2));assert not errors
