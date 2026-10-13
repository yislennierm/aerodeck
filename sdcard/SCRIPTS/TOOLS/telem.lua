-- toolName = TNS|AERODECK|TNE
-- AERODECK: integrated 480x272 TX16S cockpit and telemetry console.
-- Flight/nav/power: synthetic data. System: real read-only sensor inspector.
-- No model writes or RF commands. Absent telemetry is shown as --.
-- PAGE cycles six pages; bottom tabs select directly.
-- Tools: ENTER/header cycles diagram mode 1-4; PREV/NEXT touchscreen buttons change list.
-- Telemetry: ENTER or touch the header status to cycle LIVE/DEMO/LOW/LINK LOSS.
-- Aileron/elevator sticks tilt the flight display. RTN exits.
local telemetry=(function()
local root='/SCRIPTS/TOOLS/AERODECK/'
local bg,colors,start,last,mode,glyphs,minimum
local units={}
local function scanUnits()
 units={}
 for i=0,63 do local sensor=model.getSensor(i);if sensor and sensor.name then units[sensor.name]=sensor.unit end end
end
local function init() start=getTime();last=-100;mode=2;glyphs={};minimum=nil;scanUnits() end
local function ink(c) lcd.setColor(CUSTOM_COLOR,c) end
local function box(x,y,w,h,c) ink(c);lcd.drawFilledRectangle(x,y,w,h,CUSTOM_COLOR) end
local function txt(x,y,s,c,right)
 ink(c);lcd.drawText(x,y,s,CUSTOM_COLOR+SMLSIZE+(right and RIGHT or 0))
end
local function number(x,y,s)
 s=tostring(s)
 for i=1,#s do
  local c=string.sub(s,i,i);local token=({['.']='dot',['-']='minus'})[c] or c
  local k='n22-'..token
  if not glyphs[k] then glyphs[k]=Bitmap.open(root..k..'.png') end
  lcd.drawBitmap(glyphs[k],x+(i-1)*13,y)
 end
end
local function read(names,kind)
 for _,name in ipairs(names) do
  local f=getFieldInfo(name)
  if f then local v=getValue(f.id);if type(v)=='number' then
   local unit=units[name]
   if kind=='speed' then
    if unit==UNIT_KTS then v=v*1.852 elseif unit==UNIT_MPH then v=v*1.609344 elseif unit==UNIT_METERS_PER_SECOND then v=v*3.6 elseif unit==UNIT_FEET_PER_SECOND then v=v*1.09728 elseif unit~=UNIT_KMH then return nil end
   elseif kind=='angle' then
    if unit==UNIT_RADIANS then v=v*180/math.pi elseif unit~=UNIT_DEGREE then return nil end
   elseif kind=='alt' then
    if unit==UNIT_FEET then v=v*.3048 elseif unit~=UNIT_METERS then return nil end
   end
   return v
  end end
 end
end
local function fmt(v,pattern,suffix)
 if type(v)~='number' then return '--' end
 return string.format(pattern or '%.0f',v)..(suffix or '')
end
local function getData(t)
 if mode~=1 then
  local low=mode==3;local lost=mode==4
  return {v=low and 13.6 or 16.4+.08*math.sin(t/4),a=25+5*math.sin(t/3),mah=2762+math.floor(t*5),pct=low and 16 or 83,lq=lost and nil or 99,rssi=lost and nil or -68,snr=lost and nil or 12,power=250,down=lost and nil or 100,rf=3,sats=lost and nil or 13,speed=lost and nil or 31+4*math.sin(t/5),alt=lost and nil or 33,hdg=lost and nil or (150+t*2)%360,pitch=lost and nil or -.2+math.sin(t/3),roll=lost and nil or .5+3*math.sin(t/4),flight=lost and '--' or 'ACRO',ok=not lost,demo=true}
 end
 local r=getRSSI();local ok=type(r)=='number' and r>0
 if not ok then return {ok=false,demo=false} end
 return {v=read({'RxBt','VFAS','Bat'}),a=read({'Curr'}),mah=read({'Capa'}),pct=read({'Bat%'}),lq=read({'RQly','LQ'}),rssi=read({'1RSS','RSSI'}),snr=read({'RSNR','SNR'}),power=read({'TPWR'}),down=read({'TQly'}),rf=read({'RFMD'}),sats=read({'Sats'}),speed=read({'GSpd'},'speed'),alt=read({'GAlt'},'alt'),hdg=read({'Hdg'},'angle'),pitch=read({'Ptch'},'angle'),roll=read({'Roll'},'angle'),flight='--',ok=true,demo=false}
end
local function run(event,touch)
 if event==EVT_VIRTUAL_EXIT then return 1 end
 if not start then init() end
 local new=mode
 if event==EVT_VIRTUAL_ENTER then new=mode%4+1
 
 elseif event==EVT_TOUCH_TAP and touch and touch.y<36 and touch.x>=309 then new=mode%4+1 end
 if new~=mode then mode=new;minimum=nil;last=-100;scanUnits() end
 local now=getTime();if now-last<10 and now>=last then return 0 end;last=now
 if not colors then colors={white=lcd.RGB(236,243,244),muted=lcd.RGB(142,162,175),gold=lcd.RGB(234,182,100),green=lcd.RGB(142,214,176),cyan=lcd.RGB(131,207,232),red=lcd.RGB(255,101,95),dark=lcd.RGB(10,17,23)} end
 local p=colors;if not bg then bg=Bitmap.open(root..'console.png') end
 lcd.drawBitmap(bg,0,0)
 local d=getData((now-start)/100)
 -- Never retain old telemetry values after a link loss.
 if not d.ok then d={ok=false,demo=mode~=1} end
 if d.v and (not minimum or d.v<minimum) then minimum=d.v end
 local status=mode==1 and (d.ok and 'LIVE SENSORS' or 'NO TELEMETRY') or (mode==3 and 'DEMO / LOW PACK' or mode==4 and 'DEMO / LINK LOSS' or 'DEMO / NORMAL')
 local alert=(mode==3 or not d.ok)
 -- Status is right aligned to fit the fixed header slot.
 box(309,9,156,20,alert and p.red or p.dark);txt(460,13,status,alert and p.dark or p.gold,true)
 number(17,72,fmt(d.v,'%.2f'));number(176,72,fmt(d.lq));number(334,72,fmt(d.speed,'%.1f'))
 local cells=d.demo and 4 or nil -- never infer chemistry/cell count from live voltage
 local rows={
  {fmt(d.a,'%.1f',' A'),fmt(d.mah,'%.0f',' mAh'),fmt(d.pct,'%.0f',' %'),fmt(cells and d.v and d.v/cells,'%.2f',' V'),fmt(d.ok and minimum or nil,'%.2f',' V'),cells and '4S / DEMO' or '--'},
  {fmt(d.rssi,'%.0f',' dBm'),fmt(d.snr,'%.0f',' dB'),fmt(d.power,'%.0f',' mW'),fmt(d.down,'%.0f',' %'),fmt(d.rf),d.ok and 'CONNECTED' or 'NO DATA'},
  {fmt(d.sats),fmt(d.alt,'%.0f',' m'),fmt(d.hdg,'%.0f',' deg'),fmt(d.pitch,'%.1f',' deg'),fmt(d.roll,'%.1f',' deg'),d.flight or '--'}
 }
 for col=1,3 do
  local c=col==1 and (mode==3 and p.red or p.gold) or col==2 and p.green or p.cyan
  for j=1,6 do txt(149+(col-1)*158,124+(j-1)*19,rows[col][j],d.ok and (j==6 and c or p.white) or p.muted,true) end
  local v=col==1 and d.pct or col==2 and d.lq or (d.sats and math.min(100,d.sats/20*100))
  for j=0,19 do if v and j<v/5 then box(16+(col-1)*158+math.floor(j*6.6),102,4,3,c) end end
 end
 box(8+(mode-1)*118,248,110,2,alert and p.red or p.gold)
 return 0
end
return {init=init,run=run,release=function() bg=nil;glyphs={};collectgarbage('collect') end,refresh=function() last=-100 end}

end)()
local ROOT='/SCRIPTS/TOOLS/AERODECK/'
local started, page, background, palette, failure
local glyphs={}
local widths={[30]=18,[22]=13,[16]=10,[11]=7}
local pages={'flight','nav','power','system','console','console'}
local order={1,5,2,3,4,6}
local function adjacent(delta)
 for i,v in ipairs(order) do if v==page then return order[(i-1+delta)%6+1] end end
