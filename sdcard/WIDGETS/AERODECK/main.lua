-- AERODECK companion widget. Compact view is always live; fullscreen loads the same app.
local function create(zone,options)return {zone=zone,options=options,map={},modelName=nil,app=nil}end
local function update(w,options)w.options=options;w.modelName=nil end
local function mappings(w)
 local name=model.getInfo().name or 'model';if name==w.modelName then return end
 w.modelName=name;w.map={};local key=''
 for i=1,#name do key=key..string.format('%02x',string.byte(name,i))end
 local f=io.open('/SCRIPTS/TOOLS/AERODECK/settings-'..key..'.cfg','r')
 if f then local s=io.read(f,4096);io.close(f);if s and string.sub(s,1,7)=='ADCFG1\n' then for k,v in string.gmatch(s,'([%w]+)=([^\r\n]*)')do w.map[k]=v end end end
end
local function read(w,key,names)
 local choice=w.map[key];if choice=='None' then return nil end
 if choice and choice~='Auto' then names={choice}end
 for _,name in ipairs(names)do
  local id
  if getSourceIndex and CHAR_TELEMETRY then
   local source=getSourceIndex(CHAR_TELEMETRY..name);if type(source)=='number'and source>0 then id=source end
  else local info=getFieldInfo(name);id=info and info.id end
  if id then local v,current=getSourceValue(id);if current and type(v)=='number'then return v end end
 end
end
local function refresh(w,event,touch)
 if event~=nil then
  if not w.app then
   local loader=loadScript('/SCRIPTS/TOOLS/telem.lua')
   if loader then w.app=loader();if w.app and w.app.init then w.app.init()end end
  end
  if w.app then
   if w.app.run(event,touch)==1 then w.app=nil;w.modelName=nil;collectgarbage('collect');lcd.exitFullScreen()end
  else lcd.drawText(8,12,'Install SCRIPTS/TOOLS/telem.lua',SMLSIZE);if event==EVT_VIRTUAL_EXIT then lcd.exitFullScreen()end end
  return
 end
 if w.app then if w.app.stop then w.app.stop()end;w.app=nil;w.modelName=nil;collectgarbage('collect')end
 mappings(w)
 local z=w.zone;local v=read(w,'voltage',{'RxBt','VFAS','Bat'});local lq=read(w,'lq',{'RQly','LQ'});local a=read(w,'current',{'Curr'})
 local bg=lcd.RGB(7,15,22);local white=lcd.RGB(235,243,245);local green=lcd.RGB(164,227,125);local muted=lcd.RGB(144,165,178)
 lcd.setColor(CUSTOM_COLOR,bg);lcd.drawFilledRectangle(z.x,z.y,z.w,z.h,CUSTOM_COLOR)
 local function text(x,y,s,col,size)lcd.setColor(CUSTOM_COLOR,col);lcd.drawText(z.x+x,z.y+y,s,CUSTOM_COLOR+(size or SMLSIZE))end
 local function fmt(n,f,u)return n and string.format(f,n)..u or '--'end
 if z.w<150 or z.h<70 then text(4,3,'AERODECK',green);if z.h>=36 then text(4,20,fmt(v,'%.1f',' V'),white)end;return end
 text(8,6,'AERODECK',white,z.w>=250 and MIDSIZE or SMLSIZE);text(z.w-70,9,(v or lq) and 'LIVE' or 'NO DATA',green)
 text(8,31,fmt(v,'%.1f',' V'),white,MIDSIZE);text(math.floor(z.w/2),31,fmt(lq,'%.0f',' % LQ'),green)
 if z.h>=95 then text(8,57,fmt(a,'%.1f',' A'),muted);text(8,z.h-19,'FULL SCREEN: AERODECK',muted)end
end
local function background(w)
 if w.app then if w.app.stop then w.app.stop()end;w.app=nil;w.modelName=nil;collectgarbage('collect')end
end
return {name='AERODECK',options={},create=create,update=update,refresh=refresh,background=background}
