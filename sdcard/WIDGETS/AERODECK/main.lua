-- One session per widget: App mode/full screen renders it; compact/hidden views sample it.
local APP='/SCRIPTS/TOOLS/telem.lua'
local BUILD='2026.10.0-alpha'
local startupScreen,startupAttempted
local colors,heights
local function create(zone,options)return {zone=zone,options=options,app=nil,attempted=false}end
local function prepareStartup()
 startupAttempted=true
 local ok,chunk=pcall(loadScript,'/SCRIPTS/TOOLS/AERODECK/startup-screen.lua')
 if ok and type(chunk)=='function'then
  local loaded,factory=pcall(chunk)
  if loaded and type(factory)=='table'and type(factory.new)=='function'then
   startupScreen=factory.new({lcd=lcd,bitmap=Bitmap,width=LCD_W,height=LCD_H});startupScreen.prepare()
  end
 end
end
local function closeFailedSession(w)
 local app=w.app
 if not app then return false end
 if type(app.close)=='function'then
  local ok,closed=pcall(app.close)
  if ok and closed==true then
   w.closed=true;w.closeFailed=false;w.recoveryMessage='UPDATE WIDGET TO RESTART';return true
  end
  w.closeFailed=true;w.recoveryMessage='CLOSE FAILED / UPDATE TO RETRY';return false
 end
 -- A legacy stop can pause transport, but cannot confirm timer restoration.
 -- Never discard its only remaining restoration metadata or claim a new app.
 if not w.legacyStopped and type(app.stop)=='function'then w.legacyStopped=true;pcall(app.stop)end
 w.closeFailed=true;w.recoveryMessage='CLOSE UNAVAILABLE / UPDATE APP';return false
end
local function update(w,options)
 w.options=options
 if w.backgroundFailed then
  if not w.closed and not closeFailedSession(w)then return end
  w.app=nil;w.attempted=false;w.bootstrapStage=nil;w.loader=nil;w.pendingApp=nil;w.loading=nil;w.error=nil;w.snapshotFailed=nil;w.backgroundFailed=nil;w.closed=nil;w.closeFailed=nil;w.recoveryMessage=nil;w.legacyStopped=nil;w.view=nil
  return
 end
 -- Updating a failed widget offers an explicit retry; healthy sessions stay intact.
 if not w.app and not w.bootstrapStage then w.attempted=false;w.loading=nil;w.error=nil end
end
local function bootstrap(w)
 if w.app then w.loading=nil;return w.app end
 if w.attempted and not w.bootstrapStage then return end
 -- One cold branding callback precedes compilation of the large app chunk.
 if w.fullStartup and not startupAttempted then prepareStartup();return end
 -- EdgeTX allows about 20,000 VM instructions for the entire widget callback.
 -- Nested pcall does not create another budget. Cold load, chunk execution and
 -- session initialization therefore occupy separate callbacks, with no live
 -- service/render call in the callback that finishes initialization.
 if not w.bootstrapStage then
  w.attempted=true;w.loading='LOADING APP'
  if type(loadScript)~='function'then w.error='APP UNAVAILABLE';w.loading=nil;return end
  local ok,loader=pcall(loadScript,APP)
  if not ok or type(loader)~='function'then w.error='APP UNAVAILABLE';w.loading=nil;return end
  w.loader=loader;w.bootstrapStage='CHUNK';return
 elseif w.bootstrapStage=='CHUNK'then
  local loaded,app=pcall(w.loader);w.loader=nil
  if not loaded or type(app)~='table'then w.bootstrapStage=nil;w.loading=nil;w.error='APP LOAD FAILED';return end
  if type(app.setRetained)=='function'then app.setRetained(true)end
  if startupScreen and type(app.setStartupScreen)=='function'then app.setStartupScreen(startupScreen)end
  w.pendingApp=app;w.bootstrapStage='INIT';w.loading='STARTING SESSION';return
 end
 local app=w.pendingApp
 if type(app.init)=='function'then
  local initialized=pcall(app.init)
  if not initialized then w.bootstrapStage=nil;w.loading=nil;w.error='APP INIT FAILED';return end
 end
 w.pendingApp=nil;w.bootstrapStage=nil;w.app=app
