-- Actual exact-geo plot helper against the previous production projection.
-- Run from the project root; optional args: helper fragment, main source.
local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local main=read(arg[2]or'sdcard/SCRIPTS/TOOLS/telem.lua')
local function functionText(start)
 local a=assert(string.find(main,start,1,true));local b=assert(string.find(main,'\nend\n',a,true));return string.sub(main,a,b+4)
end
local helper
if arg[1]then helper=read(arg[1])else
 local a=assert(string.find(main,'navPlot=(function()',1,true),'integrated plot helper required')
 local b=assert(string.find(main,'\nend)()',a,true));helper='local '..string.sub(main,a,b+6)
end
local prefix=[[local pi=math.pi
local function round(v)return math.floor(v+.5)end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
]]..functionText('local function atan2(y,x)')..'\n'..functionText('local function geo(a,b)')..[[
local originalGeo=geo
local calls=0
geo=function(...)calls=calls+1;return originalGeo(...)end
]]
local exports=[[return {plot=navPlot,calls=function()return calls end,oracle=function(origin,p,zoom)
 local distance,angle=originalGeo(origin,p);local rad=angle*pi/180;local scale=({.35,.7,1.4})[zoom]
 return round(104+distance*math.sin(rad)*scale),round(141-distance*math.cos(rad)*scale)
end}]]
local compile=loadstring or load
local function make()return assert(compile(prefix..'\n'..helper..'\n'..exports,'@actual-nav-plot'))()end
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function point(i)return{lat=25.9976807+i*.00001,lon=-97.1573563+i*.00002,tick=i*100}end
local function pixelsUnchanged(frame,held)
 check(frame==held.frame,'pending work retains the completed frame object')
 for i,p in ipairs(held.path)do check(frame.path[i].x==p[1]and frame.path[i].y==p[2]and frame.path[i].point==p[3],'pending work cannot mutate completed pixel '..i)end
end
local function freeze(frame)
 local saved={frame=frame,path={}}
 for i,p in ipairs(frame.path)do saved.path[i]={p.x,p.y,p.point}end
 return saved
