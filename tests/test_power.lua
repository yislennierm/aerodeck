-- Exercise real Power rendering, real settings/telemetry and the compact widget.
-- Synthetic fixtures only: these checks do not measure hardware rendering/FPS.
local hostio=io
local widgetFactory=assert(loadfile('sdcard/WIDGETS/AERODECK/main.lua'))
local adapter=assert(loadfile('tests/test_ui_navigation.lua'))('adapter')
local E=adapter.events
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local base='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nvtxMode=2\n'
local function make(options)
 local a=adapter.make(options);a.arrange(3);return a
end
local function find(a,predicate)
 for _,c in ipairs(a.commands())do if c.kind=='text'and predicate(c)then return c end end
end
local function has(a,text)return find(a,function(c)return c.text==text end)~=nil end
local function draw(a)
 local data=a.telemetryData();a.drawPower(data);return data
end
local function watts(a)
 return find(a,function(c)return string.match(c.text,'^CURRENT / .* W$')end)
end
local function bounds(c)
 local w,h=lcd.sizeText(c.text,c.flags);local left=c.x
 if math.floor(c.flags/RIGHT)%2==1 then left=left-w end
 return left,c.y,left+w,c.y+h
end
local function inspectLayout(a)
 local rows={}
 for _,c in ipairs(a.commands())do
  if c.kind=='text'and c.y>=64 and c.y<218 then
   local left,top,right,bottom=bounds(c)
   local x1,x2=c.x<191 and 8 or 191,c.x<191 and 183 or 472
   check(left>=x1+7 and right<=x2-7 and top>=64 and bottom<=218,'Power text stays inside its own panel: '..c.text)
   if c.x==19 or c.x==172 then rows[c.y]=rows[c.y]or {};rows[c.y][c.x]=c end
  elseif c.kind=='text'and c.y>=222 then
   local left,top,right,bottom=bounds(c)
   local x1,x2=c.x<168 and 8 or c.x<328 and 168 or 328,c.x<168 and 160 or c.x<328 and 320 or 472
   check(left>=x1+7 and right<=x2-7 and top>=222 and bottom<=243,'Power action label stays in its hit cell')
  elseif c.kind=='line'and c.x>=201 and c.x2<=461 and c.y>=64 then
   local top,bottom=c.y<145 and 90 or 171,c.y<145 and 126 or 207
   check(c.y>=top and c.y<=bottom and c.y2>=top and c.y2<=bottom,'Power traces stay inside their plot below the source caption')
  end
 end
 for _,row in pairs(rows)do if row[19]and row[172]then
  local _,_,captionRight=bounds(row[19]);local valueLeft=bounds(row[172])
  check(valueLeft>=captionRight+6,'Power value must not overlap its caption: '..row[19].text..' / '..row[172].text)
 end end
end

-- Cache-health states affect the visible explanation, not invented numeric data.
for _,case in ipairs({
 {name='disabled',options={settings=base..'voltage=None\n'},state='OFF',message='SOURCE DISABLED'},
 {name='not discovered',options={absent={RxBt=true}},state='NOT FOUND',message='SENSOR NOT FOUND'},
 {name='invalid',options={values={RxBt='invalid'}},state='INVALID',message='INVALID SENSOR VALUE'},
 {name='stale',options={current={RxBt=false}},state='STALE',message='WAITING FOR LIVE DATA'}
})do
 local a=make(case.options);local d=draw(a);local _,state=a.sourceStatus({'RxBt','VFAS','Bat'})
 check(state==case.state,'cached voltage health matches '..case.name)
 check(d.v==nil and has(a,case.message),'Power explains '..case.name..' instead of drawing a phantom voltage')
 check(not watts(a),'no watts may be derived from unavailable voltage')
 inspectLayout(a)
 if case.state=='OFF'then
  local saved=a.savedSettings();check(a.send(E.EVT_TOUCH_TAP,{x=210,y=231})==0,'disabled source can be refreshed')
  d=draw(a);check(d.v==nil and a.config.get('voltage')=='None'and a.savedSettings()==saved and a.writes()==0,'refresh must honor a deliberately saved None and never rewrite settings')
 end
