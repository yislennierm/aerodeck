-- Run the actual cockpit with measured native font boxes and real asset dimensions.
-- This verifies LCD commands and cache behavior; physical frame rate needs the radio.
-- At the user's30–40cm distance, enforce font hierarchy and clear geometry, not a physical-legibility claim.
local f=assert(io.open('sdcard/SCRIPTS/TOOLS/telem.lua'));local original=f:read('*a');f:close()
local tail=assert(string.find(original,'return {init=init,run=run,stop=fcLink.stop}',1,true))
local source=string.sub(original,1,tail-1)..[[return {
 draw=function(data,colors)palette=colors;cockpit(data)end,
 enter=function()changePage(1)end,
 home=function(value)navHome=value end,
 stats=renderStats}]]
SMLSIZE=0;TINSIZE=128;MIDSIZE=256;DBLSIZE=512;CUSTOM_COLOR=4096;RIGHT=65536;SOLID=0
local checks=0
local function check(v,why)assert(v,why);checks=checks+1 end
local commands,opens,converts={}, {},0
local color
local colors={tape=1,border=2,green=3,muted=4,red=5,orange=6,white=7,dim=8,sky=9,ground=10,horizon=11,ladder=12,black=13,cyan=14,panel=15,bg=16}
local function fontMetrics(text,flags)
 text=tostring(text);local font=(flags or 0)%1024
 local scale=font==TINSIZE and .75 or font==MIDSIZE and 1.5 or font==DBLSIZE and 2 or 1
 local widths={W=10,M=9,I=3,[' ']=4,['/']=5,['.']=3};local width=0
 for i=1,#text do local char=string.sub(text,i,i)
  -- Native MID digits are14px wide;359=42px and2762=56px on the target.
  width=width+(font==MIDSIZE and char>='0'and char<='9'and 14/scale or widths[char]or 7)
 end
 return width*scale,font==TINSIZE and 12 or font==MIDSIZE and 29 or font==DBLSIZE and 38 or 17