end
local bezel,ribbon
local scenario,zoom=1,2
local sensors,sensorOffset={},0
local lastFrame=-100
local pi=math.pi
local function round(x) return math.floor(x+0.5) end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function ink(c) lcd.setColor(CUSTOM_COLOR,c) end
local function rect(x,y,w,h,c)
 if w<=0 or h<=0 then return end
 ink(c);lcd.drawFilledRectangle(round(x),round(y),round(w),round(h),CUSTOM_COLOR)
end
local function line(x,y,a,b,c)
 ink(c);lcd.drawLine(round(x),round(y),round(a),round(b),SOLID,CUSTOM_COLOR)
end
local function clip(x,y,a,b,xmin,xmax,ymin,ymax,c)
 ink(c);lcd.drawLineWithClipping(round(x),round(y),round(a),round(b),xmin,xmax,ymin,ymax,SOLID,CUSTOM_COLOR)
end
local function circle(x,y,r,c)
 ink(c);lcd.drawCircle(round(x),round(y),round(r),CUSTOM_COLOR)
end
local function triangle(x,y,heading,size,c)
 local a=heading*pi/180
 local function pt(dx,dy) return x+dx*math.cos(a)-dy*math.sin(a), y+dx*math.sin(a)+dy*math.cos(a) end
 local x1,y1=pt(0,-size);local x2,y2=pt(-size*.65,size*.7);local x3,y3=pt(size*.65,size*.7)
 ink(c);lcd.drawFilledTriangle(round(x1),round(y1),round(x2),round(y2),round(x3),round(y3),CUSTOM_COLOR)
