-- Development only: compare actual cockpit source in identical LCD environments.
-- Disable JIT globally before loading any app chunk so hooks see every bytecode.
if jit then jit.off();jit.flush()end
local root=assert(arg[1]);local candidatePath=arg[2]or(root..'/project/sdcard/SCRIPTS/TOOLS/telem.lua');local function read(p)local f=assert(io.open(p));local s=f:read('*a');f:close();return s end
local checks=0;local function ok(v,s)assert(v,s);checks=checks+1 end
local function metrics(text,font)
 text=tostring(text);font=(font or 0)%1024;local scale=font==128 and .75 or font==256 and 1.5 or font==512 and 2 or 1
 local width=0;local widths={W=10,M=9,I=3,[' ']=4,['/']=5,['.']=3}
 for i=1,#text do local c=string.sub(text,i,i);width=width+(font==256 and c>='0'and c<='9'and 14/scale or widths[c]or 7)end
 return width*scale,font==128 and 12 or font==256 and 29 or font==512 and 38 or 17
end
local palette={tape=1,border=2,green=3,muted=4,red=5,orange=6,white=7,dim=8,sky=9,ground=10,horizon=11,ladder=12,black=13,cyan=14,panel=15,bg=16}
local function make(path,name)
 local state={commands={},font=0,colors=0,settings=0};local ink;local options={attitudeOverlay=1,compassSource=0,rollDisplay=0,lqCrit=20,lqLow=70}
 local env={SMLSIZE=0,TINSIZE=128,MIDSIZE=256,DBLSIZE=512,CUSTOM_COLOR=4096,RIGHT=65536,SOLID=0,unpack=unpack or table.unpack};setmetatable(env,{__index=_G});env._G=env
 local function cmd(k,...)state.commands[#state.commands+1]={k,ink,...}end
 env.lcd={sizeText=function(s,f)state.font=state.font+1;return metrics(s,f)end,setColor=function(_,c)state.colors=state.colors+1;ink=c end}
 for method,kind in pairs({drawText='text',drawFilledRectangle='fill',drawLine='line',drawLineWithClipping='clip',drawCircle='circle',drawFilledTriangle='triangle',drawHudRectangle='hud',drawBitmap='bitmap',drawBitmapPattern='pattern'})do local k=kind;env.lcd[method]=function(...)cmd(k,...)end end
 env.Bitmap={open=function(p)return p end,getSize=function()return 18,18 end,toMask=function(p)return p end}
 local s=read(path);local tail=assert(s:find('return {init=init,run=run,stop=fcLink.stop,',1,true));s=s:sub(1,tail-1)..[[return {draw=function(d,p)palette=p;cockpit(d)end,settings=function(get)configuration.get=get end}]]
 local chunk;if setfenv then chunk=assert(loadstring(s,name));setfenv(chunk,env)else chunk=assert(load(s,name,'t',env))end
 state.source=name;state.app=chunk();state.app.settings(function(k)state.settings=state.settings+1;return options[k]or 0 end)
 function state.draw(d)state.commands={};state.app.draw(d,palette);return state.commands end
 function state.options(o)for k,v in pairs(o)do options[k]=v end end
 return state
end
local baseline=make(root..'/baseline-telem.lua','@actual-baseline');local candidate=make(candidatePath,'@actual-candidate')
local function same(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function allowed(c,d,o)
 if c[1]~='text'then return false end;local x,y,t=c[3],c[4],tostring(c[5]);if x==225 and y==68 and(t=='COG'or t=='YAW')then return true end
 if d.pitch==nil or d.roll==nil then return false end
 if y==68 and((x==128 and t=='P')or(x==286 and t=='R'))then return true end
 if y>=65 and y<=73 and((x>=141 and x<=204)or(x>=300 and x<=352))then
  if t=='deg'or t==string.format('%+.0f',d.pitch)or t==string.format('%+.0f',(o.rollDisplay==1 and-d.roll or d.roll)+0.0)then return true end
 end
 local n=tonumber(t);return n and n~=0 and n>=-90 and n<=90 and n%20==0 and x>=128 and x<=352 and y>=65 and y<=204
end
local removed=0;local geometry=0;local frames=0
local function compare(d,o)
 baseline.options(o);candidate.options(o);local a,b=baseline.draw(d),candidate.draw(d);local j=1
 for i,c in ipairs(a)do
  if b[j]and same(c,b[j])then if c[1]~='text'then geometry=geometry+1 end;j=j+1
  else ok(allowed(c,d,o),'Unexpected missing/changed baseline command '..i..' '..tostring(c[1])..' '..tostring(c[3])..','..tostring(c[4])..' '..tostring(c[5]));removed=removed+1 end
 end
 ok(j==#b+1,'Candidate added or reordered a retained command');frames=frames+1
end
local base={lq=99,v=22.8,pct=54,estimated=true,rssi=-67,power=250,cells=6,mah=2762,snr=8,pitch=0,roll=0,speed=31,alt=33,hdg=150,course=150,yaw=75,a=12.5,session={current={lat=26,lon=-97},homeBearing=200,flightSeconds=98}}
local function copy(d)local t={};for k,v in pairs(d)do t[k]=v end;return t end
for _,rd in ipairs({0,1})do for _,cs in ipairs({0,1})do for _,overlay in ipairs({0,1})do
 local o={rollDisplay=rd,compassSource=cs,attitudeOverlay=overlay}
 for _,p in ipairs({-90,-40,-20,-10,0,10,20,40,90})do for _,r in ipairs({-180,-120,-90,-60,-35,0,35,60,90,120,180})do local d=copy(base);d.pitch=p;d.roll=r;d.course=(p+r+720)%360;compare(d,o)end end
 for _,d in ipairs({{}, {pitch=0,roll=0,v=0,a=0,pct=0,cells=6,lq=0,speed=0,alt=0,mah=0}, {pitch=90,roll=180,v=100000,pct=12345,cells=12,mah=99999999,speed=1e8,alt=-1e8,hdg=359.99,a=999999}, {pitch=10}, {roll=35}})do compare(d,o)end
end end end
print('COMPARE frames='..frames..' geometryExact='..geometry..' removedText='..removed..' checks='..checks)
local warm={rollDisplay=0,compassSource=0,attitudeOverlay=1};baseline.options(warm);candidate.options(warm)
local data={};for i=1,240 do local d=copy(base);d.pitch=math.sin(i*.1)*35;d.roll=math.cos(i*.1)*120;d.course=(i*1.9)%360;d.yaw=(i*1.1)%360;d.speed=i%90;d.alt=33+i*.3;d.a=i*.1;data[i]=d end
for i=1,120 do baseline.draw(data[i]);candidate.draw(data[i])end
local function measure(state)
 state.font=0;state.colors=0;state.settings=0;local total={instructions=0,text=0,geometry=0,draw=0,font=0,color=0,setting=0};local instruction=0
 local function hook()local info=debug.getinfo(2,'S');if info and info.source==state.source then instruction=instruction+1 end end
 for i=121,240 do
  local start=instruction;debug.sethook(hook,'',1);local commands=state.draw(data[i]);debug.sethook()
  total.instructions=total.instructions+instruction-start
  for _,c in ipairs(commands)do total.draw=total.draw+1;if c[1]=='text'then total.text=total.text+1 else total.geometry=total.geometry+1 end end
 end
 total.font=state.font;total.color=state.colors;total.setting=state.settings;return total
end
local b,c=measure(baseline),measure(candidate);ok(b.geometry==c.geometry,'Geometry call counts changed in moving sample');ok(c.instructions<b.instructions,'No production-source instruction reduction')
for _,k in ipairs({'instructions','text','geometry','draw','font','color','setting'})do print('METRIC '..k..' '..b[k]..' '..c[k])end
print('RESULT PASS measuredMovingFrames=120')
