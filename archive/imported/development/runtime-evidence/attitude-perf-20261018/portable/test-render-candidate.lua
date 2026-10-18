-- Compare actual baseline/candidate LCD commands; count font API calls separately.
local root=assert(arg[1],'candidate directory required')
local candidatePath=arg[2]or(root..'/render-candidate.lua')
local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function metrics(text,font)
 text=tostring(text);font=(font or 0)%1024
 local scale=font==128 and .75 or font==256 and 1.5 or font==512 and 2 or 1
 local width=0;local widths={W=10,M=9,I=3,[' ']=4,['/']=5,['.']=3}
 for i=1,#text do local char=string.sub(text,i,i);width=width+(font==256 and char>='0'and char<='9'and 14/scale or widths[char]or 7)end
 return width*scale,font==128 and 12 or font==256 and 29 or font==512 and 38 or 17
end
local palette={tape=1,border=2,green=3,muted=4,red=5,orange=6,white=7,dim=8,sky=9,ground=10,horizon=11,ladder=12,black=13,cyan=14,panel=15,bg=16}
local function make(path,opts)
 opts=opts or {};local state={commands={},measurements=0};local ink
 local env={SMLSIZE=0,TINSIZE=opts.noTin and nil or 128,MIDSIZE=256,DBLSIZE=512,CUSTOM_COLOR=4096,RIGHT=65536,SOLID=0}
 if opts.noTin then env.TINSIZE=nil end
 setmetatable(env,{__index=_G});env._G=env
 local function command(kind,...)
  local c={kind,ink,...};state.commands[#state.commands+1]=c
 end
 local function measure(s,font)state.measurements=state.measurements+1;return metrics(s,font)end
 if opts.fallback then measure=function()state.measurements=state.measurements+1;return nil,nil end end
 local lcd={sizeText=measure,setColor=function(_,color)ink=color end,
 drawText=function(...)command('text',...)end,drawFilledRectangle=function(...)command('fill',...)end,
 drawLine=function(...)command('line',...)end,drawLineWithClipping=function(...)command('clip',...)end,
 drawCircle=function(...)command('circle',...)end,drawFilledTriangle=function(...)command('triangle',...)end,
 drawHudRectangle=function(...)command('hud',...)end,drawBitmap=function(...)command('bitmap',...)end,
 drawBitmapPattern=function(...)command('pattern',...)end}
 env.lcd=lcd
 env.Bitmap={open=function(path)return path end,getSize=function(path)return 18,18 end,toMask=function(path)return path end}
 local original=read(path);local tail=assert(string.find(original,'return {init=init,run=run,stop=fcLink.stop,',1,true))
 local source=string.sub(original,1,tail-1)..[[return {
 draw=function(d,p)palette=p;cockpit(d)end,
 cell=function(args,p)palette=p;flightValue(unpack(args))end,
 enter=function()changePage(1)end,
 settings=function(values)configuration.get=function(key)return values[key]or 0 end end,
 resetLcd=function(other)lcd=other end,
 watchWidth=function(observe)local original=textWidth;textWidth=function(...)observe();return original(...)end end}]]
 local chunk
 if setfenv then chunk=assert(loadstring(source,'@actual-render-'..path));setfenv(chunk,env)else env.unpack=table.unpack;chunk=assert(load(source,'@actual-render-'..path,'t',env))end
 local app=chunk();app.enter();state.widthCalls=0;app.watchWidth(function()state.widthCalls=state.widthCalls+1 end)
 function state.draw(d)state.commands={};app.draw(d,palette);return state.commands end
 function state.cell(args)state.commands={};app.cell(args,palette);return state.commands end
 state.app=app;state.lcd=lcd;return state
end
local baseline=make(root..'/render-baseline.lua');local candidate=make(candidatePath)
local function compare(a,b,path)
 path=path or 'commands';check(type(a)==type(b),path..' type changed')
 if type(a)~='table'then check(a==b,path..' differs: '..tostring(a)..' vs '..tostring(b));return end
 for k,v in pairs(a)do compare(v,b[k],path..'/'..tostring(k))end
 for k in pairs(b)do check(a[k]~=nil,path..' unexpected key '..tostring(k))end
end
local data={lq=99,v=22.8,pct=73,rssi=-67,power=250,cells=6,mah=2762,snr=8,pitch=-12,roll=8,speed=31,alt=33,hdg=150,a=12.5}
local function copy(t)local n={};for k,v in pairs(t)do n[k]=v end;return n end
local cases={data,{}, {lq=0,v=0,pct=0,rssi=0,power=0,cells=6,mah=0,snr=0,pitch=0,roll=0,speed=0,alt=0,hdg=0,a=0},
 {lq=1000,v=100000.1,pct=12345,rssi=-999999,power=100000,cells=12,mah=999999999,snr=-100000,pitch=-90,roll=180,speed=1e8,alt=-1e8,hdg=359.99,a=999999.5},
 {lq=100,v=25.2,pct=100,estimated=true,cells=6,mah=2762,a=.5,protocol={family='FRSKY',subtype='R9'},rssi=86,rxV=4.9,down=100,cell=4.2,cellProvenance='REPORTED CELL'}}
for _,d in ipairs(cases)do compare(baseline.draw(d),candidate.draw(d))end
for _,p in ipairs({-89,-40,-20,-10,-.2,0,.2,10,20,40,89})do
 for _,r in ipairs({-180,-120,-90,-60,-35,0,.2,35,60,90,120,180})do
  local d=copy(data);d.pitch=p;d.roll=r;d.hdg=(p+r+720)%360;compare(baseline.draw(d),candidate.draw(d))
 end
end
-- Every cell input participates in the cache key; colors must remain live.
local variants={
 {10,40,62,34,'22.8','V',256,7}, {10,40,62,34,'22.9','V',256,6},
 {10,40,62,34,'22.9','A',256,7}, {10,40,62,34,'22.9','mAh',256,7},
 {10,40,62,34,'1234567890','mAh',512,7}, {10,40,15,18,'1234567890','',512,7,true},
 {10,40,100,45,'22.9','',512,6,true}, {10,40,100,45,'22.9','V',0,7,true},
 {10,40,100,45,'22.9','V',128,7,true}, {10,40,62,34,'--','V',256,4},
 {10,40,62,34,'0','V',256,4}, {522,39,62,34,'5.0','V',256,7},
 {10,40,62,34,'0','V',256,4}}
for _,v in ipairs(variants)do compare(baseline.cell(v),candidate.cell(v))end
for _,options in ipairs({{fallback=true},{noTin=true},{fallback=true,noTin=true}})do
 local b,c=make(root..'/render-baseline.lua',options),make(candidatePath,options)
 for _,v in ipairs(variants)do compare(b.cell(v),c.cell(v))end
end
-- Replace native metrics and LCD tables while using the same cells/strings.
for _,state in ipairs({baseline,candidate})do
 state.lcd.sizeText=function(s,font)state.measurements=state.measurements+1;local w,h=metrics(s,font);return w*1.1,h+1 end
end
for _,v in ipairs(variants)do compare(baseline.cell(v),candidate.cell(v))end
for _,state in ipairs({baseline,candidate})do
 local other={};for k,v in pairs(state.lcd)do other[k]=v end
 state.app.resetLcd(other)
end
for _,v in ipairs(variants)do compare(baseline.cell(v),candidate.cell(v))end
-- Bounded position cache: eviction is observable, newest position remains hot.
local bounded=make(candidatePath)
for i=1,100 do bounded.cell({i,42,62,34,'22.8','V',256,7})end
local before=bounded.widthCalls;bounded.cell({100,42,62,34,'22.8','V',256,7})
check(before==bounded.widthCalls,'Most recent cell should remain hot')
bounded.cell({1,42,62,34,'22.8','V',256,7});check(bounded.widthCalls>before,'Old cells must be evicted rather than retained indefinitely')
-- Fresh instances give comparable cumulative font call counts.
local b,c=make(root..'/render-baseline.lua'),make(candidatePath)
b.draw(data);c.draw(data);b.measurements=0;c.measurements=0
for i=1,150 do compare(b.draw(data),c.draw(data))end
local stableB,stableC=b.measurements,c.measurements
check(stableC<stableB*.5,'Stable Flight must remove at least half of native font API calls')
b.measurements=0;c.measurements=0
for i=1,150 do local d=copy(data);d.pitch=math.sin(i*.1)*35;d.roll=math.cos(i*.1)*60;d.hdg=(i*1.9)%360;d.speed=i%90;d.alt=33+i*.3;d.a=i*.1;compare(b.draw(d),c.draw(d))end
local movingB,movingC=b.measurements,c.measurements
check(movingC<movingB*.7,'Moving Flight must remove at least30% of native font API calls')
print(string.format('RENDER_CANDIDATE_PASS checks=%d stableMeasurements=%d/%d movingMeasurements=%d/%d',checks,stableC,stableB,movingC,movingB))