end
local function loadBitmap(file)
 local b=Bitmap.open(ROOT..file..'.png')
 local w,h=Bitmap.getSize(b)
 if w==0 or h==0 then failure='Missing/too large: '..file end
 return b
end
local function digits(x,y,value,size)
 local s=tostring(value)
 for i=1,#s do
  local c=string.sub(s,i,i) -- EdgeTX does not expose string method indexing.
  local token=({['.']='dot',[':']='colon',['-']='minus'})[c] or c
  local key='n'..size..'-'..token
  if not glyphs[key] then glyphs[key]=loadBitmap(key) end
  lcd.drawBitmap(glyphs[key],x+(i-1)*widths[size],y)
 end
end
local function changePage(nextPage)
 if page==5 then telemetry.release() end
 page=nextPage
 -- Keep only one full-screen bitmap resident, plus the small glyph cache.
 background=nil;bezel=nil;collectgarbage('collect')
 if page~=5 then background=loadBitmap(pages[page]) else telemetry.refresh() end;lastFrame=-100
end
local function init()
 telemetry.init();started=getTime(); page=1; failure=nil; lastFrame=-100
 background=nil;glyphs={};bezel=nil;ribbon=nil;sensorOffset=0;sensors={};scenario=1;zoom=2
end
local function data(t)
 local a=t/19
 local x=78*math.sin(a);local y=-50*math.sin(a*.7)
 local d={
  t=t,volts=16.7-t*.006,remaining=clamp(100-t*.17,0,100),
  current=14+6*math.sin(t/6)+3*math.sin(t/2.1),mah=round(t*5.7),
  lq=round(97+2*math.sin(t/7)),sats=16,
  alt=round(82+19*math.sin(t/13)),speed=round(43+9*math.sin(t/7)),
  x=x,y=y,dist=round(math.sqrt(x*x+y*y)*3),
  heading=(127+round(35*math.sin(t/19)))%360,
  roll=10*math.sin(t/8)+clamp(getValue('ail')/1024,-1,1)*35,
  pitch=4*math.sin(t/6)+clamp(getValue('ele')/1024,-1,1)*15
 }
 if scenario==2 then d.volts=d.volts-2.3;d.remaining=18 end
 if scenario==3 then d.lq=0;d.sats=0;d.roll=0;d.pitch=0 end
 return d
end
local function smallText(x,y,s,c)
 ink(c);lcd.drawText(x,y,s,SMLSIZE+CUSTOM_COLOR)
