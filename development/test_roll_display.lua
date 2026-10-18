-- Actual app/real settings store with synthetic telemetry. This checks rendering
-- polarity and persistence; the user's physical radio still decides sign acceptance.
local adapter=assert(loadfile('development/test_ui_navigation.lua'))('adapter')
local storeFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/model-store.lua'))()
local E=adapter.events;local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function near(v,w,tolerance,why)check(type(v)=='number'and math.abs(v-w)<=(tolerance or .0001),why..': '..tostring(v))end
local base='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nmspMode=0\nvtxMode=2\nattitudeOverlay=1\nflightBank=0\ncompassSource=0\ncurrent=None\n'
local function make(direction,roll,pitch)
 local info={filename='roll-a.yml',name='UITEST'}
 local a=adapter.make({filename=info.filename,extrema={Roll={min=-.6,max=.9}}})
 local store=storeFactory.new({io=io,remove=del,rename=rename})
 local suffix=direction~=nil and'rollDisplay='..direction..'\n'or''
 check(store.save('settings',info,base..suffix,function(raw)if string.sub(raw,1,7)=='ADCFG1\n' then return{}end end),'fixture uses the actual filename-owned settings save')
 a.setAttitude(-(pitch or 0)*math.pi/180,(roll or 30)*math.pi/180)
 a.reinit();a.send(0)
 -- Record the real clipped horizon/ladder API, which the shared shell harness
 -- otherwise treats as an inert native call. Production source stays untouched.
 local clips,ink={},nil;local setColor,clip=lcd.setColor,lcd.drawLineWithClipping
 lcd.setColor=function(flag,color)ink=color;setColor(flag,color)end
 lcd.drawLineWithClipping=function(x,y,x2,y2,xmin,xmax,ymin,ymax,pattern,flags)
  clips[#clips+1]={x=x,y=y,x2=x2,y2=y2,color=ink}
  return clip(x,y,x2,y2,xmin,xmax,ymin,ymax,pattern,flags)
 end
 local h={a=a,info=info,store=store}
 function h.send(event,touch)clips={};local result=a.send(event or 0,touch);return result end
 function h.arrange(page)clips={};a.arrange(page)end
 function h.clips()return clips end
 h.send();return h
end
local function find(a,kind,predicate)
 for _,c in ipairs(a.commands())do if c.kind==kind and predicate(c)then return c end end
end
local function angle(a,x)
 return find(a,'text',function(c)return c.x==x and c.y>=65 and c.y<83 end)
end
local function cleanPrimary(a)
 check(not angle(a,300)and not angle(a,141),'Primary PFD removes both numerical P/R readouts')
 for _,c in ipairs(a.commands())do if c.kind=='text'and c.x>=126 and c.x<354 and c.y>=64 and c.y<222 then
  check(c.text~='P'and c.text~='R'and c.text~='deg'and c.text~='COG'and c.text~='YAW','Primary PFD has no angle/source captions')
  check(tonumber(c.text)==nil,'Primary PFD has no moving pitch-label numbers')
 end end
end
local function verifyHud(h,xmin,xmax,expectedRoll,expectedPitch,why)
 local a=h.a;local count=0
 for _,c in ipairs(a.commands())do if c.kind=='hud'then
  count=count+1;check(c.xmin==xmin and c.xmax==xmax,why..' uses its own native viewport')
  near(c.roll,expectedRoll,.0001,why..' passes selected display roll to native horizon')
  near(c.pitch,expectedPitch,.0001,why..' never changes pitch polarity')
 end end
 check(count==1,why..' draws exactly one native horizon')
end
local function verifyRaw(a,rawRoll,why)
 near(a.snapshot().roll,rawRoll,.0001,why..' leaves shared normalized Roll unchanged')
 local native,current=getSourceValue(1039)
 near(native,rawRoll*math.pi/180,.000001,why..' leaves native Roll source bytes/value unchanged')
 check(current==true,why..' preserves actual source freshness')
end
local function bankTip(a,warning)
 local best,distance
 for _,c in ipairs(a.commands())do
  if c.kind=='line'and(c.color==0x68dded or warning and c.color==0xffae62)and c.y>=84 and c.y<=140 and c.y2>=84 and c.y2<=140 then
   for _,v in ipairs({{x=c.x,y=c.y},{x=c.x2,y=c.y2}})do
    local r=(v.x-240)^2+(v.y-154)^2
    if r>=58^2 and r<=70^2 and(not distance or r<distance)then best=v;distance=r end
   end
  end
 end
 return best
end
local function coherentBank(h,displayed)
 local a=h.a;local tip=bankTip(a);check(tip~=nil,'graduated PFD draws its bank pointer')
 local radians=displayed*math.pi/180
 -- drawHudRectangle positive bank uses a horizon that rises toward the right.
 -- The skyward normal must therefore point upper-left, not opposite that sky.
 near(tip.x,240-math.sin(radians)*60,.6,'pointer follows the native skyward normal horizontally')
 near(tip.y,154-math.cos(radians)*60,.6,'pointer follows the native skyward normal vertically')
 local horizon
 for _,c in ipairs(h.clips())do if c.color==0x9dd0dd then horizon=c;break end end
 check(horizon~=nil,'graduated PFD draws the zero-horizon stroke')
 local dx,dy=horizon.x2-horizon.x,horizon.y2-horizon.y
 local nx,ny=tip.x-240,tip.y-154
 check(math.abs((dx*nx+dy*ny)/(math.sqrt(dx*dx+dy*dy)*60))<.025,'pointer is perpendicular to the moving horizon')
 check(displayed>0 and dy<0 or displayed<0 and dy>0 or displayed==0 and dy==0,'ladder slope agrees with the roll passed to the native horizon')
end
-- Default (including a pre-upgrade file with no new key) keeps the prior raw
-- display convention. Reversed changes all visual consumers, never telemetry.
for _,direction in ipairs({0,1})do
 for _,roll in ipairs({-60,-30,0,30,60})do
  local pitch=12;local displayed=(direction==1 and-roll or roll)+0.0
  local h=make(direction,roll,pitch);local a=h.a
  check(a.config.get('rollDisplay')==direction,'saved display direction reaches actual configuration')
  verifyHud(h,136,344,displayed,pitch,'primary PFD');verifyRaw(a,roll,'primary PFD')
  cleanPrimary(a)
  coherentBank(h,displayed)
  h.send(E.EVT_TOUCH_TAP,{x=150,y=233})
  check(a.visible('VIDEO >'),'actual Flight bank control reaches Video summary')
  verifyHud(h,284,392,displayed,pitch,'Flight Video mini HUD');verifyRaw(a,roll,'Flight Video summary')
  h.arrange(11);h.send(E.EVT_TOUCH_TAP,{x=400,y=45})
  check(a.visible('LIVE ATTITUDE'),'actual Video panel switch opens its live attitude view')
  verifyHud(h,341,462,displayed,pitch,'Video control mini HUD');verifyRaw(a,roll,'Video control panel')
  local caption=find(a,'text',function(c)return c.x==341 and c.y==195 end)
  check(caption and caption.text=='R '..string.format('%.0f',displayed)..' deg','Video R readout agrees with its horizon')
  h.arrange(5)
  local rawText=find(a,'text',function(c)return c.y==102 and c.x>370 and c.text==string.format('%.1f',roll)end)
  check(rawText~=nil,'LIVE telemetry Roll remains in the normalized source convention')
  h.send(E.EVT_TOUCH_TAP,{x=30,y=45})
  check(find(a,'text',function(c)return c.y==102 and c.x>370 and c.text==string.format('%.1f',-.6*180/math.pi)end)~=nil,'native MIN Roll is not flipped by a display preference')
  h.send(E.EVT_TOUCH_TAP,{x=30,y=45})
  check(find(a,'text',function(c)return c.y==102 and c.x>370 and c.text==string.format('%.1f',.9*180/math.pi)end)~=nil,'native MAX Roll is not flipped or swapped by a display preference')
 end
end
-- Mirror actual pitch-ladder strokes between the two display directions. This
-- covers translation as well as slope; changing just the pointer would fail.
for _,roll in ipairs({-45,-30,30,45})do
 local normal=make(0,roll,-12);local original=normal.clips()
 local reversed=make(1,roll,-12);local reflected=reversed.clips()
 check(#original>6 and #original==#reflected,'both directions preserve the real ladder stroke inventory')
 for i,line in ipairs(original)do
  local other=reflected[i];check(line.color==other.color,'mirrored ladder preserves semantic line color')
  near(other.x,480-line.x2,1,'reversed ladder mirrors its left endpoint horizontally')
  near(other.x2,480-line.x,1,'reversed ladder mirrors its right endpoint horizontally')
  near(other.y,line.y2,1,'reversed ladder left endpoint has the matching reflected height')
  near(other.y2,line.y,1,'reversed ladder right endpoint has the matching reflected height')
 end
end
-- Large banks retain full signed native geometry; only the small bank arc saturates.
for _,direction in ipairs({0,1})do
 local h=make(direction,150,-8);local a=h.a;local displayed=direction==1 and-150 or 150
 verifyHud(h,136,344,displayed,-8,'large-bank PFD');verifyRaw(a,150,'large-bank display')
 cleanPrimary(a)
 local tip=assert(bankTip(a,true),'Large-bank reference remains visible')
 local limited=displayed>0 and 60 or -60
 near(tip.x,240-math.sin(limited*math.pi/180)*60,.6,'Only the graduated pointer saturates beyond60deg')
 a.setAttitudeCurrent(false);h.send()
 check(not a.hud()and not angle(a,300)and a.visible('UNAVAILABLE'),'missing attitude never fabricates a flipped or cached horizon/readout')
 h.send(E.EVT_TOUCH_TAP,{x=150,y=233})
 check(not a.hud()and a.visible('NO ATTITUDE'),'missing Flight Video attitude stays explicit in either direction')
 h.arrange(11);h.send(E.EVT_TOUCH_TAP,{x=400,y=45})
 check(not a.hud()and a.visible('NO ATTITUDE')and a.visible('R --'),'missing Video panel Roll remains unavailable')
end
-- A real physical edit remains a draft until Save; reopening uses the same
-- filename-owned envelope, and another model never inherits its direction.
local h=make(nil,30,6);local a=h.a
check(a.config.get('rollDisplay')==0,'old saved settings without the new key default to unchanged Normal')
local primaryPath=assert(h.store.paths('settings',h.info)).canonical
local batteryBefore={}
for path,raw in pairs(a.files)do if string.find(path,'battery-',1,true)then batteryBefore[path]=raw end end
check(a.config.openSection(11,'rollDisplay'),'roll direction is physically reachable in User Interface settings')
a.config.input(E.EVT_VIRTUAL_ENTER);a.config.input(E.EVT_VIRTUAL_NEXT);a.config.input(E.EVT_VIRTUAL_ENTER)
check(a.config.hasChanges()and a.config.get('rollDisplay')==0,'rotary adjustment changes only the unsaved draft')
h.arrange(1);verifyHud(h,136,344,30,6,'unsaved setting')
check(a.config.save(),'explicit Save persists the display preference')
check(string.find(a.files[primaryPath],'\nrollDisplay=1\n',1,true)~=nil,'actual settings envelope contains the saved direction')
h.send();verifyHud(h,136,344,-30,6,'saved setting');verifyRaw(a,30,'saved setting')
a.reinit();h.send()
check(a.config.get('rollDisplay')==1 and a.config.get('current')=='None','reopen preserves correction and unrelated source choice')
verifyHud(h,136,344,-30,6,'reopened setting');verifyRaw(a,30,'reopened setting')
local saved=a.files[primaryPath]
a.setModelInfo({filename='roll-b.yml',name='UITEST'});h.send()
check(a.config.get('rollDisplay')==0 and a.files[primaryPath]==saved,'same display name on another model does not inherit or rewrite saved direction')
verifyHud(h,136,344,30,6,'different model default')
a.setModelInfo(h.info);h.send()
check(a.config.get('rollDisplay')==1 and a.files[primaryPath]==saved,'returning to original filename restores its saved correction')
verifyHud(h,136,344,-30,6,'original model return')
for path,raw in pairs(batteryBefore)do check(a.files[path]==raw,'display correction does not touch independent battery preferences')end
check(#a.timerWrites==0 and #a.timerResets==0 and #a.sensorResets==0,'display preference never resets native radio timers or telemetry')
print('PASS: '..checks..' actual-app roll display, sky-pointer/ladder, raw telemetry and per-model persistence checks (synthetic; physical sign acceptance remains open)')
