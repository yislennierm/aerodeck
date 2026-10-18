-- Actual app: live transmitter gauge, semantic map/HUD images and warm cache.
local adapter=assert(loadfile('tests/test_ui_navigation.lua'))('adapter')
local E=adapter.events;local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function find(a,kind,test)for _,c in ipairs(a.commands())do if c.kind==kind and test(c)then return c end end end
local function marker(a,name)
 if name=='quad'then return find(a,'disc',function(c)return c.r==3 and c.color==0xe8f2f5 and c.y>=64 and c.y<244 end)end
 return find(a,'pattern',function(c)return c.path:find('/'..name..'-18.png',1,true)and c.y>=64 and c.y<244 end)
end
local function fill(a)return find(a,'fill',function(c)return c.x==46 and c.w==7 and c.y>=7 and c.y+c.h==29 end)end
local opts={radioVoltage=6.6,radioGeneral={battMin=6.6,battMax=8.4,battWarn=6.8}}
local a=adapter.make(opts)
check(not fill(a),'empty native voltage range produces no fabricated full gauge')
check(find(a,'fill',function(c)return c.x==44 and c.y==5 and c.w==11 and c.h==26 and c.color==0x8ca4b3 end),'empty gauge retains a muted silhouette rather than implying a full coloured battery')
check(find(a,'text',function(c)return c.text=='6.6 V'and c.color==0xfa5b40 end),'native battery warning remains visible in red voltage even with empty gauge')
opts.radioVoltage=8.4;a.background(120);a.send(0)
check(fill(a)and fill(a).h==22,'native maximum fills the22px interior')
opts.radioVoltage=7.5;a.background(120);a.send(0)
check(fill(a)and fill(a).h==11,'midrange voltage produces a half-height gauge')
opts.radioCurrent=false;a.background(120);a.send(0)
check(not fill(a)and a.visible('-- V'),'stale TX voltage clears fill and voltage text')
local before=a.writes();a.send(E.EVT_TOUCH_TAP,{x=112,y=10})
check(a.state().page==1 and a.visible('12:34')and a.writes()==before,'expanded header cycles retained clock view without selecting Data or saving')
a.send(E.EVT_TOUCH_TAP,{x=120,y=10});check(a.state().page==5,'adjacent Data hit area begins exactly at120')
-- Map marker images remain native-size, exact positions/course and cached.
a=adapter.make({settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nmspMode=0\nautoHome=1\n'})
a.arrange(7);for i=1,30 do a.send(0)end
local quad=marker(a,'quad');local home=marker(a,'home')
check(quad and quad.r==3 and home and home.size==18,'actual Track draws a position dot and the Material home image')
local opens,scans,writes=a.bitmapLoads(),a.sourceScans(),a.writes()
for i=1,100 do a.send(0)end
check(a.bitmapLoads()==opens and a.sourceScans()==scans and a.writes()==writes,'warm map images cause no further SD loads, source scans or writes')
-- At coincident home/aircraft, the home glyph becomes a connected callout;
-- the geographic anchor remains exact instead of hiding one symbol.
local current=a.snapshot().session.current
check(current~=nil,'real sample GPS is current')
a.gpsAction('home');for i=1,30 do a.send(0)end
home=marker(a,'home');quad=marker(a,'quad')
check(home and quad and home.x<quad.x-10,'coincident home label is displaced instead of covering the quad')
check(find(a,'fill',function(c)return c.x==239 and c.y==153 and c.w==3 and c.h==3 end),'home collision callout retains the true center anchor')
a.setSensor('GPS',nil,false,true);a.background(120);a.send(0)
check(not marker(a,'quad')and marker(a,'home'),'GPS loss removes current aircraft but retains the known home')
a.arrange(1);a.background(120);a.send(0)
-- A fresh session home-bearing may be absent after loss; never fabricate a marker.
check(a.snapshot().session.current==nil,'image marker work does not invent a GPS fix')
print('PASS: '..checks..' actual native-range gauge, expanded header, semantic image marker, overlap, loss and warm-cache checks')
