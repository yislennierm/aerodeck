-- Native-size startup artwork, loaded once on demand; no hidden-view drawing.
local M={}
function M.new(api)
 local lcd,bitmap=api.lcd,api.bitmap
 local width,height=api.width or 480,api.height or 272
 local logo,attempted,colors
 local labels={['LOADING APP']='Loading application',['STARTING SESSION']='Starting flight session',
  DISPLAY='Preparing display',['BATTERY SETTINGS']='Loading battery settings',['APPLICATION SETTINGS']='Loading preferences',
  TELEMETRY='Preparing telemetry',['INPUT PROVIDER']='Preparing controls',['INPUT INVENTORY']='Discovering controls',
  ['FC CONNECTION']='Preparing flight controller',['RUNTIME SERVICES']='Preparing services',['FLIGHT SESSION']='Starting flight session',
  ['SESSION RESET']='Preparing flight data',['SOURCE BINDINGS']='Finding telemetry sources',['FC CLIENT']='Preparing FC connection',
  ['ARMING DECODER']='Preparing arm information',ICONS='Preparing icons',['NATIVE EXTREMA']='Preparing telemetry history',READY='Ready',['READING CURRENT TELEMETRY']='Reading telemetry',['UPDATING SOURCES / FLIGHT CONTROLLER']='Preparing flight data'}
 local function palette()
  if not colors then colors={bg=lcd.RGB(5,12,19),white=lcd.RGB(232,242,245),muted=lcd.RGB(140,164,179),warning=lcd.RGB(255,174,98)}end
  return colors
 end
 local function centered(text,y,font,color)
  text=tostring(text or'');font=font or SMLSIZE
  local w=type(lcd.sizeText)=='function'and lcd.sizeText(text,font)or#text*(font==MIDSIZE and 14 or 7)
  lcd.setColor(CUSTOM_COLOR,color);lcd.drawText(math.floor((width-w)/2),y,text,CUSTOM_COLOR+font)
 end
 local s={}
 function s.prepare()
  if attempted then return end;attempted=true
  if bitmap and type(bitmap.open)=='function'and type(bitmap.getSize)=='function'then
   local ok,b=pcall(bitmap.open,'/SCRIPTS/TOOLS/AERODECK/icons/branding/aerodeck-logo-120.png')
   if ok and b then local sized,w,h=pcall(bitmap.getSize,b);if sized and w==120 and h==120 then logo=b end end
  end
 end
 function s.draw(message,build,warning)
  local c=palette();lcd.setColor(CUSTOM_COLOR,c.bg);lcd.drawFilledRectangle(0,0,width,height,CUSTOM_COLOR)
  local top=math.floor(height*.09)
  if logo and type(lcd.drawBitmap)=='function'then lcd.drawBitmap(logo,math.floor((width-120)/2),top)end
  local titleY=top+120
  centered('AERODECK',titleY,MIDSIZE or SMLSIZE,c.white)
  local stage=labels[message]or message or'Loading application'
  if type(message)=='string'then
   local n,total=string.match(message,'^ICONS (%d+) / (%d+)$')
   if n then stage='Preparing icons '..n..' / '..total
   elseif string.sub(message,1,8)=='INPUTS /'then stage='Discovering controls'end
  end
  local titleHeight=29
  if type(lcd.sizeText)=='function'then local _,h=lcd.sizeText('Ag',MIDSIZE or SMLSIZE);titleHeight=h or titleHeight end
  centered(stage,titleY+titleHeight+12,SMLSIZE,warning and c.warning or c.muted)
  if build then centered(build,height-26,TINSIZE or SMLSIZE,c.muted)end
 end
 return s
end
return M