end
local function flight(d)
 local p=palette
 if not bezel then bezel=loadBitmap('bezel') end
 local names={'normal','low','lost'}
 if not ribbon then ribbon=loadBitmap('status-'..names[scenario]) end
 lcd.drawBitmap(ribbon,100,42)
 digits(16,64,scenario==3 and '--' or d.lq,30)
 digits(14,198,scenario==3 and '--' or '-65',16)
 digits(398,64,scenario==3 and '--.-' or string.format('%.1f',d.volts),30)
 digits(434,120,scenario==3 and '--' or string.format('%.1f',d.volts/4),11)
 digits(438,158,scenario==3 and '--' or round(d.remaining),11)
 digits(402,198,scenario==3 and '---' or d.mah,16)
 for i=0,14 do
  local c=i<4 and p.red or (i<7 and p.orange or p.green)
  if i<d.lq*.15 then rect(17,169-i*5,27,3,c) end
  if scenario~=3 and i<d.remaining*.15 then rect(402,169-i*5,27,3,c) end
 end
 -- A native horizon behind a bitmap instrument bezel; no per-pixel Lua loop.
 rect(164,64,152,152,p.sky)
 ink(p.ground);lcd.drawHudRectangle(d.pitch,d.roll,164,316,64,216,CUSTOM_COLOR)
 local angle=-d.roll*pi/180
 local ox=240+math.sin(d.roll*pi/180)*d.pitch
 local oy=140+math.cos(d.roll*pi/180)*d.pitch*1.85
 local function mark(offset,half,c)
  local yy=oy+offset*math.cos(angle);local xx=ox-offset*math.sin(angle)
  clip(xx-half*math.cos(angle),yy-half*math.sin(angle),xx+half*math.cos(angle),yy+half*math.sin(angle),164,315,64,215,c)
 end
 mark(0,170,p.horizon)
 for i=-5,5 do if i~=0 then mark(i*14,i%2==0 and 31 or 16,p.ladder) end end
 lcd.drawBitmap(bezel,164,64)
 local a=(-d.roll-90)*pi/180
 triangle(240+58*math.cos(a),140+58*math.sin(a),-d.roll,4,p.orange)
 -- Fixed aircraft symbol with dark underlay and gold foreground.
 for _,dy in ipairs({1,0}) do
  local c=dy==1 and p.black or p.orange
  line(208,148+dy,231,148+dy,c);line(231,148+dy,235,153+dy,c)
  line(245,153+dy,249,148+dy,c);line(249,148+dy,272,148+dy,c)
 end
 rect(238,144,4,4,p.orange)
 -- Instrument tapes remain outside the circular aperture.
 rect(103,82,41,131,p.tape);rect(336,82,41,131,p.tape)
 for offset=-30,30,10 do
  if scenario~=3 then
  local v=math.floor(d.speed/10)*10+offset;local yy=149-(v-d.speed)*3
  if yy>88 and yy<204 then digits(107,yy-5,v,11);line(135,yy,142,yy,p.muted) end
  v=math.floor(d.alt/10)*10+offset;yy=149-(v-d.alt)*3
  if yy>88 and yy<204 then digits(344,yy-5,v,11);line(338,yy,344,yy,p.muted) end
  end
 end
 rect(99,137,49,24,p.black);rect(332,137,49,24,p.black)
 line(99,137,145,137,p.green);line(335,137,381,137,p.green)
 digits(111,140,d.speed,16);digits(344,140,d.alt,16)
 if scenario==3 then
  rect(171,126,138,35,p.black)
  smallText(184,131,'TELEMETRY LOST',p.red)
  smallText(191,147,'DEMO SCENARIO',p.muted)
  rect(100,139,46,20,p.black);rect(334,139,46,20,p.black)
  digits(111,140,'--',16);digits(344,140,'--',16)
 end
 digits(132,227,scenario==3 and '---' or d.dist,11);digits(222,227,scenario==3 and '---' or string.format('%03d',d.heading),11)
 digits(326,227,scenario==3 and '--' or string.format('%.1f',d.current),11)
