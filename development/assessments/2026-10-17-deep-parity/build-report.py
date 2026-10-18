from pathlib import Path
import json,hashlib,collections,html,shutil,datetime,re

H=Path(__file__).resolve().parent
W=H.parents[2]
R=Path('/Users/nene/Documents/fpv-1')
L=R/'radiomaster_tx16s_mkII/LUA'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda n:json.loads((H/n).read_text())
save=lambda n,d:(H/n).write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')

rows=[];excerpts={};problems=[];normalizations=[];sourcefiles={}
for domain in ['ui','data','control','config']:
    a=load(domain+'-rows.json')
    for r in a:
        r['domain']=domain
        for e in r['evidence']:
            p=Path(e['file']);p=p if p.is_absolute() else W/p
            if not p.exists():problems.append('Missing '+str(p));continue
            actual=sha(p)
            if e.get('sha256') and e['sha256']!=actual:
                original=Path(e.get('originalFile','/nonexistent'))
                if original.exists() and sha(original)==e['sha256']:
                    e['originalSha256']=e['sha256'];normalizations.append(str(p))
                else:problems.append('Hash mismatch '+str(p));continue
            e['sha256']=actual
            if p.is_relative_to(H):portable=p.relative_to(H)
            elif p.is_relative_to(R):
                portable=Path('source-evidence/repository')/p.relative_to(R)
            else:
                portable=Path('source-evidence/external')/(actual[:12]+'-'+p.name)
            q=H/portable
            if q!=p:q.parent.mkdir(exist_ok=True,parents=True);shutil.copy2(p,q)
            e['portableFile']=str(portable)
            e['baselineFile']=e['file']
            sourcefiles[str(portable)]=dict(file=str(portable),sha256=actual,baselineFile=str(p),bytes=p.stat().st_size)
            line=e.get('line',1);text=p.read_text(errors='replace').splitlines()
            if not isinstance(line,int) or line<1 or line>max(len(text),1):problems.append('Line out of bounds '+str(p)+':'+str(line));continue
            key=str(portable)+':'+str(line);e['excerptKey']=key
            if p.suffix.lower() in ['.lua','.txt','.cpp','.json','.py','.cjs','.js']:
                start=max(1,line-3);end=min(len(text),line+12)
                excerpts[key]=dict(startLine=start,lines=text[start-1:end],line=line)
        rows.append(r)
    save(domain+'-rows.json',a)
assert len(rows)==350,len(rows)
assert len(set(r['id'] for r in rows))==len(rows)
assert not problems,'\n'.join(problems)

snapshot=load('source-snapshot.json')
archive=W/'work/edgetx/toolbox-200-reference.zip'
snapshot['originalArchive']=dict(file=str(archive),bytes=archive.stat().st_size,sha256=sha(archive),version='Supplied FM2M Toolbox2.0 package; no claim about other editions')
save('source-snapshot.json',snapshot)
scope=dict(onlyExcluded='Activation/licence enforcement mechanism',gatedFunctionalCapabilitiesRequired=True,fullProtocolsAndPackagedResolutionsRequired=True,productionModified=False,hardwareTestedThisAudit=False)
counts={d:dict(collections.Counter(r['status'] for r in rows if r['domain']==d)) for d in ['ui','data','control','config']}
report=dict(schemaVersion=1,title='AERODECK / Toolbox2 deep comparison',date='2026-10-17',baselineCommit=snapshot['repoCommit'],aerodeckBuild=snapshot['aerodeckBuild'],scope=scope,rowCount=len(rows),counts=counts,countsAreCompletionPercentages=False,overlapWarning='Rows include overlapping data,UI,control and configuration contracts. Do not sum as independent features or derive parity%.',rows=rows)
save('assessment.json',report);save('evidence-excerpts.json',excerpts);save('evidence-files.json',list(sourcefiles.values()))

# Coverage describes review depth, rather than equating generated dumps with proof.
inventory=load('module-inventory.json')['modules']
data={r['module']:r for r in load('module-coverage-data.json')['modules']}
control={r['module']:r for r in load('control-module-coverage.json')['modules']}
ui={str(Path(r['path']).relative_to('work/edgetx/toolbox-200-reference/fm2m-toolbox-200-edgetx/FM2M/APPS/TOOLBOX2')):r for r in load('ui-evidence/original-inputs.json')}
cfg={str(Path(r['originalFile']).relative_to(Path(snapshot['toolboxOriginalRoot']))):r for r in load('config-evidence/module-index.json')}
supp={r['module']:r for r in load('supplemental-control-coverage.json')['modules']}
layout=load('layout-family-coverage.json')
layoutmodules={}
for family in layout['rows']:
    for resolution,variant in family['variants'].items():layoutmodules['UI/'+resolution+'/'+family['family']]=family
