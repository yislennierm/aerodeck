from pathlib import Path
import json,hashlib
H=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
path=H/'data-rows.json'; rows=json.loads(path.read_text())
for r in rows:
    if r['id']=='DATA-001':
        r['feature']='Basic qualified CRSF/ELRS sensor access'
        r['toolbox']='TBS family registers qualified native telemetry names and numeric source IDs; individual family decoders are assessed separately.'
        r['aerodeck']='Qualified native names and cached numeric IDs supply current values; complete protocol coverage is not claimed by this row.'
    if r['id']=='DATA-044':
        r['feature']='Conditional accelerometer modules / disabled runtime registration'
        r['status']='unverified'
        r['toolbox']='FRS/TBS ACC modules define X/Y/Z readers, but TLMINIT registers them only when MDL_ACC_ON is true. Supplied initialization/save force it off and its selector is hidden; no reachable bypass or active producer was found.'
        r['aerodeck']='No three-axis acceleration fields. This is not scored as a proven accessible Toolbox feature gap.'
        r['userImpact']='Module presence alone would incorrectly inflate parity requirements. Keep actual source availability and consumer reachability open.'
        r['acceptance']='Prove an accessible producer/registration path before treating measured acceleration as required parity. If implemented as an addition, use real axis sources and units, never fabricated vectors.'
        r['requiredForReplacement']=False
        for f in ['data-evidence/LIB-TLM-TLMINIT.txt','config-evidence/CFGMDL.txt','config-evidence/CFGUPD.txt']:
            p=H/f
            if not any(e['file']==str(p) for e in r['evidence']):r['evidence'].append(dict(file=str(p),line=1,kind='original-bytecode-disassembly',sha256=sha(p)))
    if r['id']=='DATA-107':
        r['feature']='Diagnostic error-log file / defective reference toggle'
        r['toolbox']='FSLOG appends queued diagnostics to lua_log.txt. Original CFGAPP uses APP_errLog but runtime/serialization use APP_LOG_ERR; numeric0 remains truthy in the consumer. A working user opt-in toggle is not proven.'
        for f,line in [('config-evidence/CFGAPP.txt',1),('data-evidence/MAIN-ML.txt',1),('data-evidence/LIB-TB-DATAINIT.txt',1)]:
            p=H/f
            if not any(e['file']==str(p) for e in r['evidence']):r['evidence'].append(dict(file=str(p),line=line,kind='original-bytecode-disassembly',sha256=sha(p)))
    if r['id']=='DATA-113':
        r['aerodeck']='Native values are read through source APIs. Filesystem writes are app settings/backups; uplink packets use FC read commands and consume shared CRSF queues/link bandwidth. No model/FC/RF setting writes are present.'
    if r['id']=='DATA-118':
        r['feature']='Runtime-filtered radio-input inventory'
        r['toolbox']='RDINP probes known switchesSA–SJ,potsS1–S4/6pos,LS/RS and trimsT1–T6 with getFieldInfo/getSourceName, retaining candidates that resolve. This is not arbitrary telemetry or hardware discovery.'
        r['acceptance']='Probe supported radio-input candidates, expose those that resolve and diagnose missing saved inputs; unavailable hardware must not create phantom choices.'
path.write_text(json.dumps(rows,indent=2,ensure_ascii=False)+'\n')
notes={'review':'Independent cross-domain peer review; production unchanged.','corrections':[{'id':'DATA-001','change':'Narrow equivalent claim to basic qualified access, not full protocol family.'},{'id':'DATA-044','change':'Accelerometer registration is gated off; do not invent an accessible Toolbox feature from module presence.'},{'id':'DATA-107','change':'Separate real logger from defective/unproven user toggle.'},{'id':'DATA-113','change':'Read commands still consume shared transport and link bandwidth.'},{'id':'DATA-118','change':'Known radio-input candidates are probed; no arbitrary source discovery.'}]}
(H/'peer-review.json').write_text(json.dumps(notes,indent=2)+'\n')