end
for _,case in ipairs({{current=false,value=12,state='STALE'},{current=true,value='bad',state='INVALID'}})do
 local a=make({values={Curr=case.value},current={Curr=case.current}});local d=draw(a)
 local _,state=a.sourceStatus('Curr')
 check(d.a==nil and state==case.state and not watts(a),'stale/invalid current cannot produce watts or a live current trace')
 check(has(a,case.state=='STALE'and 'WAITING FOR LIVE DATA'or 'INVALID SENSOR VALUE'),'current source failure remains explicit')
end
local missingCurrent=make({absent={Curr=true}});local missingData=draw(missingCurrent)
local _,missingState=missingCurrent.sourceStatus('Curr')
check(missingData.a==nil and missingState=='NOT FOUND'and has(missingCurrent,'SENSOR NOT FOUND')and not watts(missingCurrent),'undiscovered current is diagnosed separately and never derives watts')
local a=make();local d=draw(a)
check(d.v==24 and d.a==12 and watts(a).text=='CURRENT / 288 W','watts use both current engineering values')
local reads,scans=a.sourceReads(),a.sourceScans()
for i=1,100 do a.drawPower(d)end
check(a.sourceReads()==reads and a.sourceScans()==scans,'Power source-health rendering consumes cached state without sensor reads/scans')
inspectLayout(a)
a=make({values={Curr=0}});d=draw(a)
check(d.a==0 and has(a,'0.0 A')and watts(a).text=='CURRENT / 0 W','real zero current is valid and derives zero watts')
a=make({values={RxBt=0,Curr=0}});d=draw(a)
check(d.v==0 and d.a==0 and watts(a).text=='CURRENT / 0 W','a received numeric zero voltage is not absence')

-- Legacy three-profile files survive five-profile defaults, edits and reload.
local old=base..'pack=3\ncells1=6\ncapacity1=1300\ncells2=4\ncapacity2=2200\ncells3=6\ncapacity3=1700\n'
a=make({settings=old})
check(a.config.get('pack')==3 and a.config.get('capacity1')==1300 and a.config.get('capacity2')==2200 and a.config.get('capacity3')==1700,'legacy active selection and all three saved profiles remain unchanged')
for _,i in ipairs({4,5})do check(a.config.get('cells'..i)==4 and a.config.get('capacity'..i)==1500,'new profile '..i..' receives compatible defaults')end
a.arrange(8);check(a.config.openSection(4,'pack'),'battery favourites remain a real configurable category')
check(a.send(E.EVT_VIRTUAL_ENTER)==0);check(a.send(E.EVT_VIRTUAL_NEXT)==0);check(a.send(E.EVT_VIRTUAL_NEXT)==0);check(a.send(E.EVT_VIRTUAL_ENTER)==0)
check(a.config.openSection(4,'capacity5'),'fifth capacity row is reachable through actual configuration')
check(a.send(E.EVT_VIRTUAL_ENTER)==0);check(a.send(E.EVT_VIRTUAL_NEXT)==0);check(a.send(E.EVT_VIRTUAL_ENTER)==0)
check(a.send(E.EVT_TOUCH_TAP,{x=190,y=231})==0,'real Save Settings action writes the profile draft')
check(a.config.get('pack')==5 and a.config.get('capacity5')==1550 and a.config.get('capacity3')==1700,'fifth active pack and edit persist without damaging old profiles')
local saved=a.savedSettings();local reopened=make({settings=saved})
check(reopened.config.get('pack')==5 and reopened.config.get('capacity5')==1550 and reopened.config.get('cells4')==4,'saved fifth profile reloads through the production parser')

