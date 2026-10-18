-- Explicit quick pack proposal. No telemetry, SD, model or output APIs.
-- Row selection is pending only; the injected selectPack callback exclusively
-- owns validated persistence of the pack key. Failed saves never claim Apply.
local M={}
local function integer(v,lo,hi)return type(v)=='number'and v==v and v%1==0.0 and v>=lo and v<=hi end
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local controls={}
for index=0,5 do controls[#controls+1]={'packRow'..index,8,90+index*21,464,21,'PACK '..index,index}end
controls[7]={'packCancel',8,222,112,21,'CANCEL'}
controls[8]={'packEdit',128,222,168,21,'EDIT PACKS'}
controls[9]={'packUse',304,222,168,21,'USE PACK'}
function M.new(opts)
 opts=opts or{}
 local lcd=opts.lcd
 if type(lcd)~='table'or type(lcd.sizeText)~='function'or type(lcd.setColor)~='function'or type(lcd.drawText)~='function'or type(lcd.drawFilledRectangle)~='function'
  or type(opts.configget)~='function'then return nil,'QUICK PACK DEPENDENCY UNAVAILABLE'end
 local fonts=opts.fonts or{};local small,tiny=fonts.small or 0x300,fonts.tiny or 0x200
 local flag=opts.colorFlag or 0
 local palette=opts.palette;local empty={}
 local state={active=false,status='CLOSED',rows={},focus=1,focusName='packRow0',pending=0,current=nil}
 local api={controls=controls}
 local function config(key)
  local ok,value=pcall(opts.configget,key);if ok then return value end
 end
 local function rows()
  local out=state.rows
  out[1]=out[1]or{};local auto=out[1]
  auto.id=0;auto.label='MANUAL / AUTO';auto.enabled=true;auto.chemistry=nil;auto.cells=nil;auto.capacity=nil
  auto.chemistryLabel='';auto.cellsLabel='';auto.capacityLabel='MODEL BATTERY SETTINGS'
  for index=1,5 do
   local row=out[index+1]or{};out[index+1]=row
   row.id=index;row.label='PACK '..index
   row.chemistry=config('chemistry'..index);row.cells=config('cells'..index);row.capacity=config('capacity'..index)
   row.off=row.chemistry==0.0
   row.valid=(row.chemistry==1.0 or row.chemistry==2.0)and integer(row.cells,1,99)and integer(row.capacity,100,100000)
   row.enabled=row.valid==true and not row.off
   row.chemistryLabel=row.off and'OFF'or row.chemistry==1.0 and'LiPo'or row.chemistry==2.0 and'Li-ion'or'INVALID'
   row.cellsLabel=finite(row.cells)and tostring(row.cells)..'S'or'--'
   row.capacityLabel=finite(row.capacity)and tostring(row.capacity)..' mAh'or'--'
   if not row.enabled and not row.off then row.label=row.label..' / INVALID'end
  end
 end
 local function focus(index)state.focus=index;state.focusName=controls[index][1]end
 function api.enabled(name)
  local n=type(name)=='string'and tonumber(string.match(name,'^packRow(%d)$'))or nil
  if n then return n<=5 and state.rows[n+1]and state.rows[n+1].enabled or false end
  if name=='packUse'then local row=state.rows[state.pending+1];return row and row.enabled or false end
  return name=='packCancel'or name=='packEdit'
 end
 function api.open()
  rows();state.current=config('pack');state.pending=integer(state.current,0,5)and state.current or 0
  state.active=true;state.status='PENDING';state.error=nil
  if not state.rows[state.pending+1].enabled then state.pending=0;state.error='CURRENT PACK IS OFF / SELECT A VALID PACK'end
  focus(state.pending+1)
  return true
 end
 function api.active()return state.active end
 function api.snapshot()return state end -- Stable borrowed read-only state.
 function api.stop()state.active=false;state.status='CLOSED';state.error=nil end
 function api.result()return state.status,state.pending end
 function api.move(delta)
  if not state.active or not integer(delta,-1,1)or delta==0 then return false end
  local index=state.focus
  for _=1,#controls do index=(index-1+delta)%#controls+1;if api.enabled(controls[index][1])then focus(index);return true end end
  return false
 end
 local function rejected(message)
  state.status='ERROR';state.error=type(message)=='string'and string.sub(message,1,96)or'PACK SAVE REJECTED'
  return 'ERROR',state.error
 end
 function api.action(name)
  if not state.active then return 'CLOSED'end
  local n=type(name)=='string'and tonumber(string.match(name,'^packRow(%d)$'))or nil
  if n then
   if not api.enabled(name)then return 'PENDING','PACK DISABLED'end
   state.pending=n;state.status='SELECTED';state.error=nil;focus(9);return 'SELECTED'
  elseif name=='packCancel'then state.active=false;state.status='CANCEL';state.error=nil;return 'CANCEL'
  elseif name=='packEdit'then state.active=false;state.status='EDIT';state.error=nil;return 'EDIT'
  elseif name=='packUse'then
   rows() -- Revalidate an explicitly applied proposal against current config.
   if not api.enabled(name)then return rejected('PACK IS OFF OR INVALID / EDIT PACKS')end
   if type(opts.selectPack)~='function'then return rejected('PACK SAVE UNAVAILABLE')end
   local ok,success,why=pcall(opts.selectPack,state.pending)
   if not ok then return rejected(success)end
   if success~=true then return rejected(why)end
   state.current=state.pending;state.active=false;state.status='APPLIED';state.error=nil;return 'APPLIED'
  end
  return 'PENDING'
 end
 function api.activate()return api.action(state.focusName)end
 function api.hit(x,y)
  if not state.active or not finite(x)or not finite(y)then return nil end
  for _,c in ipairs(controls)do if x>=c[2]and x<c[2]+c[4]and y>=c[3]and y<c[3]+c[5]and api.enabled(c[1])then return c[1]end end
 end
 function api.input(event,touch)
  if not state.active then return false,'CLOSED'end
  local status,err
  if EVT_VIRTUAL_EXIT and event==EVT_VIRTUAL_EXIT then status=api.action('packCancel')
  elseif(EVT_VIRTUAL_NEXT and event==EVT_VIRTUAL_NEXT)or(EVT_VIRTUAL_NEXT_PAGE and event==EVT_VIRTUAL_NEXT_PAGE)then api.move(1);status='PENDING'
  elseif(EVT_VIRTUAL_PREV and event==EVT_VIRTUAL_PREV)or(EVT_VIRTUAL_PREV_PAGE and event==EVT_VIRTUAL_PREV_PAGE)then api.move(-1);status='PENDING'
  elseif EVT_VIRTUAL_ENTER and event==EVT_VIRTUAL_ENTER then status,err=api.activate()
  elseif EVT_TOUCH_TAP and event==EVT_TOUCH_TAP and type(touch)=='table'then local name=api.hit(touch.x,touch.y);if name then status,err=api.action(name)end end
  return true,status or'PENDING',err -- Active modal consumes outside/global events.
 end
 local function paint()
  if type(palette)=='function'then local ok,value=pcall(palette);if ok and type(value)=='table'then return value end
  elseif type(palette)=='table'then return palette end
  return empty
 end
 local function rect(x,y,w,h,c)lcd.setColor(flag,c);lcd.drawFilledRectangle(x,y,w,h,flag)end
 local function fit(text,width,font)
  local measured=lcd.sizeText(text,font)
  if type(measured)=='number'and measured<=width then return text end
  local n=#text
  while n>0 do
   n=n-1;local value=string.sub(text,1,n)..'...';local w=lcd.sizeText(value,font)
   if type(w)=='number'and w<=width then return value end
  end
  return ''
 end
 local function text(x,y,h,value,c,font,width,right)
  value=fit(value,width,font);local w,height=lcd.sizeText(value,font)
  if type(height)~='number'or height<=0 then height=font==tiny and 12 or 17 end
  if right and type(w)=='number'then x=x-w end
  lcd.setColor(flag,c);lcd.drawText(x,y+math.floor((h-height)/2),value,flag+font)
 end
 function api.draw()
  if not state.active then return end
  local p=paint();local bg=p.black or p.bg or 0;local panel=p.tape or p.panel or bg;local white=p.white or 0;local muted=p.muted or white;local cyan=p.cyan or white;local green=p.green or cyan;local orange=p.orange or white
  rect(4,62,472,182,bg);rect(8,64,464,22,panel)
  text(18,64,22,'BATTERY PACK',white,small,148)
  local status=state.error or('CURRENT '..(state.current==0.0 and'MANUAL / AUTO'or integer(state.current,1,5)and'PACK '..state.current or'UNKNOWN'))
  text(462,64,22,status,state.error and orange or muted,tiny,278,true)
  for i,row in ipairs(state.rows)do
   local c=controls[i];local focused=state.focus==i and row.enabled
   rect(c[2],c[3],c[4],c[5],focused and green or panel)
   if state.pending==row.id and not focused then rect(8,c[3],3,c[5],cyan)end
   local color=focused and bg or row.enabled and white or muted
   text(18,c[3],21,row.label,color,small,128)
   if row.id==0 then text(462,c[3],21,row.capacityLabel,color,tiny,288,true)
   else
    text(158,c[3],21,row.chemistryLabel,color,small,68)
    text(238,c[3],21,row.cellsLabel,color,small,46)
    text(462,c[3],21,row.capacityLabel,color,small,166,true)
   end
  end
  for i=7,9 do
   local c=controls[i];local enabled=api.enabled(c[1]);local focused=enabled and state.focus==i
   rect(c[2],c[3],c[4],c[5],focused and cyan or panel)
   text(c[2]+8,c[3],c[5],c[6],focused and bg or enabled and white or muted,small,c[4]-16)
  end
 end
 return api
end
return M
