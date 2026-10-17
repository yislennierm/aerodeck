-- Verify the actual AERODECK adapter handles the active TEST model's empty config.
local f=assert(io.open('sdcard/SCRIPTS/TOOLS/telem.lua'));local code=f:read('*a');f:close()
local initStart=assert(code:find('local fcLink=',1,true))
local initEnd=assert(code:find('local configuration=(function()',initStart,true))
local updateStart=assert(code:find('function fcLink.update',initEnd,true))
local updateEnd=assert(code:find('local telemetry=(function()',updateStart,true))
local adapter=code:sub(initStart,initEnd-1)..code:sub(updateStart,updateEnd-1)..'\nreturn fcLink'
local factory=dofile('sdcard/SCRIPTS/TOOLS/AERODECK/crsf-msp.lua')
local fm,current,native='ACRO*',true,true
local cfg={rcProtocol='None',fcType='None',mspMode=1}
configuration={get=function(k)return cfg[k]end,resolve=function()return 'FM'end}
cachedTelemetryField=function()return {id=42}end
getSourceValue=function(id)assert(id==42);return fm,current,current end
model={getSensor=function(i)if i==0 and native then return {type=0,id=0x21,name='FM'}end end}
loadScript=function(path)assert(path=='/SCRIPTS/TOOLS/AERODECK/crsf-msp.lua');return function()return factory end end
local streaming=true
getSwitchIndex=function(name)assert(name=='Tele');return 9 end
getSwitchValue=function(id)assert(id==9);return streaming end
local requests=0
crossfireTelemetryPush=function(kind,packet)assert(kind==0x7A and packet[5]==2);requests=requests+1;return true end
crossfireTelemetryPop=function()end
local app=assert(loadstring(adapter))();app.init();app.update(0);app.update(100)
assert(requests==1 and app.state.pendingCommand==2,'Empty TEST settings must use detected CRSF and identify FC')
for _,mode in ipairs({'ACRO','!FS!','FAILSAFE',''})do fm=mode;app.update(110);assert(not app.state.active and not app.state.pendingCommand,'armed/failsafe/unknown must cancel')end
fm='ACRO*';current=false;app.update(200);assert(app.state.status=='NO CURRENT LINK')
current=true;streaming=false;app.update(250);assert(app.state.status=='NO CURRENT LINK')
streaming=true;cfg.mspMode=0;app.update(300);assert(app.state.status=='OFF')
cfg.mspMode=1;cfg.fcType='INAV';app.update(400);assert(app.state.status=='OFF')
cfg.fcType='None';cfg.rcProtocol='FrSky';app.update(500);assert(app.state.status=='OFF')
cfg.rcProtocol='None';native=false;app.init();app.update(600);assert(app.state.status=='OFF')
native=true;app.init();app.update(700);app.update(800);assert(requests==2)
app.stop();assert(app.state.status=='OFF' and not app.state.pendingCommand)
assert(code:find('fcLink.update(getTime())',1,true)<code:find(' local pitch,roll=telemetry.pollAttitude()',1,true),'transport must run before telemetry/draw throttling')
print('PASS: empty TEST configuration auto-detects CRSF; armed/failsafe/unknown/stale/disabled/incompatible gates; exit cancels; transport before draw')
