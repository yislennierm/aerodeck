-- Actual retained app startup and every real route. Harness-only retained flag
-- prevents the adapter's default synchronous init/prepaint from warming icons.
local candidate=arg[1]or'sdcard/SCRIPTS/TOOLS/telem.lua'
local realIO=io
local function read(path)local f=assert(realIO.open(path));local s=f:read('*a');f:close();return s end
local adapterSource=read('tests/test_ui_navigation.lua')
local old="local app=assert(loadstring(source,'@telem-under-test'))();app.init()"
local new="lcd.clear=function()end;local app=assert(loadstring(source,'@telem-under-test'))();app.setRetained(true);app.init()"
local a,b=assert(string.find(adapterSource,old,1,true));adapterSource=string.sub(adapterSource,1,a-1)..new..string.sub(adapterSource,b+1)
local open=realIO.open
local function adapter()
 io=realIO;realIO.open=function(path,...)return open(path=='sdcard/SCRIPTS/TOOLS/telem.lua'and candidate or path,...)end
 loadstring=loadstring or load;unpack=unpack or table.unpack
 local loaded=assert(loadstring(adapterSource,'@retained-cold-adapter'))('adapter');realIO.open=open
 return loaded
end
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function make(badAsset)
 local app=adapter().make({settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nmspMode=0\nvtxMode=0\n'})
 check(app.inputs.startup and app.inputs.startup.phase==3,'fixture starts before any normal render or icon prime')
 check(app.bitmapLoads()==0,'cold fixture has not prepainted or decoded an asset')
 local counts={};local opens=Bitmap.open;local patterns=lcd.drawBitmapPattern;local draws=0
 Bitmap.open=function(path)counts[path]=(counts[path]or 0)+1;if badAsset and string.find(path,badAsset,1,true)then return nil end;return opens(path)end
 lcd.drawBitmapPattern=function(...)draws=draws+1;return patterns(...)end
 return app,counts,function()return draws end
end
local function startup(app)
 local callbacks,iconCallbacks=0,0
 while app.inputs.startup do
  callbacks=callbacks+1;check(callbacks<200,'startup remains bounded')
  local phase=app.inputs.startup.phase;local before=app.bitmapLoads();app.background(4)
  local delta=app.bitmapLoads()-before
  check(delta>=0 and delta<=1,'startup callback opens at most one icon')
  if phase==14 then iconCallbacks=iconCallbacks+1 else check(delta==0,'only dedicated icon stage may perform icon I/O')end
 end
 app.background(4)
 check(app.snapshot()and not app.snapshot().initializing,'first real telemetry snapshot follows completed priming')
 return iconCallbacks
end
local originalGC=collectgarbage;local forced=0
collectgarbage=function(mode,...)if mode=='collect'then forced=forced+1 end;return originalGC(mode,...)end
local app,counts,draws=make()
check(startup(app)==20,'all twenty actual native icon variants use separate callbacks')
check(app.bitmapLoads()==20,'startup opens exactly seven navigation and thirteen detail masks')
check(counts['/SCRIPTS/TOOLS/AERODECK/icons/gpp_bad.png']==1,'the new native 30px ARM INFO mask is primed exactly once')
check(counts['/SCRIPTS/TOOLS/AERODECK/icons/speed.png']==nil,'retained speed 30px asset is not part of the active toolbar prime set')
local nativePrime=app.bitmapLoads()
for id=1,13 do app.arrange(id);check(app.bitmapLoads()==nativePrime,'first visit to route'..id..' has no cold icon decode')end
for i=1,150 do app.send(0)end
check(app.bitmapLoads()==nativePrime and draws()>0,'warm rendering uses retained masks without SD reads')
check(forced==0,'startup, route changes and warm draws never force a full GC')
for path,count in pairs(counts)do check(count==1,'one SD read per native variant: '..path)end
app.reinit();check(startup(app)==1 and app.bitmapLoads()==nativePrime,'same-resolution reload keeps complete positive caches')
-- Failed assets are primed once and remain geometry fallbacks, not repeated I/O.
local failed,failedCounts=make('battery_full-18.png');startup(failed)
local failedReads=0;for path,count in pairs(failedCounts)do if string.find(path,'battery_full-18.png',1,true)then failedReads=failedReads+count end end
check(failedReads==1,'missing asset is attempted exactly once during priming')
local afterFailure=failed.bitmapLoads();for id=1,13 do failed.arrange(id)end
check(failed.bitmapLoads()==afterFailure,'all routes retain negative cache results')
failed.reinit();check(startup(failed)==1,'same-resolution reload retains negative cache results')
-- Switch the actual display adapter. A new display object at the same logical
-- resolution is reusable; a changed physical asset namespace/size is not.
local nativeLoad=loadScript;local displayFactory=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/display.lua'))()
loadScript=function(path)if string.find(path,'/display.lua',1,true)then return function()return displayFactory end end;return nativeLoad(path)end
LCD_W=800;LCD_H=480;failed.reinit();startup(failed)
local scaled=0;for path,count in pairs(failedCounts)do if string.find(path,'/icons/800x480/',1,true)then scaled=scaled+1;check(count==1,'scaled path loads once')end end
check(scaled==20,'changed physical resolution cannot draw retained native-size masks')
check(failedCounts['/SCRIPTS/TOOLS/AERODECK/icons/800x480/gpp_bad.png']==1,'800x480 primes the native 50px ARM INFO mask')
check(failedCounts['/SCRIPTS/TOOLS/AERODECK/icons/800x480/speed.png']==nil,'800x480 retains speed without priming a retired toolbar mask')
LCD_W=480;LCD_H=272;loadScript=nativeLoad
collectgarbage=originalGC
print('PASS: '..checks..' actual retained cold-icon startup, bounded callbacks, cache lifetime, all routes, negative cache and display identity checks')
