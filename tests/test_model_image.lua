local factory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/model-image.lua'))()
local reads,draws,checks=0,{},0
local function check(v,why)assert(v,why);checks=checks+1 end
local api={open=function(p)reads=reads+1;if string.find(p,'missing',1,true)then return nil end;if string.find(p,'throw',1,true)then error('SD ERROR')end;return {p}end,getSize=function()return 320,180 end}
local m=factory.new({Bitmap=api,lcd={drawBitmap=function(...)draws[#draws+1]={...}end}})
check(m.set('quad.png',false,'a').status=='OFF'and reads==0,'disabled image performs no IO')
check(m.set('',true,'a').status=='NOT SET'and reads==0,'no model image stays honest')
for _,name in ipairs({'../quad.png','a/quad.png','a\\quad.png','quad.gif','quad\n.png',string.rep('a',100)..'.png'})do check(m.set(name,true,'a').status~='READY'and reads==0,'invalid filename never opens SD path')end
check(m.set('quad.png',true,'a').status=='READY'and m.snapshot().path=='/IMAGES/quad.png'and reads==1,'model filename/extension preserved verbatim')
for i=1,100 do check(m.set('quad.png',true,'a').status=='READY'and m.draw(354,89,108,70),'cached model image remains drawable')end
check(reads==1 and #draws==100,'warm image draws never reopen SD')
local d=draws[1];check(d[4]==33 and d[2]==355 and d[3]==94,'native integer percent fits and centers320x180 in108x70')
check(m.set('quad.png',true,'b').status=='READY'and reads==2,'new model identity reloads its own image')
check(m.set('missing.png',true,'b').status=='MISSING','missing image is a visible nonfatal state')
for i=1,100 do m.set('missing.png',true,'b')end;check(reads==3,'missing image is cached without repeated SD probes')
check(m.set('throw.png',true,'b').status=='MISSING','IO exception is contained')
check(not m.draw(1,1,1,1),'failed image cannot draw an invented bitmap')
if debug and debug.setmetatable then local mt=debug.getmetatable('');debug.setmetatable('',nil);local ok,err=pcall(function()check(m.set('quad.png',true,'b').status=='READY','embedded string compatibility')end);debug.setmetatable('',mt);assert(ok,err)end
print('PASS: '..checks..' real-model image path/cache/percent-fit/failure checks')
