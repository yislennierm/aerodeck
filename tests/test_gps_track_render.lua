-- Actual main/session: mature trails, bounded preparation, no physical FPS claim.
local realLoadstring=loadstring;local inspected
loadstring=function(source,name,...)
 if name=='@telem-under-test'then
  local n;source,n=string.gsub(source,' runtimeServices=runtimeServices,',' plot=navPlot,runtimeServices=runtimeServices,',1);assert(n==1)
  local chunk,err=realLoadstring(source,name,...);if not chunk then return nil,err end
  return function(...)local app=chunk(...);inspected=app;return app end
 end
 return realLoadstring(source,name,...)
end
local adapter=assert(loadfile('tests/test_ui_navigation.lua'))('adapter');local E=adapter.events
local checks=0;local function check(v,why)checks=checks+1;assert(v,why)end
local function make(auto)
 getUsage=nil
 local a=adapter.make({settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nmspMode=0\nvtxMode=0\nautoHome='..(auto and 1 or 0)..'\ntrail=180\n'})
 local plot=inspected.plot;check(plot~=nil,'inspection-only plot access')
 local clips={};local setInk=lcd.setColor;local ink;lcd.setColor=function(index,c)ink=c;setInk(index,c)end
 lcd.drawLineWithClipping=function(x,y,x2,y2,...)if ink==0x68dded then clips[#clips+1]={x=x,y=y,x2=x2,y2=y2}end end
 local h={app=a,plot=plot}
 function h.draw(event,touch)clips={};check(a.send(event or 0,touch)==0,'real page stays operational');for _,c in ipairs(a.commands())do check(not(c.kind=='text'and c.text:match('^TRACK %d+/%d+$')),'pending projection never shows an internal progress counter')end;return clips end
 function h.finish()
  for i=1,100 do h.draw();local s=plot.snapshot();if s.frame and not s.pending and s.frame.count==#h.app.snapshot().session.track and s.frame.last==h.app.snapshot().session.track[#h.app.snapshot().session.track]then return s.frame end end
  error('plot preparation did not complete')
 end
 return h
end
local h=make(true);local a=h.app;local start=a.snapshot().session.current;local lat,lon=start.lat,start.lon
for i=1,200 do a.setSensor('GPS',{lat=lat+math.sin(i*.13)*.0005,lon=lon+math.cos(i*.13)*.0005},true,true);a.background(100)end
local session=a.snapshot().session;local track=session.track
check(#track==180 and session.home~=nil,'real history reaches/rolls max before first Track entry')
check(h.plot.snapshot().cacheCount==180,'off-page service primes cached projections')
a.arrange(7);local frame=h.finish()
check(frame.count==180 and #frame.path==180,'full history publishes without decimation')
check(frame.first==track[1]and frame.last==track[#track],'chronological endpoints preserved')
local function checkScale()
 local f=h.plot.snapshot().frame;if not f then return end
 local radii=f.zoom==3 and{28,56}or{35,70}
 local captions=({{'100 m','200 m'},{'50 m','100 m'},{'20 m','40 m'}})[f.zoom]
 local rings,labels=0,{}
 for _,c in ipairs(a.commands())do
  if c.kind=='circle'and c.x==240 and c.y==154 and c.color==0x395464 then
   rings=rings+1;check(c.r==radii[rings],'metric ring radius matches the published zoom')
  end
  if c.kind=='text'and c.x>=80 and c.x<400 then labels[c.text]=true end
 end
 check(rings==2 and labels[captions[1]]and labels[captions[2]],'both range rings have the correct real-metre labels')
end
checkScale()
local writes,scans=a.writes(),a.sourceScans();local originals={};local mathCalls=0
for _,key in ipairs({'sin','cos','atan','sqrt'})do originals[key]=math[key];local fn=math[key];math[key]=function(...)mathCalls=mathCalls+1;return fn(...)end end
for i=1,120 do
 mathCalls=0;local clips=h.draw()
 check(#clips==179,'every refresh draws all179 native-clipped segments')
 check(mathCalls<=72,'warm map must not reproject180points: '..mathCalls)
 check(h.plot.snapshot().frame==frame,'unchanged history reuses its complete plot')
 check(#a.snapshot().session.track==180,'painting never changes history')
end
for key,fn in pairs(originals)do math[key]=fn end
check(a.writes()==writes and a.sourceScans()==scans,'no painting SD writes/source inventory')
for i=1,3 do h.draw(E.EVT_TOUCH_TAP,{x=70,y=259});checkScale();frame=h.finish();checkScale();check(frame.count==180 and #frame.path==180,'all zooms retain180points');check(frame.scale==({.35,.7,1.4})[frame.zoom],'range and path share completed scale')end
local beforeFirst,beforeLast=track[1],track[#track]
a.setSensor('GPS',{lat=lat+.0004,lon=lon-.0004},true,true);a.background(100)
check(#track==180 and track[1]~=beforeFirst and track[#track]~=beforeLast,'real full-buffer pruning changes endpoints')
frame=h.finish();check(frame.first==track[1]and frame.last==track[#track],'constant length cannot hide a rolled trail')
a.gpsAction('home')
check(a.snapshot().session.home.source=='LOCAL MANUAL','Set Home uses real session')
check(h.plot.snapshot().frame==nil,'new home clears old-owner plot')
frame=h.finish();check(frame.count==#a.snapshot().session.track,'replacement home trail publishes')
a.setSensor('GPS',nil,false,true);a.background(100);h.draw()
check(a.snapshot().session.current==nil and a.visible('TRACK / LAST KNOWN'),'GPS loss separates old trail and current aircraft')
h=make(false);a=h.app;local p=a.snapshot().session.current;lat,lon=p.lat,p.lon
for i=1,180 do a.setSensor('GPS',{lat=lat+i*.00001,lon=lon+i*.00001},true,true);a.background(100)end
a.arrange(7);local completed=0;local previous
for i=1,220 do
 a.setSensor('GPS',{lat=lat+.0018+i*.00001,lon=lon+.0018},true,true);h.draw();local s=h.plot.snapshot()
 if s.frame and s.frame~=previous then completed=completed+1;previous=s.frame;check(s.frame.origin~=a.snapshot().session.current,'map owns frozen origin');check(s.frame.count==180,'no-home map preserves full trail')end
end
check(completed>=2,'moving no-home GPS cannot starve publication')
check(a.snapshot().session.home==nil and a.snapshot().session.current~=nil,'map invents no home and preserves current GPS')
-- Retained-widget callbacks often reach map work with15% already consumed.
-- The previous<=10gate left mature maps unfinished alongside normal FC traffic.
h=make(true);a=h.app;a.setRetained(true);a.reinit()
while a.inputs.startup do a.background(4)end
a.background(20)
local retainedStart=a.snapshot().session.current;lat,lon=retainedStart.lat,retainedStart.lon
for i=1,180 do a.setSensor('GPS',{lat=lat+i*.00001,lon=lon+i*.00001},true,true);a.background(100)end
getUsage=function()return 15 end
a.arrange(7);frame=h.finish()
check(frame.count==180,'retained15%-entry callbacks finish full mature trail')
check(not a.inputs.navPlotPriority(100000),'unchanged published map reserves no FC callback')
local last=a.inputs.navPlotAt;a.inputs.navPlotAt=last-100
h.draw(E.EVT_TOUCH_TAP,{x=70,y=259})
check(h.plot.snapshot().pending,'zoom begins bounded retained job')
frame=h.finish();check(frame.count==180,'retained zoom finishes without strict10%-gate starvation')
-- If the remaining budget stays above18%, one failed map opportunity must
-- not keep suppressing transport on every callback. Priority grants themselves
-- own a separate200ms timestamp, independent of successful preparation work.
getUsage=function()return 19 end
h.draw(E.EVT_TOUCH_TAP,{x=70,y=259})
check(not h.plot.snapshot().pending,'19%-entry callback cannot start map work above the measured bound')
local previousStep=a.inputs.navPlotAt
check(a.inputs.navPlotPriority(200001),'dirty blocked map receives one200ms FC-free opportunity')
check(a.inputs.navPlotYieldAt==200001 and a.inputs.navPlotAt==previousStep,'grant records yield time without claiming geometry progress')
check(not a.inputs.navPlotPriority(200002),'blocked map cannot reserve every following transport callback')
check(a.inputs.navPlotPriority(200021),'a later blocked map may request its next200ms opportunity')
check(not a.inputs.navPlotPriority(200022),'the second grant also stays rate bounded')
check(a.inputs.navPlotPriority(1000),'clock rollback permits one fresh scheduling opportunity')
check(not a.inputs.navPlotPriority(1001),'clock rollback cannot create a permanent transport pause')
-- Manual home changes owner before the next budgeted projection step. Even a
-- blocked helper must not paint the previous home/path under the new center.
local oldOwner=h.plot.snapshot().frame;check(oldOwner~=nil,'manual-home fixture has a completed previous-owner picture')
a.gpsAction('home')
local freshHome=a.snapshot().session.home;local freshTrack=a.snapshot().session.track
check(freshHome and freshHome.source=='LOCAL MANUAL'and freshHome~=oldOwner.home,'real Set Home captures a fresh session owner')
check(h.plot.snapshot().frame==nil and not h.plot.snapshot().pending,'manual home clears old-owner pixels even when19% blocks preparation')
check(a.inputs.navPlotAt==-100 and a.inputs.navPlotYieldAt==-100,'manual home resets both progress and priority ownership timestamps')
local blockedClips=h.draw()
check(#blockedClips==0 and h.plot.snapshot().frame==nil,'no old-owner trail is painted while the fresh-home job is budget blocked')
check(a.snapshot().session.home==freshHome and a.snapshot().session.track==freshTrack,'blocked drawing preserves the fresh real home/history owner')
getUsage=function()return 0 end
frame=h.finish()
check(frame.home==freshHome and frame.track==freshTrack and frame.origin.lat==(freshHome.lat+0.0)and frame.origin.lon==(freshHome.lon+0.0),'next completed frame and centered home share the exact fresh origin')
getUsage=nil
loadstring=realLoadstring
print('PASS: '..checks..' actual GPS Track checks; mature180, rolling history, zooms, constant warm geometry, manual home, GPS loss and moving no-home origin')