end
local function service(w,view)
 local app=bootstrap(w)
 if app then
  if type(app.background)=='function'then
   if not w.backgroundFailed then
    local ok=pcall(app.background)
    if not ok then w.backgroundFailed=true;w.error='SESSION ERROR';closeFailedSession(w)end
   end
  else
   -- Old apps cannot share compact data. Pause their foreground transport once.
   if w.view=='full' and type(app.stop)=='function'then pcall(app.stop)end
   w.error='UPDATE AERODECK'
  end
 end
 w.view=view
 return app
end
local function snapshot(w)
 local app=w.app
 if w.backgroundFailed or w.loading or not app or type(app.snapshot)~='function'then return nil end
 local ok,data=pcall(app.snapshot)
 if ok and type(data)=='table'then
  if w.snapshotFailed then w.snapshotFailed=nil;if w.error=='SESSION ERROR'then w.error=nil end end
  return data
 end
 -- A newly initialized shared session can legitimately have no first sample.
 -- Only an exception or an invalid non-nil return is a snapshot failure.
 if not ok or data~=nil then w.snapshotFailed=true;w.error='SESSION ERROR'end
 return nil
end
local function palette()
 if not colors then
  colors={bg=lcd.RGB(7,15,22),white=lcd.RGB(235,243,245),green=lcd.RGB(164,227,125),muted=lcd.RGB(144,165,178),warning=lcd.RGB(255,174,98)}
  heights={}
 end
 return colors
end
local function measure(s,font)
 if lcd.sizeText then
  local width,height=lcd.sizeText(s,font)
  if type(width)=='number'and type(height)=='number'then return width,height end
 end
 return #s*(font==MIDSIZE and 14 or font==TINSIZE and 6 or 8),font==MIDSIZE and 29 or font==TINSIZE and 13 or 17
end
local function fits(s,width,height,font)
 local tw,th=measure(s,font);return tw<=width and th<=height
end
local function fit(s,width,height,preferred)
 local font=preferred or SMLSIZE
 if fits(s,width,height,font)then return s,font end
 font=SMLSIZE;if fits(s,width,height,font)then return s,font end
 if TINSIZE then font=TINSIZE;if fits(s,width,height,font)then return s,font end end
 local _,th=measure('',font);if th>height or measure('...',font)>width then return '',font end
 while #s>0 and measure(s..'...',font)>width do s=string.sub(s,1,-2)end
 return s..'...',font
end
local function text(w,x,y,width,height,s,color,font)
 local z=w.zone
 width=math.min(width,z.w-x);height=math.min(height,z.h-y)
 if width<=0 or height<=0 then return end
 local shown,size=fit(s,width,height,font)
 if shown==''then return end
 local h=heights[size]
 if not h then local _,value=measure('Ag',size);h=value;heights[size]=h end
 lcd.setColor(CUSTOM_COLOR,color)
 lcd.drawText(z.x+x,z.y+y+math.floor((height-h)/2),shown,CUSTOM_COLOR+size)
end
local function valid(value)return type(value)=='number'and value==value and value~=math.huge and value~=-math.huge end
local function number(value,fmt,unit)
 if not valid(value)then return '--'end
 return string.format(fmt,value)..unit
