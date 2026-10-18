// Disposable current native-widget preview. All simulator writes stay private.
const http=process.getBuiltinModule('http'),crypto=process.getBuiltinModule('crypto'),path=process.getBuiltinModule('path');
const HOME=process.env.AERODECK_PREVIEW_HOME||path.resolve(base,'../../.build/preview');
const snapshot=JSON.parse(fs.readFileSync(path.join(HOME,'preview-build.json'),'utf8'));
const SOURCE=snapshot.sourceSHA256,PORT=Number(process.env.AERODECK_PREVIEW_PORT||8767);
if(![8766,8767].includes(PORT))throw Error('Unsupported preview port');
const digest=b=>crypto.createHash('sha256').update(b).digest('hex');
let checkedAt=0,driftCache;
function buildState(force=false){
 if(!force&&driftCache&&Date.now()-checkedAt<500)return driftCache;
 const root=snapshot.canonicalRoot,folder=path.join(root,'sdcard/SCRIPTS/TOOLS/AERODECK');
 const names=['sdcard/SCRIPTS/TOOLS/telem.lua','sdcard/WIDGETS/AERODECK/main.lua'];
 for(const name of fs.readdirSync(folder))if(name.endsWith('.lua'))names.push('sdcard/SCRIPTS/TOOLS/AERODECK/'+name);
 function icons(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const file=path.join(dir,e.name);if(e.isDirectory())icons(file);else if(e.isFile()&&e.name.endsWith('.png'))names.push(path.relative(root,file).split(path.sep).join('/'));}}
 icons(path.join(folder,'icons'));
 const current={};for(const name of names.sort())current[name]=digest(fs.readFileSync(path.join(root,name)));
 const changedFiles=[...new Set([...Object.keys(current),...Object.keys(snapshot.runtimeSHA256)])].filter(name=>current[name]!==snapshot.runtimeSHA256[name]);
 checkedAt=Date.now();driftCache={...snapshot,sourceDrift:changedFiles.length>0,changedFiles,currentSourceSHA256:current['sdcard/SCRIPTS/TOOLS/telem.lua'],currentRuntimeCount:Object.keys(current).length,nativeFrames:lcdStats().frames,runtimeIdentity:digest(JSON.stringify(snapshot.runtimeSHA256))};return driftCache;
}
// Let the bounded widget bootstrap finish, then use the real native context menu.
await sleep(13000);e.simuTouchDown(300,145);await sleep(1100);e.simuTouchUp();await sleep(500);await tap(220,150);await sleep(1800);
const screens=snapshot.screenRoutes;
if(!screens||Object.keys(screens).length!==13||Object.values(screens).some(route=>!Array.isArray(route)||route.length<1||route.length>2||route.some(p=>!Array.isArray(p)||p.length!==2||!Number.isInteger(p[0])||!Number.isInteger(p[1])||p[0]<0||p[0]>=480||p[1]<0||p[1]>=272)))throw Error('Invalid source-derived screen shortcuts');
const html=`<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>AERODECK · Current local native preview</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#08121b;color:#e8f2f5;font:15px system-ui,sans-serif;min-height:100vh;padding:24px 14px}
main{max-width:1000px;margin:auto}h1{font-size:23px;font-weight:650;margin:0 0 6px;letter-spacing:.03em}
p{color:#9bb1bd;margin:7px 0 14px;line-height:1.45}.banner{border:1px solid #eab66a;background:#33271b;color:#ffce89;padding:11px 14px;margin-bottom:20px;font-weight:700;letter-spacing:.05em}
canvas{display:block;width:100%;max-width:480px;height:auto;image-rendering:pixelated;border:1px solid #49616c;touch-action:manipulation;cursor:pointer;background:#000}
.keys,.screens{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}button{color:#edf7fa;background:#19303e;border:1px solid #425f6d;border-radius:5px;padding:11px 15px;font:inherit;cursor:pointer}button:hover,button[aria-pressed="true"]{background:#244856}button:disabled{opacity:.5;cursor:wait}.screens button{font-size:13px;padding:8px 12px}.meta{display:flex;justify-content:space-between;gap:16px;font-size:12px;color:#94aebc;margin-top:9px}.note{font-size:13px}#connection{color:#a4e37d}
</style><main>
<div class="banner">${snapshot.build} / LOCAL · NOT INSTALLED / SAMPLE TELEMETRY</div>
<h1>AERODECK · RadioMaster TX16S</h1>
<p>This runs a snapshot of the current local Lua source in the native TX16S simulator. Click the display to explore.<br>Source <code>${SOURCE.slice(0,12)}</code> · Radio installation: managed separately by your equipment repository. <a href="/build" style="color:#a4e37d">Build details</a> · <a href="/startup" style="color:#68dded">Loading screen</a><br>Release validation is pending for this local development snapshot.</p>
<canvas width="480" height="272" tabindex="0" aria-label="Interactive 480 by 272 radio display"></canvas>
<div class="keys" aria-label="Preview size"><button data-scale="480" aria-pressed="true">1× pixels</button><button data-scale="960" aria-pressed="false">Enlarged</button></div>
<div class="meta"><span id="connection">Connecting to local simulator…</span><span>Native display: 480 × 272 · ←/→: PAGE · ↑/↓: rotary · Escape: RTN</span></div>
<details style="margin-top:14px"><summary style="cursor:pointer;color:#9bb1bd">Simulator keys and screen shortcuts</summary><div class="keys">
<button data-key="13">SYS / Sections</button><button data-key="13" data-duration="1000">Hold SYS / Quick Actions</button><button data-rotary="-1">Rotary ‹</button><button data-rotary="1">Rotary ›</button><button data-key="1">RTN</button><button data-key="2">ENTER</button><button data-key="3">PAGE ‹</button><button data-key="4">PAGE ›</button>
</div>
<div class="screens" aria-label="Open a screen">
<button data-screen="flight">Flight</button><button data-screen="data">Telemetry</button><button data-screen="power">Power</button><button data-screen="link">RC link</button><button data-screen="gps">GPS</button><button data-screen="arm">Arming status</button><button data-screen="inputs">Radio inputs</button><button data-screen="video">Video</button><button data-screen="setup">Setup</button><button data-screen="sticks">Stick guide</button><button data-screen="sensors">Sensors</button><button data-screen="diagnostics">Diagnostics</button>
</div>
</details><p class="note">This session uses synthetic inputs to review screens and interactions. Pixel size depends on your monitor; this is not a physical-size calibration. It does not connect to your radio or prove hardware telemetry performance.</p>
</main><script>
const canvas=document.querySelector('canvas'),ctx=canvas.getContext('2d'),pixels=ctx.createImageData(480,272),status=document.querySelector('#connection');const EXPECTED_SOURCE=${JSON.stringify(SOURCE)};const guarded={'X-AERODECK-Source':EXPECTED_SOURCE};let pending=false,stale=false;
async function frame(){try{const response=await fetch('/frame',{cache:'no-store',headers:guarded});if(response.status===409||response.status===428){stale=true;throw Error('stale');}if(!response.ok)throw Error();const raw=await response.arrayBuffer();if(raw.byteLength!==480*272*2)throw Error();const view=new DataView(raw);for(let i=0,j=0;i<480*272;i++,j+=4){const v=view.getUint16(i*2,true);pixels.data[j]=((v>>11)&31)*255/31;pixels.data[j+1]=((v>>5)&63)*255/63;pixels.data[j+2]=(v&31)*255/31;pixels.data[j+3]=255;}ctx.putImageData(pixels,0,0);if(!pending)status.textContent='Local native simulator · sample telemetry';}catch(_){status.textContent=stale?'Preview source changed — restart the local preview, then refresh this page.':'Simulator disconnected · retrying…';}setTimeout(frame,50);}frame();
async function command(path){if(pending||stale)return;pending=true;document.querySelectorAll('button').forEach(b=>b.disabled=true);status.textContent='Applying simulator input…';try{const r=await fetch(path,{method:'POST',headers:guarded});if(r.status===409||r.status===428){stale=true;throw Error('stale');}if(!r.ok)throw Error();}catch(_){status.textContent=stale?'Preview source changed — refresh after restarting it.':'Input failed · reconnecting…';}finally{pending=false;document.querySelectorAll('button').forEach(b=>b.disabled=false);}}
document.querySelectorAll('[data-scale]').forEach(b=>b.onclick=()=>{canvas.style.maxWidth=b.dataset.scale+'px';document.querySelectorAll('[data-scale]').forEach(item=>item.setAttribute('aria-pressed',String(item===b)));});
document.querySelectorAll('[data-rotary]').forEach(b=>b.onclick=()=>command('/rotary?d='+b.dataset.rotary));
document.querySelectorAll('[data-key]').forEach(b=>b.onclick=()=>command('/key?k='+b.dataset.key+'&d='+(b.dataset.duration||120)));
document.querySelectorAll('[data-screen]').forEach(b=>b.onclick=()=>command('/screen?name='+b.dataset.screen));
canvas.onclick=event=>{const r=canvas.getBoundingClientRect(),x=Math.floor((event.clientX-r.left)*480/r.width),y=Math.floor((event.clientY-r.top)*272/r.height);if(x>=0&&x<480&&y>=0&&y<272)command('/tap?x='+x+'&y='+y);};
document.addEventListener('keydown',event=>{if((event.key==='ArrowUp'||event.key==='ArrowDown')&&!event.repeat){event.preventDefault();command('/rotary?d='+(event.key==='ArrowDown'?1:-1));return;}const map={Escape:1,Enter:2,ArrowLeft:3,ArrowRight:4};if(map[event.key]&&!event.repeat){event.preventDefault();command('/key?k='+map[event.key]+'&d=120');}});
</script></html>`;
// Serve verified recorded startup artwork independently of live simulator input.
function startupCapture(){
 const root=snapshot.canonicalRoot,manifest=JSON.parse(fs.readFileSync(path.join(root,'development','build-'+snapshot.build+'.json'),'utf8'));
 const reportPath=path.join(root,manifest.nativeEvidence.file),reportBytes=fs.readFileSync(reportPath);
 if(digest(reportBytes)!==manifest.nativeEvidence.sha256)throw Error('Startup evidence changed');
 const report=JSON.parse(reportBytes);
 if(report.mainSHA256!==SOURCE||Object.keys(snapshot.runtimeSHA256).some(n=>report.runtimeSHA256[n]!==snapshot.runtimeSHA256[n]))throw Error('Startup capture belongs to another build');
 const entry=report.screens.find(item=>item.file===(report.startupCapture||'startup-043.png'));if(!entry)throw Error('No verified startup capture');
 const png=fs.readFileSync(path.join(path.dirname(reportPath),entry.file));if(digest(png)!==entry.sha256)throw Error('Startup image changed');return png;
}
const startupHtml=`<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>AERODECK loading screen</title>
<style>body{margin:0;padding:28px;background:#08121b;color:#e8f2f5;font:15px system-ui,sans-serif}main{max-width:980px;margin:auto}h1{font-size:23px;margin-bottom:8px}p{color:#9bb1bd;line-height:1.5}img{display:block;width:480px;max-width:100%;height:auto;image-rendering:pixelated;border:1px solid #395464}a{color:#68dded}button{margin:14px 8px 0 0;padding:10px 15px;background:#19303e;color:#e8f2f5;border:1px solid #395464;border-radius:5px;cursor:pointer}</style>
<main><h1>AERODECK loading screen</h1><p>Recorded native TX16S frame · ${snapshot.build} · 480 × 272<br>This is the verified startup capture, shown for inspection. <a href="/">Open the live simulator</a></p>
<img id="capture" src="/startup.png?source=${SOURCE}" width="480" height="272" alt="AERODECK AD logo and loading status on the radio's dark background">
<button onclick="document.getElementById('capture').style.width='480px'">Native pixels</button><button onclick="document.getElementById('capture').style.width='960px'">2× enlarged</button>
<p>Source: <code>${SOURCE.slice(0,12)}</code>. The EdgeTX badge is the firmware's unfocused App mode overlay.</p></main></html>`;
let chain=Promise.resolve(),queued=0;
const send=(res,status,body,type='text/plain; charset=utf-8')=>{if(!res.destroyed){res.writeHead(status,{'Content-Type':type,'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','X-AERODECK-Source':SOURCE});res.end(body);}};
function guard(req,res){
 if(req.headers['x-aerodeck-source']!==SOURCE){send(res,req.headers['x-aerodeck-source']?409:428,'Refresh the browser: preview source identity changed.');return false;}
 let b;try{b=buildState();}catch(err){send(res,503,'Canonical source unavailable');return false;}
 if(b.sourceDrift){send(res,409,JSON.stringify({error:'SOURCE DRIFT — restart local preview',changedFiles:b.changedFiles}),'application/json');return false;}return true;
}
const server=http.createServer((req,res)=>{
 if(!req.url||req.url.length>512){send(res,414,'Request too long');return;}
 let u;try{u=new URL(req.url,'http://127.0.0.1:'+PORT);}catch(_){send(res,400,'Invalid URL');return;}
 if(req.method==='GET'&&u.pathname==='/'){send(res,200,html,'text/html; charset=utf-8');return;}
 if(req.method==='GET'&&(u.pathname==='/startup'||u.pathname==='/startup.png')){
  try{
   if(buildState(true).sourceDrift){send(res,409,'Source changed — restart the local preview');return;}
   const png=startupCapture();
   if(u.pathname==='/startup'){send(res,200,startupHtml,'text/html; charset=utf-8');return;}
   if(u.searchParams.get('source')!==SOURCE){send(res,409,'Startup source identity changed');return;}
   send(res,200,png,'image/png');
  }catch(err){send(res,503,'Verified startup capture is unavailable for this build');}return;
 }
 if(req.method==='GET'&&u.pathname==='/build'){try{send(res,200,JSON.stringify(buildState(true),null,2),'application/json');}catch(err){send(res,503,'Canonical source unavailable');}return;}
 if(req.method==='GET'&&u.pathname==='/frame'){if(!guard(req,res))return;try{const frame=copyFrame();if(!Buffer.isBuffer(frame)||frame.length!==480*272*2)throw Error();send(res,200,frame,'application/octet-stream');}catch(_){send(res,503,'Framebuffer unavailable');}return;}
 if(req.method!=='POST'||!['/key','/tap','/screen','/rotary'].includes(u.pathname)){send(res,404,'Not found');return;}
 if(req.headers.origin&&!['http://127.0.0.1:'+PORT,'http://localhost:'+PORT].includes(req.headers.origin)){send(res,403,'Local origin required');return;}
 if(req.headers['transfer-encoding']||Number(req.headers['content-length']||0)!==0){send(res,400,'Inputs use URL parameters only');req.resume();return;}
 if(!guard(req,res))return;let action;
 if(u.pathname==='/rotary'){const d=Number(u.searchParams.get('d'));if(d!==1&&d!==-1){send(res,400,'Invalid rotary direction');return;}action=async()=>{e.simuRotaryEncoderEvent(d);await sleep(200);};}
 else if(u.pathname==='/key'){const k=Number(u.searchParams.get('k')),d=u.searchParams.has('d')?Number(u.searchParams.get('d')):120;if(![1,2,3,4,13].includes(k)||!Number.isInteger(d)||d<80||d>1000){send(res,400,'Invalid key or duration');return;}action=()=>key(k,d);}
 else if(u.pathname==='/tap'){const x=u.searchParams.has('x')?Number(u.searchParams.get('x')):NaN,y=u.searchParams.has('y')?Number(u.searchParams.get('y')):NaN;if(!Number.isInteger(x)||!Number.isInteger(y)||x<0||x>=480||y<0||y>=272){send(res,400,'Invalid display coordinate');return;}action=()=>tap(x,y);}
 else{const name=u.searchParams.get('name');if(!Object.prototype.hasOwnProperty.call(screens,name)){send(res,400,'Unknown screen');return;}action=async()=>{for(const p of screens[name])await tap(p[0],p[1]);};}
 if(queued>=16){send(res,429,'Input queue full');return;}queued++;
 const job=chain.then(async()=>{if(buildState(true).sourceDrift){const err=Error('Source drift');err.status=409;throw err;}return action();});chain=job.catch(()=>{});
 job.then(()=>send(res,200,'ok'),err=>send(res,err.status||500,err.status===409?'Source changed — restart preview':'Simulator input failed')).finally(()=>queued--);
});
await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(PORT,'127.0.0.1',resolve);});
console.log('CURRENT PREVIEW '+JSON.stringify({url:'http://127.0.0.1:'+PORT+'/',build:snapshot.build,sourceSHA256:SOURCE,runtimeCount:snapshot.runtimeCount,localOnly:true,installed:false,sampleTelemetry:true}));
await new Promise(()=>{});