end
lcd={sizeText=fontMetrics,setColor=function(_,c)color=c end,
 drawFilledRectangle=function(x,y,w,h)commands[#commands+1]={kind='fill',x=x,y=y,w=w,h=h,color=color}end,
 drawText=function(x,y,s,flags)
  local w,h=fontMetrics(s,flags);local left=x
  if math.floor(flags/RIGHT)%2==1 then left=x-w end
  commands[#commands+1]={kind='text',x=x,y=y,left=left,right=left+w,w=w,h=h,text=tostring(s),font=flags%1024,color=color}
 end,
 drawLine=function(x,y,x2,y2)commands[#commands+1]={kind='line',x=x,y=y,x2=x2,y2=y2,color=color}end,
 drawLineWithClipping=function(x,y,x2,y2,xmin,xmax,ymin,ymax)
  commands[#commands+1]={kind='clip',x=x,y=y,x2=x2,y2=y2,xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,color=color}
 end,drawCircle=function()end,drawFilledTriangle=function(x1,y1,x2,y2,x3,y3)
  commands[#commands+1]={kind='triangle',x1=x1,y1=y1,x2=x2,y2=y2,x3=x3,y3=y3,color=color}
 end,
 drawHudRectangle=function(pitch,roll,xmin,xmax,ymin,ymax)
  commands[#commands+1]={kind='hud',pitch=pitch,roll=roll,xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax}
 end,
 drawBitmap=function(b,x,y)commands[#commands+1]={kind='bitmap',bitmap=b,x=x,y=y}end,
 drawBitmapPattern=function(mask,x,y)commands[#commands+1]={kind='pattern',mask=mask,x=x,y=y,color=color}end}
local function pngSize(path)
 local localPath='sdcard'..path
 local image=assert(io.open(localPath,'rb'),'Missing runtime asset '..localPath)
 local bytes=image:read(26);image:close()
 check(string.sub(bytes,1,8)=='\137PNG\13\10\26\10','Runtime artwork must be lossless PNG')
 local function u32(i)local a,b,c,d=string.byte(bytes,i,i+3);return ((a*256+b)*256+c)*256+d end
 return u32(17),u32(21),string.byte(bytes,26)
end
Bitmap={open=function(path)
 check(string.find(path,'/SCRIPTS/TOOLS/AERODECK/icons/',1,true)==1,
  'Native Flight must not read instrument bitmaps, covers, textures or digit sprites: '..path)
 opens[#opens+1]=path;local w,h=pngSize(path)
 return {path=path,w=w,h=h}
end,getSize=function(b)return b.w,b.h end,toMask=function(b)
 check(b.w==18 and b.h==18,'Flight detail icons must use their 18 px assets')
 converts=converts+1;return b.path
end}
local app=assert(loadstring(source,'@actual-flat-flight'))()
local function draw(data)commands={};app.draw(data,colors);return commands end
local function first(kind,predicate)
 for _,c in ipairs(commands)do if c.kind==kind and (not predicate or predicate(c))then return c end end
end
local function textAt(x,top,bottom,right)
 for i,c in ipairs(commands)do
  if c.kind=='text'and c.x>=x and c.x<(right or x+1)and c.y>=top and c.y+c.h<=bottom then
   local hidden=false
   for j=i+1,#commands do local r=commands[j]
    if r.kind=='fill'and r.x<=c.left and r.x+r.w>=c.right and r.y<=c.y and r.y+r.h>=c.y+c.h then hidden=true;break end
   end
   if not hidden then return c end
  end
 end
end
local function inside(c,left,top,right,bottom,name)
 check(c~=nil,name..' must be drawn')
 check(c.left>=left and c.right<=right and c.y>=top and c.y+c.h<=bottom,name..' exceeds its cell: '..c.text)
end
local function field(x,top,bottom,expected,right,name)
 local c=textAt(x,top,bottom,right);inside(c,x,top,right,bottom,name)
 check(c.text==expected,name..' must preserve present values and missing state; got '..c.text)
 return c
end
local function fill(x,y,w,h,c)
 return first('fill',function(v)return v.x==x and v.y==y and v.w==w and v.h==h and (not c or v.color==c)end)
end
local function panelTextBounds()
 for _,c in ipairs(commands)do
  if c.kind=='text'and((c.x>=8 and c.x<=70)or(c.x>=410 and c.x<=472))then
   local left=c.x<=70 and 8 or 410;inside(c,left,35,left+62,244,'Side panel numeric or unit text')
  end
 end
end
local function visibleText(predicate)
 for i,c in ipairs(commands)do if c.kind=='text'and predicate(c)then
  local hidden=false
  for j=i+1,#commands do local r=commands[j]
   if r.kind=='fill'and r.x<=c.left and r.x+r.w>=c.right and r.y<=c.y and r.y+r.h>=c.y+c.h then hidden=true;break end
  end
  if not hidden then return c end
 end end
end
local function near(actual,expected,tolerance,why)check(math.abs(actual-expected)<=(tolerance or .5),why)end
local function pitchCaption(c)
 if c.kind~='text'or c.color~=colors.white or c.font~=SMLSIZE or not tonumber(c.text)then return false end
 local hudSeen=false
 for _,command in ipairs(commands)do
  if command.kind=='hud'then hudSeen=true end
  if command.kind=='text'and command.text=='P'and command.x==128 then return false end
  if command==c then return hudSeen end
 end
 return false
end
local function clearAngleFields(c)
 check(c.y+c.h<=64 or c.y>=84 or (c.right<=127 or c.left>=205)and(c.right<=285 or c.left>=353),'Pitch captions must remain clear of both live-angle readouts')
end
local data={lq=99,v=22.8,pct=73,rssi=-67,power=250,cells=6,mah=2762,snr=8,pitch=-12,roll=8,speed=31,alt=33,hdg=150,a=12.5}
local cells={{8,61,95,70,'lq'},{410,61,95,472,'v'},{8,126,155,70,'rssi'},{410,126,155,472,'mah'},
 {8,177,206,70,'snr'},{410,177,206,472,'a'},{8,225,243,70,'power'},{410,225,243,472,'cell'},
 {78,138,170,124,'speed'},{356,138,170,402,'alt'}}
app.enter();draw(data)
check(app.stats.background=='FLAT / NATIVE','Diagnostics must identify the actual flat renderer')
check(fill(4,35,70,209,colors.tape)and fill(406,35,70,209,colors.tape),'Matching narrow rails must preserve the reclaimed instrument area')
check(fill(78,34,324,30,colors.black),'Removing the top arming button must give the compass its full324px band')
for _,y in ipairs({108,159,208})do check(fill(8,y,62,1,colors.border)and fill(410,y,62,1,colors.border),'Rail separators must align')end
local lq=field(8,61,95,'99',70,'Link quality');check(lq.font==MIDSIZE,'Primary LQ retains the readable mid-size native font')
field(410,61,95,'22.8',472,'Pack voltage')
local rssi=field(8,126,155,'-67',70,'RSSI');local used=field(410,126,155,'2762',472,'Consumed capacity')
local snr=field(8,177,206,'8',70,'SNR');field(410,177,206,'12.5',472,'Current')
local power=field(8,225,243,'250',70,'TX power');local cell=field(410,225,243,'3.80',472,'Average cell voltage')
check(rssi.font==MIDSIZE and snr.font==MIDSIZE,'Actual RSSI and SNR receive the primary native29px value font')
check(used.font==MIDSIZE and used.h==29 and used.w==56,'A normal four-digit used counter retains its measured56px by29px native font box')
check(power.font==SMLSIZE and cell.font==SMLSIZE and power.h==17 and cell.h==17,'TX power and derived average cell voltage remain compact supporting context')
local speed=field(78,138,170,'31',124,'Ground speed');local altitude=field(356,138,170,'33',402,'GPS altitude')
near((speed.left+speed.right)/2,101,.5,'Ground speed centers its measured font box')
near((altitude.left+altitude.right)/2,379,.5,'Altitude centers its measured font box')
check(speed.font==MIDSIZE and altitude.font==MIDSIZE,'Normal tape values retain the mid-size native font')
local hud=assert(first('hud'));check(hud.pitch==-12 and hud.roll==8,'Renderer preserves the verified signed attitude')
check(hud.xmin==78 and hud.xmax==402 and hud.ymin==64 and hud.ymax==244,'Native HUD uses the enlarged 324 by180 viewport')
field(141,65,83,'-12',204,'Pitch angle');field(300,65,83,'+8',352,'Roll angle')
check(first('text',function(c)return c.text=='P'and c.x==128 end)and first('text',function(c)return c.text=='R'and c.x==286 end),'Compact live-angle prefixes retain distinct pitch and roll meanings')
for _,x in ipairs({141,300})do
 local number=textAt(x,65,83,x==141 and 204 or 352)
 local unit=first('text',function(c)return c.text=='deg'and c.x>number.x and c.x<(x==141 and 204 or 352)and c.y>=65 and c.y+c.h<=83 end)
 check(unit and unit.y+unit.h==number.y+number.h,'Angle degree units share their measured numeric baseline')
end
check(not first('triangle'),'The overlapping decorative bank pointer must be replaced by live angle values')
check((hud.xmax-hud.xmin-2*46)*(hud.ymax-hud.ymin)==232*180,'Clear attitude area must use the reclaimed232 by180 pixels')
check((232*180)>1.86*(184*122),'Clear attitude area must exceed the previous layout by at least86 percent')
check(not first('bitmap'),'Flight instruments must use native drawing without instrument bitmaps')
check(fill(78,64,46,180,colors.tape)and fill(356,64,46,180,colors.tape),'Equal opaque tapes define the clear attitude area')
check(first('text',function(c)return c.text=='GS km/h'and c.y>=64 and c.y+c.h<=81 end),'Speed caption identifies ground speed and its unit')
check(first('text',function(c)return c.text=='ALT m'and c.y>=64 and c.y+c.h<=81 end),'Altitude caption identifies metres')
check(fill(8,100,61,4,colors.green)and fill(410,100,26,4,colors.green),'Meters reflect actual LQ and battery percentage')
panelTextBounds()
for _,v in ipairs({{8,61,95,70,'%'},{410,61,95,472,'V'}})do
 local number=textAt(v[1],v[2],v[3],v[4]);local unit=first('text',function(c)return c.text==v[5]and c.y>=v[2]and c.y+c.h<=v[3]and c.x>number.x and c.x<v[4]end)
 check(unit and unit.y+unit.h==number.y+number.h,'Primary tiny units share their actual numeric baseline')
end
for _,caption in ipairs({'RSSI dBm','AVG CELL V','TX mW','CURRENT A','SNR dB','USED mAh'})do
 check(first('text',function(c)return c.text==caption end),'Rail captions retain their actual telemetry meaning and units')
end

draw({})
check(not first('hud'),'Missing pitch/roll must not draw a synthetic horizon')
check(first('text',function(c)return c.text=='ATTITUDE'end)and first('text',function(c)return c.text=='UNAVAILABLE'end),'Missing attitude must be explicit')
check(not first('text',function(c)return (c.x==141 or c.x==300)and c.y>=65 and c.y+c.h<=83 end),'Missing attitude must not leave angle values on screen')
for _,v in ipairs(cells)do
 local missing=field(v[1],v[2],v[3],'--',v[4],'Unavailable '..v[5])
 if v[1]==8 or v[1]==410 then check(missing.color==colors.muted,'Unavailable rail values must be visibly muted')end
end
check(not first('fill',function(c)return c.y==100 and c.h==4 and c.color~=colors.dim end),'Missing meter data leaves the tracks empty')

local zero={lq=0,v=0,pct=0,rssi=0,power=0,cells=6,mah=0,snr=0,pitch=0,roll=0,speed=0,alt=0,hdg=0,a=0}
draw(zero)
local zeroText={lq='0',v='0.0',rssi='0',cell='0.00',power='0',a='0.0',snr='0',mah='0',speed='0',alt='0'}
for _,v in ipairs(cells)do field(v[1],v[2],v[3],zeroText[v[5]],v[4],'Real zero '..v[5])end
check(first('hud'),'A real level attitude of zero remains available')
field(141,65,83,'+0',204,'Zero pitch angle');field(300,65,83,'+0',352,'Zero roll angle')

local bounded={lq=150,pct=150,v=22.8,cells=6}
draw(bounded);field(8,61,95,'150',70,'Out-of-range LQ')
check(fill(8,100,62,4,colors.green)and fill(410,100,36,4,colors.green),'Only the visual meters clamp over-range values')
bounded.lq=-15;bounded.pct=-10;draw(bounded);field(8,61,95,'-15',70,'Negative LQ')
check(not first('fill',function(c)return c.y==100 and c.h==4 and c.color~=colors.dim end),'Negative meter values cannot extend outside the track')
draw({lq=60,pct=73,estimated=true});check(textAt(8,61,95,70).color==colors.red,'Critical LQ uses the configured boundary')
check(first('text',function(c)return c.text=='~73%'end),'Estimated percentage retains its estimate marker')
draw({lq=80});check(textAt(8,61,95,70).color==colors.orange,'Low LQ uses the configured boundary')
draw({v=22.8,battery='BATTERY LOW',pct=73})
check(textAt(410,61,95,472).color==colors.orange and fill(410,100,26,4,colors.orange),'Battery warning retains its voltage and meter emphasis')
local function iconColor(name)
 local image=first('pattern',function(c)return string.find(c.mask,'/'..name..'-18.png',1,true)~=nil end)
 check(image~=nil,'Rail health icon must remain present');return image.color
end
check(iconColor('battery_full')==colors.orange,'Battery icon must emphasize an actual battery warning')
draw({});check(iconColor('cell_tower')==colors.muted and iconColor('battery_full')==colors.muted,'Missing link and battery telemetry must mute their health icons')
for _,v in ipairs({{99,colors.green},{80,colors.orange},{60,colors.red},{0,colors.red}})do
 draw({lq=v[1]});check(iconColor('cell_tower')==v[2],'Link icon must follow actual LQ threshold health, including real zero')
end
for _,count in ipairs({0,999,2762,9999,10000})do
 draw({mah=count});local usedValue=field(410,126,155,tostring(count),472,'Consumed-capacity range')
 check(usedValue.font==(count<10000 and MIDSIZE or SMLSIZE),'Consumption uses the largest requested native font that actually fits its62px width')
end
for _,count in ipairs({0,-1})do
 draw({v=22.8,cells=count});local value=field(410,225,243,'--',472,'Invalid configured cell count')
 check(value.color==colors.muted,'Undefined average cell voltage must remain unavailable')
end
for _,case in ipairs({{0,false},{73,false},{100,false},{73,true},{100,true},{999999999999,true}})do
 draw({v=22.8,pct=case[1],estimated=case[2]})
 local percent=first('text',function(c)return c.x==472 and c.y>=95 and c.y+c.h<=107 end)
 inside(percent,410,95,472,107,'Battery percentage')
 for _,c in ipairs(commands)do if c.kind=='fill'and c.x==410 and c.y==100 and c.h==4 then
  check(c.x+c.w<=percent.left-3,'Battery meter must remain separate from its fitted percentage text, including estimated100 percent')
 end end
 if case[1]==100 and case[2]then check(percent.text=='~100%','Normal estimated full capacity keeps its explicit estimate marker')end
end
draw({lq=999999999999,v=999999999999,pct=99,rssi=-999999999999,power=999999999999,cells=6,mah=999999999999,snr=-999999999999,
 speed=100000000,alt=-100000000,hdg=-999999,a=999999999999})
for _,v in ipairs(cells)do inside(textAt(v[1],v[2],v[3],v[4]),v[1],v[2],v[4],v[3],'Long '..v[5])end
panelTextBounds()
for _,c in ipairs(commands)do
 if c.kind=='text'and c.y>=64 and c.y+c.h<=244 and(c.x>=78 and c.x<=124 or c.x>=356 and c.x<=402)then
  local left=c.x<=124 and 78 or 356;inside(c,left,64,left+46,244,'Long tape tick or selected value')
 end
end
draw({alt=-33});field(356,138,170,'-33',402,'Negative altitude')

-- Bearing wrap must retain real values and move the ribbon smoothly through north.
local function ribbon(value,expected)
 draw({hdg=value});local badge=field(212,34,64,expected,268,'Heading ribbon badge')
 check(badge.font==MIDSIZE and badge.h==29,'The primary heading uses the large native29px font')
 for _,c in ipairs(commands)do if c.kind=='text'and c.y>=34 and c.y+c.h<=64 and c.x>=78 and c.x<=402 then
  inside(c,78,34,402,64,'Heading ribbon label')
 end end
end
ribbon(150,'150')
check(visibleText(function(c)return c.text=='210'and c.left>=324 and c.right<=400 and c.y>=34 and c.y+c.h<=64 end),'The freed upper-right band must show the complete nearby210-degree reference')
for _,v in ipairs({{0,'000'},{360,'000'},{720,'000'},{-360,'000'},{-1,'359'},{359,'359'},{1,'001'}})do ribbon(v[1],v[2])end
ribbon(359,'359')
local before=assert(visibleText(function(c)return c.text=='030'and c.y>=34 and c.y<64 end),'Near north, east-side bearing must wrap to 030').x
check(visibleText(function(c)return c.text=='330'and c.y>=34 and c.y<64 end),'Near north, west-side bearing must remain 330')
ribbon(1,'001')
local after=assert(visibleText(function(c)return c.text=='030'and c.y>=34 and c.y<64 end)).x
near(after,before-3.6,1,'Bearing labels must move continuously across 359 to 001')
for _,v in ipairs({{60,'N','E'},{150,'E','S'},{240,'S','W'},{330,'W','N'}})do
 ribbon(v[1],string.format('%03d',v[1]))
 check(visibleText(function(c)return c.text==v[2]and c.y>=34 and c.y<64 end)and visibleText(function(c)return c.text==v[3]and c.y>=34 and c.y<64 end),'Visible compass cardinals must wrap correctly')
end
for _,v in ipairs({{15,'015'},{140,'140'},{45.25,'045'},{14.6,'015'},{359.6,'000'},{-.4,'000'}})do
 ribbon(v[1],v[2]);local labelCount=0
 for _,c in ipairs(commands)do
  if c.kind=='text'and c.color==colors.white and c.font==SMLSIZE and c.y>=34 and c.y+c.h<=64 and c.left>=78 and c.right<=402 then
   labelCount=labelCount+1
   check(c.right<=204 or c.left>=276,'Heading labels must remain complete outside the center badge and its four-pixel gutter')
  end
  if c.kind=='line'and(c.color==colors.border or c.color==colors.muted)and(c.y==57 or c.y==60)and c.y2==62 then
   check(c.x<=204 or c.x>=276,'Heading ticks must not leave fragments beside the selected bearing')
  end
 end
 check(labelCount>=2,'Occlusion avoidance must retain useful bearing labels on the ribbon')
end
ribbon(nil,'--')
check(not visibleText(function(c)return c.y>=34 and c.y+c.h<=64 and c.left>=78 and c.right<=402 and c.text~='--'end),'Missing heading must not fabricate ribbon labels')
check(not first('line',function(c)return c.y==56 and c.y2==59 and c.color==colors.border end),'Missing heading must not fabricate bearing ticks')

-- The native horizon, fixed datum and signed ladder must use the same reference.
draw({pitch=0,roll=0,speed=0,alt=0})
local zeroHorizon=assert(first('clip',function(c)return c.color==colors.horizon end))
near((zeroHorizon.x+zeroHorizon.x2)/2,240,.5,'Zero-pitch horizon shares the aircraft x datum')
near((zeroHorizon.y+zeroHorizon.y2)/2,154,.5,'Zero-pitch horizon shares the aircraft and tape y datum')
local zeroStrokes={}
for _,c in ipairs(commands)do if c.kind=='clip'and c.color==colors.horizon then zeroStrokes[#zeroStrokes+1]=c end end
check(#zeroStrokes==2,'The zero-pitch horizon has two native clipped strokes')
near((zeroStrokes[2].y+zeroStrokes[2].y2)/2,155,.5,'The second horizon stroke adds one visible pixel')
check(first('line',function(c)return c.x==196 and c.x2==226 and c.y==154 and c.y2==154 and c.color==colors.orange end)
 and first('line',function(c)return c.x==254 and c.x2==284 and c.y==154 and c.y2==154 and c.color==colors.orange end),'Fixed aircraft wings must be level with the zero-pitch native horizon')
for _,side in ipairs({{196,226},{254,284}})do
 for y=153,156 do check(first('line',function(c)return c.x==side[1]and c.x2==side[2]and c.y==y and c.y2==y and c.color==colors.black end),'Aircraft wing uses the full four-pixel dark halo')end
 for y=154,155 do check(first('line',function(c)return c.x==side[1]and c.x2==side[2]and c.y==y and c.y2==y and c.color==colors.orange end),'Aircraft wing retains two gold pixels at its shared datum')end
end
check(fill(236,150,8,8,colors.black)and fill(237,151,6,6,colors.orange),'The wider aircraft retains a six-pixel center marker and dark outline')
local positive=assert(visibleText(function(c)return c.text=='20'and pitchCaption(c)and c.y<154 end),'Positive twenty-degree ladder label must be above datum')
local negative=assert(visibleText(function(c)return c.text=='-20'and pitchCaption(c)and c.y>154 end),'Negative twenty-degree ladder label must be below datum')
check(positive.font==SMLSIZE and negative.font==SMLSIZE and positive.h==17 and negative.h==17,'Signed major pitch labels use the native17px font')
check(not visibleText(function(c)return pitchCaption(c)and math.abs(tonumber(c.text))%20~=0 end),'Minor ten-degree rungs remain unlabelled')
near(positive.y+positive.h/2,154-37,.5,'Positive twenty degrees uses native 1.85 pixels per degree')
near(negative.y+negative.h/2,154+37,.5,'Negative twenty degrees uses native 1.85 pixels per degree')
for _,c in ipairs(commands)do
 if c.kind=='clip'then check(c.xmin==126 and c.xmax==354 and c.ymin==65 and c.ymax==243,'Horizon and ladder strokes stay inside the clear center viewport')end
 if c.kind=='text'and c.x==114 and c.y>=64 and c.y+c.h<=244 then check(not tonumber(c.text)or tonumber(c.text)>=0,'Ground-speed scale must not display negative tick values')end
end
for _,v in ipairs({{10,0},{-10,0},{10,30},{-10,30},{10,-30}})do
 draw({pitch=v[1],roll=v[2]})
 local selected=first('clip',function(c)return c.color==colors.ladder and math.abs((c.x+c.x2)/2-240)<=.5 and math.abs((c.y+c.y2)/2-154)<=.5 end)
 check(selected,'The actual signed pitch rung must meet the aircraft datum, including banked attitudes')
end
for _,pitch in ipairs({10,20,-10,-20,9.8,19.6})do
 draw({pitch=pitch,roll=0});local labelCount=0
 for _,c in ipairs(commands)do if pitchCaption(c)then
  labelCount=labelCount+1
  clearAngleFields(c)
  check(c.right<=193 or c.left>=288 or c.y+c.h<=150 or c.y>=165,'Pitch captions must remain clear of the fixed aircraft envelope')
 end end
 check(labelCount>=2,'Aircraft clearance must retain useful signed pitch labels')
 if pitch==20 then
  local caption=visibleText(function(c)return c.text==tostring(pitch)and c.color==colors.white and c.y>=65 and c.y<243 end)
  check(caption and caption.left>=288,'Selected level-bank pitch caption remains visible beyond the right aircraft wing')
 end
end
for _,roll in ipairs({35,-35,60,-60,90,-90,120,-120,180})do
 for _,pitch in ipairs({0,10,-10,25,-25})do
  draw({pitch=pitch,roll=roll});local captions={}
  for _,c in ipairs(commands)do if pitchCaption(c)then
   captions[#captions+1]=c
   clearAngleFields(c)
   check(c.right<=193 or c.left>=288 or c.y+c.h<=150 or c.y>=165,'Banked pitch captions must remain clear of the fixed aircraft envelope')
  end end
  check(#captions>=2,'Bank '..roll..' / pitch '..pitch..' must retain readable pitch captions')
  for i=1,#captions do for j=i+1,#captions do local a,b=captions[i],captions[j]
   check(a.right+3<=b.left or b.right+3<=a.left or a.y+a.h+3<=b.y or b.y+b.h+3<=a.y,
    'Pitch captions '..a.text..' and '..b.text..' need a three-pixel gap at bank '..roll..' / pitch '..pitch)
  end end
 end
end
for _,v in ipairs({{12,-35,'+12','-35'},{-25,120,'-25','+120'},{90,-180,'+90','-180'}})do
 draw({pitch=v[1],roll=v[2]})
 field(141,65,83,v[3],204,'Signed pitch angle');field(300,65,83,v[4],352,'Signed roll angle')
end
for _,data in ipairs({{pitch=10},{roll=20},{}})do
 draw(data)
 check(not first('hud')and not first('text',function(c)return (c.x==141 or c.x==300)and c.y>=65 and c.y+c.h<=83 end),'Incomplete attitude must suppress both the horizon and angle readouts')
end
for _,value in ipairs({0,3,7,9.9,10,13,17,23,27,30,33,36.6,-3,-33})do
 draw({speed=value,alt=value});local tickCount=0
 for _,c in ipairs(commands)do if c.kind=='text'and c.color==colors.muted and(c.x==114 or c.x==397)and c.y>=64 and c.y+c.h<=244 then
  tickCount=tickCount+1
  check(c.y%1==0,'Tape tick captions must land on native pixel rows')
  check(c.y>=82,'Tape tick captions must remain below the unit header')
  check(c.y+c.h<=138 or c.y>=170,'Tape tick captions must not be partially covered by the selected readout or its border')
  check(c.font==SMLSIZE and c.h==17,'Ordinary tape labels use the enlarged native17px font')
 end end
 check(tickCount>=2,'Tape readout clearance must retain useful surrounding tick labels')
end
draw({pitch=12,roll=30})
local banked=assert(first('clip',function(c)return c.color==colors.horizon end))
near((banked.x+banked.x2)/2,246,.5,'Banked pitch follows the native horizontal origin shift')
near((banked.y+banked.y2)/2,154+math.cos(math.pi/6)*12*1.85,.5,'Banked pitch follows the native vertical origin shift')
check(banked.y2<banked.y,'Positive bank retains the verified native horizon slope')

local warmOpens,warmConverts=#opens,converts
for i=1,150 do data.pitch=i%30;data.roll=i%60;data.mah=i;data.v=22+i/100;draw(data);if i%25==0 then collectgarbage('collect')end end
app.enter();draw(data)
check(#opens==warmOpens and converts==warmConverts,'Steady-state frames, collection and selecting Flight again must not reload or reconvert assets')
check(warmOpens==2 and warmConverts==2,'Cockpit loads only its two small rail icon masks')
print('PASS: '..checks..' actual Flight checks; rectangular PFD, heading wrap, signed native-scale ladder, shared datum, missing/zero/long telemetry, and icon-only stable cache')