helpers={r['module']:r for r in layout['commonHelpers']}
coverage=[]
for m in inventory:
    f=m['file'];reviews=[]
    if f in data:reviews.append(data[f]['reviewDepth'])
    if f in control:reviews.append(control[f]['review'])
    if f in ui:reviews.append('UI instrument/lifecycle branch/field review; see individual cited rows, not all instructions')
    if f in cfg:reviews.append('Configuration declaration/persistence/dependency review; recovered symbols checked against original constants; selected control flow checked')
    if f in supp:reviews.append(supp[f]['reviewDepth']+' '+ '; '.join(supp[f]['findings']))
    if f in layoutmodules:
        family=layoutmodules[f]
        reviews.append('Grouped resolution-family review: '+family['reviewScope']+' Observed differences: '+family['reviewedDifferences'])
    if f in helpers:reviews.append(helpers[f]['reviewScope']+' Purpose: '+helpers[f]['purpose'])
    if not reviews:
        reviews=['Grouped inventory/symbol/layout review only; no complete semantic branch review claimed']
    coverage.append(dict(file=f,sha256=m['sha256'],domain=m['domain'],review=reviews,originalDisassemblyAvailable=f in data or f in control or f in ui or f in cfg or f in supp or f in helpers))
save('coverage.json',dict(modules=coverage,total=len(coverage),inventoryOnly=sum(r['review'][0].startswith('Grouped inventory') for r in coverage),caveat='All287 parsed/inventoried; selected material call paths reviewed. This is not formal equivalence or an assertion every branch was semantically audited.'))

# Printable configuration appendix:90 exact declarations +10 workflow contracts.
cfgrows=[r for r in rows if r['domain']=='config']
out=['AERODECK / TOOLBOX2 — CONFIGURATION FIELD AND WORKFLOW MATRIX','Baseline ebb932a / POWER-LIVE-20261017','Only activation enforcement excluded; all functional capabilities remain required.','', '90 declaration rows (65 literal+25 generated), plus10 workflow contracts. Counts overlap other domains; no parity percentage.','Unverified declarations are verification tasks, not silently discarded requirements.','']
for r in cfgrows:
    out += [r['id']+' | '+r['feature']+' | '+r['status'].upper(),'  Toolbox: '+r['toolbox'],'  AERODECK: '+r['aerodeck'],'  Acceptance: '+str(r['acceptance']),'']
(H/'section-config.txt').write_text('\n'.join(out)+'\n')

fig=H/'figures';fig.mkdir(exist_ok=True)
for src,name in [(L/'development/ui-previews/power-live/power-normal-flight.png','aerodeck-flight-native.png'),(L/'development/ui-previews/power-live/power-normal.png','aerodeck-power-native.png'),(H/'ui-evidence/toolbox-critical-assets-contact.png','toolbox-assets.png')]:shutil.copy2(src,fig/name)
shutil.copy2(L/'development/ui-previews/power-live/verification.json',H/'native-preview-provenance.json')
save('figure-provenance.json',[dict(file='figures/aerodeck-flight-native.png',sha256=sha(fig/'aerodeck-flight-native.png'),kind='Exact-source EdgeTX3.0WASM synthetic fixture; not actual2.12.4 quad capture',sourceMainSha256=snapshot['runtimeHashMap']['SCRIPTS/TOOLS/telem.lua']),dict(file='figures/aerodeck-power-native.png',sha256=sha(fig/'aerodeck-power-native.png'),kind='Exact-source synthetic fixture; not live quad'),dict(file='figures/toolbox-assets.png',sha256=sha(fig/'toolbox-assets.png'),kind='Contact sheet of original Toolbox assets, not running UI')])

assessment=html.escape((H/'ASSESSMENT.txt').read_text())
payload=json.dumps(dict(report=report,excerpts=excerpts),ensure_ascii=False).replace('<','\\u003c')
template=(H/'report-template.html').read_text()
(H/'index.html').write_text(template.replace('@@ASSESSMENT@@',assessment).replace('@@PAYLOAD@@',payload))
(H/'README.txt').write_text('Open index.html for the searchable offline assessment.\nRead ASSESSMENT.txt for the principal findings, detailed attitude comparison,12-list analysis and delivery gates.\nassessment.json contains all350 overlapping observations; counts are not parity percentages.\nThe four domain row files, domain narratives, source snapshots, original disassemblies and evidence excerpts preserve review evidence.\ncoverage.json distinguishes grouped inventory from cited material branch/field review.\nOnly activation/licence enforcement is excluded. All actual gated functions and supported protocol/platform capabilities remain in scope.\nNo production Lua, radio or per-model preferences were changed.\n')
print(json.dumps(dict(rows=len(rows),counts=counts,evidenceFiles=len(sourcefiles),uniqueExcerpts=len(excerpts),hashFieldNormalizations=len(normalizations),coverageModules=len(coverage),inventoryOnly=sum(r['review'][0].startswith('Grouped inventory') for r in coverage)),indent=2))
