-- Actual splash renderer: cached native bitmap, alpha asset, bounded placement and failure fallback.
local factory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/startup-screen.lua'))()
local checks=0;local function check(v,why)assert(v,why);checks=checks+1 end
SMLSIZE=0;MIDSIZE=256;TINSIZE=128;CUSTOM_COLOR=4096
local path='sdcard/SCRIPTS/TOOLS/AERODECK/icons/branding/aerodeck-logo-120.png'
local f=assert(io.open(path,'rb'));local h=f:read(33);f:close()
local function u32(i)local a,b,c,d=string.byte(h,i,i+3);return((a*256+b)*256+c)*256+d end
check(h:sub(1,8)=='\137PNG\13\10\26\10'and u32(17)==120 and u32(21)==120,'approved artwork is exactly120x120')
check(h:byte(25)==8 and h:byte(26)==6,'artwork retains8-bit RGBA transparency')
local function fixture(width,height,mode)
 local opens,inks,images,texts,boxes=0,{}, {},{},{}
 local lcd={RGB=function(r,g,b)return r*65536+g*256+b end,setColor=function(_,c)inks[#inks+1]=c end}
 lcd.sizeText=function(s,font)return #s*(font==MIDSIZE and 14 or font==TINSIZE and 6 or 8),font==MIDSIZE and 29 or font==TINSIZE and 12 or 17 end
 lcd.drawText=function(x,y,s,flags)texts[#texts+1]={x=x,y=y,s=s,font=flags-CUSTOM_COLOR,c=inks[#inks]}end
 lcd.drawFilledRectangle=function(x,y,w,h)boxes[#boxes+1]={x,y,w,h,inks[#inks]}end
 lcd.drawBitmap=function(b,x,y)images[#images+1]={b=b,x=x,y=y}end
 local bitmap={open=function(p)opens=opens+1;check(p=='/'..path:sub(8),'runtime path matches approved asset');if mode=='missing'then return nil elseif mode=='throw'then error('unreadable PNG')end;return{}end,
  getSize=function()return mode=='wrong'and 119 or 120,120 end}
 local screen=factory.new({lcd=lcd,bitmap=bitmap,width=width,height=height})
 return screen,function()return opens,images,texts,boxes,lcd end
end
local s,inspect=fixture(480,272)
s.draw('LOADING APP','2026.10.0-alpha')
local opens,images,texts,boxes=inspect();check(opens==0 and #images==0,'drawing cannot perform SD I/O before explicit preparation')
s.prepare();s.prepare();s.draw('INPUTS / ANALOG 16','2026.10.0-alpha')
opens,images,texts,boxes=inspect();check(opens==1 and #images==1 and images[1].x==180 and images[1].y==24,'one native120px logo is centered on TX16S')
check(boxes[#boxes][5]==0x050c13,'every frame explicitly covers the theme background with original dark navy')
for i=1,80 do s.draw('ICONS 7 / 20','2026.10.0-alpha')end
opens,images,texts,boxes=inspect();check(opens==1 and #images==81,'all subsequent frames reuse the bitmap')
local friendly=false
for _,v in ipairs(texts)do
 local w,h=inspect();local _,_,_,_,lcd=inspect();w,h=lcd.sizeText(v.s,v.font)
 check(v.x==math.floor((480-w)/2)and v.x>=0 and v.x+w<=480 and v.y>=0 and v.y+h<=272,'native text is centered and inside the screen: '..v.s)
 if v.s=='Discovering controls'then friendly=true end
end
check(friendly,'internal control-inventory counters have a clear stage caption')
for _,mode in ipairs({'missing','wrong','throw'})do
 local a,read=fixture(480,272,mode);a.prepare()
 for i=1,20 do a.prepare();a.draw('Starting flight session','2026.10.0-alpha',true)end
 local n,p,t,b=read();check(n==1 and #p==0 and #t>0 and b[#b][5]==0x050c13,'missing/bad artwork keeps one attempt and a real dark text fallback: '..mode)
 local warning=false;for _,v in ipairs(t)do if v.s=='Starting flight session'and v.c==0xffae62 then warning=true end end
 check(warning,'failure stage has an explicit warning color: '..mode)
end
local large,read=fixture(800,480);large.prepare();large.draw('READY','2026.10.0-alpha')
local _,p=read();check(p[1].x==340,'native bitmap remains centered on a larger display')
print('PASS: '..checks..' actual splash asset, centering, explicit palette, cache, stage captions and fallback checks')
