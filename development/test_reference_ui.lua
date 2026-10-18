local project=arg[1]or'.'
local dependencies=arg[2]or project
-- Match EdgeTX's embedded string API; host string:method syntax is unavailable.
local stringMeta=debug.getmetatable('')
debug.setmetatable('',nil)
local function module(path)
 local chunk=assert(loadfile(path))
 local safe={type=type,tonumber=tonumber,tostring=tostring,ipairs=ipairs,pairs=pairs,pcall=pcall,math=math,string=string,table=table}
 setmetatable(safe,{__index=function(_,name)error('Forbidden UI module global: '..name)end})
 if setfenv then setfenv(chunk,safe)end
 return chunk()
end
local ui=module(project..'/sdcard/SCRIPTS/TOOLS/AERODECK/reference-ui.lua')
local arm=module(dependencies..'/sdcard/SCRIPTS/TOOLS/AERODECK/arm-status.lua')
local guides=module(dependencies..'/sdcard/SCRIPTS/TOOLS/AERODECK/reference.lua')
local checks=0
local function check(v,message)checks=checks+1;assert(v,message or('check '..checks))end
local colors={black=1,tape=2,cyan=3,white=4,muted=5,orange=6,border=7,dim=8,green=9}
local function setup(noTone)
 local records,tones,current={},{},nil
 local heights={[0]=21,[0x100]=20,[0x200]=12,[0x300]=17,[0x400]=29}
 local lcd={}
 function lcd.sizeText(text,flags)
  local h=heights[math.floor((flags or 0)/256)%16*256]or 17
  return #text*h*0.49,h
 end
 function lcd.setColor(_,color)current=color end
 function lcd.drawFilledRectangle(x,y,w,h,flags)
  records[#records+1]={kind='rect',x=x,y=y,w=w,h=h,color=current,flags=flags}
 end
 function lcd.drawText(x,y,text,flags)
  local w,h=lcd.sizeText(text,flags)
  records[#records+1]={kind='text',x=x,y=y,w=w,h=h,text=text,color=current,flags=flags}
 end
 local sink=not noTone and function(frequency,duration,pause)tones[#tones+1]={frequency,duration,pause}end or nil
 local options={arm=arm,reference=guides,lcd=lcd,palette=function()return colors end,fonts={tiny=0x200,small=0x300,medium=0x400},colorFlag=0x01000000,tone=sink}
 local app=assert(ui.new(options))
 local function draw(area)
  for i=#records,1,-1 do records[i]=nil end
  if area=='arm'then app.drawArm()else app.drawGuide()end
  for _,r in ipairs(records)do
   check(r.x>=4 and r.y>=62 and r.x+r.w<=476.01 and r.y+r.h<=244.01,'Every body element stays in its owned region: '..tostring(r.text or r.kind))
  end
  return records
 end
 return app,records,tones,draw,options
end
local function has(records,text)
 for _,r in ipairs(records)do if r.kind=='text'and r.text==text then return true end end
 return false
end
local app,records,tones,draw=setup()
local state=app.snapshot()
check(app.snapshot()==state,'Snapshot is a stable object')
check(state.view=='LIVE'and not state.reference and not state.liveAvailable and state.armCount==0)
check(state.armed==nil and state.ready==nil,'UI never makes an arming/readiness claim')
draw('arm');check(has(records,'NO LIVE DATA')and has(records,'STATUS MISSING'),'Missing is not shown as zero live flags')
check(not app.enabled('arm','armPreview')and not app.armAction('armPreview'))
check(app.armAction('armFilter'))
state=app.snapshot();check(state.reference and state.view=='REFERENCE'and state.armCount==30)
draw('arm');check(has(records,'OFFLINE REFERENCE')and not has(records,'LIVE BIT 0'),'Manual catalogue cannot appear active')
check(app.enabled('arm','armFamily')and app.armAction('armFamily'))
check(app.snapshot().referenceFamily=='INAV'and app.snapshot().armCount==25)
check(app.armAction('armSelect',12));draw('arm')
check(has(records,'KILLSW'),'Legacy reference remains available with its explanation')
check(app.armAction('armFamily'));check(app.snapshot().referenceFamily=='BF')
app.setContext('BF',1,46,26)
check(app.snapshot().armCount==26,'Reference matches exact known BF API/count when family matches')
for i=1,26 do
 check(app.armAction('armSelect',i));check(app.snapshot().armSelected==i)
 draw('arm')
end
check(app.snapshot().armPage==5 and not app.enabled('arm','armNext')and app.enabled('arm','armPrev'))
check(app.armAction('move',10000)and app.snapshot().armSelected==26,'Selection clamps at final reason')
check(app.armAction('move',-10000)and app.snapshot().armSelected==1,'Selection clamps at first reason')
check(not app.enabled('arm','armPrev')and not app.armAction('armPrev'))
check(app.armAction('armNext')and app.snapshot().armSelected==7)
check(app.armAction('armRow6')and app.snapshot().armSelected==12)
local target=app.hit('arm',9,88);check(target=='armRow1')
check(app.hit('arm',500,100)==nil and app.hit('arm',10,246)==nil,'Global footer remains parent-owned')
check(app.armAction('armFilter')and app.snapshot().view=='LIVE')
local reasonA={bit=18,code='GPS',title='GPS not ready',detail='A valid fix is required.',help='Wait for satellites.',known=true}
local reasonB={bit=7,code='THROTTLE',title='Throttle high',detail='Throttle is high.',help='Lower throttle.',known=true}
local live={reasons={reasonA,reasonB},maskHex='00040080'}
app.setLive(live,true,'LIVE')
check(app.snapshot().liveAvailable and app.snapshot().armCount==2)
draw('arm');check(has(records,'LIVE BIT 18')and has(records,'GPS'),'Live data is explicitly labelled')
check(app.armAction('armSelect',2))
app.setLive({reasons={reasonB,reasonA}},true,'LIVE')
check(app.snapshot().armSelected==1,'Selection follows surviving bit/code across reordered replies')
check(live.reasons[1]==reasonA and live.reasons[2]==reasonB and reasonA.reference==nil,'Caller decode data is not mutated')
app.setLive(live,false,'OLD')
check(not app.snapshot().liveAvailable and app.snapshot().armCount==0 and app.snapshot().status=='OLD','Offline clears LIVE immediately')
draw('arm');check(has(records,'STATUS OLD')and not has(records,'GPS'))
app.armAction('armFilter');check(app.snapshot().reference and app.snapshot().armCount==26,'Offline reference survives lost live data')
app.setLive(live,false,'OLD');check(app.snapshot().armCount==26)
app.armAction('armFilter');app.setLive(nil,true,'LIVE','UNSUPPORTED INAV RELEASE')
check(app.snapshot().status=='ERROR'and not app.snapshot().liveAvailable,'Transport activity alone is not decoded live evidence')
draw('arm');check(has(records,'STATUS ERROR'))
app.setLive({reasons={}},true,'LIVE')
draw('arm');check(has(records,'NO FLAGS')and has(records,'0 FLAGS'),'A verified empty reply is distinct from unavailable')
check(app.snapshot().armed==nil and app.snapshot().ready==nil)
-- A reason longer than the detail viewport remains entirely reachable.
local longReason={bit=1,code='LONG',title=string.rep('Long title ',15),detail=string.rep('Detailed context ',45),help=string.rep('Inspect conditions ',45)..' TAIL_SENTINEL',known=true}
app.setLive({reasons={longReason}},true,'LIVE')
check(app.snapshot().armScrollMax>1 and app.enabled('arm','armDetailDown'))
while app.enabled('arm','armDetailDown')do check(app.armAction('armDetailDown'))end
draw('arm');check(has(records,'TAIL_SENTINEL')or(function()for _,r in ipairs(records)do if r.text and string.find(r.text,'TAIL_SENTINEL',1,true)then return true end end end)(),'Last help text remains visible after scroll')
check(app.snapshot().armScroll==app.snapshot().armScrollMax and app.enabled('arm','armDetailUp'))
check(not app.armAction('armDetailDown'),'Scrolling is bounded')
-- Unknown live flag is not promoted into a verified audible code.
app.setLive({reasons={{bit=31,code='BIT 31',title='Unknown',detail='Unknown release',help='Use matching configurator',known=false}}},true,'LIVE')
check(not app.enabled('arm','armPreview')and not app.armAction('armPreview'))
draw('arm');check(has(records,'NO VERIFIED BEEP CODE'))
-- Full guide coverage, pagination and native control geometry.
check(app.snapshot().guideCount==20 and app.snapshot().guidePages==4)
for i=1,20 do check(app.guideAction('guideSelect',i));draw('guide')end
check(app.snapshot().guideSelected==20 and not app.enabled('guide','guideNext'))
app.guideAction('guideFamily');check(app.snapshot().guideFamily=='INAV'and app.snapshot().guideCount==28 and app.snapshot().guidePages==6)
for i=1,28 do check(app.guideAction('guideSelect',i));draw('guide')end
check(app.snapshot().guideSelected==28 and not app.enabled('guide','guideRow4')and not app.enabled('guide','guideRow5'),'Last partial guide page has no dead rows')
check(app.hit('guide',10,89)=='guideRow1'and app.hit('guide',10,222)==nil)
app.guideAction('guideSelect',20)
check(app.snapshot().guideScrollMax>1,'Long bypass conditions need and expose note scrolling')
while app.enabled('guide','guideNoteDown')do app.guideAction('guideNoteDown')end
draw('guide');check(app.snapshot().guideScroll==app.snapshot().guideScrollMax)
check(has(records,'MANUAL ONLY / NO COMMANDS')and has(records,'MANUAL GUIDE'),'Guide never claims to execute its shown command')
-- All four mode diagrams use the original normalized T/Y/P/R tuples. Compass
-- has distinct axes, unlike symmetric tuples that could conceal a mapping bug.
app.guideAction('guideFamily');app.guideAction('guideSelect',6)
local expected={{{25,102},{44,92}},{{25,92},{44,102}},{{20,102},{49,92}},{{20,92},{49,102}}}
for mode=1,4 do
 local delta=mode-app.snapshot().mode;app.guideAction('guideMode',delta)
 check(app.snapshot().mode==mode)
 draw('guide')
 local dots={};for _,r in ipairs(records)do if r.kind=='rect'and r.w==5 and r.h==5 and r.color==colors.green then dots[#dots+1]=r end end
 check(#dots>=2)
 for i=1,2 do check(dots[i].x==expected[mode][i][1]and dots[i].y==expected[mode][i][2],'Mode '..mode..' compass axis position')end
end
app.guideAction('guideMode',1);check(app.snapshot().mode==1,'Mode cycles4 ->1')
for _,bad in ipairs({'1',false,0/0})do check(not app.guideAction('guideMode',bad)and not app.guideAction('move',bad)and not app.armAction('move',bad))end
-- Tone scheduling: explicit user action, one normal-priority tone per callback,
-- no catch-up loops and no dependency on a getTime()/telemetry/output global.
local sound,_,played=setup()
sound.setLive({reasons={reasonA}},true,'LIVE')
check(#played==0 and sound.tick(100)==false,'No autoplay')
check(sound.armAction('armPreview')and sound.snapshot().playing)
check(sound.tick(100)and #played==1 and played[1][1]==2400 and played[1][2]==350 and played[1][3]==200)
check(not sound.tick(100)and not sound.tick(154)and #played==1)
check(sound.tick(155)and #played==2)
check(sound.tick(10000)and #played==3,'A long callback gap emits one tone, never a catch-up flood')
check(played[3][2]==350 and played[3][3]==400,'Final long tone preserves original pause')
check(not sound.tick(10074)and sound.tick(10075)and #played==4 and played[4][2]==100 and played[4][3]==200)
for _,now in ipairs({10105,10135,10165})do check(sound.tick(now))end
check(#played==7 and sound.snapshot().playing)
check(not sound.tick(10195)and not sound.snapshot().playing,'Sequence ends after final pause')
sound.armAction('armPreview');sound.tick(10200);local before=#played
sound.stop();check(not sound.tick(20000)and #played==before,'Leaving view cancels future tones')
sound.armAction('armPreview');check(sound.snapshot().playing)
check(not sound.tick(1)and not sound.snapshot().playing,'Clock rollback cancels rather than flooding audio')
sound.armAction('armPreview');sound.setLive(nil,false,'OLD')
check(not sound.snapshot().playing and not sound.tick(30000),'Live loss cancels its pending preview')
local mute=setup(true);mute.setLive({reasons={reasonA}},true,'LIVE')
check(not mute.enabled('arm','armPreview')and not mute.armAction('armPreview'),'Missing tone API is honest and inert')
check(ui.new({})==nil,'Required modules are not silently faked')
print('Reference UI: '..checks..' checks PASS (host synthetic; no radio writes or hardware claim)')
debug.setmetatable('',stringMeta)
