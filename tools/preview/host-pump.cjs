const fs=require('fs'),path=require('path');
const {Worker,isMainThread,workerData,parentPort}=require('worker_threads');
const {WASI}=require('wasi');
const base=path.resolve(__dirname,'../../.build/preview');
const sd=process.env.EDGETX_SIM_SD||path.join(base,'sd'),settings=process.env.EDGETX_SIM_SETTINGS||path.join(base,'settings');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
const mod=isMainThread?await WebAssembly.compile(fs.readFileSync(process.env.AERODECK_SIM_WASM||path.join(base,'tx16s.wasm'))):workerData.mod;
const memory=isMainThread?new WebAssembly.Memory({initial:512,maximum:32768,shared:true}):workerData.memory;
const analogs=isMainThread?new SharedArrayBuffer(16*4):workerData.analogs;
if(isMainThread)new Int32Array(analogs).fill(2048);
const tids=isMainThread?new SharedArrayBuffer(4):workerData.tids;
if(isMainThread)new Int32Array(tids)[0]=2;
const workers=[];
const wasi=new WASI({version:'preview1',args:[],env:{},preopens:{[sd]:sd,[settings]:settings},returnOnExit:true});
const imports={wasi_snapshot_preview1:wasi.wasiImport,env:{memory,
 simuGetAnalog:i=>new Int32Array(analogs)[i]??2048,
 simuTrace:ptr=>{const b=new Uint8Array(memory.buffer);let end=ptr;while(b[end]&&end<ptr+4096)end++;let msg=Buffer.from(b.subarray(ptr,end)).toString();if(isMainThread)console.log(msg);else parentPort.postMessage({log:msg});},
 simuLcdNotify:()=>{},simuQueueAudio:()=>{}},wasi:{'thread-spawn':arg=>{
 const tid=Atomics.add(new Int32Array(tids),0,1);const w=new Worker(__filename,{workerData:{mod,memory,analogs,tids,tid,arg}});
 w.on('message',m=>{if(m.log)console.log(m.log);});w.on('error',e=>console.error('WORKER',e));workers.push(w);return tid;
}}};
const inst=await WebAssembly.instantiate(mod,imports);const e=inst.exports;
if(!isMainThread){wasi.initialize({exports:{memory}});e.wasi_thread_start(workerData.tid,workerData.arg);return;}
wasi.initialize(inst);
const cstr=s=>{let b=Buffer.from(s+'\0');let p=e.malloc(b.length);new Uint8Array(memory.buffer,p,b.length).set(b);return p;};
console.log('EXPORT dimensions',e.simuLcdGetWidth(),e.simuLcdGetHeight());
e.simuInit();const a=cstr(sd),b=cstr(settings);e.simuFatfsSetPaths(a,b);e.free(a);e.free(b);e.simuCreateDefaults();e.simuStart(0);
const ptr=e.malloc(480*272*2);
// Match the official continuous consumer: copy a published dirty frame, then ACK.
// Screenshots read the owned cache and never ACK an unrelated/in-progress draw.
let latestFrame=Buffer.alloc(480*272*2),lcdFrames=0;const lcdPumpStarted=Date.now();
const lcdPump=setInterval(()=>{if(e.simuLcdChanged()){const n=e.simuLcdCopy(ptr,480*272*2);latestFrame=Buffer.from(new Uint8Array(memory.buffer,ptr,n));lcdFrames++;e.simuLcdFlushed();}},16);
const copyFrame=()=>Buffer.from(latestFrame);
process.on('exit',()=>{clearInterval(lcdPump);console.log('QA_LCD_PUMP',JSON.stringify({intervalMs:16,frames:lcdFrames,elapsedMs:Date.now()-lcdPumpStarted,continuousDirtyCopyThenAck:true,screenshotExtraAck:false}));});
const shot=name=>{const frame=copyFrame();fs.mkdirSync(path.join(__dirname,'captures'),{recursive:true});fs.writeFileSync(path.join(__dirname,'captures',name+'.raw'),frame);console.log('SHOT',name,frame.length);};
const key=async(k,d=120)=>{e.simuSetKey(k,1);await sleep(d);e.simuSetKey(k,0);await sleep(250);};
const tap=async(x,y)=>{e.simuTouchDown(x,y);await sleep(100);e.simuTouchUp();await sleep(250);};
await sleep(3000);shot('boot');
// optional scripted firmware interaction from a local, task-authored file.
if(process.argv[2]){const run=new Function('e','key','tap','shot','sleep','analogs','fs','base','copyFrame','lcdStats','return (async()=>{'+fs.readFileSync(process.argv[2],'utf8')+'})()');await run(e,key,tap,shot,sleep,new Int32Array(analogs),fs,base,copyFrame,()=>({frames:lcdFrames,elapsedMs:Date.now()-lcdPumpStarted}));}
console.log('FINISH');for(const w of workers)await w.terminate();process.exit(0);
})().catch(e=>{console.error(e);process.exit(1);});
