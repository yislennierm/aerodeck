const h=base+'/../gps-track-20261018/',which=process.env.QA_CASE;const save=n=>{fs.writeFileSync(h+which+'-'+n+'.raw',copyFrame());console.log('QA_GPS_SHOT',n);};
await sleep(13000);e.simuTouchDown(300,145);await sleep(1100);e.simuTouchUp();await sleep(500);await tap(220,150);await sleep(1800);save('flight');await tap(262,15);save('gps');await sleep(1200);
const records=[];let blank=0,progress=0,stage='TRACK';const start=Date.now();
const monitor=setInterval(()=>{const raw=copyFrame(),v=raw.readUInt16LE((2*480+4)*2);const dark=((v>>11)&31)<6&&((v>>5)&63)<12&&(v&31)<10;let glyph=0;for(let y=2;y<32;y++)for(let x=5;x<35;x++){const q=raw.readUInt16LE((y*480+x)*2);if(((q>>11)&31)>8&&((q>>5)&63)>15&&(q&31)>10)glyph++;}if(!dark)blank++;else if(glyph<=40)progress++;records.push({elapsedMs:Date.now()-start,stage,darkHeader:dark,homeGlyphPixels:glyph});},37);
await tap(350,44);save('track-initial');for(let i=0;i<4;i++){await sleep(3000);save('track-'+((i+1)*3));}
for(let i=0;i<3;i++){await tap(150,232);await sleep(9000);save('zoom-'+i);}
stage='SET HOME';save('before-home');await tap(244,232);save('home-immediate');await sleep(2500);save('home-new-track');await tap(140,44);stage='GPS DETAILS';save('details-new-home');await sleep(1500);await tap(350,44);stage='TRACK';await sleep(2500);save('track-final');clearInterval(monitor);
fs.writeFileSync(h+which+'-observations.json',JSON.stringify({elapsedMs:Date.now()-start,samples:records.length,intervalMs:37,blankFrames:blank,ordinaryProgressFrames:progress,forcedGC:false,records},null,2));process.exit(0);
