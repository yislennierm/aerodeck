-- Actual GPS viewport, native position dot and modal ownership.
local adapter=assert(loadfile('tests/test_ui_navigation.lua'))('adapter')
local E=adapter.events;local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local fields={{name='RxBt',value=24,unit=0},{name='RQly',value=99,unit=0},
 {name='GPS',value={lat=25.9976807,lon=-97.1573563},unit=0},
 {name='Hdg',value=150,unit=7},{name='Yaw',value=0,unit=7,id=30},
 {name='Sats',value=13,unit=0},{name='GSpd',value=31,unit=5},{name='GAlt',value=123,unit=9},
 {name='Ptch',value=0,unit=7,id=30},{name='Roll',value=0,unit=7,id=30}}
local a=adapter.make({fields=fields,settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nmspMode=0\nautoHome=1\n'})
a.arrange(7);for i=1,20 do a.send(0)end
local function image()
 for _,c in ipairs(a.commands())do if c.kind=='disc'and c.r==3 and c.color==0xe8f2f5 then return c end end
end
local function fill(x,y,w,h)
 for _,c in ipairs(a.commands())do if c.kind=='fill'and c.x==x and c.y==y and c.w==w and c.h==h then return c end end
end
check(fill(0,34,480,212)and fill(76,64,328,180),'GPS shares Flight surface and75px rails without reducing the map height')
check(not a.visible('YAW')and not a.visible('COURSE'),'overview does not duplicate heading detail')
-- Four real readouts in each Flight-width rail, with native MID/SMALL fitting.
for _,x in ipairs({8,410})do for _,top in ipairs({49,101,153,205})do
 local value
 for _,c in ipairs(a.commands())do if c.kind=='text'and c.x==x and c.y>=top then
  local width,height=lcd.sizeText(c.text,c.flags)
  if c.y+height<=top+31 then value=c;check(width<=62,'supporting value fits its fixed62px column');check(c.flags%1024~=DBLSIZE,'GPS does not restore oversized numeric cards');break end
 end end
 check(value~=nil,'all eight supporting readouts occupy their declared cells')
end end

local dot=assert(image());local x,y=dot.x,dot.y
local reads,scans,writes=a.bitmapLoads(),a.sourceScans(),a.writes()
for _,angle in ipairs({0,45,90,135,180,225,270,315,359,360,-22.5})do
 a.setSensor('Yaw',angle,true,true);a.background(20);a.send(0)
 local marker=assert(image())
 check(marker.x==x and marker.y==y,'yaw changes cannot rotate, move or replace the position marker')
 check(marker.x-5>=76 and marker.x+5<404 and marker.y-5>=64 and marker.y+5<244,'dot and halo stay inside the map')
 local halo=0
 for _,c in ipairs(a.commands())do
  if c.kind=='disc'and c.x==x and c.y==y and c.r==5 and c.color==0x050c13 then halo=halo+1 end
  check(not(c.kind=='pattern'and c.path:find('/quad',1,true)),'position uses no aircraft bitmap')
  check(not(c.kind=='text'and c.text:match('^TRACK %d+/%d+$')),'projection progress is never presented as flight data')
 end
 check(halo==1,'white dot has exactly one dark native halo')
end
check(a.bitmapLoads()==reads and a.sourceScans()==scans and a.writes()==writes,'warm position rendering performs no SD reads, scans or writes')
a.setSensor('Yaw',nil,false,true);a.setSensor('Hdg',nil,false,true);a.background(40);a.send(0)
check(image()and image().x==x and image().y==y,'position remains valid without yaw or course')
check(a.visible('25.9976807')and a.visible('-97.1573563'),'exact coordinates are visible on the dashboard')
a.gpsScrollTo('Home LON')
check(a.visible('Home LON'),'home coordinates remain reachable in one unified inspector')
a.gpsScrollTo('Physical HDOP')
check(a.visible('NOT REPORTED'),'unreported physical precision is not invented')
a.send(E.EVT_VIRTUAL_EXIT)
check(not a.inputs.gpsInfo,'RTN returns directly to the dashboard')
a.send(E.EVT_VIRTUAL_ENTER);a.send(E.EVT_VIRTUAL_ENTER)
check(a.inputs.gpsInfo~=nil,'physical focus opens the visible Info control')
a.send(E.EVT_VIRTUAL_EXIT)
a.setSensor('GPS',nil,false,true);a.background(40);a.send(0)
check(not image()and a.visible('TRACK / LAST KNOWN'),'GPS loss cannot leave a live aircraft picture on the retained trail')
a.send(E.EVT_TOUCH_TAP,{x=400,y=259});local m=assert(a.inputs.gpsMenu)
check(m.kind=='ACTIONS'and not a.inputs.gpsMenuEnabled(2),'Set Home is disabled without valid current position')
local previous=a.snapshot().session.home
a.send(E.EVT_TOUCH_TAP,{x=180,y=m.top+24+45})
check(a.inputs.gpsMenu and a.snapshot().session.home==previous,'disabled action cannot change home')
a.send(E.EVT_VIRTUAL_EXIT)
check(a.writes()==0,'navigation and image direction never save settings')
print('PASS: '..checks..' actual GPS space/dot checks; viewport, native halo, heading independence, no progress counters, direct selectors, loss and home guards')
