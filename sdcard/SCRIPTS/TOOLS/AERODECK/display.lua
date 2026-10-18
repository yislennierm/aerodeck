-- Uniform viewport adapter for AERODECK's 480x272 logical canvas.
-- 480x272 returns the exact original LCD object: no drawing wrappers/probes.
-- Other supported panels keep the same geometry; remaining bottom rows belong
-- to the caller's physical extra-information strip. No drawing or I/O at load.
local M={sources={
 fonts='https://github.com/EdgeTX/edgetx/blob/v2.12.4/radio/src/gui/colorlcd/fonts.h#L25-L41',
 constants='https://github.com/EdgeTX/edgetx/blob/v2.12.4/radio/src/lua/api_general.cpp#L3207-L3215',
 fontSelection='https://github.com/EdgeTX/edgetx/blob/v2.12.4/radio/src/fonts/CMakeLists.txt#L5-L11',
 lcd='https://github.com/EdgeTX/edgetx/blob/v2.12.4/radio/src/lua/api_colorlcd.cpp',
 touch='https://github.com/EdgeTX/edgetx/blob/v2.12.4/radio/src/lua/lua_event.cpp#L87-L99'
}}
local floor,min,max=math.floor,math.min,math.max
local function round(v)return floor(v+0.5)end
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
-- COLORLCD font field, not the different monochrome FONTSIZE_MASK.
-- Index: STD,BOLD,XXS,XS,L,XL,XXL,LXL. Heights from official standard English
-- font sources, used only as logical row-height budgets on a larger panel.
local baseHeights={21,20,12,17,29,40,69,51}
local passThrough={'RGB','setColor','getColor','clear','refresh','resetBacklightTimeout','exitFullScreen'}
function M.new(native,width,height)
 if type(native)~='table'then return nil,'NO LCD API'end
 if not((width==480 and(height==272 or height==320))or(width==800 and height==480))then
  return nil,'UNSUPPORTED DISPLAY'
 end
 local scale=min(width/480,height/272)
 local vx,vy=round((width-480*scale)/2),0
 local vw,vh=round(480*scale),round(272*scale)
 local p={raw=native,width=width,height=height,scale=scale,
  virtualWidth=480,virtualHeight=272,offset={x=vx,y=vy},
  viewport={x=vx,y=vy,w=vw,h=vh},extra={x=0,y=vy+vh,w=width,h=height-vy-vh},
  native=width==480 and height==272,hardwareVerified=false}
 local function X(x)return vx+round(x*scale)end
 local function Y(y)return vy+round(y*scale)end
 local function length(v)return round(v*scale)end
 -- Endpoint-derived extents avoid a one-pixel gap between adjacent cells.
 local function W(x,w)return X(x+w)-X(x)end
 local function H(y,h)return Y(y+h)-Y(y)end
 p.point=function(x,y)return X(x),Y(y)end
 p.rect=function(x,y,w,h)return X(x),Y(y),W(x,w),H(y,h)end
 p.iconSize=length
 local assetRoot=width==800 and 'icons/800x480/'or 'icons/'
 function p.iconPath(file)
  if type(file)~='string'or not string.match(file,'^[%w_%-]+%.png$')then return nil,'INVALID ICON FILE'end
  return assetRoot..file
 end
 local mappedTouch={}
 function p.touch(raw)
  if type(raw)~='table'or not finite(raw.x)or not finite(raw.y)then return nil end
  if raw.x<vx or raw.x>=vx+vw or raw.y<vy or raw.y>=vy+vh then return nil end
  if scale==1.0 and vx==0.0 and vy==0.0 then return raw end
  for k in pairs(mappedTouch)do mappedTouch[k]=nil end
  for k,v in pairs(raw)do mappedTouch[k]=v end
  -- Pixel centers invert the same rounded cell boundaries used for painting.
  -- Plain division can put the first painted pixel before its logical target
  -- (e.g. virtual x8 paints at physical13, but13/(5/3) is7.8).
  mappedTouch.x=floor((raw.x-vx+0.5)/scale);mappedTouch.y=floor((raw.y-vy+0.5)/scale)
  if finite(raw.startX)then mappedTouch.startX=floor((raw.startX-vx+0.5)/scale)end
  if finite(raw.startY)then mappedTouch.startY=floor((raw.startY-vy+0.5)/scale)end
  if finite(raw.slideX)then mappedTouch.slideX=raw.slideX/scale end
  if finite(raw.slideY)then mappedTouch.slideY=raw.slideY/scale end
  return mappedTouch
 end
 -- A retained touch snapshot belongs to the caller. The scaled adapter reuses
 -- its own output table and never mutates EdgeTX's event table.
 if p.native then
  p.lcd=native;p.font=function(flags)return flags or 0 end
  return p
 end
 if type(native.sizeText)~='function'then return nil,'TEXT METRICS UNAVAILABLE'end
 -- Probe once, never during warm drawing. Existing native font index is kept
 -- whenever it fits its scaled row. This avoids promoting fixed captions to
 -- wider fonts. Only an oversized/unavailable font falls back to a smaller one.
 local heights,fontMap={},{}
 for index=0,7 do
  local _,h=native.sizeText('Ag',index*256)
  if finite(h)and h>0 then heights[index]=h end
 end
 for index=0,7 do
  local budget=baseHeights[index+1]*scale
  local chosen=index
  if not heights[index]or heights[index]>budget+0.01 then
   chosen=nil
   for candidate=0,7 do
    local h=heights[candidate]
    if h and h<=budget+0.01 and(not chosen or h>heights[chosen])then chosen=candidate end
   end
   if not chosen then return nil,'NO FONT FITS VIEWPORT'end
  end
  fontMap[index]=chosen*256
 end
 function p.font(flags)
  flags=flags or 0
  local index=floor(flags/256)%16
  local mapped=fontMap[index]
  -- Unknown font fields are left untouched rather than guessed.
  return mapped and flags-index*256+mapped or flags
 end
 p.fontMap=fontMap;p.fontHeights=heights
 local lcd={}
 for _,name in ipairs(passThrough)do lcd[name]=native[name]end
 p.lcd=lcd
 if native.sizeText then function lcd.sizeText(text,flags)
  local w,h=native.sizeText(text,p.font(flags));return w/scale,h/scale
 end end
 if native.drawText then function lcd.drawText(x,y,text,flags,inverse)
  return native.drawText(X(x),Y(y),text,p.font(flags),inverse)
 end end
 if native.drawTextLines then function lcd.drawTextLines(x,y,w,h,text,flags,inverse)
  local a,b=native.drawTextLines(X(x),Y(y),W(x,w),H(y,h),text,p.font(flags),inverse)
  if finite(a)and finite(b)then return(a-vx)/scale,(b-vy)/scale end
  return a,b
 end end
 for _,name in ipairs({'drawNumber','drawTimer','drawChannel','drawSwitch','drawSource'})do
  local draw=native[name]
  if draw then lcd[name]=function(x,y,value,flags,inverse)return draw(X(x),Y(y),value,p.font(flags),inverse)end end
 end
 if native.drawPoint then function lcd.drawPoint(x,y,flags)return native.drawPoint(X(x),Y(y),flags)end end
 if native.drawLine then function lcd.drawLine(x1,y1,x2,y2,pattern,flags)
  return native.drawLine(X(x1),Y(y1),X(x2),Y(y2),pattern,flags)
 end end
 if native.drawLineWithClipping then function lcd.drawLineWithClipping(x1,y1,x2,y2,xmin,xmax,ymin,ymax,pattern,flags)
  local left,right=max(vx,X(xmin)),min(vx+vw,X(xmax))
  local top,bottom=max(vy,Y(ymin)),min(vy+vh,Y(ymax))
  if left>=right or top>=bottom then return end
  return native.drawLineWithClipping(X(x1),Y(y1),X(x2),Y(y2),left,right,top,bottom,pattern,flags)
 end end
 if native.drawRectangle then function lcd.drawRectangle(x,y,w,h,flags,thickness,opacity)
  return native.drawRectangle(X(x),Y(y),W(x,w),H(y,h),flags,max(1,length(thickness or 1)),opacity)
 end end
 if native.drawFilledRectangle then function lcd.drawFilledRectangle(x,y,w,h,flags,opacity)
  return native.drawFilledRectangle(X(x),Y(y),W(x,w),H(y,h),flags,opacity)
 end end
 if native.invertRect then function lcd.invertRect(x,y,w,h,flags)
  return native.invertRect(X(x),Y(y),W(x,w),H(y,h),flags)
 end end
 if native.drawGauge then function lcd.drawGauge(x,y,w,h,fill,maxfill,flags)
  return native.drawGauge(X(x),Y(y),W(x,w),H(y,h),fill,maxfill,flags)
 end end
 for _,name in ipairs({'drawCircle','drawFilledCircle'})do
  local draw=native[name]
  if draw then lcd[name]=function(x,y,r,flags)return draw(X(x),Y(y),length(r),flags)end end
 end
 for _,name in ipairs({'drawTriangle','drawFilledTriangle'})do
  local draw=native[name]
  if draw then lcd[name]=function(x1,y1,x2,y2,x3,y3,flags)return draw(X(x1),Y(y1),X(x2),Y(y2),X(x3),Y(y3),flags)end end
 end
 for _,name in ipairs({'drawArc','drawPie'})do
  local draw=native[name]
  if draw then lcd[name]=function(x,y,r,start,finish,flags)return draw(X(x),Y(y),length(r),start,finish,flags)end end
 end
 if native.drawAnnulus then function lcd.drawAnnulus(x,y,r1,r2,start,finish,flags)
  return native.drawAnnulus(X(x),Y(y),length(r1),length(r2),start,finish,flags)
 end end
 if native.drawHudRectangle then function lcd.drawHudRectangle(pitch,roll,xmin,xmax,ymin,ymax,flags)
  -- Native HUD offsets pitch in fixed pixels/degree, independent of its bounds.
  -- Scale pitch only at this draw boundary so its horizon follows the same
  -- transform as the logical ladder. Roll is an angle and is never stretched.
  return native.drawHudRectangle(pitch*scale,roll,X(xmin),X(xmax),Y(ymin),Y(ymax),flags)
 end end
 if native.drawBitmap then function lcd.drawBitmap(bitmap,x,y,percent)
  local nativePercent=round((percent and percent~=0 and percent or 100)*scale)
  return native.drawBitmap(bitmap,X(x),Y(y),nativePercent)
 end end
 -- Native masks cannot be scaled by this API. Caller must load iconPath()'s
 -- deterministic native-size asset and verify Bitmap.getSize == iconSize().
 if native.drawBitmapPattern then function lcd.drawBitmapPattern(bitmap,x,y,flags)
  return native.drawBitmapPattern(bitmap,X(x),Y(y),flags)
 end end
 if native.drawBitmapPatternPie then function lcd.drawBitmapPatternPie(bitmap,x,y,start,finish,flags)
  return native.drawBitmapPatternPie(bitmap,X(x),Y(y),start,finish,flags)
 end end
 return p
end
return M
