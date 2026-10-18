-- Actual production-app consumers for the final dashboard options.
local fixture=assert(loadfile('tests/fixtures/msp_fixture.lua'))()
local adapter=assert(loadfile('tests/test_ui_navigation.lua'))('adapter')
local E=adapter.events;local checks=0
local function check(v,why)assert(v,why);checks=checks+1 end
local base='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nvtxMode=2\npack=1\ncells1=6\ncapacity1=6000\nautoHome=1\n'
local function make(extra,opts)opts=opts or{};opts.settings=base..(extra or'');return adapter.make(opts)end
local function find(a,kind,predicate)for _,c in ipairs(a.commands())do if c.kind==kind and predicate(c)then return c end end end
local function center(a)return find(a,'text',function(c)return c.x>=208 and c.x<272 and c.y>=34 and c.y<64 end)end
local function tap(a,x,y)a.send(E.EVT_TOUCH_TAP,{x=x,y=y})end
local function cleanPrimary(a)
 for _,c in ipairs(a.commands())do if c.kind=='text'and c.x>=126 and c.x<354 and c.y>=64 and c.y<222 then
  check(c.text~='P'and c.text~='R'and c.text~='deg'and c.text~='COG'and c.text~='YAW'and tonumber(c.text)==nil,'Primary attitude stays free of numeric angle and source captions')
 end end
end
-- Compass reference changes the actual heading, with no silent fallback.
local a=make();cleanPrimary(a);check(center(a).text=='150'and not a.visible('COG')and not a.visible('YAW'),'default compass retains actual GPS course without source text')
a=make('compassSource=1\n');a.addSensor('Yaw',math.pi/2,UNIT_RADIANS,true);a.reinit();a.send(0)
check(center(a).text=='090'and not a.visible('YAW')and not a.visible('COG'),'selected body yaw retains its normalized live value without source text')
a.setSensor('Yaw',math.pi/2,false,true);a.background(50);a.send(0)
check(center(a).text=='--'and not a.visible('YAW')and not a.visible('COG'),'missing selected yaw never substitutes GPS course or source captions')
-- Minimal/Graduated affect overlays, retaining the same native attitude renderer.
a=make('attitudeOverlay=1\n');local graduated=0;for _,c in ipairs(a.commands())do if c.kind=='line'then graduated=graduated+1 end end
cleanPrimary(a);local hud=a.hud();check(hud and hud.xmin==136 and hud.xmax==344,'Graduated draws one native full-size horizon')
local pitch,roll=hud.pitch,hud.roll
a=make('attitudeOverlay=0\n');local minimal=0;for _,c in ipairs(a.commands())do if c.kind=='line'then minimal=minimal+1 end end
cleanPrimary(a);check(a.hud()and a.hud().pitch==pitch and a.hud().roll==roll and graduated>minimal+25,'Minimal removes graduated marks without changing attitude acquisition/sign')
-- Alternate flight banks are functional summaries, not a second hidden PFD draw.
local wire=fixture.new({external=true,clock=function()return getTime()end})
a=make('flightBank=1\n',{device=wire});for i=1,250 do a.send(0)end
check(a.visible('VIDEO /')and a.visible('5800')and not a.visible('NO CURRENT VTX REPORT'),'Video bank renders an actual verified live FC report')
local hudCount=0;for _,c in ipairs(a.commands())do if c.kind=='hud'then hudCount=hudCount+1;check(c.xmin==284 and c.xmax==392,'Video bank draws only its mini attitude')end end
check(hudCount==1,'alternate bank avoids drawing the covered primary horizon')
for _,sent in ipairs(wire.sent)do check(sent.cmd~=89 and sent.cmd~=250,'viewing alternate bank never writes FC settings')end
tap(a,150,233);check(a.visible('NAVIGATION')and a.visible('76Q4XRXV+33C') ,'bank cycling reaches current navigation')
check(not a.hud()and a.visible('To local home')and a.snapshot().session.current,'Navigation bank uses shared valid GPS/home session')
tap(a,150,233);check(a.hud()and a.hud().xmin==136 and a.visible('PFD >'),'bank cycle restores original PFD');cleanPrimary(a)
a=make('flightBank=2\n');check(a.visible('NAVIGATION')and not a.hud(),'saved default bank is applied on initialization')
-- Full date uses the real clock API; optional image uses the model header leaf.
a=make('modelImage=1\n');getDateTime=function()return{year=2026,mon=10,day=17,hour=12,min=34}end
a.background(110);a.send(0);for i=1,3 do tap(a,65,8)end
check(a.visible('2026/10/17'),'header cycles to complete date')
local opens,draws=0,{}
local realOpen=Bitmap.open;Bitmap.open=function(path)if path=='/IMAGES/quad.png'then opens=opens+1;return{216,132,path}end;return realOpen(path)end
lcd.drawBitmap=function(b,x,y,percent)draws[#draws+1]={b=b,x=x,y=y,percent=percent}end
a.setModelInfo({name='UITEST',bitmap='quad.png'});a.send(0)
a.arrange(12);for i=1,5 do tap(a,20,74)end
check(a.visible('ABOUT / SYSTEM')and a.visible('2026/10/17'),'About exposes real full date')
check(opens==1 and #draws==1 and draws[1].percent==50 and draws[1].x==352 and draws[1].y==91,'actual System image loads exact model filename and fits through native percent scaling')
for i=1,10 do a.send(0)end;check(opens==1,'warm System page reuses cached image handle')
a=make('modelImage=0\n');local offOpens=0;realOpen=Bitmap.open;Bitmap.open=function(path)if string.find(path,'/IMAGES/',1,true)then offOpens=offOpens+1 end;return realOpen(path)end
a.setModelInfo({name='UITEST',bitmap='quad.png'});a.arrange(12);for i=1,5 do tap(a,20,74)end
check(offOpens==0 and a.visible('OFF'),'disabled model image performs no image SD access')
-- Flight uses one capacity gauge; Power retains the separate voltage range.
a=make('',{values={RxBt=22.8,Capa=2762}});local d=a.snapshot()
check(math.abs(d.voltagePct-200/3)<.001 and math.abs(d.pct-(100-2762/60))<.001,'current cell voltage range is independent from consumed-capacity estimate')
check(not find(a,'fill',function(c)return c.x==410 and c.y==93 and c.h==2 end),'Flight omits the ambiguous voltage-range gauge')
local meter=find(a,'fill',function(c)return c.x==410 and c.y==103 and c.h==4 and c.w<62 end)
check(meter and math.abs(meter.w-62*d.pct/100)<.5 and a.visible('54%')and a.visible('EST'),'Flight full-width gauge consumes remaining capacity and retains estimate marker')
a.arrange(3)
local range=find(a,'fill',function(c)return c.x==19 and c.y==128 and c.h==3 and c.w<153 end)
check(range and math.abs(range.w-153*2/3)<.5 and a.visible('LEFT'),'Power retains voltage range separately from labelled remaining capacity')
a.setSensor('RxBt',22.8,false,true);a.background(30);a.send(0)
check(a.snapshot().voltagePct==nil and not find(a,'fill',function(c)return c.x==19 and c.y==128 and c.h==3 and c.w<153 end),'stale voltage clears Power voltage range')
a.arrange(1)
check(a.visible('54%')and a.visible('EST')and not find(a,'fill',function(c)return c.x==410 and c.y==93 and c.h==2 end),'missing voltage never replaces the independent remaining-capacity value')
print('PASS: '..checks..' actual dashboard option, bank, date, image and independent power gauge checks')