end
local function bearing(x,y)
 local xx,yy=-y,-x
 if xx>0 then return math.atan(yy/xx)
 elseif xx<0 then return math.atan(yy/xx)+(yy>=0 and pi or -pi)
 elseif yy~=0 then return yy>=0 and pi/2 or -pi/2 end
 return 0
end
local navDemo,navHome,navTrack,navLast,navCurrent=true,nil,{},-100,nil
local navUnits={}
local function navReset()
 navHome=nil;navTrack={};navLast=-100;navCurrent=nil;navUnits={}
 for i=0,63 do local s=model.getSensor(i);if s and s.name then navUnits[s.name]=s.unit end end
end
local function navRead(name,kind)
 local f=getFieldInfo(name);if not f or not getSourceValue then return nil end
 local v,current=getSourceValue(f.id)
 if not current then return nil end
 if kind=='gps' then
  if type(v)=='table' and type(v.lat)=='number' and type(v.lon)=='number' and v.lat==v.lat and v.lon==v.lon and math.abs(v.lat)<=90 and math.abs(v.lon)<=180 then return {lat=v.lat,lon=v.lon} end
  return nil
 end
 if type(v)~='number' or v~=v then return nil end
 local u=navUnits[name]
 if kind=='speed' then
  if u==UNIT_KTS then return v*1.852 elseif u==UNIT_MPH then return v*1.609344 elseif u==UNIT_METERS_PER_SECOND then return v*3.6 elseif u==UNIT_KMH then return v else return nil end
 elseif kind=='alt' then
  if u==UNIT_FEET then return v*.3048 elseif u==UNIT_METERS then return v else return nil end
 elseif kind=='angle' then
  if u==UNIT_RADIANS then return v*180/pi elseif u==UNIT_DEGREE then return v else return nil end
 end
 return v
end
local function atan2(y,x)
 if x>0 then return math.atan(y/x) elseif x<0 then return math.atan(y/x)+(y>=0 and pi or -pi) elseif y>0 then return pi/2 elseif y<0 then return -pi/2 end
 return 0
end
local function geo(a,b)
 local r=pi/180;local la,lb=a.lat*r,b.lat*r;local dl=(b.lon-a.lon)*r;local dp=lb-la
 local h=clamp(math.sin(dp/2)^2+math.cos(la)*math.cos(lb)*math.sin(dl/2)^2,0,1)
 local dist=6371000*2*atan2(math.sqrt(h),math.sqrt(1-h))
 local angle=(atan2(math.sin(dl)*math.cos(lb),math.cos(la)*math.sin(lb)-math.sin(la)*math.cos(lb)*math.cos(dl))/r+360)%360
 return dist,angle
end
local function navAction(action)
 if action=='mode' then navDemo=not navDemo;navReset()
 elseif action=='zoom' then zoom=zoom%3+1
 elseif action=='home' and navCurrent then navHome={lat=navCurrent.lat,lon=navCurrent.lon};navTrack={} end
 lastFrame=-100