end
local function drawCompact(w,d)
 local z=w.zone;local c=palette()
 lcd.setColor(CUSTOM_COLOR,c.bg);lcd.drawFilledRectangle(z.x,z.y,z.w,z.h,CUSTOM_COLOR)
 local layout=w.layout
 if not layout or layout.w~=z.w or layout.h~=z.h then
  local pad=z.w<150 and 4 or 8
  layout={w=z.w,h=z.h,pad=pad,half=math.floor(z.w/2),small=z.w<150 or z.h<70,wide=z.w>=230}
  w.layout=layout
 end
 local pad=layout.pad;local width=z.w-pad*2
 text(w,pad,3,width,18,'AERODECK',c.white,SMLSIZE)
 if d and d.initializing then
  text(w,pad,25,width,20,'STARTING AERODECK',c.muted,SMLSIZE)
  if z.h>=70 then text(w,pad,47,width,z.h-50,tostring(d.initializing),c.muted,TINSIZE or SMLSIZE)end
  return
 end
 if w.error or not d or d.sessionError then
  local problem=w.error or w.loading or(d and d.sessionError and 'SESSION UNAVAILABLE')or(w.app and'WAITING FOR DATA'or'UPDATE AERODECK')
  if w.recoveryMessage and z.h>=70 then
   text(w,pad,25,width,20,problem,c.warning,SMLSIZE)
   text(w,pad,47,width,z.h-50,w.recoveryMessage,c.warning,TINSIZE or SMLSIZE)
  else text(w,pad,25,width,z.h-28,problem,c.warning,SMLSIZE)end
  return
 end
 local voltageColor=valid(d.v)and(d.battery and c.warning or c.white)or c.muted
 local linkColor=valid(d.lq)and(d.link and c.warning or c.green)or c.muted
 if layout.small then
  text(w,pad,24,width,z.h-27,number(d.v,'%.1f',' V'),voltageColor,MIDSIZE)
  return
 end
 if layout.wide then
  local live=valid(d.v)or valid(d.a)or valid(d.lq)
  text(w,z.w-90,3,82,18,live and 'LIVE' or 'NO VALUES',live and((d.battery or d.link)and c.warning or c.green)or c.muted,TINSIZE or SMLSIZE)
 end
 local cellWidth=layout.half-pad-4
 text(w,pad,26,cellWidth,29,number(d.v,'%.1f',' V'),voltageColor,MIDSIZE)
 text(w,layout.half+4,26,z.w-layout.half-pad-4,29,number(d.lq,'%.0f','% LQ'),linkColor,MIDSIZE)
 if z.h>=95 then
  text(w,pad,57,cellWidth,18,number(d.a,'%.1f',' A'),c.muted,SMLSIZE)
  local pct=number(d.pct,'%.0f','% LEFT');if d.estimated and pct~='--'then pct='~'..pct end
  text(w,layout.half+4,57,z.w-layout.half-pad-4,18,pct,c.muted,SMLSIZE)
  text(w,pad,z.h-19,width,17,'FULL SCREEN: AERODECK',c.muted,TINSIZE or SMLSIZE)
 end
end
local function drawStartup(w,message)
 if startupScreen then startupScreen.draw(message,BUILD,w.error~=nil);return end
 -- Keep a dark, centered text fallback if the branding module is unavailable.
 local c=palette();local width,height=LCD_W or 480,LCD_H or 272
 lcd.setColor(CUSTOM_COLOR,c.bg);lcd.drawFilledRectangle(0,0,width,height,CUSTOM_COLOR)
 local function row(value,y,font)
  local tw=measure(value,font);lcd.setColor(CUSTOM_COLOR,w.error and c.warning or c.white)
  lcd.drawText(math.floor((width-tw)/2),y,value,CUSTOM_COLOR+font)
 end
 row('AERODECK',math.floor(height/2)-20,MIDSIZE);row(message,math.floor(height/2)+24,SMLSIZE)
end
local function refresh(w,event,touch)
 local focused=event~=nil
 local z=w.zone
 -- App mode owns the whole display before EdgeTX grants input focus. Size
 -- chooses presentation; event presence only chooses who owns key/touch input.
 local fullsize=z.x==0 and z.y==0 and z.w==LCD_W and z.h==LCD_H
 if focused or fullsize then
  w.fullStartup=true
  local app=bootstrap(w);w.view='full'
  if w.backgroundFailed then
   drawStartup(w,w.recoveryMessage or w.error or'SESSION ERROR')
   if event==EVT_VIRTUAL_EXIT then w.view='compact';if lcd.exitFullScreen then lcd.exitFullScreen()end end
   return
  end
  if app and type(app.run)=='function'then
   if app.run(event or 0,focused and touch or nil)==1 and focused then
    service(w,'compact')
    if lcd.exitFullScreen then lcd.exitFullScreen()end
   end
  else
   drawStartup(w,w.error or w.loading or'LOADING APP')
   if event==EVT_VIRTUAL_EXIT then w.view='compact';if lcd.exitFullScreen then lcd.exitFullScreen()end end
  end
  return
 end
 w.fullStartup=false;service(w,'compact');drawCompact(w,snapshot(w))
end
local function background(w)w.fullStartup=false;service(w,'hidden')end
return {name='AERODECK',options={},create=create,update=update,refresh=refresh,background=background}
