-- Real renderer at the Bitmap/LCD boundary: native-size assets, cache lifetime
-- and failure isolation. Run from project root; no radio or SD changes.
local f=assert(io.open('sdcard/SCRIPTS/TOOLS/telem.lua'));local app=f:read('*a');f:close()
local first=assert(string.find(app,'local iconShapes={',1,true))
local last=assert(string.find(app,'local function numberText',first,true))
local make=assert(loadstring([[return function(api)
 local inputRuntime={}
 local ROOT,Bitmap,lcd=api.root,api.Bitmap,api.lcd
 local SOLID,CUSTOM_COLOR=api.SOLID,api.CUSTOM_COLOR
 local collectgarbage=api.collectgarbage
 local function round(x)return math.floor(x+.5)end
 local function ink(c)lcd.setColor(CUSTOM_COLOR,c)end
]]..string.sub(app,first,last-1)..'\nreturn icon\nend'))()
local checks=0
local function check(value,why)assert(value,why);checks=checks+1 end
local names={[0]='home',[1]='speed',[5]='table_chart',[7]='my_location',[11]='head_mounted_device',
 [8]='tune',[13]='build',[2]='route',[3]='battery_full',[9]='cell_tower',[10]='gpp_bad',
 [6]='sports_esports',[4]='sensors',[12]='bug_report',[14]='satellite_alt'}
