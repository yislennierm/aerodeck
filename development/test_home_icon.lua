-- Exercise the actual icon renderer, including its lazy SD/mask lifetime.
-- This is an LCD-boundary test, not a simulator of the radio graphics engine.
local f=assert(io.open('sdcard/SCRIPTS/TOOLS/telem.lua'))
local app=f:read('*a');f:close()
local first=assert(string.find(app,'local iconShapes={',1,true))
local last=assert(string.find(app,'local function numberText',first,true))
local source=[[return function(api)
 local ROOT,Bitmap,lcd=api.root,api.Bitmap,api.lcd
 local SOLID,CUSTOM_COLOR=api.SOLID,api.CUSTOM_COLOR
 local function round(x)return math.floor(x+.5)end
 local function ink(c)lcd.setColor(CUSTOM_COLOR,c)end
]]..string.sub(app,first,last-1)..'\nreturn icon\nend'
local make=assert(loadstring(source))()
local checks=0
local function check(value,why)assert(value,why);checks=checks+1 end
local function fixture(w,h,options)
 options=options or {}
 local calls={opens={},converts=0,patterns={},lines={},rects=0,circles=0,inks={}}
 local weakBitmap=setmetatable({},{__mode='v'})
 local mask=string.char(30,0,30,0)..string.rep(string.char(255),900)
 local api={root='/SCRIPTS/TOOLS/AERODECK/',SOLID=0,CUSTOM_COLOR=4096,Bitmap={},lcd={}}
 api.Bitmap.open=function(path)
  calls.opens[#calls.opens+1]=path
  local b={w=w,h=h};weakBitmap[1]=b;return b
 end
 api.Bitmap.getSize=function(b)return b.w,b.h end
 if not options.noToMask then api.Bitmap.toMask=function(b)
  check(b.w==30 and b.h==30,'only an exact30px bitmap may be converted')
  calls.converts=calls.converts+1;return mask
 end end
 api.lcd.setColor=function(index,color)calls.inks[#calls.inks+1]={index,color}end
 api.lcd.drawLine=function(...)calls.lines[#calls.lines+1]={...}end
 api.lcd.drawFilledRectangle=function()calls.rects=calls.rects+1 end
 api.lcd.drawCircle=function()calls.circles=calls.circles+1 end
 if not options.noPattern then api.lcd.drawBitmapPattern=function(...)
  calls.patterns[#calls.patterns+1]={...}
 end end
 return make(api),calls,weakBitmap,mask
end

local icon,calls,weakBitmap,mask=fixture(30,30)
icon(1,10,2,0x777777)
check(#calls.opens==1 and calls.opens[1]=='/SCRIPTS/TOOLS/AERODECK/icons/speed.png','other Material icons use their own image, not the home asset')
calls.patterns={};calls.lines={};calls.circles=0
for i=1,100 do
 local color=i%2==0 and 0xffffff or 0x8ca4b3
 icon(0,5,2,color)
 local draw=calls.patterns[i];local ink=calls.inks[#calls.inks]
 check(draw and draw[1]==mask and draw[2]==5 and draw[3]==2 and draw[4]==4096,'home mask uses native coordinates and CUSTOM_COLOR')
 check(ink[1]==4096 and ink[2]==color,'the cached mask must take the current tint on every draw')
 if i==50 then collectgarbage('collect')end
end
check(#calls.opens==2 and calls.opens[2]=='/SCRIPTS/TOOLS/AERODECK/icons/home.png','many frames/pages must read the home PNG only once')
check(calls.converts==2 and #calls.patterns==100,'home and speed masks survive collection without re-opening or re-converting')
check(#calls.lines==0 and calls.rects==0 and calls.circles==0,'successful home rendering must not also draw the primitive fallback')
collectgarbage('collect')
check(weakBitmap[1]==nil,'retain the small mask, not the decoded bitmap userdata')
icon(5,170,2,0xffffff)
check(#calls.opens==3 and calls.opens[3]=='/SCRIPTS/TOOLS/AERODECK/icons/table_chart.png','another Material icon loads only its own asset')
icon(0,5,2,0xffffff)
check(#calls.opens==3 and calls.converts==3,'other icons must not invalidate the warm home mask')

local function fallback(w,h,options,expectedOpens)
 local draw,seen=fixture(w,h,options)
 for _=1,3 do draw(0,5,2,0xabcdef);collectgarbage('collect')end
 check(#seen.patterns==0,'unavailable image/mask API must use geometry')
 check(#seen.lines==48,'home fallback remains the original eight double-stroked lines')
 local line=seen.lines[1]
 check(line[1]==8 and line[2]==16 and line[3]==20 and line[4]==5,'fallback retains the original x6,y3 geometry origin')
 check(#seen.opens==expectedOpens,'failed or unsupported home assets must not retry SD on subsequent frames')
 check(seen.converts==0,'missing/wrong-size assets and unsupported APIs must not convert a mask')
end
fallback(0,0,nil,1)
fallback(28,28,nil,1)
fallback(30,29,nil,1)
fallback(30,30,{noToMask=true},0)
fallback(30,30,{noPattern=true},0)
print('PASS: '..checks..' home icon cache, tint, GC, fallback and compatibility checks')