end
local function verify(h,frame,points,origin,zoom)
 check(frame and frame.count==#points and #frame.path==#points,'published path retains every captured history point without decimation')
 check(frame.zoom==zoom and frame.origin.lat==(origin.lat+0.0)and frame.origin.lon==(origin.lon+0.0),'frame carries captured origin and scale ownership')
 for i,p in ipairs(points)do local x,y=h.oracle(origin,p,zoom);local actual=frame.path[i]
  check(actual.point==p and actual.x==x and actual.y==y,'pixel projection exactly matches old geodesic oracle at point '..i)
 end
end
local function step(h,home,pos,track,zoom,now)
 local before=h.calls();local s,geometry,processed=h.plot.step(home,pos,track,zoom,now)
 check(h.calls()-before==geometry and geometry<=8 and processed<=32,'every step has at most8exact geodesic calls and32processed points')
 check(s.cacheCount<=180,'projection cache never exceeds180entries')
 return s,geometry,processed
end
local function finish(h,home,pos,track,zoom,now)
 local prior=h.plot.snapshot().frame;local held=prior and freeze(prior)
 local s,geometry,processed=step(h,home,pos,track,zoom,now or 0)
 if s.pending then check(geometry==0 and processed==0,'start-only callback copies refs without projection work')end
 local ticks=0
 while s.pending do
  if held and s.frame then pixelsUnchanged(s.frame,held)end
  ticks=ticks+1;check(ticks<=24,'all180uncached points make bounded progress')
  s=step(h,home,pos,track,zoom,(now or 0)+ticks*4)
 end
 return s.frame,ticks
end
local home={lat=25.9976807,lon=-97.1573563};local current=point(200)
-- Priming grows with new observations only, not with accumulated history.
local h=make();local track={}
for i=1,180 do
 track[i]=point(i);local before=h.calls();local s,computed=h.plot.prime(home,current,track)
 check(computed and h.calls()==before+1,'one appended point requires exactly one prewarm projection')
 before=h.calls();h.plot.prime(home,current,track);check(h.calls()==before,'same latest immutable point requires no extra geometry')
 check(s.cacheCount==i,'prewarm retains bounded per-point identities')
end
for zoom=1,3 do local before=h.calls();local frame,ticks=finish(h,home,current,track,zoom)
 check(h.calls()==before and ticks==6,'warm180point scaling uses six32point callbacks and no geodesic recomputation')
 verify(h,frame,track,home,zoom)
end
for i=181,260 do
 table.remove(track,1);track[#track+1]=point(i)
 local before=h.calls();h.plot.prime(home,current,track);check(h.calls()==before+1,'rolling oldest eviction computes only the new point')
 check(h.plot.snapshot().cacheCount==180,'rolling cache remains bounded180')
 if i%10==0 then before=h.calls();local frame=finish(h,home,current,track,2,i*100);check(h.calls()==before,'index shifts never invalidate179retained points');verify(h,frame,track,home,2)end
end
-- Cold full track is not synchronously built by prime/start or by a painter.
h=make();local before=h.calls();local state=h.plot.prime(home,current,track)
check(h.calls()==before+1 and state.frame==nil,'late first prime computes only latestpoint, never copies180points')
local frame,ticks=finish(h,home,current,track,3)
check(ticks==23,'cold180point job completes via bounded misses rather than all at once')
verify(h,frame,track,home,3)
-- Home and source table ownership reset both cache and old picture.
local newHome={lat=home.lat,lon=home.lon};state=h.plot.prime(newHome,current,track)
check(state.frame==nil and not state.pending and state.cacheCount==1,'new home identity clears old picture/cache even at equal coordinates')
frame=finish(h,newHome,nil,track,1);verify(h,frame,track,newHome,1)
local replacement={};for i,p in ipairs(track)do replacement[i]=p end
state=h.plot.prime(newHome,nil,replacement);check(state.frame==nil and state.cacheCount==1,'new source track table cannot inherit previous projection ownership')
frame=finish(h,newHome,nil,replacement,1);verify(h,frame,replacement,newHome,1)
h.plot.reset();check(h.plot.snapshot().frame==nil and h.plot.snapshot().cacheCount==0,'explicit model/source reset clears all borrowed plot state')
-- No-home current-origin jobs finish coherently while telemetry keeps moving.
h=make();track={};for i=1,180 do track[i]=point(i)end
local capture={};for i,p in ipairs(track)do capture[i]=p end
local origin={lat=0,lon=0};state=step(h,nil,origin,track,1,0);check(state.pending and state.frame==nil,'no-home first job captures a genuine current origin')
local moved
for i=1,23 do
 moved={lat=i*.01,lon=-i*.02}
 if i%4==0 then table.remove(track,1);track[#track+1]=point(180+i)end
 state=step(h,nil,moved,track,i%3+1,i*4)
 if i<23 then check(state.pending and state.frame==nil,'newGPSpoints/zoom do not starve the coherent in-progress job')end
end
check(not state.pending,'moving no-home origin still completes all180captured points')
verify(h,state.frame,capture,origin,1)
local old=freeze(state.frame);local nextOrigin={lat=.5,lon=-.75};capture={};for i,p in ipairs(track)do capture[i]=p end
state=step(h,nil,nextOrigin,track,3,100);check(state.pending,'latest requested origin/zoom starts after previous completion')
for i=1,23 do pixelsUnchanged(state.frame,old);state=step(h,nil,{lat=.5+i*.01,lon=-.75},track,2,100+i*4)end
verify(h,state.frame,capture,nextOrigin,3)
-- GPS loss retains the completed last-known frame, never a fake current marker.
local held=state.frame;state=step(h,nil,nil,track,3,300)
check(state.frame==held and not state.pending and state.waiting and state.frame.current==nil,'no current GPS retains last-known plot without fabricated current coordinates')
before=h.calls();state=step(h,nil,held.origin,track,3,304)
check(state.frame==held and not state.pending and not state.waiting and h.calls()==before,'same-origin GPS recovery clears waiting without a new projection job')
h=make();state=step(h,nil,nil,{},2,0);check(state.frame==nil and state.waiting,'no history/current origin remains explicitly unavailable')
-- Antimeridian/high-latitude/global points still use exact old spherical math.
for _,scene in ipairs({
 {origin={lat=0,lon=179.999},points={{lat=0,lon=-179.999},{lat=.001,lon=180},{lat=-.001,lon=179.998}}},
 {origin={lat=89.99,lon=-45},points={{lat=89.991,lon=135},{lat=89.98,lon=70},{lat=80,lon=-170}}},
 {origin={lat=-89.99,lon=170},points={{lat=-89.98,lon=-170},{lat=-80,lon=0},{lat=0,lon=-10}}},
 {origin={lat=1.25,lon=0},points={{lat=1,lon=0},{lat=0,lon=0},{lat=.1,lon=.1}}}})do
 local g=make();for zoom=1,3 do local v=finish(g,scene.origin,nil,scene.points,zoom);verify(g,v,scene.points,scene.origin,zoom)end
end
-- Never silently discard excess or malformed input; no projection retry loop.
h=make();local excess={};for i=1,181 do excess[i]=point(i)end
before=h.calls();state=step(h,home,current,excess,1,0)
check(state.error=='TRACK LIMIT EXCEEDED'and state.frame==nil and h.calls()==before,'overflow is explicit, not a hidden180point truncation')
local bad={point(1),{lat=0/0,lon=0}};step(h,home,current,bad,1,0);state=step(h,home,current,bad,1,4)
check(state.error=='INVALID TRACK POINT'and not state.pending and state.frame==nil,'invalid point cannot publish a partial fake path')
before=h.calls();for i=1,10 do step(h,home,current,bad,1,8+i*4)end
check(h.calls()==before,'unchanged invalid target cannot repeatedly project or allocate a retry job')
local meta=debug.getmetatable('');debug.setmetatable('',nil)
local okay,err=pcall(function()local g=make();finish(g,home,current,{point(1),point(2)},1)end)
debug.setmetatable('',meta);check(okay,'native stripped string compatibility: '..tostring(err))
print('PASS: '..checks..' exact geodesic plot pixels, bounded work/cache, full180history, rolling eviction, owner/zoom/current-origin coherence and no fabricated current GPS')
