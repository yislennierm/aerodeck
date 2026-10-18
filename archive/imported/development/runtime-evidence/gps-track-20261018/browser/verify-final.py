"""Read-only final-preview verification: no keys, touches, rotary, or screen input."""
from pathlib import Path
import argparse,datetime,hashlib,json,shutil,struct,time,urllib.error,urllib.request,zlib
D=Path(__file__).resolve().parent
H=D.parent.parent/'current-preview-20261018'
p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8766);p.add_argument('--expected',required=True);a=p.parse_args();base='http://127.0.0.1:'+str(a.port)
def req(path,head=None):
 try:
  with urllib.request.urlopen(urllib.request.Request(base+path,headers=head or{}),timeout=3)as r:return r.status,dict(r.headers),r.read()
 except urllib.error.HTTPError as e:return e.code,dict(e.headers),e.read()
for _ in range(35):
 try:
  status,headers,raw=req('/build')
  if status==200:break
 except (OSError,urllib.error.URLError):pass
 time.sleep(1)
else:raise SystemExit('Owned preview did not finish native startup')
b=json.loads(raw);assert b['sourceSHA256']==a.expected and not b['sourceDrift']and b['runtimeCount']==64
canonical=Path(b['canonicalRoot']);assert canonical==Path('/Users/nene/Documents/fpv-1/radiomaster_tx16s_mkII/LUA')
actual={name:hashlib.sha256((canonical/name).read_bytes()).hexdigest()for name in b['runtimeSHA256']};assert actual==b['runtimeSHA256']
(D/('final-'+a.expected[:12]+'-build.json')).write_bytes(raw)
head={'X-AERODECK-Source':a.expected};status,headers,frame=req('/frame',head);assert status==200 and len(frame)==480*272*2
(D/('final-'+a.expected[:12]+'-preview.rgb565')).write_bytes(frame)
assert headers['X-AERODECK-Source']==a.expected
assert req('/frame')[0]==428 and req('/frame',{'X-AERODECK-Source':'stale'})[0]==409
status,headers,html=req('/');text=html.decode();assert status==200 and a.expected in text and b['build']in text and 'LOCAL · NOT INSTALLED'in text and 'SAMPLE TELEMETRY'in text
rgb=bytearray()
for i in range(0,len(frame),2):
 v=frame[i]+frame[i+1]*256;rgb.extend((((v>>11)&31)*255//31,((v>>5)&63)*255//63,(v&31)*255//31))
def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
rows=b''.join(b'\x00'+bytes(rgb[y*480*3:(y+1)*480*3])for y in range(272))
image=D/('final-'+a.expected[:12]+'-preview.png');image.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',480,272,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(rows))+chunk(b'IEND',b''))
log=(H/('server-'+str(a.port)+'.log')).read_text();assert 'QA_DEV_ERROR'not in log and 'CPU limit'not in log
inputs=json.loads((H/'captures/warm/inputs.json').read_text());assert inputs['sourceSha256']==a.expected and inputs['rollDisplayPreference']==0 and inputs['rawPoseMotion']['rollAmplitudeDegrees']==30 and inputs['forcedGCDisabled']and inputs['nativeCallbackInstructionBudget']==20000 and inputs['nativeBudgetHookModified']is False
meta=json.loads((H/('server-'+str(a.port)+'.json')).read_text())
assert meta['sourceSHA256']==a.expected
savedLog=D/('final-'+a.expected[:12]+'-native.log');shutil.copy2(H/('server-'+str(a.port)+'.log'),savedLog)
savedText=savedLog.read_text();assert 'QA_DEV_ERROR'not in savedText and 'CPU limit'not in savedText
status,_,last=req('/build');last=json.loads(last);assert status==200 and not last['sourceDrift']and last['sourceSHA256']==a.expected
report={'verifiedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'canonicalHashesIndependentlyMatched':True,'url':base+'/','build':b['build'],'sourceSHA256':a.expected,'runtimeCount':64,'runtimeSHA256':b['runtimeSHA256'],'sourceDrift':False,'pid':meta['pid'],'image':str(image),'imageSHA256':hashlib.sha256(image.read_bytes()).hexdigest(),'nativeErrors':False,'nativeBudgetHookModified':False,'rollDisplayPreference':0,'sampleRollAmplitudeDegrees':30,'forcedGCDisabled':True,'onlyGetRequests':True,'uiInputsSent':0,'frameGuard':{'missing':428,'stale':409},'localOnly':True,'installed':False,'sampleTelemetry':True,'visualReview':'PENDING','log':str(savedLog),'frameFormat':'480 by 272 pixels, little-endian RGB565'}
out=D/('final-'+a.expected[:12]+'-verification.json');out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'verification':str(out),**{k:report[k]for k in ['url','build','sourceSHA256','pid','image','runtimeCount','sourceDrift','nativeErrors','uiInputsSent']}},indent=2))