local selected=base..'pack=5\ncells5=6\ncapacity5=1500\n'
a=make({settings=selected,values={Capa=350}});d=draw(a)
check(d.capacity==1500 and d.remainingMah==1150 and math.abs(d.pct-100*1150/1500)<.001 and d.estimated,'selected-capacity remaining uses actual consumption and is explicitly estimated')
check(has(a,'~77% / 1.15 Ah'),'Power shows the selected-capacity estimate and remaining amount')
a=make({settings=selected,values={Capa=0}});d=draw(a)
check(d.remainingMah==1500 and d.pct==100 and d.estimated,'a current zero consumption may correctly yield estimated full capacity')
a=make({settings=selected,absent={Capa=true}});d=draw(a)
check(d.remainingMah==nil and d.pct==nil and not d.estimated,'missing consumption must not fabricate full remaining capacity or100 percent')
a=make({settings=selected,current={Capa=false}});d=draw(a)
check(d.remainingMah==nil and d.pct==nil,'stale consumption cannot keep a prior capacity estimate')
a=make({settings=selected,absent={Capa=true}});a.addSensor('Bat%',83,0,true)
check(a.send(E.EVT_TOUCH_TAP,{x=210,y=231})==0);d=draw(a)
check(d.remainingMah==nil and d.pct==83 and not d.estimated,'real native remaining percentage survives missing consumption without inventing remainingmAh')
a=make({settings=selected,values={Capa=350}});a.addSensor('Bat%',99,0,true)
check(a.send(E.EVT_TOUCH_TAP,{x=210,y=231})==0);d=draw(a)
check(d.remainingMah==1150 and math.abs(d.pct-100*1150/1500)<.001 and d.estimated,'a selected capacity uses its own consumed-based estimate consistently even when native percentage differs')
a=make({settings=selected,values={Capa=2000}});d=draw(a)
check(d.remainingMah==0 and d.pct==0,'consumption beyond selected capacity clamps remaining at zero')
a=make({values={Capa=2762}});draw(a);check(has(a,'2.76 Ah'),'used capacity formats large totals in Ah')
a=make({values={Capa=999}});draw(a);check(has(a,'999 mAh'),'small consumed totals retain mAh')

-- Exercise numeric fitting with the actual renderer, not copied layout logic.
a=make({values={RxBt=999999999999,Curr=999999999999,Capa=999999999999}});draw(a);inspectLayout(a)
local long='Pack Voltage With A Very Long Telemetry Sensor Name'
a=make({settings=base..'voltage='..long..'\n'});a.addSensor(long,24,'V',true)
check(a.send(E.EVT_TOUCH_TAP,{x=210,y=231})==0,'real refresh discovers the newly present manual source')
check(a.send(0)==0);d=draw(a);check(d.v==24,'long manual source names resolve to actual telemetry');inspectLayout(a)

-- Compact widget uses the main app's shared data, including source decisions.
-- Qualified source/input-collision coverage lives in test_widget_lifecycle.lua.
local function widgetCase(options)
 local a=adapter.make(options or{})
 local commands,loads,backgrounds={},0,0
 local mainLoader=loadScript
 loadScript=function(path)
  if path=='/SCRIPTS/TOOLS/telem.lua'then
   loads=loads+1
   return function()return{
    init=function()end,
    background=function()backgrounds=backgrounds+1;a.background()end,
    snapshot=a.snapshot,
    run=function(event,touch)return a.send(event,touch)end
   }end
  end
  return mainLoader(path)
 end
 local drawText=lcd.drawText
 lcd.drawText=function(x,y,s,flags)commands[#commands+1]={x=x,y=y,text=tostring(s)}end
 local widget=widgetFactory();local instance=widget.create({x=0,y=0,w=480,h=140},{})
 for i=1,4 do widget.refresh(instance,nil)end
 check(loads==1 and backgrounds==1 and instance.app,'cold widget load/chunk/init complete before the first shared live service')
 local function contains(s)for _,c in ipairs(commands)do if c.text==s then return true end end;return false end
 local retained=instance.app;local data=a.snapshot();local scans=a.sourceScans()
 widget.background(instance);widget.refresh(instance,nil)
 check(loads==1 and backgrounds==3 and instance.app==retained and a.snapshot()==data,'compact/hidden callbacks retain the same shared application and snapshot')
 check(a.sourceScans()==scans,'compact/hidden warm sampling must not enumerate model sensors again')
 lcd.drawText=drawText
 return contains
end
local contains=widgetCase({values={Curr=0}})
check(contains('0.0 A'),'compact widget displays the actual shared zero current')
contains=widgetCase({settings=base..'voltage=None\n',values={Curr=12}})
check(contains('--')and contains('12.0 A'),'compact widget honors shared voltage None without suppressing current')
contains=widgetCase({values={Curr=123},current={Curr=false}})
check(contains('--')and not contains('123.0 A'),'compact widget cannot display a stale numeric current from the shared app')
io=hostio
print('PASS: '..checks..' actual Power/source-health, watts, five-profile persistence, capacity prerequisite, bounds and shared-session widget assertions')
