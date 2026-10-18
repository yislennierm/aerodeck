-- Pure display-contract tests, not a claim of hardware layout verification.
local root=arg[1]or'.'
-- Embedded EdgeTX strings do not expose the host Lua string-method metatable.
-- Exercise that contract rather than letting host-only file:match() pass.
local stringMeta=debug.getmetatable('')
debug.setmetatable('',nil)
local display=assert(loadfile(root..'/sdcard/SCRIPTS/TOOLS/AERODECK/display.lua'))()
local checks=0
local function check(v,message)checks=checks+1;assert(v,message or('check '..checks))end
local function near(a,b,tolerance)check(math.abs(a-b)<=(tolerance or 0.00001),tostring(a)..' != '..tostring(b))end
local function rounded(v)return math.floor(v+0.5)end
local function copy(t)local out={};for k,v in pairs(t)do out[k]=v end;return out end
local std={21,20,12,17,29,40,69,51}
local large={27,27,17,23,42,55,93,71}
local function mock(heights)
 local calls,api={},{}
 local function save(name,...)
  calls[#calls+1]={name=name,args={...}}
 end
 local names={'RGB','setColor','getColor','clear','refresh','resetBacklightTimeout','exitFullScreen',
  'drawText','drawTextLines','drawNumber','drawTimer','drawChannel','drawSwitch','drawSource',
  'drawPoint','drawLine','drawLineWithClipping','drawRectangle','drawFilledRectangle','invertRect',
  'drawGauge','drawCircle','drawFilledCircle','drawTriangle','drawFilledTriangle','drawArc','drawPie',
  'drawAnnulus','drawHudRectangle','drawBitmap','drawBitmapPattern','drawBitmapPatternPie'}
 for _,name in ipairs(names)do
  local label=name
  api[name]=function(...)
   save(label,...)
   if label=='drawTextLines'then local a={...};return a[1]+a[3],a[2]+a[4]end
  end
 end
 api.sizeText=function(text,flags)
  save('sizeText',text,flags)
  local index=math.floor((flags or 0)/256)%16
  local h=heights[index+1]or heights[1]
  -- Fixed mock metrics are sufficient for coordinate/fit consistency. Real
  -- glyph metrics must still be checked on each target firmware/font set.
  return #text*h*0.5,h
 end
 return api,calls
end
local function last(calls,name)
 local c=calls[#calls];check(c and c.name==name,'Expected '..name..', got '..tostring(c and c.name));return c.args
end
local function noCalls(calls,fn)
 local count=#calls;fn();check(#calls==count,'Unexpected native calls')
end
local raw,calls=mock(std)
local p=assert(display.new(raw,480,272))
check(p.lcd==raw and p.raw==raw and p.native,'TX16S receives exact original LCD object')
check(#calls==0,'TX16S constructor does not probe fonts/draw/allocate wrappers')
check(p.scale==1 and p.offset.x==0 and p.offset.y==0)
check(p.viewport.w==480 and p.viewport.h==272 and p.extra.h==0)
check(p.iconSize(30)==30 and p.iconSize(18)==18 and p.iconPath('home.png')=='icons/home.png')
local touch={x=456,y=259,startX=450,startY=250,slideX=6,slideY=9,tapCount=1}
check(p.touch(touch)==touch,'Identity touch object is preserved')
check(p.font(0xA5000404)==0xA5000404,'Identity flags unchanged')
noCalls(calls,function()p.point(1,2);p.rect(1,2,3,4)end)
for _,size in ipairs({{480,320},{800,480}})do
 local w,h=size[1],size[2]
 local native,events=mock(w==800 and large or std)
 local q=assert(display.new(native,w,h));local s=q.scale
 check(q.lcd~=native and q.raw==native and not q.native)
 check(q.viewport.w==w and q.viewport.h==rounded(272*s))
 check(q.extra.y==q.viewport.h and q.extra.y+q.extra.h==h)
 check(q.extra.h==(w==800 and 27 or 48),'Extra height reserved for useful physical strip')
 check(q.offset.x==0 and q.offset.y==0)
 check(#events==8,'Only eight font probes, once at bootstrap')
 local target=q.lcd
 local a,b,c,d=q.rect(78,64,324,180)
 near(a,rounded(78*s));near(b,rounded(64*s));near(c,rounded(402*s)-a);near(d,rounded(244*s)-b)
 check(a+c<=w and b+d<=q.viewport.h,'Flight HUD contained in viewport')
 for x=0,479 do
  local x1,_,ww=q.rect(x,0,1,1);local x2=q.point(x+1,0)
  check(x1+ww==x2,'Adjacent virtual cells have no physical gap')
 end
 for y=0,271 do
  local _,y1,_,hh=q.rect(0,y,1,1);local _,y2=q.point(0,y+1)
  check(y1+hh==y2,'Adjacent virtual rows have no physical gap')
 end
 local nav={{0,0,40,34},{105,0,63,34},{168,0,63,34},{231,0,63,34},{294,0,63,34},{357,0,63,34},{420,0,60,34}}
 local controls={{432,246,48,26},{0,246,432,26},{10,222,74,23},{88,222,74,23},{172,222,140,23},{320,222,150,23}}
 for _,item in ipairs(nav)do controls[#controls+1]=item end
 for _,box in ipairs(controls)do
  local x,y,ww,hh=q.rect(box[1],box[2],box[3],box[4])
  check(x>=0 and y>=0 and x+ww<=w and y+hh<=q.viewport.h,'Core navigation/actions fit')
  local original={x=x+ww/2,y=y+hh/2,tapCount=1,swipeLeft=false}
  local input=assert(q.touch(original))
  check(input.x>=box[1] and input.x<box[1]+box[3] and input.y>=box[2] and input.y<box[2]+box[4],'Visible target center maps to its logical action')
  check(original.x==x+ww/2 and original.y==y+hh/2,'Raw touch remains untouched')
 end
 local t=q.touch({x=100*s,y=200*s,startX=90*s,startY=180*s,slideX=-10*s,slideY=20*s,tapCount=2,swipeLeft=true})
 near(t.x,100);near(t.y,200);near(t.startX,90);near(t.startY,180);near(t.slideX,-10);near(t.slideY,20)
 check(t.tapCount==2 and t.swipeLeft==true)
 local newer=q.touch({x=100*s,y=200*s})
 check(newer.startX==nil and newer.slideX==nil and newer.tapCount==nil,'Reused scaled touch has no stale fields')
 check(q.touch({x=10,y=q.extra.y})==nil and q.touch({x=10,y=h-1})==nil,'Extra-strip taps never activate main controls')
 for _,bad in ipairs({{x=-1,y=10},{x=w,y=10},{x=10,y=-1},{x=10,y=h},{x='1',y=1},{x=0/0,y=1}})do check(q.touch(bad)==nil)end
 check(q.touch(nil)==nil)
 for pixel=0,q.viewport.w-1 do
  local mapped=assert(q.touch({x=pixel,y=100}))
  local x=mapped.x
  check(rounded(x*s)<=pixel and pixel<rounded((x+1)*s),'Every painted horizontal pixel belongs to the same logical hit cell')
 end
 for pixel=0,q.viewport.h-1 do
  local mapped=assert(q.touch({x=100,y=pixel}))
  local y=mapped.y
  check(rounded(y*s)<=pixel and pixel<rounded((y+1)*s),'Every painted vertical pixel belongs to the same logical hit cell')
 end
 check(q.iconSize(30)==(w==800 and 50 or 30) and q.iconSize(18)==(w==800 and 30 or 18))
 check(q.iconPath('home.png')==(w==800 and'icons/800x480/home.png'or'icons/home.png'))
 check(q.iconPath('../home.png')==nil)
 -- Color, align, inverse/blink flags outside COLORLCD0x0F00 are preserved.
 for index=0,7 do
  local flags=0xA502000D+index*256
  local mapped=q.font(flags)
  check(mapped-math.floor(mapped/256)%16*256==flags-index*256,'Only color-LCD font field may change')
  local expectedHeight=(w==800 and large or std)[math.floor(mapped/256)%16+1]
  check(expectedHeight<=std[index+1]*s+0.01,'Mapped font fits its scaled logical row')
  target.drawText(100,90,'Ag',flags,123)
  local args=last(events,'drawText');check(args[1]==rounded(100*s) and args[2]==rounded(90*s) and args[4]==mapped and args[5]==123)
  local tw,th=target.sizeText('Ag',flags);near(th,expectedHeight/s);near(tw,expectedHeight/s)
 end
 check(q.font(0xB0000F0D)==0xB0000F0D,'Unknown font field is not remapped by a guessed index')
 local ex,ey=target.drawTextLines(10,20,100,40,'abc',0x300)
 near(ex,(rounded(110*s))/s);near(ey,(rounded(60*s))/s)
 for _,name in ipairs({'drawNumber','drawTimer','drawChannel','drawSwitch','drawSource'})do
  target[name](10,20,345,0x300,456)
  local args=last(events,name);check(args[1]==rounded(10*s) and args[2]==rounded(20*s) and args[3]==345 and args[4]==q.font(0x300) and args[5]==456)
 end
 target.drawLine(10,20,30,40,0xFF,123)
 local args=last(events,'drawLine');check(args[1]==rounded(10*s) and args[4]==rounded(40*s) and args[5]==0xFF and args[6]==123)
 target.drawLineWithClipping(-20,-30,500,300,-10,500,-20,300,0xFF,123)
 args=last(events,'drawLineWithClipping');check(args[5]==0 and args[6]==w and args[7]==0 and args[8]==q.viewport.h and args[9]==0xFF and args[10]==123)
 noCalls(events,function()target.drawLineWithClipping(0,0,1,1,10,5,0,10,0xFF,123)end)
 target.drawRectangle(10,20,30,40,123,2,9)
 args=last(events,'drawRectangle');check(args[1]==rounded(10*s) and args[3]==rounded(40*s)-rounded(10*s) and args[6]==rounded(2*s) and args[7]==9)
 target.drawFilledRectangle(10,20,30,40,123,9)
 args=last(events,'drawFilledRectangle');check(args[4]==rounded(60*s)-rounded(20*s) and args[5]==123 and args[6]==9)
 target.invertRect(10,20,30,40,123);args=last(events,'invertRect');check(args[3]==rounded(40*s)-rounded(10*s) and args[5]==123)
 target.drawGauge(10,20,30,40,17,100,123);args=last(events,'drawGauge');check(args[5]==17 and args[6]==100 and args[7]==123,'Fill fraction is not scaled')
 for _,name in ipairs({'drawCircle','drawFilledCircle'})do
  target[name](240,154,60,123);args=last(events,name)
  check(args[1]==rounded(240*s) and args[2]==rounded(154*s) and args[3]==rounded(60*s),'Circle radius uses same scale as both axes')
 end
 for _,name in ipairs({'drawTriangle','drawFilledTriangle'})do
  target[name](10,20,30,40,50,60,123);args=last(events,name)
  check(args[1]==rounded(10*s) and args[6]==rounded(60*s) and args[7]==123)
 end
 for _,name in ipairs({'drawArc','drawPie'})do
  target[name](10,20,30,-90,180,123);args=last(events,name)
  check(args[3]==rounded(30*s) and args[4]==-90 and args[5]==180 and args[6]==123,'Angles remain angles')
 end
 target.drawAnnulus(10,20,30,40,-90,180,123);args=last(events,'drawAnnulus')
 check(args[3]==rounded(30*s) and args[4]==rounded(40*s) and args[5]==-90 and args[6]==180)
 -- Across full orientation, native horizon origin follows the exact same
 -- transform as the Lua ladder. Scaling bounds without pitch is incorrect.
 for _,pitch in ipairs({-60,-20,0,20,60})do for _,roll in ipairs({-180,-90,-35,0,35,90,180})do
  target.drawHudRectangle(pitch,roll,78,402,64,244,123)
  args=last(events,'drawHudRectangle');near(args[1],pitch*s);check(args[2]==roll and args[7]==123)
  local r=roll*math.pi/180
  local nativeX=(args[3]+args[4])/2+math.sin(r)*args[1]
  local nativeY=(args[5]+args[6])/2+math.cos(r)*args[1]*1.85
  near(nativeX,(240+math.sin(r)*pitch)*s,0.51)
  near(nativeY,(154+math.cos(r)*pitch*1.85)*s,0.51)
 end end
 local image={id='bitmap'}
 target.drawBitmap(image,10,20);args=last(events,'drawBitmap');check(args[1]==image and args[2]==rounded(10*s) and args[4]==rounded(100*s))
 target.drawBitmap(image,10,20,50);args=last(events,'drawBitmap');check(args[4]==rounded(50*s))
 target.drawBitmapPattern('native-sized-mask',10,20,123);args=last(events,'drawBitmapPattern');check(args[1]=='native-sized-mask' and args[4]==123)
 target.drawBitmapPatternPie('native-sized-mask',10,20,-90,180,123);args=last(events,'drawBitmapPatternPie');check(args[4]==-90 and args[5]==180 and args[6]==123)
 check(target.RGB==native.RGB and target.setColor==native.setColor and target.getColor==native.getColor and target.clear==native.clear,'Non-coordinate LCD operations are exact passthrough functions')
 local before=#events
 for i=1,100 do target.drawFilledRectangle(0,0,480,272,123)end
 check(#events==before+100,'Warm drawing does not repeat font probes')
end
-- Unexpected oversized font metrics cause an explicit conservative fallback.
local odd,oddEvents=mock({21,20,12,17,90,40,69,51})
local q=assert(display.new(odd,480,320))
check(q.font(0x400)~=0x400 and q.fontHeights[math.floor(q.font(0x400)/256)]<=29,'An oversized font must not spill outside its row')
local impossible=mock({21,20,60,17,29,40,69,51})
local absent,errorText=display.new(impossible,480,320)
check(absent==nil and errorText=='NO FONT FITS VIEWPORT','No guessed font when every available font exceeds a required row')
local noMetrics=mock(std);noMetrics.sizeText=nil
check(display.new(noMetrics,800,480)==nil,'No silent geometry/font support without metrics')
check(display.new({},480,272).lcd~=nil,'Native path does not require unused metrics')
for _,dimensions in ipairs({{320,240},{480,271},{800,272},{1024,600},{0,0},{480.5,272},{'480',272}})do
 local value,errorText=display.new(raw,dimensions[1],dimensions[2]);check(value==nil and errorText=='UNSUPPORTED DISPLAY')
end
check(display.new(nil,480,272)==nil)
print('Display adapter: '..checks..' checks PASS (synthetic; no target hardware claim)')
debug.setmetatable('',stringMeta)
