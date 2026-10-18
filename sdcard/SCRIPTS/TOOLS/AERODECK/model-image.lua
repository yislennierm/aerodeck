-- Optional real EdgeTX model bitmap. The model header already includes its
-- filename/extension. Native drawBitmap uses integer percent, not target pixels.
local M={}
function M.new(opts)
 opts=opts or{};local bitmap=opts.Bitmap or Bitmap;local lcd=opts.lcd or lcd
 local state={status='OFF'};local handle,lastName,lastEnabled,lastOwner,geometry
 local api={}
 function api.set(name,enabled,owner)
  enabled=enabled==true
  if name==lastName and enabled==lastEnabled and owner==lastOwner then return state end
  lastName=name;lastEnabled=enabled;lastOwner=owner;handle=nil;geometry=nil
  state.status='OFF';state.path=nil;state.width=nil;state.height=nil;state.error=nil
  if not enabled then return state end
  if name==nil or name==''then state.status='NOT SET';return state end
  if type(name)~='string'or #name>96 or string.find(name,'[%c/\\]')or name=='.'or name=='..'then state.status='INVALID';state.error='INVALID MODEL IMAGE NAME';return state end
  local extension=string.lower(string.match(name,'%.([^%.]+)$')or'')
  if extension~='png'and extension~='bmp'and extension~='jpg'and extension~='jpeg'then state.status='UNSUPPORTED';state.error='UNSUPPORTED MODEL IMAGE';return state end
  if type(bitmap)~='table'or type(bitmap.open)~='function'or type(bitmap.getSize)~='function'then state.status='UNSUPPORTED';state.error='BITMAP API UNAVAILABLE';return state end
  local path='/IMAGES/'..name;local ok,b=pcall(bitmap.open,path)
  if not ok or not b then state.status='MISSING';state.error='MODEL IMAGE NOT FOUND';return state end
  local sized,w,h=pcall(bitmap.getSize,b)
  if not sized or type(w)~='number'or type(h)~='number'or w<1 or h<1 or w>8192 or h>8192 then state.status='INVALID';state.error='INVALID MODEL IMAGE';return state end
  handle=b;state.path=path;state.width=w;state.height=h;state.status='READY';return state
 end
 function api.draw(x,y,w,h)
  if not handle or type(lcd)~='table'or type(lcd.drawBitmap)~='function'then return false,state.error or state.status end
  if type(w)~='number'or type(h)~='number'or w<1 or h<1 then return false,'INVALID IMAGE BOX'end
  if not geometry or geometry.x~=x or geometry.y~=y or geometry.w~=w or geometry.h~=h then
   local percent=math.floor(math.min(w/state.width,h/state.height)*100)
   if percent<1 then return false,'IMAGE TOO LARGE'end
   local width=math.floor(state.width*percent/100);local height=math.floor(state.height*percent/100)
   geometry={x=x,y=y,w=w,h=h,percent=percent,left=x+math.floor((w-width)/2),top=y+math.floor((h-height)/2)}
  end
  local ok=pcall(lcd.drawBitmap,handle,geometry.left,geometry.top,geometry.percent==100 and 0 or geometry.percent)
  if not ok then return false,'IMAGE DRAW FAILED'end;return true
 end
 function api.snapshot()return state end
 return api
end
return M
