const out=process.env.AERODECK_APP_MODE_EVIDENCE;
await sleep(16000);fs.writeFileSync(out+'/app-mode-unfocused.raw',copyFrame());
console.log('QA_CAPTURE|unfocused|no UI inputs sent');
e.simuTouchDown(300,145);await sleep(1200);e.simuTouchUp();await sleep(1500);
fs.writeFileSync(out+'/app-mode-focused.raw',copyFrame());
await key(13);fs.writeFileSync(out+'/app-mode-toolbar-focus.raw',copyFrame());
await key(1);await key(1,1200);await sleep(1000);
fs.writeFileSync(out+'/app-mode-after-release.raw',copyFrame());
console.log('QA_APP_MODE_COMPLETE',JSON.stringify(lcdStats()));