end
local function navigation(d)
 local p=palette;local now=getTime();local pos,speed,alt,sats,heading
 if navDemo then
  local t=(now-started)/100
  if not navHome then navHome={lat=59.32930,lon=18.06860} end
  pos={lat=59.32930+(.00065*math.sin(t/18)),lon=18.06860+.0012*math.cos(t/24)}
  speed=31+4*math.sin(t/5);alt=33+8*math.sin(t/12);sats=13;heading=(120+t*3)%360
 else
  pos=navRead('GPS','gps');speed=navRead('GSpd','speed');alt=navRead('GAlt','alt');sats=navRead('Sats');heading=navRead('Hdg','angle')
 end
 navCurrent=pos
 if pos and now-navLast>=100 then
  navLast=now;navTrack[#navTrack+1]={lat=pos.lat,lon=pos.lon};if #navTrack>90 then table.remove(navTrack,1) end
 end
 rect(137,3,339,31,p.black);smallText(148,12,'GPS / HOME',p.white)
 rect(330,7,139,23,p.tape);smallText(340,12,navDemo and 'DEMO GPS' or pos and 'LIVE POSITION' or 'NO CURRENT GPS',pos and p.green or p.orange)
 rect(5,38,470,206,p.black)
 local function val(v,fmt,unit) return type(v)=='number' and string.format(fmt or '%.0f',v)..(unit or '') or '--' end
 smallText(14,43,'SATS '..val(sats),p.green);smallText(125,43,val(speed,'%.1f',' km/h'),p.white);smallText(252,43,'GPS ALT '..val(alt,'%.0f',' m'),p.white)
 -- North-up local plot; ring spacing is labelled in metres, no map imagery implied.
 rect(10,64,188,151,p.tape)
 for x=14,194,20 do line(x,65,x,214,p.dim) end
 for y=65,214,20 do line(11,y,197,y,p.dim) end
 local cx,cy=104,141;local scale=({.35,.7,1.4})[zoom]
 circle(cx,cy,60,p.border);circle(cx,cy,30,p.border)
 smallText(16,69,'N',p.cyan);line(21,96,21,87,p.cyan);triangle(21,86,0,3,p.cyan)
 smallText(126,199,tostring(round(60/scale))..' m',p.muted)
 local origin=navHome or pos
 local function pt(a)
  local dist,angle=geo(origin,a);local rad=angle*pi/180
  return cx+dist*math.sin(rad)*scale,cy-dist*math.cos(rad)*scale
 end
 if origin then
  local px,py
  for _,a in ipairs(navTrack) do local x,y=pt(a);if px then clip(px,py,x,y,11,197,65,214,p.cyan) end;px,py=x,y end
  if navHome then
   line(cx-5,cy,cx,cy-5,p.orange);line(cx,cy-5,cx+5,cy,p.orange);rect(cx-3,cy,6,5,p.orange)
  end
  if pos then
   local x,y=pt(pos)
   if x>=20 and x<=188 and y>=74 and y<=203 then
    if heading then triangle(x,y,heading,7,p.white) else circle(x,y,4,p.white) end
   else smallText(18,183,'AIRCRAFT OFF PLOT',p.orange) end
  end
 else smallText(28,129,'WAITING FOR GPS',p.muted) end
 if not pos and origin then smallText(18,183,'TRACK / LAST KNOWN',p.orange) end
 local function row(y,label,value,col)
  smallText(208,y,label,p.muted);ink(col or p.white);lcd.drawText(468,y,value,SMLSIZE+CUSTOM_COLOR+RIGHT)
 end
 row(65,'AIRCRAFT LAT',pos and val(pos.lat,'%.6f') or '--')
 row(83,'AIRCRAFT LON',pos and val(pos.lon,'%.6f') or '--')
 row(101,'COURSE',pos and val(heading,'%.0f',' deg') or '--')
 line(208,120,469,120,p.border)
 row(126,'HOME LAT',navHome and val(navHome.lat,'%.6f') or '--',p.orange)
 row(144,'HOME LON',navHome and val(navHome.lon,'%.6f') or '--',p.orange)
 local dist,angle;if navHome and pos then dist,angle=geo(pos,navHome) end
 row(168,'TO HOME',val(dist,'%.0f',' m'),p.cyan)
 row(187,'BEARING',dist and dist>=1 and val(angle,'%.0f',' deg') or '--',p.cyan)
 for _,b in ipairs({{10,100,navDemo and 'USE LIVE' or 'USE DEMO'},{117,90,'ZOOM +'},{214,112,'SET HOME'},{333,137,'NORTH UP'}}) do
  rect(b[1],222,b[2],21,p.tape);smallText(b[1]+8,227,b[3],p.green)
 end
end

local function power(d)
 local p=palette
 digits(17,73,string.format('%.2f',d.volts),30)
 digits(347,46,string.format('%.2f',d.volts),11)
 digits(347,150,string.format('%.1f',d.current),11)
 for i=0,3 do
  local cell=d.volts/4+({-.008,.004,-.002,.006})[i+1]
  local fill=clamp((cell-3.4)/.8,0,1)
  rect(24+i*40,182-38*fill,19,38*fill,scenario==2 and p.orange or p.green)
  digits(17+i*40,197,string.format('%.2f',cell),11)
 end
 digits(121,220,'14',16)
 local function graph(top,voltage)
  local px,py
  for i=0,60 do
   local tt=d.t-60+i
   if tt>=0 then
    local v=voltage and (16.7-tt*.006) or (14+6*math.sin(tt/6)+3*math.sin(tt/2.1))
    if voltage and scenario==2 then v=v-2.3 end
    local fraction=voltage and clamp((v-13.6)/3.2,0,1) or clamp(v/28,0,1)
    local x,y=202+i*4.3,top+52-50*fraction
    if px then line(px,py,x,y,voltage and p.cyan or p.orange) end
    px,py=x,y
   end
  end
  if px then circle(px,py,2,p.white) end
 end
 graph(70,true);graph(174,false)
end
local function scanSensors()
 sensors={}
 if not model or not model.getSensor then return end
 for i=0,63 do
  local sensor=model.getSensor(i)
  if sensor and sensor.name and sensor.name~='' then
   local info=getFieldInfo(sensor.name)
   sensors[#sensors+1]={name=sensor.name,source=info and info.id,prec=sensor.prec or 0}
  end
 end
 sensorOffset=sensorOffset%(math.max(1,math.ceil(#sensors/5))*5)
end
local function systemPage()
 local p=palette
 rect(23,94+(scenario-1)*32,10,8,scenario==1 and p.green or (scenario==2 and p.orange or p.red))
 local rssi=getRSSI()
 smallText(215,81,rssi>0 and 'LINK RECEIVING' or 'NO TELEMETRY LINK',rssi>0 and p.green or p.orange)
 if #sensors==0 then
  smallText(215,125,'No model sensors configured.',p.white)
  smallText(215,146,'Discover them in the radio',p.muted)
  smallText(215,160,'Telemetry menu, then tap here.',p.muted)
  return
 end
 for row=1,5 do
  local s=sensors[sensorOffset+row]
  if s then
   local y=117+(row-1)*20
   smallText(215,y,s.name,p.white)
   local value='--'
   if rssi>0 and s.source then
    local v=getValue(s.source)
    if type(v)=='number' then value=string.format('%.'..clamp(s.prec,0,2)..'f',v)
    elseif type(v)=='table' then value='TABLE/GPS'
    elseif type(v)=='string' then value=string.sub(v,1,10) end
   end
   smallText(376,y,value,p.cyan)
  end
 end
end
-- Reference: betaflight.com/docs/wiki/guides/current/Controls
-- Axis order: throttle, yaw, pitch, roll; -1 low, 0 centre, +1 high.
local stickMode,commandPage=2,1
local commands={
 {'Save settings',-1,-1,-1,1},
 {'PID profile 1',-1,-1,0,-1},
 {'PID profile 2',-1,-1,1,0},
 {'PID profile 3',-1,-1,0,1},
 {'Calibrate gyroscope',-1,-1,-1,0},
 {'Calibrate accelerometer',1,-1,-1,0},
 {'Calibrate compass',1,1,-1,0},
 {'In-flight calibration*',-1,-1,1,1},
 {'Trim accelerometer left',1,0,0,-1},
 {'Trim accelerometer right',1,0,0,1},
 {'Trim accelerometer forward',1,0,1,0},
 {'Trim accelerometer back',1,0,-1,0}
}
local stickAxes={{3,4,5,2},{3,2,5,4},{5,4,3,2},{5,2,3,4}}
local function stickCommands()
 local p=palette
 rect(137,3,338,31,p.black)
 smallText(148,12,'STICK COMMANDS',p.white)
 rect(362,7,108,24,p.tape);smallText(374,12,'MODE '..stickMode,p.green)
 rect(5,38,470,207,p.black)
 smallText(14,43,'BETAFLIGHT / REFERENCE ONLY',p.orange)
 smallText(365,43,commandPage..' / 2',p.muted)
 local axes=stickAxes[stickMode]
 local function diagram(x,y,h,v)
  rect(x,y,21,21,p.border);rect(x+1,y+1,19,19,p.tape)
  line(x+10,y+2,x+10,y+18,p.dim);line(x+2,y+10,x+18,y+10,p.dim)
  rect(x+8+h*7,y+8-v*7,5,5,p.green)
 end
 for row=1,7 do
  local index=(commandPage-1)*7+row;local cmd=commands[index]
  if cmd then
   local y=63+(row-1)*22
   if row%2==1 then rect(10,y-1,460,22,p.tape) end
   diagram(18,y,cmd[axes[1]],cmd[axes[2]])
   diagram(47,y,cmd[axes[3]],cmd[axes[4]])
   smallText(83,y+4,cmd[1],p.white)
  end
 end
 rect(10,221,460,22,p.tape)
 smallText(17,226,'< PREV',p.cyan);smallText(108,226,'FC support varies*',p.muted);smallText(369,226,'NEXT >',p.cyan)
end

local function run(event,touch)
 if event==EVT_VIRTUAL_EXIT then return 1 end
 if not started then init() end
 if not palette then
  palette={}
  local colors={red={250,91,64},green={164,227,125},cyan={104,221,237},orange={255,174,98},
   white={232,242,245},muted={140,164,179},dim={42,64,79},border={57,84,100},
   sky={32,112,166},ground={117,88,49},horizon={157,208,221},ladder={128,173,191},
   black={5,12,19},tape={15,31,43},route={56,82,92}}
  for k,v in pairs(colors) do palette[k]=lcd.RGB(v[1],v[2],v[3]) end
 end
 if not background and page~=5 then changePage(page) end
 if (EVT_VIRTUAL_NEXT_PAGE and event==EVT_VIRTUAL_NEXT_PAGE) then
  changePage(adjacent(1));if page==4 then scanSensors() end
 elseif EVT_VIRTUAL_PREV_PAGE and event==EVT_VIRTUAL_PREV_PAGE then
  changePage(adjacent(-1));if page==4 then scanSensors() end
 elseif event==EVT_VIRTUAL_ENTER then
  if page==2 then navAction("mode")
  elseif page==6 then stickMode=stickMode%4+1;lastFrame=-100
  elseif page==5 then telemetry.run(event,touch)
  elseif page==4 then scenario=scenario%3+1;ribbon=nil;lastFrame=-100
  else changePage(adjacent(1));if page==4 then scanSensors() end end
 elseif EVT_TOUCH_TAP and event==EVT_TOUCH_TAP and touch then
  local x,y=touch.x,touch.y
  if x>=0 and x<480 and y>=248 then changePage(order[math.floor(x/80)+1]);if page==4 then scanSensors() end
  elseif page==6 and y<36 and x>=362 then stickMode=stickMode%4+1;lastFrame=-100
  elseif page==6 and y>=221 and y<245 then commandPage=3-commandPage;lastFrame=-100
  elseif page==5 and y<36 and x>=309 then telemetry.run(event,touch)
  elseif page==2 and y>=222 and y<245 then
   if x<113 then navAction("mode") elseif x<211 then navAction("zoom") elseif x<330 then navAction("home") end
  elseif page==4 and x>=16 and x<=186 and y>=85 and y<174 then
   local selected=math.floor((y-85)/32)+1
   if selected<=3 and (y-85)%32<25 then scenario=selected;ribbon=nil;lastFrame=-100 end
  elseif page==4 and x>=204 and x<474 and y>=98 and y<240 then
   sensorOffset=sensorOffset+5;scanSensors();lastFrame=-100
  end
 end
 if failure then
  lcd.clear();lcd.drawText(10,30,'AERODECK asset error',0);lcd.drawText(10,60,failure,0)
  lcd.drawText(10,90,'Copy the AERODECK folder beside telem.lua',0)
  return 0
 end
 -- Cap full redraws at 10 Hz; repeated callbacks retain the framebuffer.
 local now=getTime()
 if now-lastFrame<10 and now>=lastFrame then return 0 end
 lastFrame=now
 if page==5 then telemetry.run(0) else lcd.drawBitmap(background,0,0) end
 local d=data(math.max(0,(now-started)/100)%120)
 if page==1 then flight(d) elseif page==2 then navigation(d) elseif page==3 then power(d) elseif page==4 then systemPage() elseif page==6 then stickCommands() end
 rect(0,246,480,26,palette.black)
 local labels={"FLIGHT","TELEMETRY","NAV","POWER","SYSTEM","TOOLS"}
 for i,v in ipairs(order) do
  local x=(i-1)*80
  rect(x+2,248,76,23,palette.tape)
  if page==v then rect(x+2,248,76,2,palette.green) end
  smallText(x+4,254,labels[i],page==v and palette.white or palette.muted)
 end
 return 0
end
return {init=init,run=run}