local navigation={0,10,5,7,11,8,13}
-- Eleven context icons plus the footer-only satellite; link and pack reuse9/3.
local details={1,10,5,3,9,7,2,11,6,4,12,14}
local function file(id,size)return names[id]..(size==18 and '-18' or '')..'.png'end
-- These real PNG headers guard the native Bitmap contract independently of
-- the mocked renderer: RGB8, exact dimensions, no enlarged raster substitute.
local function pngHeader(path,size)
 local f=assert(io.open('sdcard/SCRIPTS/TOOLS/AERODECK/icons/'..path,'rb'));local h=f:read(33);f:close()
 check(type(h)=='string'and #h==33 and string.sub(h,1,8)=='\137PNG\13\10\26\10','PNG signature/header: '..path)
 local function u32(at)local a,b,c,d=string.byte(h,at,at+3);return ((a*256+b)*256+c)*256+d end
 check(string.sub(h,13,16)=='IHDR'and u32(17)==size and u32(21)==size,'exact native dimensions: '..path)
 check(string.byte(h,25)==8 and string.byte(h,26)==2,'native mask must be8-bit RGB: '..path)
end
pngHeader('gpp_bad.png',30);pngHeader('800x480/gpp_bad.png',50)
pngHeader('speed.png',30);pngHeader('800x480/speed.png',50)
local realGC=collectgarbage
local function fixture(options)
 options=options or {}
 local calls={opens={},converts={},patterns={},lines={},rects=0,circles=0,gc=0,events={}}
 local masks={};local weak=setmetatable({},{__mode='v'});local currentColor
 local api={root='/SCRIPTS/TOOLS/AERODECK/',SOLID=0,CUSTOM_COLOR=4096,Bitmap={},lcd={}}
 api.collectgarbage=function(mode)
  check(mode=='collect','cold icon collection uses a full collection')
  calls.gc=calls.gc+1;calls.events[#calls.events+1]={'gc'};return realGC(mode)
 end
 api.Bitmap.open=function(path)
  local n=assert(string.match(path,'^/SCRIPTS/TOOLS/AERODECK/icons/(.+%.png)$'),'SD path must stay in the icon directory')
  calls.opens[n]=(calls.opens[n]or 0)+1;calls.events[#calls.events+1]={'open',n}
  local size=string.find(n,'-18.png',1,true)and 18 or 30
  local dim=options.bad and options.bad[n]or {size,size}
  local b={w=dim[1],h=dim[2],file=n};weak[n]=b;return b
 end
 api.Bitmap.getSize=function(b)return b.w,b.h end
 if not options.noToMask then api.Bitmap.toMask=function(b)
  calls.converts[b.file]=(calls.converts[b.file]or 0)+1
  local key=string.char(b.w,0,b.h,0)..b.file
  masks[b.file]=key;calls.events[#calls.events+1]={'convert',b.file};return key
 end end
 api.lcd.setColor=function(index,color)check(index==4096,'icon tint uses CUSTOM_COLOR');currentColor=color end
 if not options.noPattern then api.lcd.drawBitmapPattern=function(mask,x,y,flags)
  calls.patterns[#calls.patterns+1]={mask=mask,x=x,y=y,flags=flags,color=currentColor}
 end end
 api.lcd.drawLine=function(...)calls.lines[#calls.lines+1]={...}end
 api.lcd.drawFilledRectangle=function()calls.rects=calls.rects+1 end
 api.lcd.drawCircle=function()calls.circles=calls.circles+1 end
 return make(api),calls,masks,weak
end

local icon,calls,masks,weak=fixture()
for _,set in ipairs({{ids=navigation,size=30},{ids=details,size=18}})do
 for i,id in ipairs(set.ids)do
  local x,y=5+i*3,set.size==30 and 2 or 39;local color=0x80abcd+i
  if set.size==30 then icon(id,x,y,color)else icon(id,x,y,color,18)end
  local n=file(id,set.size);local p=calls.patterns[#calls.patterns]
  check(calls.opens[n]==1 and calls.converts[n]==1,'each visible navigation/detail asset loads and converts exactly once: '..n)
  check(p.mask==masks[n]and p.x==x and p.y==y and p.flags==4096 and p.color==color,'native mask coordinates/tint are preserved: '..n)
 end
end
check(calls.gc==0,'cold icon decoding must not force a full collection in the rendering callback')
local coldGC=calls.gc
for frame=1,100 do
 for _,set in ipairs({{ids=navigation,size=30},{ids=details,size=18}})do
  for _,id in ipairs(set.ids)do icon(id,5,set.size==30 and 2 or 39,frame,set.size)end
 end
 if frame==50 then realGC('collect')end
end
check(calls.gc==coldGC,'steady-state drawing must never force garbage collection')
for n,count in pairs(calls.opens)do
 check(count==1 and calls.converts[n]==1,'warm pages/GC must never read or convert an asset again: '..n)
end
check(#calls.lines==0 and calls.rects==0 and calls.circles==0,'available raster assets do not also draw vector fallbacks')
realGC('collect')
for n in pairs(calls.opens)do check(weak[n]==nil,'decoded userdata must be collectible after retaining only its mask: '..n)end
check(#calls.patterns==(#navigation+#details)*101,'every requested warm/native draw reaches the mask renderer')

local function fallback(size,dimensions,options,opens)
 options=options or {};options.bad=options.bad or {};options.bad[file(0,size)]=dimensions
 local draw,seen=fixture(options)
 for _=1,3 do draw(0,5,2,0xabcdef,size);realGC('collect')end
 local n=file(0,size)
 check(#seen.patterns==0 and #seen.lines==48,'unavailable assets keep the original double-stroked home fallback')
 local p=seen.lines[1]
 if size==30 then check(p[1]==8 and p[2]==16 and p[3]==20 and p[4]==5,'30px fallback preserves the old28px origin plus one pixel')
 else check(p[1]==6 and p[2]==10 and p[3]==14 and p[4]==3,'18px fallback scales old geometry at the requested origin')end
 check((seen.opens[n]or 0)==opens and seen.gc==0,'negative caches prevent repeated SD attempts without forcing GC')
 check(seen.converts[n]==nil,'wrong-size/missing/unsupported assets do not convert')
 return draw,seen
end
fallback(30,{0,0},nil,1)
fallback(30,{30,29},nil,1)
fallback(18,{30,30},nil,1)
fallback(18,{18,0},nil,1)
fallback(30,{30,30},{noToMask=true},0)
fallback(18,{18,18},{noPattern=true},0)
local partial,seen=fallback(30,{0,0},nil,1)
partial(1,100,2,0xffffff)
check(seen.opens['speed.png']==1 and #seen.patterns==1,'one missing asset does not poison another icon cache')
partial(0,5,2,0xffffff,18)
check(seen.opens['home-18.png']==1 and #seen.patterns==2,'30px and18px success/failure caches are independent')
local before=seen.gc;partial(0,5,2,0xffffff,24);partial(999,5,2,0xffffff)
check(seen.gc==before,'unsupported size/id uses geometry without bitmap or GC work')
print('PASS: '..checks..' Material icon native-size, cache, no forced GC, tint, lifetime and fallback checks')
