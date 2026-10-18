-- DEVELOPMENT ONLY: synthetic environment; never copy this widget to a radio.
local CASE='animated'
local function create(zone,options)return{zone=zone,options=options,stage=1}end
local function fail(w,where,reason)
 w.error=where..': '..tostring(reason);print('QA_DEV_ERROR|'..w.error)
end
local function call(w,label,fn,...)
 local ok,a,b=pcall(fn,...)
 if not ok then fail(w,label,a);return nil,false end
 return a,true,b
end
local labels={'ENV LOAD','ENV CHUNK','ENV CREATE','STORE LOAD','STORE CHUNK','SETTINGS SEED','BATTERY SEED','MSP LOAD','MSP CHUNK','MSP CREATE','APP LOAD','APP CHUNK','APP INIT'}
local function advance(w)
 if w.error or not w.stage then return end
 local n=w.stage;w.label=labels[n]
 local a,ok,why
 if n==1 then a,ok=call(w,w.label,loadScript,'/SCRIPTS/TOOLS/QAENV.lua','t');if ok and type(a)=='function'then w.envLoader=a else if ok then fail(w,w.label,'NO LOADER')end;return end
 elseif n==2 then a,ok=call(w,w.label,w.envLoader);if ok and type(a)=='table'then w.builder=a;w.envLoader=nil else if ok then fail(w,w.label,'NO FACTORY')end;return end
 elseif n==3 then a,ok=call(w,w.label,w.builder.create,_G,CASE);if ok then w.env=a else return end
 elseif n==4 then a,ok=call(w,w.label,w.env.loadScript,'/SCRIPTS/TOOLS/AERODECK/model-store.lua','t');if ok then w.storeLoader=a else return end
 elseif n==5 then a,ok=call(w,w.label,w.storeLoader);if ok then w.store=a.new({remove=del,rename=rename});w.storeLoader=nil else return end
 elseif n==6 then a,ok,why=call(w,w.label,w.builder.seedSettings,w.store,w.env);if not ok then return elseif a~=true then fail(w,w.label,why);return end
 elseif n==7 then a,ok,why=call(w,w.label,w.builder.seedBattery,w.store,w.env);if not ok then return elseif a~=true then fail(w,w.label,why);return end
 elseif n==8 then a,ok=call(w,w.label,w.env.loadScript,'/SCRIPTS/TOOLS/QAMSP.lua','t');if ok then w.mspLoader=a else return end
 elseif n==9 then a,ok=call(w,w.label,w.mspLoader);if ok then w.mspFactory=a;w.mspLoader=nil else return end
 elseif n==10 then a,ok=call(w,w.label,w.builder.installMSP,w.env,w.mspFactory);if not ok then return end;w.builder=nil;w.store=nil;w.mspFactory=nil
 elseif n==11 then a,ok=call(w,w.label,w.env.loadScript,'/SCRIPTS/TOOLS/telem.lua','t');if ok and type(a)=='function'then w.appLoader=a else if ok then fail(w,w.label,'NO LOADER')end;return end
 elseif n==12 then a,ok=call(w,w.label,w.appLoader);if ok and type(a)=='table'then w.app=a;w.appLoader=nil else if ok then fail(w,w.label,'NO APP')end;return end
 elseif n==13 then
  if type(w.app.setRetained)=='function'then w.app.setRetained(true)end
  a,ok=call(w,w.label,w.app.init);if not ok then return end
 end
 print('QA_DEV_STAGE|'..CASE..'|'..tostring(n)..'|'..w.label..'|'..tostring(getUsage and getUsage()or'UNAVAILABLE'))
 w.stage=n<13 and n+1 or nil
end
local function service(w)
 if w.error then return end
 if w.stage then advance(w);return end
 w.env.qaTick()
 local _,ok=call(w,'BACKGROUND',w.app.background);if not ok then return end
 local data,ready=call(w,'SNAPSHOT',w.app.snapshot);if not ready then return end
 if data~=nil and type(data)~='table'then fail(w,'SNAPSHOT','INVALID SHAPE');return end
 w.data=data
end
local function draw(w)
 local z=w.zone
 lcd.setColor(CUSTOM_COLOR,lcd.RGB(7,15,22));lcd.drawFilledRectangle(z.x,z.y,z.w,z.h,CUSTOM_COLOR)
 lcd.setColor(CUSTOM_COLOR,lcd.RGB(235,243,245))
 local title='QA SYNTHETIC / '..CASE
 lcd.drawText(z.x+8,z.y+4,title,CUSTOM_COLOR+SMLSIZE)
 local d=w.data;local status=w.error or(w.stage and('WAIT '..tostring(w.stage)..' / '..(w.label or labels[w.stage])))or(d and d.initializing and('STARTING '..tostring(d.initializing)))or(d and'FIXTURE READY'or'WAITING FOR DATA')
 lcd.drawText(z.x+8,z.y+27,status,CUSTOM_COLOR+SMLSIZE)
 if d and not d.initializing and not w.error then
  lcd.drawText(z.x+8,z.y+51,string.format('V %s / A %s / LQ %s',tostring(d.v),tostring(d.a),tostring(d.lq)),CUSTOM_COLOR+SMLSIZE)
  lcd.drawText(z.x+8,z.y+73,'FULL SCREEN: PRODUCTION APP',CUSTOM_COLOR+SMLSIZE)
 end
end
local function refresh(w,event,touch)
 if w.stage or not w.app or w.error then
  if w.stage then advance(w)end;draw(w)
  if event==EVT_VIRTUAL_EXIT and lcd.exitFullScreen then lcd.exitFullScreen()end
 elseif event~=nil then
  w.env.qaTick()
  local q0=getUsage();local result,ok=call(w,'RUN',w.app.run,event or 0,touch);w.benchN=(w.benchN or 0)+1;if w.benchN%30==0 then print('BENCH_AERO_FRAME|'..w.benchN..'|'..getTime()..'|'..q0..'|'..getUsage()..'|'..collectgarbage('count'))end
  if ok and result==1 then if lcd.exitFullScreen then lcd.exitFullScreen()end end
 else service(w);draw(w)end
end
local function update(w,options)w.options=options end
local function background(w)service(w)end
return{name='AERODECK',options={},create=create,update=update,refresh=refresh,background=background}
