-- toolName = TNS|AERODECK|TNE
-- AERODECK: integrated 480x272 TX16S cockpit and telemetry console.
-- Live telemetry only across flight, telemetry, power, link and GPS.
-- Shared current telemetry with bounded MSP/CRSF/S.Port and explicit VTX transactions.
-- Six stable icon sections. SYS/MDL focuses the bar; PAGE cycles sections; RTN backs out.
-- Config: 12 conditional lists; verified application settings saved per model.
-- Rotary focuses visible controls; ENTER activates. Settings Save/Revert work without touch.
-- Telemetry refresh never substitutes synthetic data.
-- Live attitude comes from current mapped sensors. Home returns Flight; unsaved exit is explicit.
local nativeLcd=lcd
local lcd=nativeLcd
local display,displayError
local BUILD_ID='GPS-TRACK-20261018'
local uiTheme
local alertsMuted=false
local alertPlayback={queue=function(event)
 if alertsMuted then return end
 for i,t in ipairs(event.tones or{})do if i>4 then break end;if playTone then playTone(t.frequency,t.durationMs,t.pauseMs,t.flags or 0)end end
 for i,h in ipairs(event.haptics or{})do if i>2 then break end;if playHaptic then playHaptic(h.nativeDuration,h.nativePause,h.interrupt and(PLAY_NOW or 0)or 0)end end
end}
local renderStats={fps=0,attitudeHz=0,drawMs=0,frames=0,changes=0,window=0,cost=0,background='NOT LOADED'}
-- Toolbox's qualified telemetry-source binding avoids collisions with named inputs.
local fieldCache,telemetryFields={},{}
local receivedSources,bindingRevision={},0
local nativeFmRevision,fmGuardName=0,nil
local missingSources,missingIndex,lastSourceRetry={},1,0
local function cachedField(name)
 local f=fieldCache[name]
 if f==nil then f=getFieldInfo(name) or false;fieldCache[name]=f end
 return f or nil
end
local function findTelemetryField(name)
 if getSourceIndex and CHAR_TELEMETRY then
  local id=getSourceIndex(CHAR_TELEMETRY..name)
  if type(id)=='number' and id>0 then
   -- EdgeTX2.12.4 numeric getFieldInfo includes the telemetry unit. Read once per bind.
   local info=getFieldInfo(id)
   return {id=id,unit=info and info.unit}
  end
  return false
 end
 return getFieldInfo(name) or false
end
local function cachedTelemetryField(name)
 local f=telemetryFields[name]
 if f==nil then
  f=findTelemetryField(name);telemetryFields[name]=f;if f then bindingRevision=bindingRevision+1;if name=='FM'or name==fmGuardName then nativeFmRevision=nativeFmRevision+1 end end
  if not f then missingSources[#missingSources+1]=name end
 end
 return f or nil
end
local function retryMissingSources()
 if #missingSources==0 then return end
 local now=getTime()
 if now>=lastSourceRetry and now-lastSourceRetry<50 then return end
 lastSourceRetry=now
 local name=missingSources[missingIndex];local f=findTelemetryField(name)
 if f then
  telemetryFields[name]=f;bindingRevision=bindingRevision+1;if name=='FM'or name==fmGuardName then nativeFmRevision=nativeFmRevision+1 end;table.remove(missingSources,missingIndex)
 else missingIndex=missingIndex+1 end
 if missingIndex>#missingSources then missingIndex=1 end
end
local function refreshSources()
 fieldCache={};telemetryFields={};receivedSources={};bindingRevision=bindingRevision+1;nativeFmRevision=nativeFmRevision+1;missingSources={};missingIndex=1;lastSourceRetry=getTime()
end
local modelStore
local function getModelStore()
 if modelStore==nil then
  local chunk=loadScript and loadScript('/SCRIPTS/TOOLS/AERODECK/model-store.lua');local factory=chunk and chunk()
  modelStore=factory and factory.new({remove=del,rename=rename})or false
 end
 return modelStore or nil
end
local batteryConfig=(function()
 local defaults={0,27,30,34,36,42,0,0}
 local revision=0
 local storeInfo,storageMeta,usingStore
 local active,draft,path,message,selected,editing,lastAlert={}, {},nil,'',1,false,-10000
 local editValue
 local labels={'Pack cell count','Cell no-power voltage','Cell minimum voltage','Cell critical voltage','Cell low voltage','Cell maximum voltage','Cell alerts type','Audible alerts'}
 local types={'Visual only','Visual + Sound','Visual + Haptic','Visual + Both'}
 local function copy(a) local b={} for i,v in ipairs(a) do b[i]=v end return b end
 local function valid(a)
  if #a~=8 then return false end
  for i,v in ipairs(a) do if type(v)~='number' or v%1~=0.0 then return false end end
  return a[1]>=0 and a[1]<=12 and a[2]>=20 and a[6]<=46 and a[2]<a[3] and a[3]<a[4] and a[4]<a[5] and a[5]<a[6] and a[7]>=0 and a[7]<=3 and a[8]>=0 and a[8]<=1
 end
 local function encode(a) return 'ADBAT1 '..table.concat(a,',')..'\n' end
 local function decode(s)
  if not s or string.sub(s,1,7)~='ADBAT1 'then return nil end
  local a={};for v in string.gmatch(string.sub(s,8),'[^,\r\n]+')do a[#a+1]=tonumber(v)or -999 end
  if valid(a)then return a end
 end
 local function read(p)
  local f=io.open(p,'r');if not f then return nil end
  local raw=io.read(f,256);io.close(f);return decode(raw)
 end
 local function write(p,a)
  local f=io.open(p,'w');if not f then return false end
  io.write(f,encode(a));io.close(f)
  local b=read(p);return b and encode(b)==encode(a)
 end
 local function init()
  storeInfo=model.getInfo();usingStore=type(storeInfo.filename)=='string'and storeInfo.filename~=''
  local name=storeInfo.name or 'model';local key=''
  for i=1,#name do key=key..string.format('%02x',string.byte(name,i)) end
  path='/SCRIPTS/TOOLS/AERODECK/battery-'..key..'.cfg'
  revision=revision+1
  if usingStore then local store=getModelStore();if store then active,storageMeta=store.read('battery',storeInfo,decode,defaults)else active=copy(defaults);storageMeta={state='MODULE UNAVAILABLE'}end
  else active=read(path)or read(path..'.bak')or copy(defaults);storageMeta={state='LEGACY / NO FILENAME API'}end
  draft=copy(active);message='SAVE BATTERY applies only battery thresholds';selected=1;editing=false;editValue=nil
 end
 local function save()
  if not valid(draft) then message='Require: no power < min < critical < low < max';return false end
  local ok
  if usingStore then local store=getModelStore();ok=store and store.save('battery',storeInfo,encode(draft),decode)
  else ok=write(path..'.bak',active)and write(path,draft)end
  if not ok then message='SAVE FAILED - previous settings retained';return false end
  active=copy(draft);revision=revision+1;message='SAVED for this model';return true
 end
 local function importLegacy()
  local store=getModelStore();if not store then return false,'MODEL STORE UNAVAILABLE'end
  local data,meta=store.importLegacy('battery',storeInfo,decode)
  if not data then message='BATTERY IMPORT FAILED';return false,meta and meta.error or'IMPORT FAILED'end
  active=data;draft=copy(active);storageMeta=meta;revision=revision+1;editing=false;selected=1;message='LEGACY BATTERY IMPORTED';return true
 end
 local function adjust(delta)
  local lo=selected==1 and 0 or selected<=6 and 20 or 0
  local hi=selected==1 and 12 or selected<=6 and 46 or selected==7 and 3 or 1
  if selected>=2 and selected<=6 then lo=20+(selected-2);hi=46-(6-selected)end
  draft[selected]=math.max(lo,math.min(hi,draft[selected]+delta))
  if selected>=2 and selected<=6 then
   for i=selected-1,2,-1 do if draft[i]>=draft[i+1]then draft[i]=draft[i+1]-1 end end
   for i=selected+1,6 do if draft[i]<=draft[i-1]then draft[i]=draft[i-1]+1 end end
  end
  message='Unsaved changes - SAVE to apply'
 end
 local function hasChanges()
  for i,v in ipairs(active)do if draft[i]~=v then return true end end;return false
 end
 local function finishEdit()editing=false;editValue=nil end
 local function beginEdit()
  if selected>8 then return false end
  if not editing then editValue=copy(draft);editing=true end;return true
 end
 local function revert()
  draft=copy(active);finishEdit();message='Battery draft discarded'
 end
 local function back()
  if not editing then return false end
  draft=editValue;finishEdit();message='Value edit cancelled';return true
 end
 local function activate()
  if selected<=8 then if editing then finishEdit() else beginEdit()end
  elseif selected==9 then finishEdit();save()
  else revert()end
 end
 local function input(event,touch)
  if event==EVT_VIRTUAL_ENTER then activate();return true
  elseif (EVT_VIRTUAL_NEXT and event==EVT_VIRTUAL_NEXT) or (EVT_VIRTUAL_PREV and event==EVT_VIRTUAL_PREV) then
   local delta=event==EVT_VIRTUAL_NEXT and 1 or -1
   if editing then adjust(delta)else selected=(selected-1+delta)%10+1 end;return true
  elseif event==EVT_TOUCH_TAP and touch then
   if touch.y>=64 and touch.y<216 then
    finishEdit();selected=math.floor((touch.y-64)/19)+1;beginEdit();return true
   elseif touch.y>=222 and touch.y<245 then
    if touch.x>=10 and touch.x<84 then if beginEdit()then adjust(-1)end
    elseif touch.x>=88 and touch.x<162 then if beginEdit()then adjust(1)end
    elseif touch.x>=172 and touch.x<312 then finishEdit();selected=9;save()
    elseif touch.x>=320 and touch.x<470 then selected=10;revert()
    else return false end;return true
   end
  end
  return false
 end
 local function draw()
  local c=uiTheme or {bg=lcd.RGB(7,15,22),panel=lcd.RGB(18,32,42),muted=lcd.RGB(144,165,178),white=lcd.RGB(235,243,245),green=lcd.RGB(164,227,125),orange=lcd.RGB(255,174,98)}
  local function box(x,y,w,h,col)lcd.setColor(CUSTOM_COLOR,col);lcd.drawFilledRectangle(x,y,w,h,CUSTOM_COLOR)end
  local fontHeight=17
  if lcd.sizeText then local _,h=lcd.sizeText('Ag',SMLSIZE);if type(h)=='number'and h>0 then fontHeight=h end end
  local function text(x,y,s,col,right,height)
   if height then y=y+math.floor((height-fontHeight)/2)end
   lcd.setColor(CUSTOM_COLOR,col);lcd.drawText(x,y,s,CUSTOM_COLOR+SMLSIZE+(right and RIGHT or 0))
  end
  box(5,62,470,181,c.bg)
  for i,label in ipairs(labels)do
   local y=64+(i-1)*19;local chosen=i==selected
   box(10,y,460,18,chosen and c.green or c.panel);local col=chosen and c.bg or c.white
   text(17,y,label,col,false,18)
   local v=i==1 and (draft[i]==0 and 'Not set' or draft[i]..'S') or i<=6 and string.format('%.1f V',draft[i]/10) or i==7 and types[draft[i]+1] or (draft[i]==0 and 'Critical only' or 'Critical + Low')
   text(459,y,(editing and chosen and '< '..v..' >' or v),col,true,18)
  end
  for _,v in ipairs({{10,74,'-',nil},{88,74,'+',nil},{172,140,'SAVE BATTERY',9},{320,150,'REVERT BATTERY',10}})do
   local chosen=v[4]==selected;box(v[1],222,v[2],21,chosen and c.green or c.panel)
   text(v[1]+10,222,v[3],chosen and c.bg or v[4] and c.green or selected<=8 and c.white or c.muted,false,21)
  end
 end
 local function check(volts,demo,override)
  local cells=demo and 4 or override or active[1]
  if not volts or cells==0 then return nil,cells end
  -- Quantize to 0.1 mV per cell before comparing saved 0.1 V boundaries.
  -- Native float32 roundoff must not flag an exact full pack as over-voltage.
  local v=math.floor(volts/cells*10000+0.5)/1000
  local status=v<=active[2] and 'NO PACK POWER' or v<active[3] and 'BELOW MINIMUM' or v<=active[4] and 'BATTERY CRITICAL' or v<=active[5] and 'BATTERY LOW' or v>active[6] and 'ABOVE MAXIMUM' or nil
  local warn=v>active[2] and (v<=active[4] or active[8]==1 and v<=active[5])
  if not demo and not alertsMuted and warn and active[7]>0 and getTime()-lastAlert>=1000 then
   lastAlert=getTime()
   if active[7]==1 or active[7]==3 then playTone(1500,150,0,0) end
   if active[7]==2 or active[7]==3 then playHaptic(15,0,0) end
  end
  return status,cells
 end
 return {storage=function()return storageMeta end,importLegacy=importLegacy,values=function()return active end,revision=function()return revision end,message=function()return message end,init=init,input=input,draw=draw,check=check,save=save,back=back,revert=revert,hasChanges=hasChanges,isEditing=function()return editing end,open=function()finishEdit();selected=1 end}
end)()


-- One dispatcher owns the FC exchange and native video queue.
-- Its uplink requests also let ELRS provide reply bandwidth; attitude remains
-- real, current EdgeTX telemetry. Never request data while armed/unknown/offline.
local fcLink={native=false,state={status='NOT LOADED'}}
function fcLink.init()
 if fcLink.service then fcLink.service:stop()end
 local chunk=loadScript and loadScript('/SCRIPTS/TOOLS/AERODECK/link.lua');local f=chunk and chunk()
 fcLink.service=f and f.new({load=loadScript,crsfPush=crossfireTelemetryPush,crsfPop=crossfireTelemetryPop,sportPush=sportTelemetryPush,sportPop=sportTelemetryPop})or nil
 fcLink.configRevision=nil;fcLink.settings={}
 fcLink.state=fcLink.service and fcLink.service.state or{status='LINK MODULE UNAVAILABLE'}
 fcLink.telemetrySwitch=getSwitchIndex and getSwitchIndex('Tele')or nil
 fcLink.nativeRevision=nil;fcLink.guardSource=nil;fcLink.nativeGuard={}
end
function fcLink.qualifyNative()
 fcLink.native=false
 for i=0,63 do local sensor=model.getSensor(i);if sensor and sensor.type==0 and sensor.id==0x21 then fcLink.native=true end end
 fcLink.nativeRevision=nativeFmRevision;fcLink.guardSource=fmGuardName
end
function fcLink.stop()if fcLink.service then fcLink.service:stop()end end
function fcLink.videoClient()return fcLink.service and fcLink.service:videoClient()end
function fcLink.videoState()return fcLink.service and fcLink.service:videoState()or{}end
local inputRuntime={}
local configuration=(function()
 local active,draft,path={}, {},nil
 local storeInfo,storageMeta,usingStore
 local section,selected,offset,editing=1,1,0,false
 local inList,listSelected,listOffset,editValue=true,1,0,nil
 local message='Changes apply after SAVE'
 local sensors={'Auto','None'}
 local schema,sections={},{}
 local revision=0
 local function item(key,label,default,lo,hi,step,choices)
  -- A setting has one owner even when it appears in multiple views.
  if schema[key] then return schema[key] end
  local s={key=key,label=label,default=default,lo=lo,hi=hi,step=step or 1,choices=choices};schema[key]=s;return s
 end
 local function note(label,value)return {label=label,note=value}end
 local function sensor(key,label)local field=item(key,label,'Auto',nil,nil,nil,sensors);field.sensor=true;return field end
 sections[1]={name='MODEL SETUP',rows={
  item('rcProtocol','RC protocol profile','Auto',nil,nil,nil,{'Auto','ELRS / CRSF','TBS Crossfire','TBS Tracer','FrSky','Other','Off'}),item('fcType','Flight controller','Auto',nil,nil,nil,{'Auto','Betaflight','INAV','Other','Off'}),item('vtxMode','VTX application',0,0,2,1,{'Off','Video controls','Video + favourites'}),
  sensor('voltage','Battery voltage'),sensor('current','Battery current'),sensor('consumed','Consumed capacity'),sensor('remaining','Battery remaining'),sensor('gps','GPS position'),sensor('speed','Ground speed'),sensor('altitude','GPS altitude'),sensor('heading','Native Hdg source'),sensor('course','GPS ground course'),sensor('yaw','Body yaw source'),sensor('pitch','Pitch'),sensor('roll','Roll'),sensor('flightmode','Flight mode source'),item('batteryEnabled','Battery voltage provider',1,0,1,1,{'Off','On'}),item('currentEnabled','Current / capacity provider',1,0,1,1,{'Off','On'}),item('gyroEnabled','Attitude provider',1,0,1,1,{'Off','On'}),item('gpsEnabled','GPS provider',1,0,1,1,{'Off','On'}),item('baroEnabled','Barometer provider',1,0,1,1,{'Off','On'}),item('pitotEnabled','Airspeed provider',1,0,1,1,{'Off','On'}),sensor('baro','Barometric altitude'),sensor('airspeed','Airspeed')}}
 sections[2]={name='RC LINK',rows={
  sensor('rssi','Signal strength source'),sensor('lq','Link quality source (%)'),sensor('snr','SNR source (dB)'),item('rssiLow','RSSI low',-95,-130,100),item('rssiCrit','RSSI critical',-105,-130,100),item('lqLow','LQ low (%)',80,1,100),item('lqCrit','LQ critical (%)',60,0,99),item('snrLow','SNR low (dB)',0,-30,50),item('snrCrit','SNR critical (dB)',-5,-30,50),item('rcSubtype','Protocol subtype','Auto',nil,nil,nil,{'Auto','ELRS 2.x','ELRS 3.x','ELRS Gemini','Crossfire','Tracer','ACCST','R9'}),item('thresholdMode','Link warning thresholds','Profile defaults',nil,nil,nil,{'Custom','Profile defaults'})}}
 sections[3]={name='MODEL BATTERY',rows={}}
 sections[4]={name='BATTERY FAVOURITES',rows={item('pack','Active profile',0,0,5,1,{'Manual / Auto cells','Pack 1','Pack 2','Pack 3','Pack 4','Pack 5'})}}
 for i=1,5 do
  local r=sections[4].rows;r[#r+1]=item('chemistry'..i,'Pack '..i..' chemistry',1,0,2,1,{'Off','LiPo','Li-ion'});r[#r+1]=item('cells'..i,'Pack '..i..' cells',4,1,99);r[#r+1]=item('capacity'..i,'Pack '..i..' capacity (mAh)',1500,100,100000,50)
 end
 sections[5]={name='FLIGHT CONTROLLER',rows={item('mspMode','FC telemetry connection',1,0,1,1,{'Off','Auto / protocol'}),item('statusInterval','FC status interval (s)',3,0,30),note('MSP connection','--'),note('Detected firmware','--'),note('Control writes','Explicit VTX apply only')}}
 local function binding(role,label,default)
  local field=item(role..'Binding',label,default or'NATIVE');field.binding=role;return field
 end
 -- Keep legacy fields readable for a one-time in-memory migration; new bindings
 -- persist stable identities and never persist source IDs or inventory positions.
 item('armSource','Legacy arm source','None');item('armPosition','Legacy arm position',1,-1,1)
 item('cutSource','Legacy cut source','None');item('cutPosition','Legacy cut position',1,-1,1)
 sections[6]={name='INDICATORS / TIMERS',rows={binding('arm','Radio arm indication'),binding('cut','Throttle cut indication','OFF'),binding('throttle','Physical throttle','SRC:thr'),binding('limiter','Throttle limiter','OFF'),
  {label='Radio arm / cut',note='--',live='inputs'},item('timerHost','Model timer host','RADIO',nil,nil,nil,{'RADIO','AERODECK'}),item('timerIndex','Model timer',0,0,3,1,{'App elapsed','Timer 1','Timer 2','Timer 3'}),item('resetModelTimer','Radio new-flight timer reset',0,0,1,1,{'No','Selected timer'}),item('resetNativeTelemetry','New flight clears radio stats',1,0,1,1,{'No','Yes'})}}
 sections[7]={name='FC MODE INDICATORS',rows={sensor('flightmode','Flight mode source'),{label='Reported FC mode',note='--',live='flight'},binding('acro','Acro indication'),binding('angle','Angle indication'),binding('horizon','Horizon indication'),binding('air','Airmode indication'),binding('turtle','Turtle indication'),binding('rth','Return to home indication'),binding('wrth','Waypoint RTH indication')}}
 sections[8]={name='VTX',rows={item('vtxBackend','Video connection','FC MSP',nil,nil,nil,{'FC MSP','TBS native'}),item('vtxHardware','TBS native hardware',0,0,8,1,{'Unknown / select','Sixty9','Uni Pro32 HV','Uni Pro32 Nano','Uni EVO','Uni Pro','Uni Pro HV','Uni Pro HV Race','Uni Pro Nano'}),item('vtxCache','FC table cache',0,0,1,1,{'Off','On'}),item('vtxPolling','Status read interval (s)',5,0,60),note('VTX connection','Betaflight / FC MSP'),note('Channel / power / PIT','Apply then verify on Video'),note('Radio / FC settings','No other writes')}}
 sections[9]={name='VTX FAVOURITES',rows={note('Purpose','Select, review, then Apply')}}
 for i=1,8 do sections[9].rows[#sections[9].rows+1]=item('vtx'..i,'Favourite '..i..' frequency (MHz)',({5865,5732,5800,5806,5917,5880,5790,5740})[i],0,65535) end
 sections[10]={name='GPS',rows={item('autoHome','Automatic home capture',0,0,2,1,{'Off','First valid position','On arm / valid GPS'}),item('homeSats','Minimum sats for auto home',8,1,64),item('trail','Track samples retained',90,10,180,10),item('zoom','Default track zoom',2,1,3,1,{'Wide','Medium','Close'}),note('Home reference','Local to AERODECK'),note('3D fix / constellation','Not provided by reader')}}
 sections[11]={name='USER INTERFACE',rows={item('theme','Display palette',0,0,3,1,{'Dark','Daylight','Night','High contrast'}),item('accent','Highlight colour',1,1,3,1,{'Green','Cyan','Amber'}),item('compassSource','Flight compass reference',0,0,1,1,{'GPS course','Body yaw'}),item('attitudeOverlay','Attitude markings',1,0,1,1,{'Minimal','Graduated'}),item('rollDisplay','Roll display direction',0,0,1,1,{'Normal','Reversed'}),item('flightBank','Default Flight centre panel',0,0,2,1,{'Attitude','Video dashboard','Navigation'}),item('modelImage','Model image on System page',0,0,1,1,{'Off','On'}),item('renderHz','Tool redraw target (Hz)',25,5,30),item('startPage','Opening page',1,1,8,1,{'Flight','Telemetry','GPS track','GPS details','Power','Sensors','Stick guide','Setup'})}}
 sections[12]={name='APPLICATION',rows={note('Telemetry source','Live sensors only'),note('Settings scope','Per model file / verified owner'),note('Saving','Verified SD file + backup'),note('Sound / haptic scope','While app session runs'),note('FC configuration writes','Explicit VTX apply only'),note('Settings reload','Reopen AERODECK')}}
 sections[12].rows[#sections[12].rows+1]=sections[5].rows[1]
 sections[12].rows[#sections[12].rows+1]=item('errorLog','Error log',0,0,1,1,{'Off','On / explicit Save Log'})
 sections[12].rows[#sections[12].rows+1]={label='IMPORT LEGACY APP SETTINGS',action='importSettings'}
 sections[12].rows[#sections[12].rows+1]={label='IMPORT LEGACY BATTERY',action='importBattery'}
 -- Preserve every saved value while omitting controls irrelevant to the draft.
 local baseRows,rowCache={},{}
 local function rowsFor(id)
  if rowCache[id]then return rowCache[id]end
  local rows={};local t=draft
  for _,row in ipairs(baseRows[id])do
   local show=true;local key=row.key
   if id==12 and row.action then
    local meta=row.action=='importSettings'and storageMeta or batteryConfig.storage()
    show=meta and meta.state=='IMPORT AVAILABLE'
   elseif id==4 and key then
    local pack=string.match(key,'^cells(%d)$')or string.match(key,'^capacity(%d)$')
    if pack and t['chemistry'..pack]==0 then show=false end
   elseif id==8 then
    if key=='vtxHardware'and t.vtxBackend~='TBS native'then show=false end
    if(key=='vtxCache'or key=='vtxPolling')and t.vtxBackend=='TBS native'then show=false end
   elseif id==2 and key then
    if t.rcProtocol=='FrSky'and(key=='lq'or key=='snr'or string.match(key,'^lq')or string.match(key,'^snr'))then show=false end
    if t.thresholdMode=='Profile defaults'and(key=='rssiLow'or key=='rssiCrit'or key=='lqLow'or key=='lqCrit')then show=false end
   end
   if show then rows[#rows+1]=row end
  end
  rowCache[id]=rows;return rows
 end
 for i,part in ipairs(sections)do local id=i;baseRows[id]=part.rows;part.rows=nil;setmetatable(part,{__index=function(_,key)if key=='rows'then return rowsFor(id)end end})end
 local function refreshRows(key)
  rowCache={}
  if key then for i,row in ipairs(rowsFor(section))do if row.key==key then selected=i;offset=math.floor((i-1)/7)*7;return end end end
  selected=1;offset=0
 end
 local function visible(t)
  local list={1}
  if t.rcProtocol~='None'and t.rcProtocol~='Other'and t.rcProtocol~='Off'then
   list[#list+1]=2
   if t.batteryEnabled==1 and t.voltage~='None'then list[#list+1]=3;list[#list+1]=4 end
   if t.fcType~='None'and t.fcType~='Other'and t.fcType~='Off'then list[#list+1]=5 end
  end
  list[#list+1]=6
  if t.rcProtocol~='None'and t.rcProtocol~='Other'and t.rcProtocol~='Off'then
   if t.fcType=='Betaflight'or t.fcType=='INAV'or t.fcType=='Auto'then list[#list+1]=7 end
   if t.vtxMode>0 then list[#list+1]=8 end
   if t.vtxMode==2 then list[#list+1]=9 end
   if t.gpsEnabled==1 and t.gps~='None'then list[#list+1]=10 end
  end
  list[#list+1]=11;list[#list+1]=12
  return list
 end
 local function copy(t)local c={} for k,v in pairs(t)do c[k]=v end return c end
 local function encode(t)
  local keys={} for k in pairs(schema)do keys[#keys+1]=k end;table.sort(keys)
  local s='ADCFG1\n';for _,k in ipairs(keys)do s=s..k..'='..tostring(t[k])..'\n' end;return s
 end
 local function validBinding(value)
  if value=='OFF'or value=='NATIVE'then return true end
  if string.match(value,'^SW:.+')then return true end
  local logical=string.match(value,'^LS:!?L(%d%d)$');if logical then return tonumber(logical)>=1 and tonumber(logical)<=64 end
  if string.match(value,'^SRC!?:[%w_%-]+$')then return true end
  local field,predicate=string.match(value,'^PRED:([%w_%-]+):([A-Z_]+)$')
  return field~=nil and(predicate=='LOW'or predicate=='MID'or predicate=='HIGH'or predicate=='NOT_LOW'or predicate=='NOT_MID'or predicate=='NOT_HIGH')
 end
 local function valid(t)
  for k,s in pairs(schema)do
   local v=t[k]
   if type(s.default)=='number' then if type(v)~='number' or v%1~=0.0 or v<s.lo or v>s.hi then return false,'Invalid '..s.label end
   elseif type(v)~='string'or #v>64 or string.find(v,'[=%c]')then return false,'Invalid source name'
   elseif s.binding and not validBinding(v)then return false,'Invalid '..s.label
   elseif not s.binding and not s.sensor and s.choices then local found=false;for _,choice in ipairs(s.choices)do if v==choice then found=true;break end end;if not found then return false,'Invalid '..s.label end end
  end
  if t.rssiCrit>=t.rssiLow or t.lqCrit>=t.lqLow or t.snrCrit>=t.snrLow then return false,'Link critical must be below low' end
  return true
 end
 local function decode(s)
  if not s or string.sub(s,1,7)~='ADCFG1\n' then return nil end
  local t,seen={},{};for k,d in pairs(schema)do t[k]=d.default end
  for k,v in string.gmatch(s,'([%w]+)=([^\r\n]*)')do if schema[k]then seen[k]=true;t[k]=type(schema[k].default)=='number'and tonumber(v)or v end end
  for _,role in ipairs({'arm','cut'})do
   if not seen[role..'Binding']and t[role..'Source']~='None'then
    local source=t[role..'Source'];local pos=t[role..'Position'];local logical=string.match(source,'^L(%d%d)$')
    if logical and pos~=0 then t[role..'Binding']='LS:'..(pos<0 and'!'or'')..source
    else t[role..'Binding']='PRED:'..string.lower(source)..':'..(pos<0 and'LOW'or pos>0 and'HIGH'or'MID')end
   end
  end
  if not seen.thresholdMode and(seen.rssiLow or seen.rssiCrit or seen.lqLow or seen.lqCrit)then t.thresholdMode='Custom'end
  if t.rcProtocol=='None'then t.rcProtocol='Auto'end;if t.fcType=='None'then t.fcType='Auto'end
  if valid(t)then return t end
 end
 local function read(p)
  local f=io.open(p,'r');if not f then return nil end
  local raw=io.read(f,8192);io.close(f);return decode(raw)
 end
 local function write(p,t)
  local f=io.open(p,'w');if not f then return false end
  io.write(f,encode(t));io.close(f);local r=read(p);return r and encode(r)==encode(t)
 end
 local function refreshSensorChoices(names)
  sensors={'Auto','None'}
  for _,name in ipairs(names)do sensors[#sensors+1]=name end
  for _,s in pairs(schema)do if s.sensor then s.choices=sensors end end
 end
 local function init()
  revision=revision+1
  local names={}
  for i=0,63 do local s=model.getSensor(i);if s and s.name and s.name~='' then names[#names+1]=s.name end end
  refreshSensorChoices(names)
  storeInfo=model.getInfo();usingStore=type(storeInfo.filename)=='string'and storeInfo.filename~=''
  local name=storeInfo.name or 'model';local key=''
  for i=1,#name do key=key..string.format('%02x',string.byte(name,i))end
  path='/SCRIPTS/TOOLS/AERODECK/settings-'..key..'.cfg'
  local defaults={};for k,s in pairs(schema)do defaults[k]=s.default end
  if usingStore then local store=getModelStore();if store then active,storageMeta=store.read('settings',storeInfo,decode,defaults)else active=defaults;storageMeta={state='MODULE UNAVAILABLE'}end
  else active=read(path)or read(path..'.bak')or defaults;storageMeta={state='LEGACY / NO FILENAME API'}end
  draft=copy(active);rowCache={};section=1;selected=1;offset=0;editing=false;editValue=nil;inList=true;listSelected=1;listOffset=0;message='Select a category; changes require explicit Save'
 end
 local function save()
  local ok,why=valid(draft);if not ok then message=why;return false end
  if usingStore then local store=getModelStore();ok=store and store.save('settings',storeInfo,encode(draft),decode)else ok=write(path..'.bak',active)and write(path,draft)end
  if not ok then message='SAVE FAILED - active settings unchanged';return false end
  active=copy(draft);revision=revision+1;message='SAVED - startup options apply on reopen';return true
 end
 local function hasChanges()
  for k,v in pairs(active)do if draft[k]~=v then return true end end;return false
 end
 local function performAction(row)
  if not row or not row.action then return false end
  if hasChanges()or batteryConfig.hasChanges()then message='Save or revert drafts before import';return true end
  if row.action=='importBattery'then local ok,why=batteryConfig.importLegacy();message=ok and'LEGACY BATTERY IMPORTED'or tostring(why)
  else
   local store=getModelStore();local data,meta
   if store then data,meta=store.importLegacy('settings',storeInfo,decode)end
   if data then active=data;draft=copy(active);storageMeta=meta;revision=revision+1;message='LEGACY SETTINGS IMPORTED'
   else message='IMPORT FAILED / LEGACY FILE RETAINED'end
  end
  editing=false;editValue=nil;refreshRows();return true
 end
 local function finishEdit()editing=false;editValue=nil end
 local function revert()
  draft=copy(active);refreshRows();finishEdit();message='App settings draft discarded'
  local found=false;for _,id in ipairs(visible(draft))do if id==section then found=true end end;if not found then inList=true end
 end
 local function discardAll()revert();batteryConfig.revert()end
 local function focusRows()
  local rows=sections[section].rows;local focus={}
  for i,s in ipairs(rows)do if not s.note then focus[#focus+1]=i end end
  if #focus>0 then focus[#focus+1]=#rows+1;focus[#focus+1]=#rows+2;if #rows>7 then focus[#focus+1]=#rows+3 end end
  return focus
 end
 local function selectRow(index)
  selected=index
  if index>=1 and index<=#sections[section].rows then offset=math.floor((index-1)/7)*7 elseif index==0 then offset=0 end
 end
 local function openSection(id,focusKey)
  finishEdit();if batteryConfig.isEditing()then batteryConfig.open()end
  if not id then inList=true;return true end
  local list=visible(draft)
  for i,v in ipairs(list)do
   if v==id then
    section=id;listSelected=i;listOffset=math.floor((i-1)/7)*7;offset=0;inList=false
    if section==3 then batteryConfig.open()else
     local focus=focusRows();selectRow(focus[1] or 0)
     if focusKey then for i,row in ipairs(sections[section].rows)do if row.key==focusKey then selectRow(i);break end end end
    end
    return true
   end
  end
  inList=true;return false
 end
 local function beginEdit()
  local row=sections[section].rows[selected]
  if not row or row.note then return false end
  if row.action then return performAction(row)end
  if not editing then editValue=draft[row.key];editing=true end
  if row.binding and inputRuntime.open then inputRuntime.open(row.binding,draft[row.key])end;return true
 end
 local function back()
  if inList then return false end
  if section==3 and batteryConfig.back()then return true end
  if editing then
   local key=sections[section].rows[selected].key;draft[key]=editValue;refreshRows(key);finishEdit();message='Value edit cancelled';return true
  end
  inList=true;return true
 end
 local function adjust(delta)
  local s=sections[section].rows[selected];if not s or s.note then return end
  if s.binding then if inputRuntime.open then inputRuntime.open(s.binding,draft[s.key])end;return
  elseif string.match(s.key,'^vtx%d$')then
   local v=fcLink.videoState and fcLink.videoState()or{};local values,seen={0},{[0]=true}
   for _,band in ipairs(v.bands or{})do for _,frequency in ipairs(band.frequencies or{})do if frequency>0 and not seen[frequency]then seen[frequency]=true;values[#values+1]=frequency end end end
   local current=draft[s.key];if not seen[current]then values[#values+1]=current end;table.sort(values)
   local index=1;for i,value in ipairs(values)do if value==current then index=i;break end end
   draft[s.key]=values[(index-1+delta)%#values+1]
  elseif s.key=='pack'then
   local values={0};for i=1,5 do if draft['chemistry'..i]~=0 then values[#values+1]=i end end
   local index=1;for i,value in ipairs(values)do if value==draft.pack then index=i;break end end
   draft.pack=values[(index-1+delta)%#values+1]
  elseif type(s.default)=='number' then draft[s.key]=math.max(s.lo,math.min(s.hi,draft[s.key]+delta*s.step))
  else
   local index=1;for i,v in ipairs(s.choices)do if v==draft[s.key]then index=i end end
   draft[s.key]=s.choices[(index-1+delta)%#s.choices+1]
  end
  refreshRows(s.key)
  message='Unsaved settings; SAVE SETTINGS to apply'
 end
 local function activate()
  local rows=sections[section].rows
  if rows[selected]and rows[selected].action then performAction(rows[selected])
  elseif selected==#rows+1 then finishEdit();save()
  elseif selected==#rows+2 then revert()
  elseif selected==#rows+3 then offset=offset+7;if offset>=#rows then offset=0 end
  elseif editing then finishEdit()else beginEdit()end
 end
 local function input(event,touch)
  if event==EVT_TOUCH_TAP and touch and touch.y>=35 and touch.y<61 and touch.x<76 and not inList then back();return true end
  if inList then
   local list=visible(draft);listSelected=math.min(#list,math.max(1,listSelected));listOffset=math.floor((listSelected-1)/7)*7
   if event==EVT_VIRTUAL_ENTER then openSection(list[listSelected]);return true
   elseif (EVT_VIRTUAL_NEXT and event==EVT_VIRTUAL_NEXT) or (EVT_VIRTUAL_PREV and event==EVT_VIRTUAL_PREV) then
    listSelected=math.max(1,math.min(#list,listSelected+(event==EVT_VIRTUAL_NEXT and 1 or -1)));listOffset=math.floor((listSelected-1)/7)*7;return true
   elseif event==EVT_TOUCH_TAP and touch then
    if touch.y>=64 and touch.y<197 then
     local index=listOffset+math.floor((touch.y-64)/19)+1;if index<=#list then listSelected=index;openSection(list[index])end;return true
    elseif touch.y>=222 and touch.y<245 and #list>7 then
     local previous=listOffset;local last=math.floor((#list-1)/7)*7
     if touch.x>=10 and touch.x<230 then listOffset=math.max(0,listOffset-7)
     elseif touch.x>=250 and touch.x<470 then listOffset=math.min(last,listOffset+7)
     else return false end
     if previous~=listOffset then listSelected=listOffset+1 end;return true
    end
   end
   return false
  end
  if section==3 then return batteryConfig.input(event,touch)end
  local rows=sections[section].rows;local focus=focusRows()
  if event==EVT_VIRTUAL_ENTER then if #focus>0 then activate()end;return true
  elseif (EVT_VIRTUAL_NEXT and event==EVT_VIRTUAL_NEXT) or (EVT_VIRTUAL_PREV and event==EVT_VIRTUAL_PREV) then
   local delta=event==EVT_VIRTUAL_NEXT and 1 or -1
   if editing then adjust(delta)
   elseif #focus>0 then local index=1;for i,v in ipairs(focus)do if v==selected then index=i end end;selectRow(focus[(index-1+delta)%#focus+1])end;return true
  elseif event==EVT_TOUCH_TAP and touch then
   if touch.y>=64 and touch.y<197 then
    local index=offset+math.floor((touch.y-64)/19)+1;local row=rows[index]
    if row and not row.note then finishEdit();selectRow(index);beginEdit()end;return true
   elseif touch.y>=200 and touch.y<220 and #rows>7 then
    finishEdit();offset=offset+7;if offset>=#rows then offset=0 end
    selected=#rows+3;return true
   elseif touch.y>=222 and touch.y<245 and #focus>0 then
    if touch.x>=10 and touch.x<84 then if beginEdit()then adjust(-1)end
    elseif touch.x>=88 and touch.x<162 then if beginEdit()then adjust(1)end
    elseif touch.x>=172 and touch.x<312 then finishEdit();selected=#rows+1;save()
    elseif touch.x>=320 and touch.x<470 then selected=#rows+2;revert()
    else return false end;return true
   end
  end
  return false
 end
 local function get(k)return active[k]~=nil and active[k] or schema[k].default end
  local keys={RxBt='voltage',VFAS='voltage',Bat='voltage',Curr='current',Capa='consumed',Fuel='consumed',['Bat%']='remaining',GPS='gps',GSpd='speed',GAlt='altitude',Alt='altitude',Hdg='heading',Yaw='yaw',['0450']='course',Ptch='pitch',Roll='roll',['5230']='pitch',['5240']='roll',['0430']='pitch',['0440']='roll',FM='flightmode',['1RSS']='rssi',RSSI='rssi',RQly='lq',LQ='lq',RSNR='snr',SNR='snr'}
 local function resolve(name)

  local key=keys[name];if not key then return name end
  local v=get(key);if v=='None' then return nil end;return v=='Auto' and name or v
 end
 local function value(name)
  name=resolve(name);if not name then return nil end
  local f=cachedTelemetryField(name);if not f then return nil end
  local v,current=getSourceValue(f.id);if current then return v end
 end
 local function indicator(prefix)
  local state=inputRuntime.state;local role=state and state.roles[prefix]
  if not role or role.state=='OFF'then return 'NOT CONFIGURED'end
  if role.state~='LIVE'then return 'SOURCE UNAVAILABLE'end
  return role.value==true and'ACTIVE'or'INACTIVE'
 end
 local function draw(externalFocus)
  local c=uiTheme or {bg=lcd.RGB(7,15,22),panel=lcd.RGB(18,32,42),white=lcd.RGB(235,243,245),green=lcd.RGB(164,227,125),orange=lcd.RGB(255,174,98),muted=lcd.RGB(144,165,178)}
  local function box(x,y,w,h,col)lcd.setColor(CUSTOM_COLOR,col);lcd.drawFilledRectangle(x,y,w,h,CUSTOM_COLOR)end
  local fontHeight=17
  if lcd.sizeText then local _,h=lcd.sizeText('Ag',SMLSIZE);if type(h)=='number'and h>0 then fontHeight=h end end
  local function text(x,y,s,col,right,height)
   if height then y=y+math.floor((height-fontHeight)/2)end
   lcd.setColor(CUSTOM_COLOR,col);lcd.drawText(x,y,tostring(s),CUSTOM_COLOR+SMLSIZE+(right and RIGHT or 0))
  end
  box(0,35,480,26,c.bg);box(5,62,470,181,c.bg)
  if inList then
   local list=visible(draft);listSelected=math.min(#list,math.max(1,listSelected));listOffset=math.floor((listSelected-1)/7)*7
   text(13,35,'SETUP CATEGORIES',c.white,false,26)
   local dirty=(hasChanges()and 'SETTINGS* 'or '')..(batteryConfig.hasChanges()and 'BATTERY*'or '')
   text(468,35,dirty~=''and dirty or 'SAVED',dirty~=''and c.orange or c.muted,true,26)
   for i=1,7 do
    local index=listOffset+i;local id=list[index]
    if id then local y=64+(i-1)*19;local chosen=index==listSelected and not externalFocus
     box(10,y,460,18,chosen and c.green or c.panel);local col=chosen and c.bg or c.white
     text(17,y,sections[id].name,col,false,18);text(459,y,'>',col,true,18)
    end
   end
   text(17,200,'Select category / ENTER to open',c.muted,false,20)
   text(459,200,(listOffset+1)..'-'..math.min(listOffset+7,#list)..' / '..#list,c.muted,true,20)
   if #list>7 then
    local last=math.floor((#list-1)/7)*7
    for _,v in ipairs({{10,220,'PREVIOUS',listOffset>0},{250,220,'NEXT',listOffset<last}})do
     box(v[1],222,v[2],21,c.panel);text(v[1]+10,222,v[3],v[4]and c.green or c.muted,false,21)
    end
   end
   return
  end
  text(13,35,'< BACK',c.green,false,26);text(80,35,sections[section].name,c.white,false,26)
  local dirty=section==3 and batteryConfig.hasChanges()or section~=3 and hasChanges()
  text(468,35,dirty and '*'or '',c.orange,true,26)
  if section==3 then
   batteryConfig.draw()
   local m=batteryConfig.message()
   if string.find(m,'FAILED',1,true)then box(76,35,372,26,c.bg);text(80,35,'BATTERY SAVE FAILED',c.orange,false,26)
   elseif string.find(m,'Require',1,true)then box(76,35,372,26,c.bg);text(80,35,'CHECK VOLTAGE ORDER',c.orange,false,26)end
   return
  end
  local rows=sections[section].rows
  for i=1,7 do
   local index=offset+i;local s=rows[index]
   if s then
    local y=64+(i-1)*19;local chosen=index==selected and not s.note
    box(10,y,460,18,chosen and c.green or c.panel);local col=chosen and c.bg or s.note and c.muted or c.white
    local v=s.action and '>'or s.note or draft[s.key]
    if not s.note and s.choices and type(s.default)=='number' then v=s.choices[v-s.lo+1]end
    if s.key and string.match(s.key,'^vtx%d$')and v==0 then v='OFF'end
    if s.binding and inputRuntime.label then v=inputRuntime.label(s.binding,v)end
    if s.live=='inputs'then v=indicator('arm')..' / '..indicator('cut')
    elseif s.live=='flight'then v=value('FM')or '--'
    elseif section==5 and index==3 then v=fcLink.state.status
    elseif section==5 and index==4 then v=fcLink.state.firmware or '--'end
    local shown=(editing and chosen)and '< '..tostring(v)..' >'or tostring(v)
    local left=s.label;local maxValue=math.min(238,math.max(100,440-(lcd.sizeText and lcd.sizeText(left,SMLSIZE)or #left*8)-10))
    while #shown>1 and lcd.sizeText and lcd.sizeText(shown,SMLSIZE)>maxValue do shown=string.sub(shown,1,#shown-2)..'~'end
    local valueWidth=lcd.sizeText and lcd.sizeText(shown,SMLSIZE)or #shown*8
    while #left>1 and lcd.sizeText and lcd.sizeText(left,SMLSIZE)>432-valueWidth-10 do left=string.sub(left,1,#left-2)..'~'end
    text(17,y,left,col,false,18);text(459,y,shown,col,true,18)
   end
  end
  local problem=string.find(message,'FAILED',1,true)or string.find(message,'Invalid',1,true)or string.find(message,'critical',1,true)
  if problem then text(17,200,string.sub(message,1,65),c.orange,false,20)
  elseif #rows>7 then
   if selected==#rows+3 then box(10,200,460,20,c.green)end
   text(17,200,'MORE ROWS >  '..(offset+1)..'-'..math.min(offset+7,#rows)..' / '..#rows,selected==#rows+3 and c.bg or c.green,false,20)
  else text(17,200,#focusRows()>0 and 'ENTER edit / RTN cancel value' or 'Reference only / RTN for categories',c.muted,false,20)end
  if #focusRows()>0 then
   for _,v in ipairs({{10,74,'-',nil},{88,74,'+',nil},{172,140,'SAVE SETTINGS',#rows+1},{320,150,'REVERT SETTINGS',#rows+2}})do
    local chosen=v[4]==selected;box(v[1],222,v[2],21,chosen and c.green or c.panel)
    text(v[1]+10,222,v[3],chosen and c.bg or v[4] and c.green or selected>0 and selected<=#rows and c.white or c.muted,false,21)
   end
  end
 end
 local linkThresholds={{'rssi','rssiCrit','rssiLow'},{'lq','lqCrit','lqLow'},{'snr','snrCrit','snrLow'}}
 local function threshold(key,d)
  local defaults=d and d.protocol and d.protocol.thresholds
  if get('thresholdMode')=='Profile defaults'and defaults and defaults[key]~=nil then return defaults[key]end
  return get(key)
 end
 local function linkStatus(d)
  local low=false
  for _,v in ipairs(linkThresholds)do
   if type(d[v[1]])=='number' then
    if d[v[1]]<=threshold(v[2],d) then return 'LINK CRITICAL' elseif d[v[1]]<=threshold(v[3],d) then low=true end
   end
  end
  if low then return 'LINK LOW' end
 end
 return {canOpen=function(id)for _,v in ipairs(visible(draft))do if v==id then return true end end;return false end,
 openSection=openSection,isList=function()return inList end,back=back,
 atFooterBoundary=function()return inList and listSelected==1 end,
 hasChanges=function()return hasChanges()or batteryConfig.hasChanges()end,hasAppChanges=hasChanges,
 discardAll=discardAll,isEditing=function()return editing or batteryConfig.isEditing()end,
 acceptBinding=function(identity)local row=sections[section].rows[selected];if row and row.binding and editing then draft[row.key]=identity or editValue;finishEdit();message=identity and'Unsaved input / SAVE SETTINGS to apply'or'Input selection cancelled'end end,
 selectPack=function(index)
  if hasChanges()or batteryConfig.hasChanges()then return false,'SAVE OR REVERT SETTINGS FIRST'end
  if type(index)~='number'or index%1~=0.0 or index<0 or index>5 or(index>0 and get('chemistry'..index)==0)then return false,'PACK IS DISABLED'end
  draft.pack=index;local ok=save();if not ok then draft=copy(active)end;refreshRows();return ok,ok and nil or message
 end,
 storage=function()return storageMeta end,init=init,input=input,draw=draw,get=get,revision=function()return revision end,resolve=resolve,value=value,threshold=threshold,linkStatus=linkStatus,indicator=indicator,save=save,refreshSensorChoices=refreshSensorChoices,
 visible=function()return visible(draft)end}

end)()


function fcLink.update(now)
 local service=fcLink.service;if not service then return end
 local profile,current,disarmed,knownFC;if fcLink.guard then profile,current,disarmed,knownFC=fcLink.guard()end
 local rc,fc=configuration.get('rcProtocol'),configuration.get('fcType')
 if fcLink.nativeRevision~=nativeFmRevision or fcLink.guardSource~=fmGuardName then fcLink.qualifyNative()end
 local known=profile and(profile.family=='CRSF'or profile.family=='FRSKY')
 local enabled=configuration.get('mspMode')==1 and known and(fc=='None'or fc=='Auto'or fc=='Betaflight'or fc=='INAV')
 if profile and profile.family=='CRSF'and not fcLink.native then enabled=false end
 if fcLink.configRevision~=configuration.revision()or fcLink.settings.video~=fcLink.videoPage or fcLink.settings.info~=fcLink.infoPage or fcLink.settings.gps~=fcLink.gpsPage then
  local s=fcLink.settings;s.vtxBackend=configuration.get('vtxBackend');s.vtxHardware=configuration.get('vtxHardware');s.statusInterval=configuration.get('statusInterval');s.vtxPolling=configuration.get('vtxPolling');s.vtxMode=configuration.get('vtxMode');s.vtxCache=configuration.get('vtxCache');s.video=fcLink.videoPage;s.info=fcLink.infoPage;s.gps=fcLink.gpsPage
  service:configure(profile,s);fcLink.configRevision=configuration.revision()
 end
 if fcLink.telemetrySwitch and getSwitchValue then current=current and getSwitchValue(fcLink.telemetrySwitch)==true end
 local ng=fcLink.nativeGuard;ng.current=current==true;ng.disarmed=disarmed==true
 if fcLink.telemetrySwitch and getSwitchValue then ng.current=getSwitchValue(fcLink.telemetrySwitch)==true end
 if not knownFC and not ng.disarmed and inputRuntime.armOverride then ng.disarmed=inputRuntime.armOverride()==false end
 fcLink.state=service:tick(now,enabled,current,disarmed,known and configuration.get('vtxMode')>0,ng)
 fcLink.client=service.client
end
local telemetry=(function()
local start,last,mode
local protocolFactory,profile,profileRevision=nil,nil,-1
local powerFactory,powerPolicy,powerSettings,powerRevision,powerBatteryRevision=nil,nil,nil,-1,-1
local extremaReader,nativeFields,nativeRevision,nativeBindings=nil,{},-1,-1
local nativeReaders,nativeAt,nativeWorkMode,nativePrepared={},-100,nil,false
local radioAt,radioVoltage=-100,nil
local radioStatus
local decoded={}
local units,sourceStates={},{}
local readPlans={}
local liveData,spareData={},{}
local function copyView(target,source)
 target=target or{}
 for key in pairs(target)do if source[key]==nil then target[key]=nil end end
 for key,value in pairs(source)do target[key]=value end
 return target
end
local function rememberSource(name,state,raw)
 local record=sourceStates[name]
 if not record then record={};sourceStates[name]=record end
 if state=='LIVE'or state=='INVALID'then local f=telemetryFields[name];if f then receivedSources[f.id]=true end end
 record.state=state;record.raw=type(raw)=='number'and raw or nil
end
local function scanUnits()
 refreshSources();units={};sourceStates={};readPlans={}
 local names={}
 for i=0,63 do
  local sensor=model.getSensor(i)
  if sensor and sensor.name and sensor.name~=''then units[sensor.name]=sensor.unit;names[#names+1]=sensor.name end
 end
 configuration.refreshSensorChoices(names)
end
local unitDefs={UNIT_VOLTS='V',UNIT_AMPS='A',UNIT_MILLIAMPS='mA',UNIT_MAH='mAh',UNIT_AH='Ah',UNIT_WH='Wh',UNIT_MILLIWATTS='mW',UNIT_WATTS='W',UNIT_PERCENT='%',UNIT_DBM='dBm',UNIT_DB='dB',UNIT_RADIANS='rad',UNIT_DEGREE='deg',UNIT_KTS='kt',UNIT_MPH='mph',UNIT_METERS_PER_SECOND='m/s',UNIT_FEET_PER_SECOND='ft/s',UNIT_KMH='km/h',UNIT_FEET='ft',UNIT_METERS='m',UNIT_RAW='NUMBER',UNIT_TEXT='TEXT'}
local canonical={rawPct='pct',power='tx',down='txlq',rf='rf',trss='txrssi',tsnr='txsnr',airspeed='aspd'}
local function refreshProfile()
 if profileRevision==configuration.revision()then return end
 profileRevision=configuration.revision();profile=nil;decoded={};readPlans={}
 if not protocolFactory and loadScript then local chunk=loadScript('/SCRIPTS/TOOLS/AERODECK/protocols.lua');protocolFactory=chunk and chunk()end
 if protocolFactory then
  local rc=configuration.get('rcProtocol');if rc=='None' or rc=='Auto'then rc='ELRS / CRSF'end
  local fc=configuration.get('fcType');if fc=='None'or fc=='Auto'then fc='Betaflight'end
  profile=protocolFactory.profile(rc,configuration.get('rcSubtype'),fc)
  for name,unit in pairs(unitDefs)do local id=_G[name];if type(id)=='number'then profile.unitNames[id]=unit end end
 end
end
local function init()
 liveData={};spareData={}
 nativePrepared=false;nativeReaders={};nativeAt=-100;nativeWorkMode=nil
 if extremaReader then extremaReader.resetBindings()end
 if loadScript then local chunk=loadScript('/SCRIPTS/TOOLS/AERODECK/power-policy.lua');powerFactory=chunk and chunk();powerPolicy=powerFactory and powerFactory.new({onAlert=function(event)if alertPlayback then alertPlayback.queue(event)end end})or nil end
 local radioChunk=loadScript and loadScript('/SCRIPTS/TOOLS/AERODECK/radio-status.lua');local radioFactory=radioChunk and radioChunk();radioStatus=radioFactory and radioFactory.new({getGeneralSettings=getGeneralSettings,getSourceValue=getSourceValue,getValue=getValue,getTime=getTime})or nil
 powerRevision=-1;powerBatteryRevision=-1;powerSettings=nil
 start=getTime();last=-100;mode=1;scanUnits();profileRevision=-1;radioAt=-100;radioVoltage=nil;refreshProfile()end
local fieldSettings={v='voltage',a='current',mah='consumed',pct='remaining',gps='gps',speed='speed',alt='altitude',baro='baro',aspd='airspeed',airspeed='airspeed',hdg='heading',course='course',yaw='yaw',pitch='pitch',roll='roll',flight='flightmode',rssi='rssi',lq='lq',snr='snr'}
local providerKeys={v='batteryEnabled',a4='batteryEnabled',a='currentEnabled',mah='currentEnabled',pct='currentEnabled',pitch='gyroEnabled',roll='gyroEnabled',yaw='gyroEnabled',gps='gpsEnabled',sats='gpsEnabled',gpsStatus='gpsEnabled',speed='gpsEnabled',alt='gpsEnabled',hdg='gpsEnabled',course='gpsEnabled',homeDistance='gpsEnabled',homeBearing='gpsEnabled',baro='baroEnabled',vspeed='baroEnabled',aspd='pitotEnabled',airspeed='pitotEnabled'}
local function resolved(original,field)
 local provider=providerKeys[field];if provider and configuration.get(provider)==0 then return nil end
 local key=fieldSettings[field]
 if key then local value=configuration.get(key);if value=='None'then return nil end;return value=='Auto'and original or value end
 if field then return original end
 return configuration.resolve(original)
end
local function bindReader(candidate,field)
 local f=cachedTelemetryField(candidate.name);candidate.binding=f or false;candidate.reader=nil
 if not f then return end
 local unit=f.unit or units[candidate.name]
 if candidate.native and(unit==0 or unit==UNIT_RAW)then unit=nil end
 candidate.reader=protocolFactory.reader(canonical[field]or field,unit,profile)
end
local function planReader(names,field)
 local revision=configuration.revision();local plan=readPlans[field]
 if plan and plan.revision==revision and plan.profile==profile then return plan end
 plan={revision=revision,profile=profile,candidates={}};readPlans[field]=plan
 if profile.supported==false then return plan end
 local aliases=profile.aliases[canonical[field]or field]or{}
 for _,original in ipairs(names)do
  local name=resolved(original,field)
  if name then
   local candidate={name=name,native=false}
   for _,alias in ipairs(aliases)do if name==alias then candidate.native=true;break end end
   bindReader(candidate,field);plan.candidates[#plan.candidates+1]=candidate
  end
 end
 return plan
end
local function plannedRead(names,field)
 local plan=planReader(names,field)
 for _,candidate in ipairs(plan.candidates)do
  if telemetryFields[candidate.name]~=candidate.binding then bindReader(candidate,field)end
  local f=candidate.binding
  if f then
   local raw,current=getSourceValue(f.id)
   if current and type(raw)=='number'and raw==raw and math.abs(raw)<math.huge then
    local value=candidate.reader(raw);rememberSource(candidate.name,value~=nil and'LIVE'or'INVALID',raw);return value
   end
   rememberSource(candidate.name,current and'INVALID'or'STALE',raw)
  else rememberSource(candidate.name,'NOT FOUND')end
 end
end
local function read(names,kind,field)
 if profile and protocolFactory and protocolFactory.reader and field and profile.fields[canonical[field]or field]then return plannedRead(names,field)end
 if profile and profile.supported==false then return nil end
 for _,original in ipairs(names) do
  local name=resolved(original,field)
  local f=name and cachedTelemetryField(name)
  if f then
   local v,current=getSourceValue(f.id)
   if current and type(v)=='number' and v==v and math.abs(v)<math.huge then
   local unit=f.unit or units[name]
   if protocolFactory and profile and field and profile.fields[canonical[field]or field]then
    local inputUnit=unit
    -- Only a verified native alias may use its documented raw convention.
    local native=false;for _,alias in ipairs(profile.aliases[canonical[field]or field]or{})do if name==alias then native=true;break end end
    if native and (unit==0 or unit==UNIT_RAW)then inputUnit=nil end
    local value,why=protocolFactory.normalize(canonical[field]or field,v,inputUnit,profile)
    rememberSource(name,value~=nil and 'LIVE'or 'INVALID',v)
    return value
   end
   rememberSource(name,'LIVE',v)
   if kind=='speed' then
    if unit==UNIT_KTS then v=v*1.852 elseif unit==UNIT_MPH then v=v*1.609344 elseif unit==UNIT_METERS_PER_SECOND then v=v*3.6 elseif unit==UNIT_FEET_PER_SECOND then v=v*1.09728 elseif unit~=UNIT_KMH then rememberSource(name,'INVALID',v);return nil end
   elseif kind=='angle' or kind=='pitch' then
    if unit==UNIT_RADIANS then
     v=v*180/math.pi
     -- CRSF pitch needs the same sign convention as Toolbox; Roll/Yaw do not.
     if kind=='pitch' then v=-v;v=v+0.0 end
    elseif unit~=UNIT_DEGREE then rememberSource(name,'INVALID',v);return nil end
   elseif kind=='vspeed' then
    if unit==UNIT_FEET_PER_SECOND then v=v*.3048 elseif unit~=UNIT_METERS_PER_SECOND then rememberSource(name,'INVALID',v);return nil end
   elseif kind=='alt' then
    if unit==UNIT_FEET then v=v*.3048 elseif unit~=UNIT_METERS then rememberSource(name,'INVALID',v);return nil end
   end
   return v
   end
   rememberSource(name,current and 'INVALID'or 'STALE',v)
  elseif name then rememberSource(name,'NOT FOUND')end
 end
end
local sourceStatePriority={['NOT FOUND']=1,STALE=2,INVALID=3,LIVE=4}
local function sourceState(original)
 local name=configuration.resolve(original)
 if not name then return nil,'OFF',nil,0 end
 local record=sourceStates[name]
 local state=record and record.state or (telemetryFields[name]and 'STALE'or 'NOT FOUND')
 return name,state,record and record.raw,sourceStatePriority[state]
end
local function sourceStatus(names)
 if profile and profile.family=='FRSKY' and type(names)=='table' and names[1]=='RxBt'then names=profile.aliases.v end
 if type(names)=='string'then local name,state,raw=sourceState(names);return name,state,raw end
 local bestName,bestState,bestRaw,bestRank=nil,'OFF',nil,0
 for _,original in ipairs(names)do
  local name,state,raw,rank=sourceState(original)
  if rank>bestRank then bestName,bestState,bestRaw,bestRank=name,state,raw,rank end
 end
 return bestName,bestState,bestRaw
end
local liveFields={{'v',{'RxBt','VFAS','Bat'}},{'a',{'Curr'}},{'mah',{'Capa'}},{'rawPct',{'Bat%'}},{'lq',{'RQly','LQ'}},{'rssi',{'1RSS','RSSI'}},{'snr',{'RSNR','SNR'}},{'power',{'TPWR'}},{'down',{'TQly'}},{'rf',{'RFMD'}},{'sats',{'Sats'}},{'speed',{'GSpd'},'speed'},{'alt',{'GAlt'},'alt'},{'hdg',{'Hdg'},'angle'},{'yaw',{'Yaw'},'angle'},{'rssi2',{'2RSS'}},{'trss',{'TRSS'}},{'tsnr',{'TSNR'}},{'vspeed',{'VSpd'},'vspeed'},{'airspeed',{'ASpd'},'speed'},}
local powerWarnings={['NO POWER']='NO PACK POWER',['BELOW MIN']='BELOW MINIMUM',CRITICAL='BATTERY CRITICAL',LOW='BATTERY LOW',['ABOVE MAX']='ABOVE MAXIMUM',['PROFILE OFF']='BATTERY PROFILE OFF'}
local extraFields={{'baro',{'Alt'},'alt'},{'rxV',{'RxBt'}},{'a1',{'A1'}},{'a2',{'A2'}},{'a3',{'A3'}},{'a4',{'A4'}},{'gpsStatus',{}},{'homeDistance',{}},{'homeBearing',{}},{'course',{'Hdg'},'angle'}}
local pitchNames,rollNames={'Ptch'},{'Roll'}
local function prime()
 if not(profile and protocolFactory and protocolFactory.reader)then return end
 for _,f in ipairs(liveFields)do
  local key=canonical[f[1]]or f[1];local names=f[2];if profile.family=='FRSKY'then names=profile.aliases[key]end
  if names then planReader(names,key)end
 end
 for _,f in ipairs(extraFields)do local names=profile.aliases[f[1]];if names then planReader(names,f[1])end end
 planReader(profile.family=='FRSKY'and profile.aliases.pitch or pitchNames,'pitch')
 planReader(profile.family=='FRSKY'and profile.aliases.roll or rollNames,'roll')
end
local attitudePitch,attitudeRoll
local function pollAttitude()
 local pitch=profile and profile.family=='FRSKY' and profile.aliases.pitch or pitchNames
 local roll=profile and profile.family=='FRSKY' and profile.aliases.roll or rollNames
 attitudePitch=pitch and read(pitch,'pitch','pitch') or nil;attitudeRoll=roll and read(roll,'angle','roll') or nil
 -- The shared snapshot is reused between slower service passes. Never let
 -- that cache hold the horizon at the power/GPS sampling rate, including loss.
 liveData.pitch=attitudePitch;liveData.roll=attitudeRoll
 return attitudePitch,attitudeRoll
end
local function getData(t,first,last,partial)
 local d=liveData
 for i=first or 1,last or #liveFields do
  local f=liveFields[i]
  local key=canonical[f[1]]or f[1]
  local names=f[2]
  if profile and profile.family=='FRSKY'then names=profile.aliases[key]end
  d[f[1]]=names and read(names,f[3],key)or nil
 end
 if partial then return d end
 for _,f in ipairs(extraFields)do
  local names=profile and profile.aliases[f[1]]
  if not profile then names=f[2]end
  d[f[1]]=names and read(names,f[3],f[1])or nil
 end
 d.rssi1=d.rssi
 if protocolFactory and profile then d.rssi=protocolFactory.bestRssi(d.rssi,d.rssi2,profile)end
 d.disabled=configuration.get('rcProtocol')=='Off';d.protocol=profile;d.rssiUnit=profile and profile.rssiUnit or 'dBm'
 d.voltageName=profile and profile.family=='FRSKY'and 'VFAS'or 'RxBt'
 d.consumedName=profile and profile.family=='FRSKY'and 'Fuel'or 'Capa'
 if decoded.rf~=d.rf then decoded.rf=d.rf;decoded.rfCaption=protocolFactory and protocolFactory.rfCaption(d.rf,profile)or nil end
 d.rfCaption=decoded.rfCaption
 if radioStatus then
  local current=radioStatus.sample(getTime())
  if not d.radioStatus or d.radioStatus.revision~=current.revision then d.radioStatus=copyView(d.radioStatus,current)end
  radioVoltage=current.voltage;d.radioWarning=current.warning
 elseif getTime()<radioAt or getTime()-radioAt>=100 then
  radioAt=getTime();local v=getValue and getValue('tx-voltage')
  radioVoltage=type(v)=='number'and v==v and v>0 and v<100 and v or nil
 end
 d.radioVoltage=radioVoltage
 d.pitch=attitudePitch;d.roll=attitudeRoll
 local rawFlight=not(profile and profile.supported==false)and configuration.value('FM')or nil;d.flight=rawFlight or '--';d.demo=false;d.estimated=nil
 d.pct=d.rawPct;d.estimatedPct=nil;d.percentageOrigin=d.rawPct~=nil and 'REPORTED' or nil

 local gpsCurrent=configuration.get('gpsEnabled')~=0 and not(profile and profile.supported==false)and configuration.value('GPS')or nil;d.gps=gpsCurrent
 d.fcReported=nil;d.fcArmed=nil;d.gpsQuality=nil;d.fix=nil
 if protocolFactory and profile then
  if profile.family=='FRSKY' then rawFlight=profile.aliases.flight and read(profile.aliases.flight,nil,'flight')end
  if rawFlight~=decoded.flight then
   decoded.flight=rawFlight;decoded.fc=rawFlight~=nil and protocolFactory.decodeFC(rawFlight,profile)or nil
  end
  d.fcReported=decoded.fc;d.flight=d.fcReported and d.fcReported.mode or(type(rawFlight)=='string'and rawFlight or '--')
  if profile.family=='FRSKY' then
   if decoded.gps~=d.gpsStatus then decoded.gps=d.gpsStatus;decoded.quality=protocolFactory.decodeGPS(d.gpsStatus,profile)end
   d.gpsQuality=decoded.quality
   if d.gpsQuality then d.sats=d.gpsQuality.sats;d.fix=d.gpsQuality.fix end
  end
 end
 if d.fcReported then d.fcArmed=d.fcReported.armed end
 d.ok=d.v~=nil or d.lq~=nil or d.rssi~=nil or d.baro~=nil or d.airspeed~=nil or d.sats~=nil or d.pitch~=nil or type(gpsCurrent)=='table' or d.flight~='--'
 return d
end
local function acquire(attitudePolled,separate,partial,published)
 refreshProfile()
 retryMissingSources()
 -- Cancellation reuses the unfinished working buffer. Never swap back into
 -- the still-published picture merely because a pending revision was replaced.
 if separate and liveData==published then liveData,spareData=spareData,liveData end
 if not attitudePolled then pollAttitude()end
 local d=getData((getTime()-start)/100,1,partial and 15 or #liveFields,partial)
 if partial then return d end
 if not d.ok then d.flight=nil end
 d.mode=mode
 return d
end
local function finishAcquire()
 local d=getData((getTime()-start)/100,16,#liveFields)
 if not d.ok then d.flight=nil end;d.mode=mode;return d
end
local function derive(d)
 if powerPolicy and batteryConfig.values then
  if powerRevision~=configuration.revision()or powerBatteryRevision~=batteryConfig.revision()then
   powerRevision=configuration.revision();powerBatteryRevision=batteryConfig.revision()
   local profiles={};for i=1,5 do profiles[i]={cells=configuration.get('cells'..i),capacity=configuration.get('capacity'..i),chemistry=configuration.get('chemistry'..i)}end
   powerSettings=powerFactory.fromLegacy(batteryConfig.values(),{profile=configuration.get('pack'),profiles=profiles,sourceId=table.concat({configuration.get('rcProtocol'),configuration.get('rcSubtype'),configuration.get('fcType'),configuration.get('voltage'),configuration.get('consumed'),tostring(configuration.get('batteryEnabled')),tostring(configuration.get('currentEnabled'))},'|')})
  end
  if powerSettings then
   powerSettings.muted=alertsMuted;d.reportedPct=d.rawPct;d.reportedCell=d.a4
   local ps=powerPolicy.update(getTime(),d,powerSettings)
   local thresholds=d.powerState and d.powerState.thresholds
   d.powerState=copyView(d.powerState,ps);d.powerState.thresholds=copyView(thresholds,ps.thresholds);d.powerError=ps.error
   d.cells=ps.cells;d.cell=ps.cell;d.cellsEstimated=ps.cellsEstimated;d.cellProvenance=ps.cellProvenance
   d.voltagePct=ps.voltagePct;d.voltagePctOrigin=ps.voltagePctOrigin
   d.capacity=ps.capacity;d.remainingMah=ps.remainingMah;d.estimatedPct=ps.derivedPct;d.pct=ps.displayPct;d.estimated=ps.pctEstimated
   d.percentageOrigin=ps.pctEstimated and 'CAPACITY ESTIMATE'or ps.reportedPct~=nil and 'REPORTED'or nil
   d.battery=powerWarnings[ps.condition]
  else d.powerError='INVALID POWER CONFIG';d.battery=nil;d.cells=nil;d.cell=nil end
 else
  d.powerError='POWER POLICY MODULE UNAVAILABLE';d.powerState=nil
  local pack=configuration.get('pack');local override=pack>0 and configuration.get('cells'..pack)or nil
  d.capacity=nil;d.remainingMah=nil
  if pack>0 then local capacity=configuration.get('capacity'..pack)
   if type(capacity)=='number'and capacity>0 then d.capacity=capacity
    if type(d.mah)=='number'then d.remainingMah=math.max(0,capacity-d.mah);d.estimatedPct=math.max(0,math.min(100,100*(1-d.mah/capacity)));d.pct=d.estimatedPct;d.estimated=true;d.percentageOrigin='CAPACITY ESTIMATE'end
   end
  end
  d.battery,d.cells=batteryConfig.check(d.v,d.demo,override);if d.cells==0 then d.cells=nil end
  d.cell=d.cells and d.v and d.v/d.cells or nil
 end
 d.link=configuration.linkStatus(d)
 return d
end
local function sample(attitudePolled)return derive(acquire(attitudePolled))end
local function extremaReady()
 return nativePrepared and nativeRevision==configuration.revision()and nativeBindings==bindingRevision
end
local function prepareExtrema()
 if extremaReady()then return extremaReader~=nil end
 refreshProfile()
 nativePrepared=true;nativeRevision=configuration.revision();nativeBindings=bindingRevision
 nativeReaders={};nativeFields={};nativeAt=-100;nativeWorkMode=nil
 if extremaReader then extremaReader.resetBindings()end
 if not extremaReader and loadScript then
  local chunk=loadScript('/SCRIPTS/TOOLS/AERODECK/native-extrema.lua');local factory=chunk and chunk()
  if factory then extremaReader=factory.new({getSourceValue=getSourceValue,received=function(id)return receivedSources[id]==true end,
   normalize=function(field,raw,unit)
    local row=nativeReaders[field];local reader=row and row[unit or false]
    if reader then return reader(raw)end
    return nil,'PROTOCOL UNAVAILABLE'
   end})end
 end
 if not extremaReader then return nil end
 do
  local function add(field)
   local target=canonical[field[1]]or field[1];local aliases=profile and profile.aliases[target]or field[2]
   if profile and profile.family=='FRSKY'then aliases=profile.aliases[target]end
   if not aliases then return end
   local name,f
   for _,alias in ipairs(aliases)do local candidate=resolved(alias,target);local bound=candidate and cachedTelemetryField(candidate);if bound then name=candidate;f=bound;break end end
   if not f then return end
   local unit=f.unit or units[name]
   -- Raw units are allowed only for a known native alias with a verified convention.
   if unit==0 or unit==UNIT_RAW then for _,alias in ipairs(aliases)do if name==alias then unit=nil;break end end end
   local inverted=target=='pitch'and(profile and profile.family=='FRSKY'or unit==UNIT_RADIANS)
   local row=nativeReaders[target];if not row then row={};nativeReaders[target]=row end
   row[unit or false]=protocolFactory and profile and protocolFactory.reader(target,unit,profile)or nil
   nativeFields[#nativeFields+1]={key=field[1]=='rssi'and'rssi1'or field[1],name=name,id=f.id,unit=unit,profileField=target,invertExtrema=inverted==true}
  end
  for _,field in ipairs(liveFields)do add(field)end
  for _,field in ipairs(extraFields)do add(field)end
  add({'pitch',pitchNames});add({'roll',rollNames})
 end
 return true
end
local function extrema(mode)
 if not extremaReady()then prepareExtrema()end
 if not extremaReader then return nil end
 local now=getTime();local view=extremaReader.snapshot()
 if view.mode~=mode or now<nativeAt or now-nativeAt>=20 then
  nativeAt=now;nativeWorkMode=mode;return extremaReader.sample(nativeFields,mode)
 end
 return view
end
local function extremaView(mode)
 if not extremaReady()or not extremaReader then return nil end
 local view=extremaReader.snapshot();return view.mode==mode and view or nil
end
local function cancelExtrema()
 if extremaReader and extremaReader.cancel then extremaReader.cancel()end
 nativeWorkMode=nil;nativeAt=-100
end
local function serviceExtrema(mode,now)
 if not extremaReady()or not extremaReader then return end
 local view=extremaReader.snapshot()
 if nativeWorkMode~=mode or view.pending and(now<nativeAt or now-nativeAt>200)or not view.pending and(now<nativeAt or now-nativeAt>=20)then
  nativeAt=now;nativeWorkMode=mode;extremaReader.begin(nativeFields,mode)
 end
 if extremaReader.snapshot().pending then return extremaReader.step(4)end
 return extremaReader.snapshot(),true,0
end
local function extremaAllowance(mode,now)
 -- Native probes: begin+first batch costs up to15 allowance points; final
 -- batch+atomic publish up to11. Ordinary batches cost at most5. Reserve the
 -- larger margin at the two boundaries without starving intermediate reads.
 local view=extremaReader and extremaReader.snapshot()
 if not view or nativeWorkMode~=mode or not view.pending or now<nativeAt or now-nativeAt>200 or view.completed+4>=view.total then return 10 end
 return 18
end
local function extremaOverdue(now)
 return now<nativeAt or now-nativeAt>=40
end
local function extremaStatus()
 if not extremaReader then return 'UNAVAILABLE'end
 return extremaReader.snapshot().pending and 'READING'or 'NATIVE'
end
local function toggle()mode=1;last=-100;scanUnits()end
return {prime=prime,acquire=acquire,finishAcquire=finishAcquire,derive=derive,extrema=extrema,prepareExtrema=prepareExtrema,extremaReady=extremaReady,extremaView=extremaView,cancelExtrema=cancelExtrema,serviceExtrema=serviceExtrema,extremaAllowance=extremaAllowance,extremaOverdue=extremaOverdue,extremaStatus=extremaStatus,clearStatistics=function()receivedSources={};nativeAt=-100;nativeWorkMode=nil;if extremaReader then extremaReader.resetBindings()end end,resetPower=function()if powerPolicy then powerPolicy.reset()end end,init=init,sample=sample,pollAttitude=pollAttitude,toggle=toggle,sourceStatus=sourceStatus,refreshBindings=function()last=-100;scanUnits()end,isDemo=function()return false end,profile=function()return profile end,release=function()end,refresh=function()last=-100 end}

end)()
fcLink.guard=function()
 local p=telemetry.profile();if p and p.supported==false then return p,false,false end;local name=configuration.resolve('FM')
 if p and p.family=='FRSKY'then local chosen=configuration.get('flightmode');name=chosen=='None'and nil or chosen~='Auto'and chosen or p.aliases.flight and p.aliases.flight[1]end
 fmGuardName=name
 local f=name and cachedTelemetryField(name);local raw,current
 if f then raw,current=getSourceValue(f.id)end
 local disarmed=false
 if current==true and type(raw)=='string'and raw~=''then
  if p and p.fcType=='INAV'then disarmed=raw=='OK'or raw=='WAIT'or raw=='0'or(string.find(raw,'!',1,true)~=nil and string.find(raw,'FS',1,true)==nil)
  else disarmed=string.find(raw,'[!?*]')~=nil and string.find(raw,'FS',1,true)==nil end
 elseif current==true and type(raw)=='number'and p and p.family=='FRSKY'then
  local ones=raw%10;disarmed=raw>=0 and raw%1==0.0 and math.floor(ones/4)%2==0
 end
 return p,current==true,disarmed,current==true and(type(raw)=='string'and raw~=''or type(raw)=='number'and p and p.family=='FRSKY')
end
do
 local provider,picker,revision,pickerKey,native=nil,nil,-1,nil,{}
 local roles={'arm','cut','acro','angle','horizon','air','turtle','rth','wrth','throttle','limiter'}
 function inputRuntime.init(deferred)
  inputRuntime.deferred=deferred==true
  if picker then picker.action('pickerCancel')end
  local chunk=loadScript and loadScript('/SCRIPTS/TOOLS/AERODECK/input-indicators.lua');local factory=chunk and chunk()
  provider=factory and factory.new({sources=sources,switches=switches,getFieldInfo=getFieldInfo,getSourceName=getSourceName,getSourceIndex=getSourceIndex,getSwitchInfo=getSwitchInfo,getSwitchIndex=getSwitchIndex,getSwitchName=getSwitchName,getSwitchValue=getSwitchValue,getLogicalSwitchValue=getLogicalSwitchValue,getSourceValue=getSourceValue,getValue=getValue,getUsage=getUsage},{learnBudget=8,deferRefresh=deferred==true})or nil
  inputRuntime.provider=provider;inputRuntime.state=nil;revision=-1;picker=nil;pickerKey=nil
 end
 function inputRuntime.refresh()
  if provider then if inputRuntime.deferred and provider.beginRefresh then provider.beginRefresh()else provider.refresh()end;revision=-1 end
  if picker then picker.action('pickerCancel')end;pickerKey=nil
 end
 function inputRuntime.discover(budget)
  if provider and provider.ready and not provider.ready()then local ready=provider.refreshStep(budget or 8);if ready then revision=-1 end;return true end
  return false
 end
 function inputRuntime.sample(d)
  if not provider then return end
  if revision~=configuration.revision()then for _,role in ipairs(roles)do provider.bind(role,configuration.get(role..'Binding'))end;revision=configuration.revision()end
  native.current=d.fcReported~=nil;native.armed=d.fcArmed;native.mode=d.flight;native.family=d.protocol and d.protocol.fcType
  inputRuntime.state=provider.sample(native);d.inputs=inputRuntime.state
  d.displayFlight=d.flight
  local state=inputRuntime.state
  if state.modeOverrideConfigured then d.displayFlight=state.modeOverrideState=='LIVE'and(state.modeOverride and'R:'..state.modeOverride or'R:--')or'R:?'end
 end
 -- A write/reset guard must not use the slower display snapshot. Read only
 -- its explicitly configured binding, with a fresh native input cache cycle.
 function inputRuntime.armOverride()
  if not provider then return nil end
  local arm=provider.preview('arm',configuration.get('armBinding'))
  if arm and arm.state=='LIVE'and arm.override then return arm.value end
 end
 function inputRuntime.armedNow()
  if fcLink.guard then
   local _,current,disarmed,known=fcLink.guard()
   if current and known then return not disarmed end
  end
  return inputRuntime.armOverride()
 end
 function inputRuntime.label(role,identity)
  if not provider then return identity end
  local choices=provider.choices(role)
  if not choices then return identity..' / discovering'end
  for i,v in ipairs(choices)do if v==identity then return choices.labels[i]end end
  return identity..' / unavailable'
 end
 function inputRuntime.open(role,identity)
  if not provider or(provider.ready and not provider.ready())then return false end
  if not picker then
   local chunk=loadScript and loadScript('/SCRIPTS/TOOLS/AERODECK/input-picker.lua');local factory=chunk and chunk()
   picker=factory and factory.new({provider=provider,lcd=lcd,palette=function()return uiTheme end,fonts={small=SMLSIZE,tiny=TINSIZE},colorFlag=CUSTOM_COLOR})or nil
  end
  if not picker then return false end
  picker.open(role,identity);pickerKey=role;return true
 end
 function inputRuntime.active()return pickerKey~=nil end
 function inputRuntime.stop()if picker and pickerKey then picker.action('pickerCancel');configuration.acceptBinding(nil)end;pickerKey=nil end
 function inputRuntime.input(event,touch)
  if not pickerKey then return false end
  if event==EVT_VIRTUAL_EXIT then picker.action('pickerCancel')
  elseif event==EVT_VIRTUAL_NEXT then picker.move(1)
  elseif event==EVT_VIRTUAL_PREV then picker.move(-1)
  elseif event==EVT_VIRTUAL_ENTER then picker.activate()
  elseif event==EVT_TOUCH_TAP and touch then local action=picker.hit(touch.x,touch.y);if action then picker.action(action,getTime())end end
  local identity,status=picker.result()
  if status=='CHOSEN'or status=='CANCELLED'then configuration.acceptBinding(status=='CHOSEN'and identity or nil);pickerKey=nil end
  return true
 end
 function inputRuntime.tick()inputRuntime.discover(8);if pickerKey then picker.tick(getTime(),native)end end
 function inputRuntime.draw()if pickerKey then picker.draw()end end
 function inputRuntime.pickerState()return pickerKey and picker.snapshot()end
end
local ROOT='/SCRIPTS/TOOLS/AERODECK/'
function inputRuntime.modelIdentity(info)
 if type(info.filename)=='string'and info.filename~=''then return 'FILE:'..info.filename end
 if info.id~=nil then return 'ID:'..tostring(info.id)end
 return 'NAME:'..(info.name or'MODEL')
end
local started, page, palette, failure, modelName
local referenceUi,ensureReferenceUi,shell,frame
local packPicker,modelImage
local quick={active=false,focus=1,ignoreRelease=false,rows={}}
local transportStop=fcLink.stop
fcLink.stop=function()quick.active=false;inputRuntime.stop();if packPicker then packPicker.stop()end;if referenceUi then referenceUi.stop()end;transportStop()end
local flightResetJob,nativeResetError
local diagnosticView=1
local session,sessionState,sharedData,modelIdentity
local navUtility,positionCode,homeCode,positionCodeLat,positionCodeLon,homeCodeLat,homeCodeLon
local retainedSession=false
local runtimeServices=(function()
 local owner,logger,modelFile,timerRevision,timerFile,logEnabled,logFile=nil,nil,nil,-1,nil,nil,nil
 local observed={}
 local failureWords={'ERROR','FAILED','TIMEOUT','INVALID','UNAVAILABLE','REJECTED','UNSUPPORTED'}
 local empty={}
 local function record(kind,value)
  if logger and type(value)=='string'and value~=''then logger.record(kind,value)end
 end
 local function observe(kind,value)
  if type(value)~='string'or value==''then value=nil end
  if observed[kind]~=value then observed[kind]=value;if value then record(kind,value)end end
 end
 local function modelInfo(info)
  modelFile=type(info)=='table'and type(info.filename)=='string'and info.filename~=''and info.filename or nil
 end
 local function init(info)
  modelInfo(info);timerRevision=-1
  if not owner then
   local chunk=loadScript and loadScript('/SCRIPTS/TOOLS/AERODECK/timer-owner.lua');local factory=chunk and chunk()
   owner=factory and factory.new and factory.new({getTimer=model.getTimer,setTimer=model.setTimer,resetTimer=model.resetTimer,getModelId=function()return modelFile end})or nil
  end
  if not logger then
   local chunk=loadScript and loadScript('/SCRIPTS/TOOLS/AERODECK/diagnostics-log.lua');local factory=chunk and chunk()
   logger=factory and factory.new and factory.new({io=io,clock=getTime,getDateTime=getDateTime,remove=del,rename=rename})or nil
  end
 end
 local function failureStatus(status)
  if type(status)~='string'then return nil end
  for _,word in ipairs(failureWords)do if string.find(status,word,1,true)then return status end end
 end
 local function update(d,flight)
  local revision=configuration.revision()
  if owner then
   if revision~=timerRevision or modelFile~=timerFile then owner.configure({host=configuration.get('timerHost'),timerIndex=configuration.get('timerIndex')});timerRevision=revision;timerFile=modelFile end
   owner.update(d.armed);d.timerOwner=owner.snapshot();d.timerError=d.timerOwner.error
   d.timerOwnershipWarning=d.timerOwner.ownershipLost and(d.timerOwner.error or'NATIVE TIMER OWNERSHIP LOST')or nil
  elseif configuration.get('timerHost')=='AERODECK'then d.timerError='TIMER MODULE UNAVAILABLE' end
  if logger then
   local enabled=configuration.get('errorLog')==1
   if enabled~=logEnabled or modelFile~=logFile then
    logger.configure(enabled,modelFile or 'MODEL ID UNAVAILABLE');logEnabled=enabled;logFile=modelFile;observed={}
   end
   d.errorLog=logger.snapshot();d.logError=d.errorLog.error
   if enabled then
    local state=fcLink.state or empty;local video=fcLink.videoState();local operation=video.operation or empty
    observe('MSP',failureStatus(state.status));observe('FC INFO',state.infoError)
    observe('VTX',operation.error);observe('VTX STATUS',failureStatus(video.status));observe('VTX TABLE',video.tableError or video.cacheError)
    observe('SESSION',d.sessionError or(flight and flight.lastError));observe('MODEL TIMER',flight and flight.timerError)
    observe('POWER',d.powerError or failureStatus(d.powerState and d.powerState.condition));observe('TIMER OWNER',d.timerError or d.timerOwnershipWarning);observe('NATIVE RESET',d.nativeResetError)
   end
  elseif configuration.get('errorLog')==1 then d.logError='LOG MODULE UNAVAILABLE' end
 end
 local function release()
  -- close() can be called outside run/background: refresh native identity before
  -- considering restoration, so old settings never reach a different model.
  if model and model.getInfo then local ok,info=pcall(model.getInfo);if ok then modelInfo(info)else modelFile=nil end end
  if owner and owner.snapshot().owned then local ok,why=owner.release();if not ok then record('TIMER OWNER',why)end;return ok,why end
  return true
 end
 return {init=init,modelInfo=modelInfo,update=update,release=release,record=record,
  timer=function()return owner and owner.snapshot()end,resetTimer=function()if owner and owner.snapshot().owned then return owner.reset()end;return false,'NOT OWNED'end,
  log=function()return logger and logger.snapshot()end,
  flush=function()
   if not logger then return false,'LOG MODULE UNAVAILABLE'end
   if retainedSession then if logger.beginFlush then return logger.beginFlush()end;return false,'LOG TRANSACTION API UNAVAILABLE'end
   return logger.flush()
  end,
  stepLog=function()if logger and logger.stepFlush then return logger.stepFlush(modelFile)end;return false,'LOG TRANSACTION API UNAVAILABLE'end}
end)()
local lastSample=-100
inputRuntime.sampleRevision=-1;inputRuntime.sampleBatteryRevision=-1;inputRuntime.serviceSerial=0
local serviceData,resetRuntime
local foreground=false
local menuOpen,menuIndex,controlFocus,exitOpen,exitChoice,configReturn,armReturn=false,1,0,false,1,1,1
local backgroundReady=false
local pages={'flight','nav','power','system','console','console','console','console'}
local sectionRoots={1,5,7,11,8,6}
local scenario,zoom=1,2
local sensors,sensorOffset={},0
local sensorMode='LIVE'
local lastFrame=-100
local pi=math.pi
local function round(x) return math.floor(x+0.5) end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function ink(c) lcd.setColor(CUSTOM_COLOR,c) end
local function rect(x,y,w,h,c)
 if w<=0 or h<=0 then return end
 ink(c);lcd.drawFilledRectangle(round(x),round(y),round(w),round(h),CUSTOM_COLOR)
end
local function line(x,y,a,b,c)
 ink(c);lcd.drawLine(round(x),round(y),round(a),round(b),SOLID,CUSTOM_COLOR)
end
local function clip(x,y,a,b,xmin,xmax,ymin,ymax,c)
 ink(c);lcd.drawLineWithClipping(round(x),round(y),round(a),round(b),xmin,xmax,ymin,ymax,SOLID,CUSTOM_COLOR)
end
local function circle(x,y,r,c)
 ink(c);lcd.drawCircle(round(x),round(y),round(r),CUSTOM_COLOR)
end
local function triangle(x,y,heading,size,c)
 local a=heading*pi/180
 local function pt(dx,dy) return x+dx*math.cos(a)-dy*math.sin(a), y+dx*math.sin(a)+dy*math.cos(a) end
 local x1,y1=pt(0,-size);local x2,y2=pt(-size*.65,size*.7);local x3,y3=pt(size*.65,size*.7)
 ink(c);lcd.drawFilledTriangle(round(x1),round(y1),round(x2),round(y2),round(x3),round(y3),CUSTOM_COLOR)
end
local function changePage(nextPage)
 if nextPage==page and backgroundReady then lastFrame=-100;return end
 if page==5 then telemetry.release() end
 if referenceUi and page==10 and nextPage~=10 then referenceUi.stop()end
 page=nextPage
 -- Flat pages retain their bounded icon masks across navigation.
 backgroundReady=false
 renderStats.background='FLAT / NATIVE'
 backgroundReady=true
 if page==5 then telemetry.refresh() end;lastFrame=-100
end
-- Widgets have a20,000-instruction callback allowance. Split cold work into
-- explicit phases; physical-input inventories additionally advance in batches.
function inputRuntime.initPhase(number,state)
 if number==1 then
  local chunk=loadScript and loadScript(ROOT..'display.lua');local factory=chunk and chunk()
  if factory then display,displayError=factory.new(nativeLcd,LCD_W or 480,LCD_H or 272);if display then lcd=display.lcd end
  elseif(LCD_W and LCD_W~=480)or(LCD_H and LCD_H~=272)then displayError='DISPLAY MODULE UNAVAILABLE'end
 elseif number==2 then batteryConfig.init()
 elseif number==3 then configuration.init();page=({1,5,2,7,3,4,6,8})[configuration.get('startPage')]
 elseif number==4 then telemetry.init()
 elseif number==5 then inputRuntime.init(state.deferred)
 elseif number==6 then
  local provider=inputRuntime.provider
  if state.deferred and provider and provider.ready and not provider.ready()then local ready,progress=provider.refreshStep(32);if progress then state.view.initializing='INPUTS / '..progress.stage..' '..progress.index end;if not ready then return false end end
 elseif number==7 then fcLink.init()
 elseif number==8 then
  runtimeServices.init(state.info)
  local chunk=loadScript and loadScript(ROOT..'navigation-utils.lua');navUtility=chunk and chunk()
  positionCode=nil;homeCode=nil;positionCodeLat=nil;positionCodeLon=nil;homeCodeLat=nil;homeCodeLon=nil
 elseif number==9 then
  local chunk=loadScript and loadScript(ROOT..'session.lua');local factory=chunk and chunk()
  session=factory and factory.new and factory.new({getTimer=model.getTimer,getDateTime=getDateTime,resetTimer=model.resetTimer})or nil
  failure=not session and'SESSION MODULE UNAVAILABLE'or nil
 elseif number==10 then
  backgroundReady=false;sensorOffset=0;sensors={};scenario=1;zoom=2
  if resetRuntime then resetRuntime()end
 elseif number==11 then telemetry.prime()
 elseif number==12 and state.deferred then fcLink.update(getTime())
 elseif number==13 then inputRuntime.primeArm()
 elseif number==14 and state.deferred then return inputRuntime.primeIcons(state)
 elseif number==15 and state.deferred then telemetry.prepareExtrema()
 end
 return true
end
local function init()
 menuOpen=false;controlFocus=0;exitOpen=false;configReturn=1;armReturn=1
 display=nil;displayError=nil;lcd=nativeLcd;failure=nil;lastFrame=-100
 local info=model.getInfo();modelName=info.name or'MODEL';modelIdentity=inputRuntime.modelIdentity(info);started=getTime();page=1
 renderStats.radioVersion=getVersion and tostring(getVersion())or'--';renderStats.ramKB=nil;renderStats.peakKB=nil
 sharedData=nil;sessionState=nil;lastSample=-100;inputRuntime.sampleRevision=-1;inputRuntime.sampleBatteryRevision=-1;inputRuntime.pendingData=nil;foreground=false;alertsMuted=false
 local state={info=info,deferred=retainedSession,phase=1,view={initializing='DISPLAY',ok=false}}
 if retainedSession then inputRuntime.startup=state
 else inputRuntime.startup=nil;for number=1,13 do inputRuntime.initPhase(number,state)end end
end
function inputRuntime.advanceStartup()
 local state=inputRuntime.startup;if not state then return false end
 local info=model.getInfo()
 if inputRuntime.modelIdentity(info)~=modelIdentity then init();return true end
 modelName=info.name or'MODEL'
 local names={'DISPLAY','BATTERY SETTINGS','APPLICATION SETTINGS','TELEMETRY','INPUT PROVIDER','INPUT INVENTORY','FC CONNECTION','RUNTIME SERVICES','FLIGHT SESSION','SESSION RESET','SOURCE BINDINGS','FC CLIENT','ARMING DECODER','ICONS','NATIVE EXTREMA'}
 state.view.initializing=names[state.phase]
 if inputRuntime.initPhase(state.phase,state)then
  state.phase=state.phase+1
  if state.phase>15 then inputRuntime.startup=nil end
 end
 return true -- Completion also yields; normal work starts next callback.
end
local function closeApp()
 local ok,why=runtimeServices.release();local owner=runtimeServices.timer()
 if ok==false and owner and owner.owned then return false,why end
 inputRuntime.stop();if packPicker then packPicker.stop()end;fcLink.stop();if referenceUi then referenceUi.stop()end;foreground=false;return true
end
local function leaveFull()
 if retainedSession then inputRuntime.stop();if packPicker then packPicker.stop()end;fcLink.stop();if referenceUi then referenceUi.stop()end;foreground=false;return true end
 local ok,why=closeApp();if not ok and shell then shell.notify('TIMER RELEASE FAILED / '..tostring(why))end;return ok,why
end
local function label(x,y,s,c,size,right)
 ink(c);lcd.drawText(x,y,tostring(s),CUSTOM_COLOR+(size or SMLSIZE)+(right and RIGHT or 0))
end
-- Center the actual EdgeTX font box, rather than assuming a short glyph height.
local vlabel=(function()
 local heights={}
 return function(x,y,h,s,c,size,right)
  size=size or SMLSIZE
  local height=heights[size]
  if not height then
   if lcd.sizeText then local _,measured=lcd.sizeText('Ag',size);if type(measured)=='number'and measured>0 then height=measured end end
   height=height or(size==MIDSIZE and 29 or size==DBLSIZE and 38 or 17);heights[size]=height
  end
  label(x,y+math.floor((h-height)/2),s,c,size,right)
 end
end)()
local function smallText(x,y,s,c)
 ink(c);lcd.drawText(x,y,s,SMLSIZE+CUSTOM_COLOR)
end
function inputRuntime.progress(message)
 local p=palette or{black=nativeLcd.RGB(5,12,19),cyan=nativeLcd.RGB(104,221,237),white=nativeLcd.RGB(232,242,245)}
 nativeLcd.setColor(CUSTOM_COLOR,p.black);nativeLcd.drawFilledRectangle(0,0,LCD_W or 480,LCD_H or 272,CUSTOM_COLOR)
 vlabel(20,78,40,'AERODECK',p.cyan,MIDSIZE)
 vlabel(20,126,28,message,p.white,SMLSIZE)
end
-- Measure with the radio font. Conservative fallback also supports LCD mocks.
local textWidth=(function()
 -- Native font metrics are stable. A bounded FIFO avoids measuring the same
 -- tape ticks/captions every frame without retaining an ever-growing history.
 local api,cache,slots,cursor=nil,{},{},1
 return function(s,size)
  s=tostring(s);size=size or SMLSIZE
  if lcd.sizeText~=api then api=lcd.sizeText;cache={};slots={};cursor=1 end
  local row=cache[size];local w=row and row[s]
  if w~=nil then return w end
  if api then w=api(s,size)end
  if type(w)~='number'then w=#s*(size==MIDSIZE and 16 or 8)end
  local old=slots[cursor]
  if old then
   local previous=cache[old.font];previous[old.text]=nil;previous.count=previous.count-1
   if previous.count==0 then cache[old.font]=nil end
  else old={};slots[cursor]=old end
  row=cache[size];if not row then row={count=0};cache[size]=row end
  row[s]=w;row.count=row.count+1;old.font=size;old.text=s
  cursor=cursor%128+1
  return w
 end
end)()
local function fittedText(s,width,size)
 s=tostring(s);size=size or SMLSIZE
 if textWidth(s,size)<=width then return s,size end
 if not TINSIZE or size~=TINSIZE then size=SMLSIZE end
 if textWidth(s,size)<=width then return s,size end
 local shown=s
 while #shown>0 and textWidth(shown..'...',size)>width do shown=string.sub(shown,1,-2)end
 return shown..'...',size
end
local function wrappedText(s,width,size)
 local rows,current={},''
 for word in string.gmatch(s or '', '%S+')do
  local candidate=current=='' and word or current..' '..word
  if current~='' and textWidth(candidate,size)>width then rows[#rows+1]=current;current=word else current=candidate end
  if textWidth(current,size)>width then
   while #current>0 and textWidth(current..'...',size)>width do current=string.sub(current,1,-2)end
   current=current..'...'
  end
 end
 if current~='' then rows[#rows+1]=current end
 return rows
end
local function bearing(x,y)
 local xx,yy=-y,-x
 if xx>0 then return math.atan(yy/xx)
 elseif xx<0 then return math.atan(yy/xx)+(yy>=0 and pi or -pi)
 elseif yy~=0 then return yy>=0 and pi/2 or -pi/2 end
 return 0
end
local navDemo,navHome,navTrack,navLast,navCurrent=false,nil,{},-100,nil
local navConfigured=false
local navPlot
local function navReset()
 navHome=nil;navTrack={};navLast=-100;navCurrent=nil
 if navPlot then navPlot.reset()end;inputRuntime.navPlotAt=-100;inputRuntime.navPlotYieldAt=-100
end
local function gpsPosition(v)
 if type(v)=='table' and type(v.lat)=='number' and type(v.lon)=='number' and v.lat==v.lat and v.lon==v.lon and math.abs(v.lat)<=90 and math.abs(v.lon)<=180 then return v end
end
local function atan2(y,x)
 if x>0 then return math.atan(y/x) elseif x<0 then return math.atan(y/x)+(y>=0 and pi or -pi) elseif y>0 then return pi/2 elseif y<0 then return -pi/2 end
 return 0
end
local function geo(a,b)
 local r=pi/180;local la,lb=a.lat*r,b.lat*r;local dl=(b.lon-a.lon)*r;local dp=lb-la
 local h=clamp(math.sin(dp/2)^2+math.cos(la)*math.cos(lb)*math.sin(dl/2)^2,0,1)
 local dist=6371000*2*atan2(math.sqrt(h),math.sqrt(1-h))
 local angle=(atan2(math.sin(dl)*math.cos(lb),math.cos(la)*math.sin(lb)-math.sin(la)*math.cos(lb)*math.cos(dl))/r+360)%360
 return dist,angle
end
-- Exact geodesic history projection. Existing geo/round/pi helpers are reused.
-- Session owns immutable track points; this cache never changes or truncates them.
navPlot=(function()
 local maximum=180
 local scales={.35,.7,1.4}
 local s={frame=nil,pending=false,completed=0,total=0,cacheCount=0}
 local cache,slots={},{}
 local nextSlot=1
 local ownerTrack,ownerHome=false,false
 local ownerLat,ownerLon,cacheLat,cacheLon
 local frames={{origin={},path={}},{origin={},path={}}}
 local job,refs=nil,{}
 local failed
 local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
 local function valid(p)return type(p)=='table'and finite(p.lat)and finite(p.lon)and math.abs(p.lat)<=90 and math.abs(p.lon)<=180 end
 local function clearCache()
  cache={};slots={};nextSlot=1;cacheLat=nil;cacheLon=nil;s.cacheCount=0
 end
 local function clear()
  clearCache();job=nil;refs={};failed=nil
  frames={{origin={},path={}},{origin={},path={}}}
  s.frame=nil;s.pending=false;s.completed=0;s.total=0;s.error=nil;s.waiting=false
 end
 local function owned(home,track)
  local lat=valid(home)and(home.lat+0.0)or nil;local lon=valid(home)and(home.lon+0.0)or nil
  if ownerTrack~=track or ownerHome~=home or ownerLat~=lat or ownerLon~=lon then
   clear();ownerTrack=track;ownerHome=home;ownerLat=lat;ownerLon=lon
  end
  if type(track)~='table'then s.error='INVALID TRACK';return false end
  if home~=nil and not valid(home)then s.error='INVALID HOME';return false end
  if #track>maximum then s.error='TRACK LIMIT EXCEEDED';return false end
  return true
 end
 local function setOrigin(origin)
  if cacheLat~=origin.lat or cacheLon~=origin.lon then
   clearCache();cacheLat=origin.lat;cacheLon=origin.lon
  end
 end
 local function projected(origin,p)
  local entry=cache[p]
  if entry then return entry.east,entry.north,false end
  if not valid(p)then return nil,nil,false,'INVALID TRACK POINT'end
  local distance,angle=geo(origin,p);local radians=angle*pi/180
  local east,north=distance*math.sin(radians),distance*math.cos(radians)
  if not finite(east)or not finite(north)then return nil,nil,true,'INVALID PROJECTION'end
  entry=slots[nextSlot]
  if entry then if cache[entry.point]==entry then cache[entry.point]=nil end
  else entry={};slots[nextSlot]=entry;s.cacheCount=s.cacheCount+1 end
  nextSlot=nextSlot%maximum+1
  entry.point=p;entry.east=east;entry.north=north;cache[p]=entry
  return east,north,true
 end
 local function sameTarget(target,origin,track,zoom)
  return target and target.track==track and target.count==#track and target.first==track[1]and target.last==track[#track]
   and target.zoom==zoom and target.origin.lat==(origin.lat+0.0)and target.origin.lon==(origin.lon+0.0)
 end
 local api={}
 function api.reset()
  clear();ownerTrack=false;ownerHome=false;ownerLat=nil;ownerLon=nil
  return s
 end
 function api.snapshot()return s end
 function api.prime(home,pos,track)
  if not owned(home,track)then return s,false end
  if not home then return s,false end
  local p=track[#track];if not p then return s,false end
  setOrigin(home)
  local _,_,computed,err=projected(home,p)
  if err then s.error=err end
  return s,computed
 end
 function api.step(home,pos,track,zoom,now,maxGeometry,maxPoints)
  if not owned(home,track)then return s,0,0 end
  if not finite(zoom)or zoom%1~=0.0 or not scales[zoom]then s.error='INVALID ZOOM';return s,0,0 end
  if maxGeometry==nil then maxGeometry=8 end;if maxPoints==nil then maxPoints=32 end
  if not finite(maxGeometry)or maxGeometry%1~=0.0 or maxGeometry<1 or not finite(maxPoints)or maxPoints%1~=0.0 or maxPoints<1 then
   s.error='INVALID STEP BUDGET';return s,0,0
  end
  maxGeometry=math.min(maxGeometry,8);maxPoints=math.min(maxPoints,32)
  if s.error=='INVALID STEP BUDGET'then s.error=nil end
  if not job then
   local origin=home or(valid(pos)and pos or nil)
   if not origin then s.waiting=true;return s,0,0 end
   s.waiting=false
   if sameTarget(s.frame,origin,track,zoom)or sameTarget(failed,origin,track,zoom)then return s,0,0 end
   -- Capture refs/origin once. New current coordinates, points and zoom wait
   -- for this coherent job to finish instead of cancelling it every GPS sample.
   local frame=frames[1]~=s.frame and frames[1]or frames[2]
   frame.origin.lat=origin.lat+0.0;frame.origin.lon=origin.lon+0.0
   frame.track=track;frame.count=#track;frame.first=track[1];frame.last=track[#track]
   frame.zoom=zoom;frame.scale=scales[zoom];frame.home=home;frame.startedAt=now;frame.completedAt=nil
   for i=1,frame.count do refs[i]=track[i]end
   for i=frame.count+1,#refs do refs[i]=nil end
   for i=frame.count+1,#frame.path do frame.path[i]=nil end
   setOrigin(frame.origin);job=frame;job.at=1
   s.pending=true;s.waiting=false;s.error=nil;s.completed=0;s.total=frame.count
   return s,0,0 -- Starting/copying the bounded job gets its own callback.
  end
  local geometryCount,processed=0,0
  while job.at<=job.count and processed<maxPoints and geometryCount<maxGeometry do
   local p=refs[job.at];local east,north,computed,err=projected(job.origin,p)
   if computed then geometryCount=geometryCount+1 end
   if err then failed=job;job=nil;s.pending=false;s.error=err;return s,geometryCount,processed end
   local pixel=job.path[job.at];if not pixel then pixel={};job.path[job.at]=pixel end
   pixel.x=round(104+east*job.scale);pixel.y=round(141-north*job.scale);pixel.point=p
   job.at=job.at+1;processed=processed+1
  end
  s.completed=job.at-1
  if job.at>job.count then
   job.completedAt=now;s.frame=job;job=nil;failed=nil;s.pending=false;s.error=nil
  end
  return s,geometryCount,processed
 end
 return api
end)()

function inputRuntime.stepNavPlot(now)
 local before=navPlot.snapshot();local pending,frame=before.pending,before.frame
 local view,geometry,processed=navPlot.step(navHome,navCurrent,navTrack,zoom,now,2,16)
 if processed>0 or view.pending~=pending or view.frame~=frame then inputRuntime.navPlotAt=now end
 return view,geometry,processed
end
function inputRuntime.navPlotPriority(now)
 local s=navPlot.snapshot();local origin=navHome or navCurrent
 if s.error or type(origin)~='table'or type(origin.lat)~='number'or type(origin.lon)~='number'then return false end
 local f=s.frame;local n=#navTrack
 local dirty=s.pending or not f or f.track~=navTrack or f.count~=n or f.first~=navTrack[1]or f.last~=navTrack[n]
  or f.zoom~=zoom or f.home~=navHome or f.origin.lat~=(origin.lat+0.0)or f.origin.lon~=(origin.lon+0.0)
 local previous=inputRuntime.navPlotAt or -100;local yielded=inputRuntime.navPlotYieldAt or -100
 if dirty and(now<previous or now-previous>=20)and(now<yielded or now-yielded>=20)then
  inputRuntime.navPlotYieldAt=now;return true
 end
 return false
end
local function navAction(action)
 if action=='mode' then telemetry.toggle()
 elseif action=='zoom' then zoom=zoom%3+1
 elseif action=='home' and session and session.setHome() then
  sessionState=session.snapshot();navHome=sessionState.home;navTrack=sessionState.track
  navPlot.reset();inputRuntime.navPlotAt=-100;inputRuntime.navPlotYieldAt=-100
 end
 lastFrame=-100
end
local function navSnapshot(d)
 return navCurrent,d.speed,d.alt,d.sats,d.course
end
local function navigation(d)
 local p=palette
 local pos,speed,alt,sats,heading=navSnapshot(d)
 rect(5,61,470,183,p.black)
 local function val(v,fmt,unit) return type(v)=='number' and string.format(fmt or '%.0f',v)..(unit or '') or '--' end
 -- North-up local plot; ring spacing is labelled in metres, no map imagery implied.
 rect(10,64,188,151,p.tape)
 for x=14,194,20 do line(x,65,x,214,p.dim) end
 for y=65,214,20 do line(11,y,197,y,p.dim) end
 local plot=navPlot.snapshot();local frame=plot.frame
 local cx,cy=104,141;local scale=frame and frame.scale or({.35,.7,1.4})[zoom]
 circle(cx,cy,60,p.border);circle(cx,cy,30,p.border)
 smallText(16,69,'N',p.cyan);line(21,96,21,87,p.cyan);triangle(21,86,0,3,p.cyan)
 smallText(126,199,tostring(round(60/scale))..' m',p.muted)
 local origin=frame and frame.origin or navHome or pos
 local function pt(a)
  local dist,angle=geo(origin,a);local rad=angle*pi/180
  return cx+dist*math.sin(rad)*scale,cy-dist*math.cos(rad)*scale
 end
 if origin then
  -- Coordinates are projected and rounded outside painting. Draw the complete
  -- published path every callback using native clipping and a single ink setup.
  if frame then
   ink(p.cyan);local path=frame.path
   for i=2,frame.count do local a,b=path[i-1],path[i]
    lcd.drawLineWithClipping(a.x,a.y,b.x,b.y,11,197,65,214,SOLID,CUSTOM_COLOR)
   end
  end
  if navHome then
   line(cx-5,cy,cx,cy-5,p.orange);line(cx,cy-5,cx+5,cy,p.orange);rect(cx-3,cy,6,5,p.orange)
  end
  if pos then
   local x,y=pt(pos)
   if x>=20 and x<=188 and y>=74 and y<=203 then
    if heading then triangle(x,y,heading,7,p.white) else circle(x,y,4,p.white) end
   else smallText(18,183,'AIRCRAFT OFF PLOT',p.orange) end
  end
 else smallText(28,129,'WAITING FOR GPS',p.muted) end
 if not pos and origin then smallText(18,183,'TRACK / LAST KNOWN',p.orange) end
 if plot.error then smallText(32,69,'TRACK UNAVAILABLE',p.orange)
 elseif plot.pending then smallText(32,69,'TRACK '..plot.completed..'/'..plot.total,p.muted)end
 local function row(y,label,value,col)
  smallText(208,y,label,p.muted);ink(col or p.white);lcd.drawText(468,y,value,SMLSIZE+CUSTOM_COLOR+RIGHT)
 end
 row(65,'AIRCRAFT LAT',pos and val(pos.lat,'%.6f') or '--')
 row(83,'AIRCRAFT LON',pos and val(pos.lon,'%.6f') or '--')
 row(101,'COURSE',pos and val(heading,'%.0f',' deg') or '--')
 line(208,120,469,120,p.border)
 row(126,'HOME LAT',navHome and val(navHome.lat,'%.6f') or '--',p.orange)
 row(144,'HOME LON',navHome and val(navHome.lon,'%.6f') or '--',p.orange)
 local dist,angle;if navHome and pos then dist,angle=geo(pos,navHome) end
 row(168,'TO HOME',val(dist,'%.0f',' m'),p.cyan)
 row(187,'BEARING',dist and dist>=1 and val(angle,'%.0f',' deg') or '--',p.cyan)
 smallText(208,206,val(sats)..' SAT / '..val(speed,'%.1f',' km/h')..' / '..val(alt,'%.0f',' m'),p.muted)
 for _,b in ipairs({{10,100,'REFRESH'},{117,90,'ZOOM +'},{214,112,'SET HOME'}}) do
  rect(b[1],222,b[2],21,p.tape);vlabel(b[1]+8,222,21,b[3],p.green)
 end
 -- Fixed orientation, not an action. Keep the three existing touch bounds.
 vlabel(341,222,21,'NORTH UP',p.muted)
end

-- Drop-in renderer fragment. Reuses navSnapshot(d); no additional sensor reads.
-- Nine17px rows fit between the64px body top and222px action bar.
local gpsView,satellitePage='DETAILS',1
local gpsDetails=(function()
 local function val(v,pattern,unit)
  return type(v)=='number' and v==v and string.format(pattern or '%.0f',v)..(unit or '') or '--'
 end
 local function row(index,title,value,home)
  local p=palette;local y=64+(index-1)*17
  rect(108,y,368,17,index%2==0 and p.black or p.tape)
  vlabel(116,y,17,title,p.muted)
  vlabel(468,y,17,value,value=='--' and p.muted or home and p.orange or p.white,SMLSIZE,true)
 end
 local function button(x,w,title,enabled)
  local p=palette
  rect(x,222,w,21,p.tape);rect(x,222,w,1,p.border)
  vlabel(x+8,222,21,title,enabled and p.green or p.muted)
 end
 return function(d)
  local p=palette
  local pos,speed,alt,sats,heading=navSnapshot(d)
  if gpsView=='SATELLITES'then
   local state=fcLink.state;local fresh=state.active and state.satellitesAt and getTime()>=state.satellitesAt and getTime()-state.satellitesAt<=800
   local entries=fresh and state.satellites or{}
   local pages=math.max(1,math.ceil(#entries/6));satellitePage=math.min(satellitePage,pages)
   rect(8,64,464,19,p.tape)
   for _,col in ipairs({{16,'SV ID'},{83,'SYSTEM / CHANNEL'},{278,'Q RAW'},{365,'SIGNAL'},{427,'USED'}})do vlabel(col[1],64,19,col[2],p.muted,TINSIZE or SMLSIZE)end
   if #entries==0 then
    vlabel(18,99,22,fresh and 'NO SATELLITES IN FC REPLY'or 'NO CURRENT SATELLITE DETAIL',p.orange)
    local shown,size=fittedText(state.satellitesStatus or state.status or 'WAITING',440,SMLSIZE)
    vlabel(18,128,22,shown,p.muted,size)
    vlabel(18,157,22,'A satellite count is separate from this list.',p.muted)
   end
   for i=1,6 do local entry=entries[(satellitePage-1)*6+i]
    if entry then local y=84+(i-1)*18;rect(8,y,464,18,i%2==0 and p.black or p.tape)
     vlabel(16,y,18,tostring(entry.id),p.white)
     vlabel(83,y,18,entry.constellation or 'CHANNEL '..tostring(entry.channelOrGnss),p.white)
     vlabel(278,y,18,tostring(entry.qualityRaw),p.muted)
     vlabel(365,y,18,tostring(entry.signal),p.cyan)
     vlabel(427,y,18,entry.used==nil and '--'or entry.used and 'YES'or 'NO',entry.used and p.green or p.muted)
    end
   end
   rect(10,197,132,21,p.tape);vlabel(18,197,21,'< PREVIOUS',satellitePage>1 and p.cyan or p.muted)
   vlabel(240,197,21,satellitePage..' / '..pages,p.muted)
   rect(330,197,142,21,p.tape);vlabel(338,197,21,'NEXT >',satellitePage<pages and p.cyan or p.muted)
  elseif gpsView=='RECOVERY'then
   rect(8,64,464,154,p.tape)
   vlabel(18,65,18,pos and'CURRENT POSITION / PLUS CODE'or'LAST KNOWN / PLUS CODE',pos and p.cyan or p.orange)
   local code=pos and d.plusCode or d.lastPlusCode
   local shown,font=fittedText(code or'NO POSITION RECEIVED',440,MIDSIZE);vlabel(18,86,32,shown,code and p.white or p.muted,font)
   local relative=d.relativeHome;local direction=relative and(math.abs(relative)<.5 and'AHEAD'or(relative<0 and'LEFT 'or'RIGHT ')..string.format('%.0f deg',math.abs(relative)))or'--'
   local entries={{'Home Plus Code',d.homePlusCode or'--'},{'Home relative to GPS course',direction},{'ETA at current ground speed',d.homeETA or'--'},{'Local home reference',navHome and navHome.source or'NOT SET'},{'Body yaw',val(d.yaw,'%.0f',' deg')}}
   for i,r in ipairs(entries)do local y=121+(i-1)*19;vlabel(18,y,19,r[1],p.muted);local text,size=fittedText(r[2],204,SMLSIZE);vlabel(462,y,19,text,p.white,size,true)end
  elseif gpsView=='QUALITY'then
   rect(8,64,464,154,p.tape)
   local dist=d.session and d.session.homeDistance
   local eta=dist and speed and speed>0 and dist/(speed/3.6)
   local quality=d.gpsQuality
   local rows={{'Reported position fix',d.fix==nil and 'NOT REPORTED'or d.fix and 'FIX'or 'NO FIX'},
    {'Reported quality index',quality and val(quality.qualityIndex)or 'NOT REPORTED'},
    {'Physical HDOP','NOT REPORTED'},
    {'FC home fix',quality and quality.homeFix~=nil and(quality.homeFix and 'SET'or 'NOT SET')or 'NOT REPORTED'},
    {'FC home distance',val(d.homeDistance,'%.0f',' m')},
    {'FC home bearing',val(d.homeBearing,'%.0f',' deg')},
    {'Local home / at current GS',eta and string.format('%02d:%02d ETA',math.floor(eta/60),math.floor(eta)%60)or '--'},
    {'Home reference',navHome and navHome.source or 'NOT SET'}}
   for i,r in ipairs(rows)do local y=65+(i-1)*19;vlabel(17,y,19,r[1],p.muted);local text,font=fittedText(r[2],210,SMLSIZE);vlabel(463,y,19,text,p.white,font,true)end
  else
  rect(4,64,100,153,p.tape);rect(4,64,3,153,p.cyan)
  smallText(13,70,'SATELLITES',p.muted)
  label(12,89,val(sats),type(sats)=='number' and p.green or p.muted,DBLSIZE)
  line(12,125,96,125,p.border)
  smallText(13,135,'FIX',p.muted)
  smallText(13,152,d.fix==nil and 'NOT REPORTED'or d.fix and 'REPORTED'or 'NO FIX',d.fix and p.green or p.orange)
  line(12,174,96,174,p.border)
  smallText(13,181,'HOME',p.muted)
  smallText(13,198,navHome and 'LOCAL SET' or 'NOT SET',navHome and p.orange or p.muted)
  local dist,angle
  if pos and navHome then dist,angle=geo(pos,navHome)end
  row(1,'Aircraft LAT',pos and val(pos.lat,'%.7f') or '--')
  row(2,'Aircraft LON',pos and val(pos.lon,'%.7f') or '--')
  row(3,'Ground speed',val(speed,'%.1f',' km/h'))
  row(4,'Altitude',val(alt,'%.0f',' m'))
  row(5,'GPS course',val(heading,'%.0f',' deg'))
  row(6,'Home LAT',navHome and val(navHome.lat,'%.7f') or '--',true)
  row(7,'Home LON',navHome and val(navHome.lon,'%.7f') or '--',true)
  row(8,'Home distance',val(dist,'%.0f',' m'),true)
  row(9,'Bearing to home',dist and dist>=1 and val(angle,'%.0f',' deg') or '--',true)
  end
  button(10,132,'REFRESH SENSORS',true)
  button(148,150,'SET LOCAL HOME',pos~=nil)
  button(313,159,gpsView=='DETAILS'and 'SATELLITES >'or gpsView=='SATELLITES'and 'QUALITY >'or gpsView=='QUALITY'and'RECOVERY >'or 'DETAILS >',true)
 end
end)()

local function scanSensors()
 sensors={}
 if not model or not model.getSensor then return end
 for i=0,63 do
  local sensor=model.getSensor(i)
  if sensor and sensor.name and sensor.name~='' then
   local info=cachedTelemetryField(sensor.name)
   sensors[#sensors+1]={name=sensor.name,source=info and info.id,prec=sensor.prec or 0,unit=sensor.unit}
  end
 end
 sensorOffset=sensorOffset%(math.max(1,math.ceil(#sensors/5))*5)
end
local function systemPage()
 local p=palette
 rect(0,61,480,185,p.black)
 local first=#sensors>0 and sensorOffset+1 or 0
 local last=math.min(sensorOffset+5,#sensors)
 smallText(14,66,first..'-'..last..' / '..#sensors..' '..sensorMode..' >',p.cyan)
 smallText(185,66,'VALUE',p.muted);smallText(358,66,'STATUS',p.muted)
 if #sensors==0 then smallText(20,100,'No sensors discovered in this radio model.',p.white);smallText(20,124,'Use the radio Telemetry > Discover New menu.',p.muted)end
 for row=1,5 do
  local s=sensors[sensorOffset+row]
  if s then
   local y=84+(row-1)*26;rect(10,y-2,460,24,p.tape)
   local value,current
   if s.source then
    value,current=getSourceValue(s.source)
    if current and type(value)=='number'and value==value and math.abs(value)<math.huge then receivedSources[s.source]=true end
    if sensorMode~='LIVE'then
     local raw=getSourceValue(s.source+(sensorMode=='MIN'and 1 or 2))
     if type(raw)=='number'and raw==raw and math.abs(raw)<math.huge and(raw~=0.0 or receivedSources[s.source])then value=raw;current=true else value=nil;current=false end
    end
   end
   local shown='--'
   if current then
    if type(value)=='number' then shown=string.format('%.'..clamp(s.prec,0,3)..'f',value)
    elseif type(value)=='table' then shown='GPS / TABLE'
    elseif type(value)=='string' then shown=string.sub(value,1,20)end
   end
   vlabel(17,y-2,24,s.name,p.white);vlabel(185,y-2,24,shown,p.cyan);vlabel(358,y-2,24,current and(sensorMode=='LIVE'and'CURRENT'or'RAW '..sensorMode)or'STALE / NONE',current and p.green or p.orange)
  end
 end
 rect(10,222,224,21,p.tape);vlabel(18,222,21,'NEXT SOURCES >',p.green)
 rect(242,222,228,21,p.tape);vlabel(250,222,21,'REFRESH',p.green)
end
-- Reference: betaflight.com/docs/wiki/guides/current/Controls
-- Axis order: throttle, yaw, pitch, roll; -1 low, 0 centre, +1 high.
local stickMode,commandPage=2,1
local function stickCommands()
 frame('MANUAL STICK GUIDE',sharedData or{})
 if ensureReferenceUi and ensureReferenceUi()then
  referenceUi.drawGuide();local state=referenceUi.snapshot();stickMode=state.mode;commandPage=state.guidePage
 else label(15,90,'REFERENCE UI UNAVAILABLE',palette.orange)end
end

-- Original symbols remain a fallback for missing or unsupported image assets.
-- Geometry and image mappings are allocated once, never per frame.
local iconShapes={
 [0]={lines={{2,13,14,2},{14,2,26,13},{5,11,5,26},{5,26,23,26},{23,26,23,11},{11,26,11,17},{11,17,17,17},{17,17,17,26}}},
 [1]={circles={{14,14,12}},lines={{2,14,10,14},{18,14,26,14},{9,14,14,18},{14,18,19,14},{14,2,14,6},{14,22,14,26}}},
 [5]={lines={{3,3,25,3},{25,3,25,25},{25,25,3,25},{3,25,3,3},{3,10,25,10},{3,18,25,18},{12,3,12,25}},rects={{6,6,3,2},{16,6,6,2},{6,13,3,2},{16,13,6,2},{6,21,3,2},{16,21,6,2}}},
 [7]={circles={{14,10,8},{14,10,2}},lines={{7,15,14,26},{14,26,21,15}}},
 [11]={lines={{2,9,26,9},{26,9,26,20},{26,20,22,23},{22,23,17,23},{17,23,14,19},{14,19,11,23},{11,23,6,23},{6,23,2,20},{2,20,2,9},{5,9,3,2},{23,9,25,2}},rects={{6,13,5,5},{17,13,5,5}}},
 [8]={lines={{2,6,26,6},{2,14,26,14},{2,22,26,22}},rects={{7,2,4,9},{19,10,4,9},{11,18,4,9}}},
 [13]={lines={{18,2,14,6},{14,6,14,11},{14,11,3,22},{3,22,3,25},{3,25,6,27},{6,27,9,26},{9,26,20,15},{20,15,24,15},{24,15,27,11},{27,11,27,6},{27,6,23,10},{23,10,19,6},{19,6,22,2},{22,2,18,2}},circles={{6,23,1}}},
 [2]={lines={{4,23,9,7},{9,7,20,20},{20,20,25,4}},circles={{4,23,2},{9,7,2},{20,20,2},{25,4,2}}},
 [3]={lines={{2,6,23,6},{23,6,23,23},{23,23,2,23},{2,23,2,6},{15,8,9,16},{9,16,15,16},{15,16,11,22},{11,22,20,12},{20,12,14,12},{14,12,15,8}},rects={{25,11,2,8}}},
 [9]={lines={{14,13,14,26},{8,26,20,26},{8,5,5,9},{5,9,8,14},{20,5,23,9},{23,9,20,14},{4,1,0,9},{0,9,4,18},{24,1,28,9},{28,9,24,18}},circles={{14,9,2}}},
 [10]={lines={{14,1,25,5},{25,5,25,14},{25,14,20,22},{20,22,14,27},{14,27,8,22},{8,22,3,14},{3,14,3,5},{3,5,14,1}},rects={{13,7,3,9},{13,19,3,3}}},
 [6]={circles={{8,16,4},{20,16,4}},lines={{2,7,26,7},{26,7,26,26},{26,26,2,26},{2,26,2,7},{14,1,14,7},{8,16,6,13},{20,16,21,13}},rects={{6,12,2,2},{20,12,2,2}}},
 [4]={lines={{1,15,6,15},{6,15,10,5},{10,5,15,24},{15,24,20,10},{20,10,23,15},{23,15,28,15}}},
 [12]={circles={{14,14,12}},rects={{13,6,3,3},{13,12,3,10}}}
}
-- Native 30px navigation / 18px detail masks. Cache successes and failures across pages.
local iconImages=(function()
 local names={[0]='home',[1]='speed',[5]='table_chart',[7]='my_location',
  [11]='head_mounted_device',[8]='tune',[13]='build',[2]='route',
  [3]='battery_full',[9]='cell_tower',[10]='gpp_bad',[6]='sports_esports',
  [4]='sensors',[12]='bug_report',[14]='satellite_alt'}
 local smallNames={}
 for id,name in pairs(names)do smallNames[id]=name..'-18'end
 -- These are the seven navigation and thirteen detail variants used by the
 -- application. One cold asset is prepared per retained startup callback.
 local primeOrder={
  {0,30},{1,30},{5,30},{7,30},{11,30},{8,30},{13,30},
  {0,18},{1,18},{2,18},{3,18},{4,18},{5,18},{6,18},
  {7,18},{9,18},{10,18},{11,18},{12,18},{14,18}}
 for _,item in ipairs(primeOrder)do item.file=(item[2]==18 and smallNames or names)[item[1]]end
 local masks={};local primeAt=1
 local contextDisplay,contextPattern,contextOpen,contextMask=false,false,false,false
 local assetContext,expected30,expected18
 local function context()
  if contextDisplay~=display or contextPattern~=lcd.drawBitmapPattern or contextOpen~=Bitmap.open or contextMask~=Bitmap.toMask then
   local path=display and display.iconPath('home.png')or'icons/home.png'
   local large=display and display.iconSize(30)or 30;local small=display and display.iconSize(18)or 18
   if assetContext~=path or expected30~=large or expected18~=small or contextPattern~=lcd.drawBitmapPattern or contextOpen~=Bitmap.open or contextMask~=Bitmap.toMask then
    masks={};primeAt=1;assetContext=path;expected30=large;expected18=small
   end
   contextDisplay=display;contextPattern=lcd.drawBitmapPattern;contextOpen=Bitmap.open;contextMask=Bitmap.toMask
  end
 end
 local function load(file,size)
  local mask=masks[file]
  if mask==nil then
   mask=false
   if Bitmap.toMask and lcd.drawBitmapPattern then
    local asset=display and display.iconPath(file..'.png')or'icons/'..file..'.png'
    local ok,b=pcall(Bitmap.open,ROOT..asset);local w,h
    if ok and b then local sized;sized,w,h=pcall(Bitmap.getSize,b);if not sized then w=nil;h=nil end end
    local expected=size==18 and expected18 or expected30
    if w==expected and h==expected then local converted,value=pcall(Bitmap.toMask,b);if converted then mask=value or false end end
   end
   masks[file]=mask
  end
  return mask
 end
 function inputRuntime.primeIcons(state)
  context()
  -- Cached successes and failures both count as complete; reinit at the same
  -- resolution finishes immediately instead of performing more SD operations.
  while primeAt<=#primeOrder do
   local item=primeOrder[primeAt];primeAt=primeAt+1
   if masks[item.file]==nil then
    load(item.file,item[2])
    if state and state.view then state.view.initializing='ICONS '..(primeAt-1)..' / '..#primeOrder end
    return primeAt>#primeOrder
   end
  end
  return true
 end
 return function(id,x,y,c,size)
  if size~=30 and size~=18 then return false end
  local file=(size==18 and smallNames or names)[id];if not file then return false end
  context();local mask=load(file,size)
  if not mask then return false end
  ink(c);lcd.drawBitmapPattern(mask,x,y,CUSTOM_COLOR);return true
 end
end)()
local function icon(id,x,y,c,size)
 size=size or 30
 if iconImages(id,x,y,c,size)then return end
 if size==30 then x=x+1;y=y+1;size=28 end
 local shape=iconShapes[id] or iconShapes[id==14 and 7 or 12];local scale=(size or 28)/28
 ink(c)
 if shape.lines then for _,v in ipairs(shape.lines)do
  local a,b,d,e=round(x+v[1]*scale),round(y+v[2]*scale),round(x+v[3]*scale),round(y+v[4]*scale)
  lcd.drawLine(a,b,d,e,SOLID,CUSTOM_COLOR)
  if math.abs(d-a)>=math.abs(e-b)then lcd.drawLine(a,b+1,d,e+1,SOLID,CUSTOM_COLOR)else lcd.drawLine(a+1,b,d+1,e,SOLID,CUSTOM_COLOR)end
 end end
 if shape.rects then for _,v in ipairs(shape.rects)do lcd.drawFilledRectangle(round(x+v[1]*scale),round(y+v[2]*scale),math.max(1,round(v[3]*scale)),math.max(1,round(v[4]*scale)),CUSTOM_COLOR)end end
 if shape.circles then for _,v in ipairs(shape.circles)do
  local a,b,r=round(x+v[1]*scale),round(y+v[2]*scale),round(v[3]*scale)
  lcd.drawCircle(a,b,r,CUSTOM_COLOR);if r>1 then lcd.drawCircle(a,b,r-1,CUSTOM_COLOR)end
 end end
end
local function numberText(v,fmt,unit)return type(v)=='number' and string.format(fmt or '%.0f',v)..(unit or '') or '--' end
frame=function(title,d)
 local p=palette
 -- The shared shell owns titles and live/alert status. Retain its tab underlay.
 rect(0,34,480,212,p.black);rect(0,35,480,26,p.tape);rect(0,60,480,1,p.border)
end
local function panel(x,y,w,h,title)
 rect(x,y,w,h,palette.tape);rect(x,y,w,1,palette.border);label(x+9,y+7,title,palette.muted)
end
local function horizonMark(ox,oy,cs,sn,offset,half,c)
 local yy=oy+offset*cs;local xx=ox-offset*sn
 clip(xx-half*cs,yy-half*sn,xx+half*cs,yy+half*sn,126,354,65,243,c)
end
-- Drop-in renderer fragment. Global nav/title/status are drawn by the caller.
-- Static row definitions are allocated once; the shared d sample supplies data.
local telemetryMode='LIVE'
local telemetryScreen=(function()
 local columns={
  {title='RADIO LINK',accent='green',rows={
   {'RFMD','rf','%.0f',''}, {'1RSS','rssi1','%.0f','dBm'},
   {'2RSS','rssi2','%.0f','dBm'}, {'RQly','lq','%.0f','%'},
   {'RSNR','snr','%.0f','dB'}, {'TPWR','power','%.0f','mW'},
   {'TRSS','trss','%.0f','dBm'}, {'TQly','down','%.0f','%'},
   {'TSNR','tsnr','%.0f','dB'}}},
  {title='FLIGHT DATA',accent='orange',rows={
   {'RxBt','v','%.2f','V'}, {'Curr','a','%.1f','A'},
   {'Capa','mah','%.0f','mAh'}, {'Bat%','rawPct','%.0f','%'},
   {'CellAvg','cell','%.2f','V'}, {'Sats','sats','%.0f',''},
   {'GSpd','speed','%.1f','km/h'}, {'GAlt','alt','%.0f','m'},
   {'FM','flight','text',''}}},
  {title='ATTITUDE / GPS',accent='cyan',rows={
   {'Ptch','pitch','%.1f','deg'}, {'Roll','roll','%.1f','deg'},
   {'Yaw','yaw','%.1f','deg'}, {'Hdg','hdg','%.0f','deg'},
   {'VSpd','vspeed','%.1f','m/s'}, {'ASpd','airspeed','%.1f','km/h'},
   {'Lat','gpsLat','%.7f',''}, {'Lon','gpsLon','%.7f',''},
   {'Baro','baro','%.1f','m'}}}
 }
 local frskyColumns={
  {title='RADIO / ANALOG',accent='green',rows={{'RSSI','rssi1','%.0f','%'},{'TQly','down','%.0f','%'},{'RxBt','rxV','%.2f','V'},{'R9PW','power','%.0f','mW'},{'A1','a1','%.2f','V'},{'A2','a2','%.2f','V'},{'A3','a3','%.2f','V'},{'A4','a4','%.2f','V'},{'FM','flight','text',''}}},
  {title='AIRCRAFT / POWER',accent='orange',rows={{'VFAS','v','%.2f','V'},{'Curr','a','%.1f','A'},{'Fuel','mah','%.0f','mAh'},{'CellAvg','cell','%.2f','V'},{'GSpd','speed','%.1f','km/h'},{'GAlt','alt','%.0f','m'},{'Baro','baro','%.0f','m'},{'VSpd','vspeed','%.1f','m/s'},{'ASpd','airspeed','%.1f','km/h'}}},
  {title='ATTITUDE / GPS',accent='cyan',rows={{'Pitch','pitch','%.1f','deg'},{'Roll','roll','%.1f','deg'},{'Hdg','hdg','%.0f','deg'},{'Sats','sats','%.0f',''},{'GPS raw','gpsStatus','%.0f',''},{'Lat','gpsLat','%.7f',''},{'Lon','gpsLon','%.7f',''},{'FC home','homeDistance','%.0f','m'},{'FC brg','homeBearing','%.0f','deg'}}}
 }
 local function value(d,key)
  if key=='cell' then return d.powerState and d.powerState.averageCell or d.v and d.cells and d.cells>0 and d.v/d.cells or nil end
  if key=='gpsLat' or key=='gpsLon' or key=='gpsState' then
   local g=d.gps
   local valid=type(g)=='table' and type(g.lat)=='number' and type(g.lon)=='number' and g.lat==g.lat and g.lon==g.lon and math.abs(g.lat)<=90 and math.abs(g.lon)<=180
   if not valid then return nil end
   if key=='gpsLat' then return g.lat elseif key=='gpsLon' then return g.lon else return 'CURRENT' end
  end
  return d[key]
 end
 return function(d)
  local p=palette
  local native=telemetryMode~='LIVE'and(inputRuntime.deferred and telemetry.extremaView(telemetryMode)or not inputRuntime.deferred and telemetry.extrema(telemetryMode))or nil
  local specs=d.protocol and d.protocol.family=='FRSKY'and frskyColumns or columns
  for col=1,3 do
   local spec=specs[col];local x=4+(col-1)*160;local w=152
   rect(x,64,w,180,p.tape);rect(x,64,w,20,p.black)
   rect(x,64,3,20,p[spec.accent]);line(x+3,64,x+w-1,64,p.border)
   vlabel(x+9,64,20,telemetryMode=='LIVE'and spec.title or(native and'NATIVE'or telemetry.extremaStatus())..' '..telemetryMode,p[spec.accent],TINSIZE or SMLSIZE)
   for row=1,9 do
    local r=spec.rows[row];local y=85+(row-1)*17
    rect(x,y,w,17,row%2==0 and p.black or p.tape)
    local historic=native and native.records[r[2]]
    local v=telemetryMode=='LIVE'and value(d,r[2])or historic and historic.value
    local shown='--'
    if r[3]=='text' then
     if type(v)=='string' and v~='' then shown=string.sub(v,1,16)end
    elseif type(v)=='number' and v==v then shown=string.format(r[3],v)end
    local key=r[1]
    if r[2]=='v'then key=d.voltageName or key elseif r[2]=='mah'then key=d.consumedName or key end
    if r[2]=='pct' and d.estimated then key='Est%' end
    vlabel(x+6,y,17,key,p.muted)
    local unit=r[2]=='rssi'and (d.rssiUnit or r[4])or r[4];local right=x+w-6
    if unit~='' then
     vlabel(right,y,17,unit,p.muted,SMLSIZE,true);right=right-textWidth(unit,SMLSIZE)-8
    end
    local color=shown=='--'and p.muted or historic and historic.state=='HISTORICAL'and p.orange or p.white
    if telemetryMode=='LIVE'and r[2]=='lq' and d.link then color=p.orange end
    if telemetryMode=='LIVE'and(r[2]=='v' or r[2]=='cell') and d.battery then color=p.orange end
    if r[2]=='gpsState' and shown~='--' then color=p.green end
    shown=fittedText(shown,math.max(8,right-(x+6+textWidth(key,SMLSIZE)+8)),SMLSIZE)
    vlabel(right,y,17,shown,color,SMLSIZE,true)
   end
  end
 end
end)()

-- Fit live values inside their own cells; never let large telemetry overlap a neighbour.
local flightValue=(function()
 -- At most 32 value cells retain their last fit. Telemetry text is never a cache key.
 -- A changed value refits only its own cell; colors and palette remain live.
 local cells,slots,heights={},{},{}
 local nextSlot=1
 local metricLcd,metricFunction
 local function height(font,unit)
  local result=heights[font]
  if result==nil then local _,measured=lcd.sizeText('Ag',font);result=measured or false;heights[font]=result end
  return result or(unit and 12 or(font==DBLSIZE and 38 or font==MIDSIZE and 29 or font==TINSIZE and 12 or 17))
 end
 return function(x,y,w,h,value,unit,size,c,center)
  if metricLcd~=lcd or metricFunction~=lcd.sizeText then
   cells,slots,heights={},{},{};nextSlot=1;metricLcd=lcd;metricFunction=lcd.sizeText
  end
  local text=tostring(value);unit=unit or '';size=size or MIDSIZE
  local unitSize=TINSIZE or SMLSIZE
  -- Native cell coordinates are bounded by the 480 px canvas. Verify the actual
  -- coordinates too, so even a colliding out-of-canvas caller cannot reuse a fit.
  local key=x+y*512;local cell=cells[key]
  if not cell or cell.x~=x or cell.y~=y then
   cell=slots[nextSlot]
   if cell then if cells[cell.key]==cell then cells[cell.key]=nil end else cell={};slots[nextSlot]=cell end
   nextSlot=nextSlot%32+1
   cell.key=key;cell.x=x;cell.y=y;cell.text=nil;cell.unit=nil;cells[key]=cell
  end
  if cell.text~=text or cell.unit~=unit or cell.size~=size or cell.unitSize~=unitSize or cell.w~=w or cell.h~=h or cell.center~=center then
   local unitWidth=cell.unit==unit and cell.unitSize==unitSize and cell.unitWidth
   if not unitWidth then unitWidth=unit~='' and textWidth(unit,unitSize)+2 or 0 end
   local font=size;local width=textWidth(text,font)
   if font==DBLSIZE and width+unitWidth>w then font=MIDSIZE;width=textWidth(text,font)end
   if width+unitWidth>w then font=SMLSIZE;width=textWidth(text,font)end
   if width+unitWidth>w and TINSIZE then font=TINSIZE;width=textWidth(text,font)end
   local shown=text;local available=w-unitWidth
   if width>available then
    if not TINSIZE or font~=TINSIZE then
     if font~=SMLSIZE then font=SMLSIZE;width=textWidth(text,font)end
    end
    if width>available then
     while #shown>0 and textWidth(shown..'...',font)>available do shown=string.sub(shown,1,-2)end
     shown=shown..'...';width=textWidth(shown,font)
    end
   end
   cell.text=text;cell.unit=unit;cell.size=size;cell.unitSize=unitSize;cell.w=w;cell.h=h;cell.center=center
   cell.unitWidth=unitWidth;cell.shown=shown;cell.font=font
   cell.drawX=center and x+math.floor((w-width-unitWidth)/2)or x
   if unit~=''then
    local fontHeight,unitHeight=height(font),height(unitSize,true)
    cell.unitX=cell.drawX+width+2;cell.unitY=y+math.floor((h-fontHeight)/2)+fontHeight-unitHeight
   end
  end
  vlabel(cell.drawX,y,h,cell.shown,c or palette.white,cell.font)
  if unit~=''then label(cell.unitX,cell.unitY,unit,palette.muted,unitSize)end
 end
end)()
local flightBank,flightSummary=0,nil
local bankTicks={}
local pitchLabels={};for i=1,8 do pitchLabels[i]={}end
local pitchBoxes={};for i=1,8 do pitchBoxes[i]={}end
for _,degrees in ipairs({-60,-45,-30,-20,-10,0,10,20,30,45,60})do
 local a=degrees*pi/180;local inner=degrees%30==0 and 50 or 54
 bankTicks[#bankTicks+1]={round(240+math.sin(a)*58),round(154-math.cos(a)*58),round(240+math.sin(a)*inner),round(154-math.cos(a)*inner)}
end
-- Display polarity is model-owned. Raw Roll telemetry remains available unchanged.
local function displayRoll(roll)
 if roll==nil then return nil end
 return (configuration.get('rollDisplay')==1 and -roll or roll)+0.0
end
local function bankReference(roll)
 local p=palette
 -- Static integer strokes already have their final pixels. Avoid four Lua
 -- rounding calls and repeated ink selection for each shadow/foreground line.
 for _,t in ipairs(bankTicks)do
  ink(p.black);lcd.drawLine(t[1]-1,t[2],t[3]-1,t[4],SOLID,CUSTOM_COLOR);lcd.drawLine(t[1]+1,t[2],t[3]+1,t[4],SOLID,CUSTOM_COLOR)
  ink(p.horizon);lcd.drawLine(t[1],t[2],t[3],t[4],SOLID,CUSTOM_COLOR)
 end
 -- Fixed bank arc: the sky pointer follows the moving horizon's upper normal.
 local a=-clamp(roll,-60,60)*pi/180;local sn,cs=math.sin(a),math.cos(a)
 local x,y=round(240+sn*60),round(154-cs*60);local bx,by=240+sn*68,154-cs*68
 local lx,ly,rx,ry=round(bx-cs*4),round(by-sn*4),round(bx+cs*4),round(by+sn*4)
 local color=math.abs(roll)>60 and p.orange or p.cyan
 ink(p.black);for dx=-1,1 do lcd.drawLine(x+dx,y,lx+dx,ly,SOLID,CUSTOM_COLOR);lcd.drawLine(x+dx,y,rx+dx,ry,SOLID,CUSTOM_COLOR)end
 ink(color);lcd.drawLine(x,y,lx,ly,SOLID,CUSTOM_COLOR);lcd.drawLine(x,y,rx,ry,SOLID,CUSTOM_COLOR);lcd.drawLine(lx,ly,rx,ry,SOLID,CUSTOM_COLOR)
end
local function flightStrip(d)
 local p=palette
 rect(126,222,228,22,p.black);line(126,222,353,222,p.border)
 local throttle=d.inputs and d.inputs.roles.throttle;local limiter=d.inputs and d.inputs.roles.limiter
 local value=throttle and throttle.state=='LIVE'and throttle.value or nil
 local caption='THR '..(value~=nil and string.format('%.0f%%',value)or'--')..' >'
 if limiter and limiter.state=='LIVE'then caption='T'..(value~=nil and string.format('%.0f',value)or'--')..' L'..string.format('%.0f',limiter.value)end
 local shown,font=fittedText(caption,78,SMLSIZE);vlabel(200,222,22,shown,p.cyan,font)
 vlabel(131,222,22,flightBank==0 and'PFD >'or flightBank==1 and'VIDEO >'or'GPS >',p.cyan,SMLSIZE)
 line(194,226,194,239,p.border)
 line(282,226,282,239,p.border)
 local timer=d.session and d.session.modelTimer;local seconds=timer and timer.value or(d.session and d.session.flightSeconds)or 0
 local sign=seconds<0 and'-'or'';seconds=math.abs(seconds)
 local timerText=sign..string.format('%02d:%02d',math.floor(seconds/60),math.floor(seconds)%60)
 shown,font=fittedText(timerText,65,SMLSIZE);vlabel(349,222,22,shown,p.white,font,true)
 line(78,244,401,244,p.border)
end
local function cockpit(d)
 local p=palette
 local heading=d.course
 if not d.protocol and heading==nil then heading=d.hdg end
 if configuration.get('compassSource')==1 then heading=d.yaw end
 if heading~=nil then heading=heading%360 end
 -- Three primary metrics per rail; radio power and calculated cell average are context.
 rect(4,35,70,209,p.tape);rect(406,35,70,209,p.tape)
 rect(4,35,70,1,p.border);rect(406,35,70,1,p.border)
 local frsky=d.protocol and d.protocol.family=='FRSKY'
 local quality=frsky and d.rssi or d.lq;local critical=frsky and'rssiCrit'or'lqCrit';local low=frsky and'rssiLow'or'lqLow'
 local lqColor=quality and(quality<=configuration.threshold(critical,d)and p.red or quality<=configuration.threshold(low,d)and p.orange or p.green)or p.muted
 local batteryColor=d.v and(d.battery and p.orange or p.green)or p.muted
 icon(9,8,39,lqColor,18);vlabel(31,36,23,frsky and'RSSI'or'LINK',p.muted,TINSIZE or SMLSIZE)
 icon(3,410,39,batteryColor,18);vlabel(472,36,23,d.cells and d.cells..'S'or 'PACK',p.muted,TINSIZE or SMLSIZE,true)
 flightValue(8,61,62,34,quality and round(quality)or '--','%',MIDSIZE,lqColor)
 flightValue(410,61,62,34,d.v and string.format('%.1f',d.v)or '--','V',MIDSIZE,d.v and(d.battery and p.orange or p.white)or p.muted)
 rect(410,93,62,2,p.dim);if d.voltagePct~=nil then rect(410,93,62*clamp(d.voltagePct,0,100)/100,2,batteryColor)end
 -- Fit the percent before allocating its bar; estimated ~100% must also fit.
 local pct=d.pct and(d.estimated and '~'or '')..round(d.pct)..'%'or '--'
 local pctFont;pct,pctFont=fittedText(pct,58,TINSIZE or SMLSIZE)
 local meterWidth=math.max(0,math.min(36,62-textWidth(pct,pctFont)-4))
 rect(8,100,62,4,p.dim);rect(410,100,meterWidth,4,p.dim)
 if quality then rect(8,100,62*clamp(quality,0,100)/100,4,lqColor)end
 if d.pct then rect(410,100,meterWidth*clamp(d.pct,0,100)/100,4,d.battery and p.orange or p.green)end
 vlabel(472,95,12,pct,p.muted,pctFont,true)
 for x=8,410,402 do
  rect(x,108,62,1,p.border);rect(x,159,62,1,p.border);rect(x,208,62,1,p.border)
 end
 vlabel(8,112,14,frsky and'RX SUPPLY V'or'RSSI '..(d.rssiUnit or 'dBm'),p.muted,TINSIZE or SMLSIZE)
 vlabel(410,112,14,'USED mAh',p.muted,TINSIZE or SMLSIZE)
 local secondary=frsky and d.rxV or d.rssi
 flightValue(8,126,62,29,secondary and string.format(frsky and'%.1f'or'%.0f',secondary)or '--','',MIDSIZE,secondary and p.white or p.muted)
 flightValue(410,126,62,29,d.mah and round(d.mah)or '--','',MIDSIZE,d.mah and p.white or p.muted)
 vlabel(8,163,14,frsky and'DOWNLINK %'or'SNR dB',p.muted,TINSIZE or SMLSIZE)
 vlabel(410,163,14,'CURRENT A',p.muted,TINSIZE or SMLSIZE)
 local third=frsky and d.down or d.snr
 flightValue(8,177,62,29,third and string.format('%.0f',third)or '--','',MIDSIZE,third and p.white or p.muted)
 flightValue(410,177,62,29,d.a and string.format('%.1f',d.a)or '--','',MIDSIZE,d.a and p.white or p.muted)
 vlabel(8,210,14,'TX mW',p.muted,TINSIZE or SMLSIZE)
 vlabel(70,210,14,'RF',p.muted,TINSIZE or SMLSIZE,true)
 vlabel(70,225,18,d.rfCaption or(frsky and d.protocol.subtype)or'--',p.white,SMLSIZE,true)
 vlabel(410,210,14,d.cellProvenance=='REPORTED CELL'and'CELL A4 V'or d.cellsEstimated and'EST CELL V'or'AVG CELL V',p.muted,TINSIZE or SMLSIZE)
 flightValue(8,225,30,18,d.power and round(d.power)or '--','',SMLSIZE,d.power and p.white or p.muted)
 local cell=d.cell or(d.v and d.cells and d.cells>0 and d.v/d.cells)or nil
 flightValue(410,225,62,18,cell and string.format('%.2f',cell)or '--','',SMLSIZE,cell and p.white or p.muted)
 if flightBank>0 then flightSummary(d);flightStrip(d);return end
 -- One rectangular PFD: the horizon, aircraft and tape indexes share (240,154).
 local attitude=d.pitch~=nil and d.roll~=nil
 local roll=attitude and displayRoll(d.roll)or nil
 local speed=d.airspeed or d.speed;local altitude=d.alt or d.baro
 rect(78,35,324,209,p.tape)
 -- Near-heading references use larger type; minor ticks stay unlabelled.
 rect(78,34,324,30,p.black)
 if heading then
  local hdg=heading%360;local base=math.floor(hdg/30)*30
  for bearing=base-60,base+60,15 do
   local xx=round(240+(bearing-hdg)*1.8);local value=bearing%360
   if xx>=80 and xx<=400 and(xx<=204 or xx>=276)then
    if bearing%30==0 then
     local caption=value==0 and 'N'or value==90 and 'E'or value==180 and 'S'or value==270 and 'W'or string.format('%03d',value)
     local width=textWidth(caption,SMLSIZE);local left=round(xx-width/2)
     if left>=80 and left+width<=400 and(left+width<=204 or left>=276)then
      vlabel(left,35,22,caption,p.white,SMLSIZE);line(xx,57,xx,62,p.muted)
     end
    else line(xx,60,xx,62,p.border)end
   end
  end
 end
 rect(208,34,64,30,p.tape)
 flightValue(212,34,56,30,heading and string.format('%03d',round(heading)%360)or '--','',MIDSIZE,p.white,true)
 line(208,63,271,63,p.cyan)

 -- Wide native sky/ground is drawn once; no bitmap masks or Lua pixel loops.
 if attitude then
  rect(78,64,324,180,p.sky)
  ink(p.ground);lcd.drawHudRectangle(d.pitch,roll,78,402,64,244,CUSTOM_COLOR)
  if configuration.get('attitudeOverlay')==1 then
  local angle=-roll*pi/180;local cs,sn=math.cos(angle),math.sin(angle)
  local sr,cr=math.sin(roll*pi/180),math.cos(roll*pi/180)
  local hx,hy=240+sr*d.pitch,154+cr*d.pitch*1.85
  horizonMark(hx,hy,cs,sn,0,150,p.horizon)
  horizonMark(hx,hy,cs,sn,1,150,p.horizon)
  local base=math.floor(d.pitch/10)*10
  local count=0
  for degree=base-40,base+40,10 do if degree~=0 and degree>=-90 and degree<=90 then
   local ox=240+sr*(d.pitch-degree);local oy=154+cr*(d.pitch-degree)*1.85
   horizonMark(ox,oy,cs,sn,0,degree%20==0 and 27 or 17,p.ladder)
   if degree%20==0 then local candidate=pitchLabels[count+1];count=count+1;candidate.degree=degree;candidate.x=round(ox+40*cs);candidate.y=round(oy+40*sn)-8;candidate.done=false end
  end end
  local painted=0
  for _=1,count do
   local chosen,best
   for i=1,count do local candidate=pitchLabels[i];local distance=math.abs(candidate.degree-d.pitch);if not candidate.done and(not best or distance<best)then chosen=candidate;best=distance end end
   chosen.done=true;local caption=tostring(chosen.degree);local width=textWidth(caption,SMLSIZE);local yy=chosen.y
   for attempt=1,4 do
    local xx=attempt==1 and chosen.x or attempt==2 and 310 or attempt==3 and 128 or 212
    local clear=xx>=128 and xx+width<=352 and yy>=65 and yy+17<=221
    if clear and xx<288 and xx+width>193 and yy<165 and yy+17>150 then clear=false end
    if clear and yy<84 and yy+17>64 then clear=false end
    if clear and xx<309 and xx+width>171 and yy<133 and yy+17>84 then clear=false end
    -- Relocated captions must also clear the zero-horizon stroke at bank.
    if clear then
     if math.abs(cs)>.001 then
      local y1,y2=hy+(xx-2-hx)*sn/cs,hy+(xx+width+2-hx)*sn/cs
      if math.min(y1,y2)<=yy+19 and math.max(y1,y2)>=yy-2 then clear=false end
     elseif hx>=xx-2 and hx<=xx+width+2 then clear=false end
    end
    for i=1,painted do local box=pitchBoxes[i];if clear and xx<box.x+box.w+3 and xx+width>box.x-3 and yy<box.y+20 and yy+17>box.y-3 then clear=false end end
    if clear then
     vlabel(xx,yy,17,caption,p.white,SMLSIZE);painted=painted+1;local box=pitchBoxes[painted];box.x=xx;box.y=yy;box.w=width;break
    end
   end
  end
  end
 else rect(78,64,324,180,p.dim)end
 if attitude and configuration.get('attitudeOverlay')==1 then bankReference(roll)end
 -- Numerical angles retain the full range beyond the graduated bank reference.
 if attitude then
  vlabel(128,65,18,'P',p.horizon,TINSIZE or SMLSIZE)
  flightValue(141,65,63,18,string.format('%+.0f',d.pitch),'deg',SMLSIZE)
  vlabel(286,65,18,'R',p.horizon,TINSIZE or SMLSIZE)
  flightValue(300,65,52,18,string.format('%+.0f',roll),'deg',SMLSIZE)
 end
 if d.session and d.session.current and d.session.homeBearing and heading~=nil then
  local relative=(d.session.homeBearing-heading+540)%360-180
  local xx=round(clamp(240+relative*1.8,132,348))
  -- The center badge keeps its own number; the caret sits below it in the HUD.
  local yy=84
  line(xx-5,yy+4,xx,yy,p.orange);line(xx,yy,xx+5,yy+4,p.orange);line(xx-3,yy+3,xx-3,yy+9,p.orange);line(xx+3,yy+3,xx+3,yy+9,p.orange);line(xx-3,yy+9,xx+3,yy+9,p.orange)
 end
 vlabel(225,65,18,configuration.get('compassSource')==1 and'YAW'or'COG',p.horizon,TINSIZE or SMLSIZE)
 -- Equal-width tapes overlay the same field, with readable primary numbers.
 rect(78,64,46,180,p.tape);rect(356,64,46,180,p.tape)
 vlabel(81,64,17,d.airspeed and 'AS km/h'or 'GS km/h',p.muted,TINSIZE or SMLSIZE)
 vlabel(399,64,17,d.alt~=nil and 'GPS m'or d.baro~=nil and 'BARO m'or 'ALT m',p.muted,TINSIZE or SMLSIZE,true)
 line(124,64,124,243,p.border);line(355,64,355,243,p.border)
 for offset=-40,40,10 do
  if speed then
   local value=math.floor(speed/10)*10+offset;local yy=round(154-(value-speed)*2.4)
   if value>=0 and yy>86 and yy<237 then
    local font=textWidth(value,SMLSIZE)<=32 and SMLSIZE or(TINSIZE or SMLSIZE)
    local tick=fittedText(value,32,font);local height=font==TINSIZE and 12 or 17;local top=yy-math.floor(height/2)
    if top>=82 and top+height<=242 and(top+height<=138 or top>=170)then vlabel(114,top,height,tick,p.muted,font,true)end;line(117,yy,123,yy,p.muted)
   end
  end
  if altitude then
   local value=math.floor(altitude/10)*10+offset;local yy=round(154-(value-altitude)*2.4)
   if yy>86 and yy<237 then
    local font=textWidth(value,SMLSIZE)<=32 and SMLSIZE or(TINSIZE or SMLSIZE)
    local tick=fittedText(value,32,font);local height=font==TINSIZE and 12 or 17;local top=yy-math.floor(height/2)
    if top>=82 and top+height<=242 and(top+height<=138 or top>=170)then vlabel(397,top,height,tick,p.muted,font,true)end;line(357,yy,363,yy,p.muted)
   end
  end
 end
 rect(78,138,46,32,p.black);rect(356,138,46,32,p.black)
 for x=78,356,278 do line(x,138,x+45,138,p.green);line(x,169,x+45,169,p.green)end
 flightValue(82,139,38,30,speed and round(speed)or '--','',MIDSIZE,nil,true)
 flightValue(360,139,38,30,altitude and round(altitude)or '--','',MIDSIZE,nil,true)
 if attitude then
  -- A wider two-pixel reference with a dark four-pixel halo is visible at a glance.
  ink(p.black);for dy=-1,2 do
   lcd.drawLine(196,154+dy,226,154+dy,SOLID,CUSTOM_COLOR);lcd.drawLine(226,154+dy,235,161+dy,SOLID,CUSTOM_COLOR)
   lcd.drawLine(245,161+dy,254,154+dy,SOLID,CUSTOM_COLOR);lcd.drawLine(254,154+dy,284,154+dy,SOLID,CUSTOM_COLOR)
  end
  ink(p.orange);for dy=0,1 do
   lcd.drawLine(196,154+dy,226,154+dy,SOLID,CUSTOM_COLOR);lcd.drawLine(226,154+dy,235,161+dy,SOLID,CUSTOM_COLOR)
   lcd.drawLine(245,161+dy,254,154+dy,SOLID,CUSTOM_COLOR);lcd.drawLine(254,154+dy,284,154+dy,SOLID,CUSTOM_COLOR)
  end
  rect(236,150,8,8,p.black);rect(237,151,6,6,p.orange)
 else
  rect(160,131,160,42,p.black)
  vlabel(240-textWidth('ATTITUDE',SMLSIZE)/2,133,17,'ATTITUDE',p.muted,SMLSIZE)
  vlabel(240-textWidth('UNAVAILABLE',SMLSIZE)/2,152,17,'UNAVAILABLE',p.muted,SMLSIZE)
 end
 flightStrip(d)

end
flightSummary=function(d)
 local p=palette;rect(78,35,324,187,p.tape);rect(78,35,324,27,p.black)
 local report=fcLink.videoState().reported
 vlabel(89,35,27,flightBank==1 and(report and report.frequencyReported==false and'VIDEO / FC CONFIG'or'VIDEO / REPORTED')or'NAVIGATION',p.cyan)
 if flightBank==1 then
  local v=fcLink.videoState();local r=v.reported;local stamp=v.reportedAt
  local fresh=r and stamp and getTime()>=stamp and getTime()-stamp<=800
  local frequency=fresh and r.frequency or nil
  flightValue(91,67,210,40,frequency and string.format('%.0f',frequency)or'--','MHz',DBLSIZE)
  local power=fresh and v.powers and v.powers[r.power or 0]
  vlabel(91,112,19,'POWER',p.muted);vlabel(271,112,19,power and(power.label or tostring(power.value))or'--',p.white,SMLSIZE,true)
  vlabel(91,136,19,'PIT',p.muted);vlabel(271,136,19,fresh and(r.pit and'ON'or'OFF')or'--',p.white,SMLSIZE,true)
  vlabel(91,160,19,'CHANNEL',p.muted);vlabel(271,160,19,fresh and tostring(r.band or'--')..' / '..tostring(r.channel or'--')or'--',p.white,SMLSIZE,true)
  local message=fresh and(v.backend or configuration.get('vtxBackend'))or'NO CURRENT VTX REPORT'
  local shown,font=fittedText(message,292,SMLSIZE);vlabel(91,195,21,shown,fresh and p.muted or p.orange,font)
  if d.pitch and d.roll then rect(284,111,108,72,p.sky);ink(p.ground);lcd.drawHudRectangle(d.pitch,displayRoll(d.roll),284,392,111,183,CUSTOM_COLOR);line(315,147,331,147,p.orange);line(345,147,361,147,p.orange)
  else rect(284,111,108,72,p.dim);vlabel(292,138,19,'NO ATTITUDE',p.muted,TINSIZE or SMLSIZE)end
 else
  local pos=d.session and d.session.current;local rows={{'Latitude',pos and string.format('%.6f',pos.lat)or'--'},{'Longitude',pos and string.format('%.6f',pos.lon)or'--'},
   {'Course',numberText(d.course,'%.0f',' deg')},{'To local home',numberText(d.session and d.session.homeDistance,'%.0f',' m')},{'Home bearing',numberText(d.session and d.session.homeBearing,'%.0f',' deg')},{'ETA at ground speed',d.homeETA or'--'}}
  for i,r in ipairs(rows)do local y=68+(i-1)*20;vlabel(90,y,20,r[1],p.muted);local shown,font=fittedText(r[2],157,SMLSIZE);vlabel(390,y,20,shown,p.white,font,true)end
  local shown,font=fittedText(d.plusCode or'NO CURRENT POSITION',300,SMLSIZE);vlabel(90,195,21,shown,d.plusCode and p.cyan or p.orange,font)
 end
end
local traces,lastTrace={},-100
local flightSeconds,flightWasArmed,lastStatus=0,false,nil
local radioArm,radioCut='NOT CONFIGURED','NOT CONFIGURED'
local function radioIndicator(v)return v=='ACTIVE' and 'ON' or v=='INACTIVE' and 'OFF' or '--'end
local serviceSettings={}
local serviceRevision,energyIdentity,gpsIdentity=-1,nil,nil
resetRuntime=function()
 if packPicker then packPicker.stop()end;quick.active=false
 navReset();navConfigured=false;traces={};lastTrace=-100;gpsView='DETAILS';satellitePage=1;telemetryMode='LIVE'
 flightSeconds=0;flightWasArmed=false;lastStatus=nil
 serviceRevision=-1;energyIdentity=nil;gpsIdentity=nil;flightResetJob=nil;nativeResetError=nil;diagnosticView=1
end
local function statusUpdate(d)
 local now=getTime();inputRuntime.sample(d);radioArm=configuration.indicator('arm');radioCut=configuration.indicator('cut')
 if d.fcArmed~=nil then d.armed=d.fcArmed elseif radioArm=='ACTIVE' then d.armed=true elseif radioArm=='INACTIVE' then d.armed=false else d.armed=nil end
 if session then
  local revision=configuration.revision()
  if revision~=serviceRevision then
   local g=configuration.get;flightBank=g('flightBank')
   serviceSettings.modelId=modelIdentity
   serviceSettings.sourceId=table.concat({g('rcProtocol'),g('fcType'),g('rcSubtype'),g('gps'),g('speed'),g('altitude'),g('heading'),g('course'),tostring(g('gpsEnabled'))},'|')
   serviceSettings.autoHome=g('autoHome')>0;serviceSettings.homeRequiresArmed=g('autoHome')==2;serviceSettings.homeSats=g('homeSats');serviceSettings.trail=g('trail')
   serviceSettings.timerIndex=g('timerIndex')
   local nextEnergy=table.concat({g('rcProtocol'),g('rcSubtype'),g('fcType'),g('voltage'),g('current'),g('consumed'),tostring(g('batteryEnabled')),tostring(g('currentEnabled')),tostring(g('pack'))},'|')
   if energyIdentity and energyIdentity~=nextEnergy then traces={};lastTrace=-100 end
   energyIdentity=nextEnergy;serviceRevision=revision
  end
  session.update(now,d,serviceSettings);sessionState=session.snapshot()
  navHome=sessionState.home;navTrack=sessionState.track;navCurrent=sessionState.current
  navPlot.prime(navHome,navCurrent,navTrack)
  flightSeconds=sessionState.flightSeconds;d.session=sessionState
  if navUtility then
   local pos=sessionState.current;local home=sessionState.home
   if pos and(pos.lat~=positionCodeLat or pos.lon~=positionCodeLon)then positionCode=navUtility.encode(pos.lat,pos.lon,11);positionCodeLat=pos.lat;positionCodeLon=pos.lon end
   if home and(home.lat~=homeCodeLat or home.lon~=homeCodeLon)then homeCode=navUtility.encode(home.lat,home.lon,11);homeCodeLat=home.lat;homeCodeLon=home.lon end
   d.plusCode=pos and positionCode or nil;d.lastPlusCode=sessionState.lastKnown and positionCode or nil;d.homePlusCode=home and homeCode or nil
   d.relativeHome=navUtility.relativeBearing(sessionState.homeBearing,d.course)
   d.homeETA=navUtility.formatETA(sessionState.homeDistance,d.speed)
  end
 end
 if now<lastTrace then lastTrace=-100 end
 if now-lastTrace>=100 then
  lastTrace=now;local sample=#traces>=90 and table.remove(traces,1) or {};sample.v=d.v;sample.a=d.a;sample.lq=d.lq;sample.rssi=d.rssi;traces[#traces+1]=sample
 end
end
function inputRuntime.dataDue(now)
 return not sharedData or now<lastSample or now-lastSample>=20 or inputRuntime.sampleRevision~=configuration.revision()or inputRuntime.sampleBatteryRevision~=batteryConfig.revision()
end
function inputRuntime.samplingPriority(now)
 local pending=inputRuntime.pendingData
 return not sharedData or now<lastSample or now-lastSample>=40 or pending and(now<pending.at or now-pending.at>=20)
end
function inputRuntime.frameData()return sharedData end
function inputRuntime.frameAttitude(pitch,roll)
 if sharedData then sharedData.pitch=pitch;sharedData.roll=roll end
end
function inputRuntime.serviceFrame(now)
 local pending=inputRuntime.pendingData
 local revision,batteryRevision=configuration.revision(),batteryConfig.revision()
 if pending and(pending.revision~=revision or pending.batteryRevision~=batteryRevision or now<pending.at or now-pending.at>30)then inputRuntime.pendingData=nil;pending=nil end
 if pending then
  if pending.phase==2 then
   telemetry.finishAcquire();pending.phase=3
  elseif pending.phase==3 then
   alertsMuted=session and session.snapshot().muted or false
   telemetry.derive(pending.data);pending.phase=4
  else
   local d=pending.data;d.sessionError=failure;d.nativeResetError=nativeResetError
   if flightResetJob then d.gps=nil;d.sats=nil end
   statusUpdate(d);runtimeServices.update(d,sessionState)
   sharedData=d;lastSample=pending.at;inputRuntime.sampleRevision=pending.revision;inputRuntime.sampleBatteryRevision=pending.batteryRevision
   inputRuntime.serviceSerial=inputRuntime.serviceSerial+1;inputRuntime.pendingData=nil
  end
 elseif inputRuntime.dataDue(now)then
  alertsMuted=session and session.snapshot().muted or false
  inputRuntime.pendingData={data=telemetry.acquire(true,true,true,sharedData),at=now,revision=revision,batteryRevision=batteryRevision,phase=2}
 end
 return sharedData
end
serviceData=function(force,attitudePolled)
 local now=getTime()
 local revision,batteryRevision=configuration.revision(),batteryConfig.revision()
 if not force and sharedData and now>=lastSample and now-lastSample<20 and inputRuntime.sampleRevision==revision and inputRuntime.sampleBatteryRevision==batteryRevision then return sharedData end
 inputRuntime.pendingData=nil
 alertsMuted=session and session.snapshot().muted or false
 local d=telemetry.sample(attitudePolled);d.sessionError=failure;d.nativeResetError=nativeResetError
 if flightResetJob then d.gps=nil;d.sats=nil end
 statusUpdate(d);sharedData=d;lastSample=now;inputRuntime.sampleRevision=revision;inputRuntime.sampleBatteryRevision=batteryRevision;inputRuntime.serviceSerial=inputRuntime.serviceSerial+1
 runtimeServices.update(d,sessionState)
 return d
end
local function trace(x,y,w,h,key,lo,hi,c)
 local px,py
 for i,s in ipairs(traces)do
  local v=s[key];local xx=x+(i-1)*w/math.max(1,#traces-1)
  if v then local yy=y+h-clamp((v-lo)/(hi-lo),0,1)*h;if px then line(px,py,xx,yy,c)end;px,py=xx,yy else px,py=nil,nil end
 end
end
local powerScreen=(function()
 local voltageNames,currentNames={'RxBt','VFAS','Bat'},{'Curr'}
 local function charge(value)
  if type(value)~='number' then return '--'end
  if value>=1000 then return string.format(value<10000 and '%.2f Ah' or '%.1f Ah',value/1000)end
  return string.format('%.0f mAh',value)
 end
 local function row(y,caption,value,color)
  label(19,y,caption,palette.muted)
  local available=172-19-textWidth(caption,SMLSIZE)-8
  local shown,size=fittedText(value,available,SMLSIZE)
  label(172,y,shown,color or palette.white,size,true)
 end
 local function chart(d,key,names,y,title)
  local p=palette;local source,state=telemetry.sourceStatus(names)
  if state=='LIVE' then
   local caption=title..' / '..tostring(source)
   if key=='a' and d.v~=nil and d.a~=nil then caption=title..' / '..string.format('%.0f W',d.v*d.a)end
   local shown=fittedText(caption,260,SMLSIZE)
   panel(191,y,281,73,shown)
   local high=key=='v' and(d.cells and d.cells*4.6 or 60)or 5
   if key=='a' then for _,sample in ipairs(traces)do if sample.a and sample.a>high then high=sample.a end end;high=math.ceil(high/5)*5 end
   trace(201,y+26,260,36,key,0,high,key=='v' and p.cyan or p.orange)
  else
   panel(191,y,281,73,title)
   local caption=state=='OFF' and 'SOURCE DISABLED' or state=='NOT FOUND' and 'SENSOR NOT FOUND' or state=='INVALID' and 'INVALID SENSOR VALUE' or 'WAITING FOR LIVE DATA'
   label(201,y+27,caption,p.orange)
   local help=state=='OFF' and 'Enable it in Sources below' or state=='NOT FOUND' and 'Discover in EdgeTX, then Refresh' or tostring(source or '--')..' / '..state
   local shown,size=fittedText(help,260,SMLSIZE);label(201,y+47,shown,p.muted,size)
  end
 end
 return function(d)
  local p=palette;frame('POWER',d)
  panel(8,64,175,154,'PACK '..(configuration.get('pack')>0 and configuration.get('pack')or'AUTO')..' >')
  flightValue(19,89,153,38,d.v and string.format('%.2f',d.v)or '--','V',DBLSIZE,d.v and p.white or p.muted)
  rect(19,128,153,3,p.dim);if d.voltagePct~=nil then rect(19,128,153*clamp(d.voltagePct,0,100)/100,3,d.battery and p.orange or p.cyan)end
  row(132,d.cellProvenance=='REPORTED CELL'and'CELL A4'or d.cellsEstimated and 'EST CELL'or'AVG CELL',numberText(d.cell or(d.cells and d.v and d.v/d.cells),'%.2f',' V'),p.cyan)
  row(152,'CURRENT',numberText(d.a,'%.1f',' A'))
  row(172,'USED',charge(d.mah))
  local left=d.pct and(d.estimated and '~'or '')..string.format('%.0f%%',d.pct)or '--'
  if d.remainingMah~=nil then left=left..' / '..charge(d.remainingMah)end
  row(192,'LEFT',left,p.green)
  chart(d,'v',voltageNames,64,'VOLTAGE')
  chart(d,'a',currentNames,145,'CURRENT')
  local cells=d.cells and d.cells..'S / LIMITS' or 'CELL LIMITS'
  for _,button in ipairs({{8,152,'SOURCES',true},{168,152,'REFRESH',true},{328,144,cells,configuration.canOpen(3)}})do
   rect(button[1],222,button[2],21,p.tape)
   vlabel(button[1]+8,222,21,button[3],button[4]and p.cyan or p.muted)
  end
 end
end)()
local inputRows={{'arm','ARM INDICATOR'},{'cut','THROTTLE CUT'},{'acro','ACRO'},{'angle','ANGLE'},{'horizon','HORIZON'},{'air','AIRMODE'},{'turtle','TURTLE'},{'rth','RETURN HOME'},{'wrth','WAYPOINT RTH'},{'throttle','PHYSICAL THROTTLE'},{'limiter','THROTTLE LIMIT'}}
local function inputScreen(d)
 local p=palette;frame('RADIO INPUTS',d)
 rect(8,64,464,24,p.tape)
 vlabel(18,64,24,'FC '..tostring(d.flight or'--'),p.white)
 local mode=d.displayFlight or d.flight or'--';local shown,font=fittedText('DISPLAY '..mode,224,SMLSIZE);vlabel(462,64,24,shown,p.cyan,font,true)
 for i,n in ipairs(inputRows)do
  local col=math.floor((i-1)/6);local x=8+col*236;local y=91+((i-1)%6)*20
  rect(x,y,228,20,i%2==0 and p.tape or p.black)
  local r=d.inputs and d.inputs.roles[n[1]];local text='--';local color=p.muted
  if r and r.state=='OFF'then text='NONE'
  elseif r and r.state=='LIVE'then text=type(r.value)=='number'and string.format('%.0f%%',r.value)or(r.override and'R 'or'FC ')..(r.value and'ON'or'OFF');color=r.override and p.cyan or p.white end
  local caption,size=fittedText(n[2],159,SMLSIZE);vlabel(x+8,y,20,caption,p.muted,size);vlabel(x+220,y,20,text,color,SMLSIZE,true)
 end
 local state=d.inputs
 vlabel(252,191,20,state and state.modeConflict and'MODE CONFLICT'or'R = RADIO / FC = REPORTED',state and state.modeConflict and p.orange or p.muted,state and state.modeConflict and SMLSIZE or(TINSIZE or SMLSIZE))
 for _,b in ipairs({{8,228,'INPUTS / TIMERS'},{244,228,'MODE INDICATORS'}})do rect(b[1],222,b[2],21,p.tape);vlabel(b[1]+8,222,21,b[3],(b[1]==8 or configuration.canOpen(7))and p.cyan or p.muted)end
end
local function linkScreen(d)
 local p=palette;frame('RC LINK',d)
 local frsky=d.protocol and d.protocol.family=='FRSKY'
 panel(8,64,146,80,frsky and'RSSI / %'or'LINK QUALITY');panel(167,64,146,80,frsky and'RECEIVER SUPPLY'or'SIGNAL STRENGTH');panel(326,64,146,80,frsky and'TX POWER / R9'or'SIGNAL / NOISE')
 flightValue(20,91,122,38,numberText(frsky and d.rssi or d.lq,'%.0f'),frsky and'%'or'%',DBLSIZE,d.link and p.orange or p.green)
 flightValue(179,91,122,38,numberText(frsky and d.rxV or d.rssi,frsky and'%.1f'or'%.0f'),frsky and'V'or'dBm',DBLSIZE)
 flightValue(338,91,122,38,numberText(frsky and d.power or d.snr,'%.0f'),frsky and'mW'or'dB',DBLSIZE,p.cyan)
 panel(8,153,305,90,(frsky and'RSSI'or'LQ')..' HISTORY / '..#traces..' SAMPLES');trace(18,182,285,50,frsky and'rssi'or'lq',0,100,p.green)
 panel(326,153,146,90,'RF STATUS');local shown,font=fittedText(frsky and d.protocol.subtype or numberText(d.power,'%.0f',' mW'),126,MIDSIZE);label(336,177,shown,p.white,font)
 label(336,200,'RF '..(d.rfCaption or '--'),p.muted);label(336,220,'DOWN '..numberText(d.down,'%.0f',' %'),p.cyan)
end
local armUi=(function()
 local decoder,stamp,cached,decodeError,selected,offset=nil,nil,nil,nil,1,0
 local decoderTried=false
 local packet,apiMajor,apiMinor,family,fcMajor,fcMinor,fcPatch
 local detailLines,helpLines,titleLines={},{},{}
 local titleSize,titleHeight=MIDSIZE,29
 local function prime()
  if not decoderTried then decoderTried=true;if loadScript then local chunk=loadScript(ROOT..'arm-status.lua');decoder=chunk and chunk()end end
 end
 local function wrap(s)
  local rows,line={},''
  for word in string.gmatch(s or '', '%S+')do
   if #line+#word>45 then rows[#rows+1]=line;line=word else line=line=='' and word or line..' '..word end
  end
  if line~='' then rows[#rows+1]=line end
  return rows
 end
 local function choose(n)
  local count=cached and #cached.reasons or 0
  selected=count>0 and ((n-1)%count+1) or 1;offset=math.floor((selected-1)/7)*7
  local reason=cached and cached.reasons[selected]
  local title=reason and reason.title or ''
  -- The right panel ends at472; leave eight native pixels after the title.
  titleSize=textWidth(title,MIDSIZE)<=305 and MIDSIZE or SMLSIZE
  titleHeight=titleSize==MIDSIZE and 29 or 17
  titleLines=wrappedText(title,305,titleSize)
  detailLines=wrap(reason and reason.detail);helpLines=wrap(reason and reason.help)
 end
 local function current()
  local state=fcLink.state
  return state.active and state.lastStatus and getTime()>=state.lastStatus and getTime()-state.lastStatus<=800
 end
 local function sync()
  local state=fcLink.state;local active=current()
  if active then
   prime()
   if stamp~=state.lastStatus or packet~=state.statusData or apiMajor~=state.apiMajor or apiMinor~=state.apiMinor or family~=state.family or fcMajor~=state.fcMajor or fcMinor~=state.fcMinor or fcPatch~=state.fcPatch then
    local same=cached and packet and state.statusData and #packet==#state.statusData and apiMajor==state.apiMajor and apiMinor==state.apiMinor and family==state.family and fcMajor==state.fcMajor and fcMinor==state.fcMinor and fcPatch==state.fcPatch
    if same then for i=1,#packet do if packet[i]~=state.statusData[i]then same=false;break end end end
    if same then stamp=state.lastStatus;packet=state.statusData;return cached,active,decodeError end
    local previous=cached and cached.reasons[selected] and cached.reasons[selected].bit
    stamp=state.lastStatus;packet=state.statusData;apiMajor=state.apiMajor;apiMinor=state.apiMinor
    family=state.family;fcMajor=state.fcMajor;fcMinor=state.fcMinor;fcPatch=state.fcPatch
    if decoder then
     if state.family=='INAV'then cached,decodeError=decoder.decodeInav(packet,state.fcMajor,state.fcMinor,state.fcPatch)else cached,decodeError=decoder.decode(packet,apiMajor,apiMinor)end
    else cached=nil;decodeError='DECODER UNAVAILABLE'end
    local nextSelection=1
    if previous and cached then for i,r in ipairs(cached.reasons)do if r.bit==previous then nextSelection=i;break end end end
    choose(nextSelection)
   end
  else cached=nil;stamp=nil;packet=nil;apiMajor=nil;apiMinor=nil;decodeError=nil end
  return cached,active,decodeError
 end
 return {
  prime=prime,
  status=sync,
  move=function(delta)choose(selected+delta)end,
  tap=function(x,y)if x<143 then if y>=64 and y<218 then local n=offset+math.floor((y-64)/22)+1;if cached and cached.reasons[n]then choose(n)end elseif y>=222 then choose(offset+8)end end end,
  draw=function(d)
   local p=palette;frame('ARM STOPS',d)
   local _,active=sync()
   rect(8,64,132,154,p.tape);rect(148,64,324,179,p.tape)
   if cached and #cached.reasons>0 then
    for i=1,7 do
     local r=cached.reasons[offset+i]
     if r then
      local y=64+(i-1)*22;local chosen=offset+i==selected
      rect(8,y,132,21,chosen and p.cyan or i%2==0 and p.black or p.tape)
      vlabel(15,y,21,r.code,chosen and p.black or p.white)
     end
    end
    local reason=cached.reasons[selected]
    label(159,74,'DISABLE FLAG '..reason.bit,p.muted)
    for i,text in ipairs(titleLines)do label(159,95+(i-1)*titleHeight,text,p.white,titleSize)end
    local detailY=math.max(126,95+#titleLines*titleHeight+2)
    for i,text in ipairs(detailLines)do label(159,detailY+(i-1)*16,text,p.white)end
    local checkY=math.max(167,detailY+#detailLines*16+9)
    label(159,checkY,'CHECK',p.cyan)
    for i,text in ipairs(helpLines)do label(159,checkY+18+(i-1)*16,text,p.muted)end
   else
    label(18,77,cached and 'NO FLAGS' or 'NO STATUS',cached and p.green or p.orange)
    label(159,78,cached and 'NO DISABLE FLAGS REPORTED' or 'WAITING FOR FC STATUS',p.white)
    label(159,110,cached and 'Received flags are clear.' or (decodeError or fcLink.state.status),p.muted)
    label(159,145,cached and 'This is the last status reply.' or 'Reads run while disarmed with',p.muted)
    label(159,164,cached and 'It does not prove armed state.' or 'current flight-mode telemetry.',p.muted)
   end
   rect(8,222,132,21,p.tape);vlabel(16,222,21,cached and #cached.reasons>7 and 'MORE FLAGS >' or 'FC STATUS',p.cyan)
   if active and cached and #cached.reasons<=7 then rect(8,222,132,21,p.tape);vlabel(16,222,21,string.format('%d FLAGS / %.1fs',#cached.reasons,(getTime()-fcLink.state.lastStatus)/100),p.cyan)end
   vlabel(159,222,21,string.format('RADIO ARM %s / CUT %s / %02d:%02d',radioIndicator(radioArm),radioIndicator(radioCut),math.floor(flightSeconds/60),math.floor(flightSeconds)%60),p.muted)
  end
 }
end)()
function inputRuntime.primeArm()armUi.prime()end
function inputRuntime.syncArm()armUi.status()end
ensureReferenceUi=function()
 if not referenceUi and loadScript then
  local modules={};for i,name in ipairs({'arm-status','reference','reference-ui'})do local chunk=loadScript(ROOT..name..'.lua');modules[i]=chunk and chunk()end
  local f=modules[3]
  referenceUi=f and f.new({arm=modules[1],reference=modules[2],lcd=lcd,palette=function()return palette end,fonts={tiny=TINSIZE,small=SMLSIZE,medium=MIDSIZE},colorFlag=CUSTOM_COLOR,tone=playTone})or nil
  if referenceUi and shell and shell.installReferences then shell.installReferences(referenceUi)end
 end
 if referenceUi then
  local flags,active,err=armUi.status();local state=fcLink.state
  referenceUi.setContext(configuration.get('fcType')=='INAV'and'INAV'or'BF',state.apiMajor,state.apiMinor,flags and flags.count)
  local fresh=state.lastStatus and getTime()>=state.lastStatus and getTime()-state.lastStatus<=800
  referenceUi.setLive(flags,active and fresh,state.lastStatus and not fresh and 'OLD'or state.status,err)
 end
 return referenceUi
end
local function statusScreen(d)
 frame('ARM INFO',d)
 if ensureReferenceUi()then local focused=shell and shell.focused();referenceUi.drawArm(focused and focused[1])
 else armUi.draw(d)end
end

local vtxSelection=1
local vtxUi=(function()
 local draft,mode,bandIndex={},'FAV',1
 local dirty,lastApplied,errorMessage=false,nil,nil
 local showAttitude=false
 local function state()return fcLink.videoState()end
 local function busy()
  local op=state().operation;local v=op and op.state
  return v=='QUEUED'or v=='WRITING'or v=='SAVING'or v=='VERIFYING'
 end
 local function sync()
  local v=state();local op=v.operation
  if op and (op.state=='APPLIED'or op.state=='SUCCEEDED') and op.id~=lastApplied then dirty=false;lastApplied=op.id;errorMessage=nil end
  if not dirty and not busy() then
   local r=v.reported or {};draft.frequency=r.frequency;draft.band=r.band and r.band>0 and r.band or nil;draft.channel=r.channel and r.channel>0 and r.channel or nil;draft.power=r.power;draft.pit=r.pit;draft.lowPowerDisarm=r.lowPowerDisarm
  end
  return v
 end
 local function choice(index)
  if configuration.get('vtxMode')~=2 then mode='BAND'end
  local v=state()
  if mode=='FAV' then
   local f=configuration.get('vtx'..index)
   return f>0 and f or nil,'F'..index
  end
  local band=v.bands and v.bands[bandIndex]
  local f=band and band.frequencies and band.frequencies[index]
  return f and f>0 and f or nil,(band and band.letter or '?')..index
 end
 local function mapped(f)
  for i,band in ipairs(state().bands or {})do for j,value in ipairs(band.frequencies or {})do if value==f then return i,j end end end
 end
 local function action(name,index)
  local client=fcLink.videoClient()
  if name=='panel' then showAttitude=not showAttitude
  elseif name=='pick' then
   local f=choice(index);if not f then return false,'EMPTY CHANNEL' end
   draft.frequency=f;if mode=='BAND'then draft.band=bandIndex;draft.channel=index else draft.band,draft.channel=mapped(f)end;dirty=true;errorMessage=nil;vtxSelection=index
  elseif name=='power' then
   local powers=state().powers or {};if #powers==0 then return false,'POWER TABLE UNAVAILABLE' end
   local first=state().reported and state().reported.minPowerIndex or 1
   draft.power=((draft.power or first)-first+1)%(#powers-first+1)+first;dirty=true
  elseif name=='pit' then
   if draft.pit==nil then return false,'PIT STATUS UNAVAILABLE' end
   draft.pit=not draft.pit;dirty=true
  elseif name=='lpd'then
   if draft.lowPowerDisarm==nil then return false,'NOT REPORTED BY THIS CONNECTION'end
   draft.lowPowerDisarm=(draft.lowPowerDisarm+1)%3;dirty=true
  elseif name=='band' then
   local bands=state().bands or {};if #bands==0 then return false,'CHANNEL TABLE UNAVAILABLE' end
   bandIndex=bandIndex%#bands+1;mode='BAND'
  elseif name=='mode' then if configuration.get('vtxMode')==2 then mode=mode=='FAV'and'BAND'or'FAV'else mode='BAND'end
  elseif name=='refresh' then
   if fcLink.service then local ok,why=fcLink.service:refreshVideo();if ok==false then return false,why end else return false,'VTX CLIENT UNAVAILABLE'end
  elseif name=='cancel' then
   if client and client.cancelVtx then client:cancelVtx()end
   dirty=false;errorMessage=nil;sync()
  elseif name=='apply' then
   if not dirty then return false,'NO CHANGES SELECTED' end
   if not client or not client.applyVtx then return false,'VTX CLIENT UNAVAILABLE' end
   local ok,why=client:applyVtx(draft)
   if not ok then errorMessage=why;return false,why end
   errorMessage=nil
  end
  return true
 end
 local function draw(d)
  if configuration.get('vtxMode')~=2 then mode='BAND'end
  local p=palette;frame('VIDEO',d);local v=sync();local r=v.reported or {}
  rect(8,64,311,34,p.tape)
  flightValue(16,64,145,34,r.frequency or '--','MHz',MIDSIZE,p.white)
  local code=r.band and r.channel and (v.bands and v.bands[r.band] and v.bands[r.band].letter or tostring(r.band))..r.channel or '--'
  vlabel(309,65,17,code,p.cyan,SMLSIZE,true)
  local age=v.reportedAt and math.max(0,(getTime()-v.reportedAt)/100)
  vlabel(309,81,15,age and string.format(r.frequencyReported==false and 'CONFIG %.1fs'or'REPORTED %.1fs',age)or 'NOT REPORTED',p.muted,TINSIZE or SMLSIZE,true)
  for i=1,8 do
   local x=8+((i-1)%4)*79;local y=102+math.floor((i-1)/4)*50
   local f,code=choice(i);local selected=dirty and f and f==draft.frequency
   local current=f and r.frequency==f
   rect(x,y,74,45,p.tape);rect(x,y,74,2,current and p.green or selected and p.cyan or p.border)
   if selected then rect(x,y,2,45,p.cyan)end
   vlabel(x+6,y+3,18,code,selected and p.cyan or p.muted)
   local shown,size=fittedText(f or 'OFF',62,SMLSIZE)
   vlabel(x+6,y+23,18,shown,f and p.white or p.muted,size)
  end
  local op=v.operation;local message=errorMessage or op and op.error or nil
  if not message then
   if busy() then message=op.state
   elseif op and(op.state=='APPLIED'or op.state=='SUCCEEDED')then message=op.confirmation=='OBSERVED REPORT'and'APPLIED / REPORT MATCHED'or'APPLIED / READBACK MATCHED'
   elseif dirty then message='SELECTED '..tostring(draft.frequency or r.frequency or '--')..' MHz'
   else message=v.tableSource=='SD CACHE'and 'CACHED TABLES / VERIFY ON APPLY'or v.cached and 'CACHED LABELS / LIVE DISCOVERY'or v.status or (configuration.get('vtxMode')==0 and 'ENABLE VTX IN SETUP' or 'WAITING FOR VTX')end
  end
  local shown,size=fittedText(message,299,SMLSIZE);vlabel(14,202,16,shown,(errorMessage or op and op.error) and p.orange or p.muted,size)
  if showAttitude then
   panel(331,64,141,154,'LIVE ATTITUDE')
   if d.pitch~=nil and d.roll~=nil then
    rect(341,90,121,73,p.sky);ink(p.ground);lcd.drawHudRectangle(d.pitch,displayRoll(d.roll),341,462,90,163,CUSTOM_COLOR)
    line(382,127,421,127,p.orange)
   else rect(341,90,121,73,p.dim);label(351,120,'NO ATTITUDE',p.muted)end
   label(341,174,'P '..numberText(d.pitch,'%.0f',' deg'),p.white)
   label(341,195,'R '..numberText(displayRoll(d.roll),'%.0f',' deg'),p.white)
  else
  rect(331,64,141,154,p.tape)
  local power=v.powers and v.powers[draft.power or 0]
  vlabel(339,65,17,'POWER',p.muted)
  local caption=power and power.label or draft.power and ('LEVEL '..draft.power)or '--'
  local powerText,powerSize=fittedText(caption,117,MIDSIZE)
  rect(335,84,133,30,p.black);vlabel(343,84,30,powerText,dirty and p.cyan or p.white,powerSize)
  rect(335,119,64,28,p.black)
  vlabel(341,119,28,draft.pit==nil and 'PIT --'or draft.pit and 'PIT ON'or 'PIT OFF',draft.pit and p.orange or p.white)
  rect(403,119,65,28,p.black);vlabel(409,119,28,draft.lowPowerDisarm==nil and 'LPD --'or draft.lowPowerDisarm==0 and 'LPD OFF'or draft.lowPowerDisarm==1 and 'LPD ON'or 'LPD 1ST',draft.lowPowerDisarm and p.cyan or p.muted,TINSIZE or SMLSIZE)
  rect(335,154,133,25,p.black)
  local band=v.bands and v.bands[bandIndex]
  vlabel(343,154,25,'BAND '..(band and band.letter or '--')..' >',p.cyan)
  rect(335,186,133,25,p.black);vlabel(343,186,25,mode=='FAV'and 'FAVOURITES'or 'CHANNELS',p.cyan)
  end
  for _,button in ipairs({{8,100,'REFRESH'},{116,100,'CANCEL'},{224,100,'APPLY'},{331,141,'EDIT FAVOURITES'}})do
   rect(button[1],222,button[2],21,p.tape)
   local labelText,labelSize=fittedText(button[3],button[2]-14,SMLSIZE)
   vlabel(button[1]+7,222,21,labelText,p.cyan,labelSize)
  end
 end
 return {draw=draw,action=action,busy=busy,choice=choice,attitude=function()return showAttitude end,reset=function()draft={};dirty=false;lastApplied=nil;errorMessage=nil;mode='FAV';bandIndex=1 end}
end)()
local function vtxScreen(d)vtxUi.draw(d)end
local newFlightUntil
local diagnosticLogIndex=1
local logMessageCache={lines={}}
local function logMessageLines(message)
 if logMessageCache.message==message then return logMessageCache.lines end
 logMessageCache.message=message
 local lines=logMessageCache.lines;for i=1,#lines do lines[i]=nil end
 local remaining=message
 for i=1,4 do
  if #remaining==0 then break end
  local n=math.min(#remaining,64)
  while n>1 and textWidth(string.sub(remaining,1,n),SMLSIZE)>440 do n=n-1 end
  if n<#remaining then
   local space
   for j=math.floor(n/2),n do if string.sub(remaining,j,j)==' 'then space=j end end
   if space then n=space end
  end
  lines[i]=string.sub(remaining,1,n);remaining=string.gsub(string.sub(remaining,n+1),'^ +','')
 end
 return lines
end
local function diagnostics(d)
 local p=palette;frame('DIAGNOSTICS',d)
 local titles={'RUNTIME >','FLIGHT CONTROLLER >','FC SENSOR HEALTH >','QUICK ACTIONS >','ERROR LOG >','ABOUT / SYSTEM >','RADIO BATTERY >'}
 panel(8,64,464,154,titles[diagnosticView])
 local state=fcLink.state;local board=state.board or{};local rows
 if diagnosticView==2 then
  rows={{'Family / firmware',(state.family or'--')..' / '..(state.firmware or'--')},{'MSP API',state.api or'--'},
   {'UID',state.uid or'--'},{'Board ID / revision',(board.identifier or'--')..' / '..tostring(board.hardwareRevision or'--')},
   {'Target',board.target or'--'},{'Board name',board.name or(state.family=='INAV'and'NOT REPORTED'or'--')},{'Manufacturer',board.manufacturer or(state.family=='INAV'and'NOT REPORTED'or'--')}}
 elseif diagnosticView==3 then
  local names={{'gyro','Gyroscope'},{'acc','Accelerometer'},{'mag','Magnetometer'},{'baro','Barometer'},{'gps','GPS'},{'rangefinder','Rangefinder'},{'pitot','Pitot'},{'opticalFlow','Optical flow'},{'overall','Overall health'}}
  local stamp=state.family=='INAV'and state.sensorHealthAt or state.lastStatus
  local fresh=state.active and stamp and getTime()>=stamp and getTime()-stamp<=800
  local healthNames={[0]='NOT SELECTED',[1]='HEALTHY',[2]='UNAVAILABLE',[3]='UNHEALTHY'}
  for i,n in ipairs(names)do
   local value='NO CURRENT STATUS'
   if fresh and state.family=='INAV'then
    local v=state.sensorHealth and state.sensorHealth[n[1]]
    if n[1]=='overall'then value=v==nil and'NOT REPORTED'or v==0 and'NOT HEALTHY'or v==1 and'HEALTHY'or'UNKNOWN '..v
    else value=v~=nil and(healthNames[v]or'UNKNOWN '..v)or'NOT REPORTED'end
   elseif fresh and state.sensors then local v=state.sensors[n[1]];value=v==nil and'NOT REPORTED'or v and'PRESENT'or'ABSENT'end
   local col=math.floor((i-1)/5);local x=18+col*232;local y=89+((i-1)%5)*24
   vlabel(x,y,23,n[2],p.muted,TINSIZE or SMLSIZE)
   local shown,font=fittedText(value,122,SMLSIZE);vlabel(x+212,y,23,shown,fresh and p.white or p.orange,font,true)
  end
  local age=stamp and getTime()>=stamp and string.format('%.1f s',(getTime()-stamp)/100)or'--'
  vlabel(250,185,23,'Status age',p.muted,TINSIZE or SMLSIZE);vlabel(462,185,23,age,p.muted,SMLSIZE,true)
 elseif diagnosticView==4 then
  for _,button in ipairs({{8,225,'RESTART MSP SESSION'},{242,230,'RELOAD AERODECK'}})do rect(button[1],89,button[2],29,p.black);vlabel(button[1]+8,89,29,button[3],p.cyan)end
  vlabel(18,132,20,'MSP restart reopens the Lua connection.',p.muted)
  vlabel(18,154,20,'Reload reinitializes the local session.',p.muted)
  vlabel(18,178,20,'New Flight clears local flight/track and',p.muted)
  vlabel(18,198,18,'optional radio statistics / selected timer.',p.muted)
 elseif diagnosticView==7 then
  local radio=d.radioStatus or{}
  rows={{'Transmitter voltage',numberText(radio.voltage,'%.1f',' V')},{'Native warning threshold',numberText(radio.battWarn,'%.1f',' V')},
   {'Native range minimum',numberText(radio.battMin,'%.1f',' V')},{'Native range maximum',numberText(radio.battMax,'%.1f',' V')},
   {'Range estimate',numberText(radio.percent,'%.0f','% / not charge capacity')},{'Warning',radio.warning==nil and'UNAVAILABLE'or radio.warning and'LOW'or'NORMAL'},
   {'Source / limits',(radio.voltageState or'MODULE UNAVAILABLE')..' / '..(radio.limitsState or'--')}}
 elseif diagnosticView==6 then
  if not modelImage then local chunk=loadScript and loadScript(ROOT..'model-image.lua');local factory=chunk and chunk();modelImage=factory and factory.new({Bitmap=Bitmap,lcd=lcd})or nil end
  local image=modelImage and modelImage.set(model.getInfo().bitmap,configuration.get('modelImage')==1,modelIdentity)
  local texts={{'Model',modelName},{'Build',BUILD_ID},{'Radio OS',renderStats.radioVersion or'--'},{'Date / LCD',(renderStats.date or'--')..' / '..tostring(LCD_W or 480)..'x'..tostring(LCD_H or 272)}}
  for i,r in ipairs(texts)do local y=89+(i-1)*17;vlabel(18,y,17,r[1],p.muted);local shown,font=fittedText(r[2],220,SMLSIZE);vlabel(335,y,17,shown,p.white,font,true)end
  rect(350,89,112,70,p.black)
  if not image or image.status~='READY'or not modelImage.draw(352,91,108,66)then
   vlabel(355,99,17,'MODEL IMAGE',p.muted,TINSIZE or SMLSIZE)
   local shown,font=fittedText(image and image.status or'UNAVAILABLE',102,SMLSIZE);vlabel(355,123,17,shown,p.muted,font)
  end
  local details={{'Lua RAM / observed peak',string.format('%.1f / %.1f KB',renderStats.ramKB or 0,renderStats.peakKB or 0)},
   {'Controls','SYS sections / hold SYS for actions'},
   {'Activation','None / no licence key required'}}
  for i,r in ipairs(details)do local y=164+(i-1)*17;vlabel(18,y,17,r[1],p.muted);local shown,font=fittedText(r[2],278,SMLSIZE);vlabel(462,y,17,shown,p.white,font,true)end
 elseif diagnosticView==5 then
  local state=runtimeServices.log();local events=state and state.events
  local count=events and #events or 0;diagnosticLogIndex=math.max(1,math.min(diagnosticLogIndex,count))
  local status=not state and 'LOG MODULE UNAVAILABLE'or not state.enabled and 'LOG OFF / ENABLE IN APPLICATION'or state.error or(state.state..' / '..count..' EVENTS')
  local shown,font=fittedText(status,444,SMLSIZE);vlabel(18,89,17,shown,state and state.enabled and p.cyan or p.muted,font)
  local event=events and events[diagnosticLogIndex]
  if event then
   shown,font=fittedText(string.format('%d/%d  %s  /  %dx',diagnosticLogIndex,count,event.kind,event.repeats),444,SMLSIZE);vlabel(18,106,17,shown,p.white,font)
   shown,font=fittedText(event.modelId..' / '..event.date..' / t'..event.lastTick,444,SMLSIZE);vlabel(18,123,17,shown,p.muted,font)
   for i,text in ipairs(logMessageLines(event.message))do vlabel(18,140+(i-1)*17,17,text,p.white)end
  else
   vlabel(18,119,20,'NO OBSERVED ERRORS',p.muted)
   vlabel(18,147,20,'Enable Error log in Application settings.',p.muted)
   vlabel(18,175,20,'SAVE LOG writes the pending RAM events.',p.muted)
  end
 else
  rows={{'Build',BUILD_ID},{'Protocol',d.protocol and d.protocol.id or 'UNKNOWN'},
   {'FC / API',(state.firmware or '--')..' / '..(state.api or '--')},{'FC connection',state.status},
   {'Timer',(d.timerOwner and d.timerOwner.owned and 'AERODECK / 'or'RADIO / ')..(d.session and d.session.modelTimer and('T'..d.session.modelTimer.index..' / '..tostring(d.session.modelTimer.value)..' s')or string.format('APP %02d:%02d',math.floor(flightSeconds/60),math.floor(flightSeconds)%60))},
   {'Rendering',string.format('%.1f fps / %.1f value Hz',renderStats.fps,renderStats.attitudeHz)},
   {'Module / reset error',d.timerError or d.timerOwnershipWarning or d.logError or d.powerError or d.sessionError or nativeResetError or'NONE'}}
 end
 if rows then for i,r in ipairs(rows)do local y=89+(i-1)*17;vlabel(18,y,17,r[1],p.muted);local shown,font=fittedText(r[2],305,SMLSIZE);vlabel(462,y,17,shown,p.white,font,true)end end
 if diagnosticView==5 then
  local state=runtimeServices.log();local count=state and #state.events or 0
  for _,b in ipairs({{8,110,'PREV ERROR',diagnosticLogIndex>1},{126,110,'NEXT ERROR',diagnosticLogIndex<count},{244,228,'SAVE LOG',state and state.enabled and state.pending}})do rect(b[1],222,b[2],21,p.tape);vlabel(b[1]+8,222,21,b[3],b[4]and p.cyan or p.muted)end
 else
  for _,b in ipairs({{8,145,'REFRESH'},{161,150,alertsMuted and 'UNMUTE'or'MUTE ALERTS'},{319,153,newFlightUntil and getTime()<newFlightUntil and'CONFIRM RESET'or'NEW FLIGHT'}})do rect(b[1],222,b[2],21,p.tape);vlabel(b[1]+8,222,21,b[3],p.cyan)end
 end
end

local accents={{164,227,125},{104,221,237},{255,174,98}}
local appliedAccent,appliedTheme
-- Six stable sections. The same bar is used by touch, SYS and PAGE.
local function selectPage(id)
 if id==12 and sharedData and sharedData.radioWarning then diagnosticView=7 end
 menuOpen=false;controlFocus=0
 if id==page and backgroundReady then lastFrame=-100;return end
 changePage(id);if id==4 then scanSensors()end
end
shell=(function()
 local groups={
  {title='FLIGHT',icon=1,tabs={{1,'INSTRUMENTS'},{10,'ARM INFO'},{13,'RADIO INPUTS'}}},
  {title='DATA',icon=5,tabs={{5,'TELEMETRY'},{3,'POWER'},{9,'RC LINK'}}},
  {title='GPS',icon=7,tabs={{7,'GPS DETAILS'},{2,'TRACK / HOME'}}},
  {title='VIDEO',icon=11,tabs={{11,'VTX CONTROL'}}},
  {title='SETUP',icon=8,tabs={{8,'CONFIGURATION'}}},
  {title='TOOLS',icon=13,tabs={{6,'STICK GUIDE'},{4,'SENSORS'},{12,'DIAGNOSTICS'}}}
 }
 local clockAt,clock,dateText=-100,'--:--','----/--/--'
 local headerView=1
 local alertTarget,notice,noticeUntil
 local function groupFor(id)
  for i,g in ipairs(groups)do for _,tab in ipairs(g.tabs)do if tab[1]==id then return i,g end end end
  return 1,groups[1]
 end
 -- Shared rectangles keep paint, keyboard focus and touch on the same grid.
 local navCells,tabCells={},{}
 for i=1,#groups do
  local x=104+math.floor((i-1)*376/6);local right=104+math.floor(i*376/6)
  local ix=x+math.floor((right-x-30)/2)
  navCells[i]={x=x,w=right-x,iconX=ix,plateX=ix-7,plateW=44}
 end
 for id=1,13 do
  local index,g=groupFor(id);local cells={};tabCells[id]=cells
  if id~=1 and index~=5 then
   local left,width=0,480
   for i,tab in ipairs(g.tabs)do
    local x=left+math.floor((i-1)*width/#g.tabs);local right=left+math.floor(i*width/#g.tabs)
    cells[#cells+1]={id=tab[1],caption=tab[2],x=x,w=right-x}
   end
  end
 end
 local bodies={
  [1]={{'flightBank',126,222,69,22,'FLIGHT PANEL'},{'inputStates',195,222,87,22,'THROTTLE / INPUT STATES'}},
  [13]={{'inputSetup',8,222,228,21,'INPUTS / TIMERS'},{'modeSetup',244,222,228,21,'MODE INDICATORS'}},
  [12]={{'diagView',8,64,464,24,'DIAGNOSTIC VIEW'},{'restartMsp',8,89,225,29,'RESTART MSP SESSION'},{'reloadApp',242,89,230,29,'RELOAD AERODECK'},{'diagRefresh',8,222,145,21,'REFRESH LIVE SOURCES'},{'mute',161,222,150,21,'MUTE ALERTS'},{'newFlight',319,222,153,21,'NEW FLIGHT'},{'logPrevious',8,222,110,21,'PREVIOUS ERROR'},{'logNext',126,222,110,21,'NEXT ERROR'},{'logSave',244,222,228,21,'SAVE ERROR LOG'}},
  [5]={{'telemetryMode',1,35,158,26,'LIVE / NATIVE MIN / MAX'}},
  [3]={{'powerSources',8,222,152,21,'BATTERY SOURCES'},{'powerRefresh',168,222,152,21,'REFRESH'},{'powerLimits',328,222,144,21,'CELL LIMITS'},{'powerPack',8,64,175,24,'BATTERY PACK PROFILE'}},
  [2]={{'refresh',10,222,100,21,'REFRESH'},{'zoom',117,222,90,21,'ZOOM +'},{'home',214,222,112,21,'SET HOME'}},
  [7]={{'refresh',10,222,132,21,'REFRESH SENSORS'},{'home',148,222,150,21,'SET LOCAL HOME'},{'gpsMode',313,222,159,21,'GPS VIEW'},{'satPrevious',10,197,132,21,'PREVIOUS SATELLITES'},{'satNext',330,197,142,21,'NEXT SATELLITES'}},
  [6]={{'mode',362,63,108,18,'STICK MODE'},{'previous',10,221,85,22,'PREVIOUS COMMANDS'},{'next',350,221,120,22,'NEXT COMMANDS'}},
  [4]={{'sensorMode',10,64,165,20,'LIVE / RAW NATIVE MIN / MAX'},{'nextSensors',10,222,224,21,'NEXT SOURCES'},{'refreshSensors',242,222,228,21,'REFRESH'}},
  [11]={{'vtxPanel',331,35,141,26,'ATTITUDE / CONTROLS'},{'vtxPower',335,84,133,30,'OUTPUT POWER'},{'vtxPit',335,119,64,28,'PIT MODE'},{'vtxLpd',403,119,65,28,'LOW POWER DISARM'},{'vtxBand',335,154,133,25,'NEXT BAND'},{'vtxMode',335,186,133,25,'FAVOURITES / CHANNELS'},{'vtxRefresh',8,222,100,21,'REFRESH VTX'},{'vtxCancel',116,222,100,21,'CANCEL CHANGES'},{'vtxApply',224,222,100,21,'APPLY VTX'},{'editFavourites',331,222,141,21,'EDIT FAVOURITES'}}
 }
 for i=8,1,-1 do table.insert(bodies[11],1,{'vtxPick',8+((i-1)%4)*79,102+math.floor((i-1)/4)*50,74,45,'CHANNEL '..i,i})end
 -- Control geometry is built once, never in the telemetry/render loop.
 local controls={}
 for id=1,13 do
  local index,g=groupFor(id);local items={};controls[id]=items
  if index~=5 and id~=10 then
   for _,tab in ipairs(tabCells[id])do if tab.id~=id then
    items[#items+1]={'page',tab.x+1,tab.y or 35,tab.w-2,tab.h or 26,tab.caption,tab.id}
   end end
  end
  for _,b in ipairs(bodies[id] or {})do items[#items+1]=b end
  items[#items+1]={'arm',432,246,48,26,'ARM INFO',10}
  items[#items+1]={'alert',0,246,432,26,'ALERT DETAILS'}
 end
 local function installReferences(ui)
  for _,spec in ipairs({{6,ui.guideControls},{10,ui.armControls}})do
   local items={}
   for _,old in ipairs(controls[spec[1]])do if old[1]=='page'then items[#items+1]=old end end
   for _,item in ipairs(spec[2])do items[#items+1]=item end
   items[#items+1]={'arm',432,246,48,26,'ARM INFO',10};items[#items+1]={'alert',0,246,432,26,'ALERT DETAILS'}
   controls[spec[1]]=items
  end
  controlFocus=0
 end
 local function enabled(item)
  if referenceUi then local name=item[1];if string.sub(name,1,5)=='guide'then return referenceUi.enabled('guide',name)elseif string.sub(name,1,3)=='arm'and name~='arm'then return referenceUi.enabled('arm',name)end end
  if vtxUi.attitude()and(item[1]=='vtxPower'or item[1]=='vtxPit'or item[1]=='vtxLpd'or item[1]=='vtxBand'or item[1]=='vtxMode')then return false end
  if item[1]=='vtxPick' then return not vtxUi.busy() and vtxUi.choice(item[7])~=nil end
  if item[1]=='vtxLpd'then return not vtxUi.busy()and fcLink.videoState().reported and fcLink.videoState().reported.lowPowerDisarm~=nil end
  if item[1]=='vtxMode'or item[1]=='editFavourites'then return configuration.get('vtxMode')==2 end
  if item[1]=='vtxApply' then return not vtxUi.busy() end
  if item[1]=='vtxPower' or item[1]=='vtxPit' then return not vtxUi.busy() end
  if item[1]=='arm' then return page~=10 end
  if item[1]=='alert' then return alertTarget~=nil end
  if item[1]=='restartMsp'or item[1]=='reloadApp'then return diagnosticView==4 end
  if item[1]=='diagRefresh'or item[1]=='mute'or item[1]=='newFlight'then return diagnosticView~=5 end
  if item[1]=='logPrevious'then return diagnosticView==5 and diagnosticLogIndex>1 end
  if item[1]=='logNext'then local state=runtimeServices.log();return diagnosticView==5 and state and diagnosticLogIndex<#state.events end
  if item[1]=='logSave'then local state=runtimeServices.log();return diagnosticView==5 and state and state.enabled and state.pending end
  if item[1]=='modeSetup'then return configuration.canOpen(7)end
  if item[1]=='powerPack'then return configuration.canOpen(4)end
  if item[1]=='powerLimits' then return configuration.canOpen(3)end
  if item[1]=='home' then return navCurrent~=nil and(not sharedData or sharedData.fix~=false)end
  if item[1]=='satPrevious'then return gpsView=='SATELLITES'and satellitePage>1 end
  if item[1]=='satNext'then return gpsView=='SATELLITES'and fcLink.state.satellites and satellitePage*6<#fcLink.state.satellites end
  if item[1]=='previous' then return commandPage>1 end
  if item[1]=='next' then return commandPage<2 end
  return true
 end
 local function outline(x,y,w,h,c)
  line(x,y,x+w-1,y,c);line(x,y,x,y+h-1,c)
  line(x+w-1,y,x+w-1,y+h-1,c);line(x,y+h-1,x+w-1,y+h-1,c)
 end
 local function moveControl(delta)
  local items=controls[page];local i=controlFocus
  for _=1,#items do
   if i==0 then i=delta>0 and 1 or #items else i=(i-1+delta)%#items+1 end
   if enabled(items[i])then controlFocus=i;return end
  end
  controlFocus=0
 end
 local function focused()
  local item=controls[page][controlFocus]
  return item and enabled(item) and item or nil
 end
 local function hit(x,y,id)
  if y<34 then
   if x<40 then return 1 elseif x<104 then return nil end
   for i,cell in ipairs(navCells)do
    if x>=cell.x and x<cell.x+cell.w then return sectionRoots[i]end
   end
  elseif not menuOpen and((id==1 and y>=34 and y<64)or(id~=1 and y>=35 and y<61))then
   for _,tab in ipairs(tabCells[id])do if x>=tab.x and x<tab.x+tab.w and y>=(tab.y or 35)and y<(tab.y or 35)+(tab.h or 26)then return tab.id end end
  end
 end
 local function updateAlerts(d)
  alertTarget=d.battery and 3 or d.radioWarning and 12 or d.link and 9 or not d.ok and 12 or nil
  -- A cleared warning must return keyboard focus to the page's normal controls.
  if controlFocus>0 and not focused()then controlFocus=0 end
 end
 local function footerHit(x,y)
  if x<0 or x>=480 or y<246 or y>=272 then return nil end
  return x>=432 and 10 or alertTarget
 end
 local function draw(id,d)
  local p=palette;local selected,g=groupFor(id)
  rect(0,0,480,34,p.black);rect(0,33,480,1,p.border)
  icon(0,5,2,p.muted)
  local now=getTime()
  if now-clockAt>=100 then
   if getDateTime then local date=getDateTime();if date then clock=string.format('%02d:%02d',date.hour,date.min);if date.year and date.mon and date.day then dateText=string.format('%04d/%02d/%02d',date.year,date.mon,date.day);renderStats.date=dateText;end end end
   clockAt=now
  end
  if headerView==1 then
   icon(3,43,0,d.radioWarning and p.orange or p.muted,18);vlabel(96,0,18,d.radioVoltage and string.format('%.1f',d.radioVoltage)or'--',p.white,SMLSIZE,true)
  elseif headerView==2 then vlabel(43,0,18,clock,p.white)
  elseif headerView==4 then local shown,font=fittedText(dateText,60,TINSIZE or SMLSIZE);vlabel(43,0,18,shown,p.white,font)
  else
   local timer=d.session and d.session.modelTimer;local seconds=timer and timer.value or flightSeconds
   vlabel(43,0,18,timer and'T'..timer.index or'APP',p.cyan,TINSIZE or SMLSIZE)
   vlabel(102,0,18,string.format('%02d:%02d',math.floor(math.abs(seconds)/60),math.floor(math.abs(seconds))%60),p.white,TINSIZE or SMLSIZE,true)
  end
  local modelCaption,modelFont=fittedText(modelName or '',54,TINSIZE or SMLSIZE)
  vlabel(43,18,15,modelCaption,p.muted,modelFont)
  for i,section in ipairs(groups)do
   local cell=navCells[i]
   if selected==i then rect(cell.plateX,1,cell.plateW,32,p.tape);rect(cell.plateX,31,cell.plateW,2,p.green)end
   icon(section.icon,cell.iconX,2,selected==i and p.white or p.muted)
   if menuOpen and menuIndex==i then outline(cell.plateX,1,cell.plateW,32,p.cyan)end
  end
  if menuOpen then
   rect(0,35,480,26,p.tape);vlabel(12,35,26,groups[menuIndex].title..' / SELECT SECTION',p.white)
   vlabel(468,35,26,'ENTER / RTN',p.cyan,SMLSIZE,true)
  elseif id~=1 and selected~=5 then
   if id~=1 then rect(0,35,480,26,p.black)end
   for i,tab in ipairs(tabCells[id])do
    local x,w,active=tab.x+1,tab.w-2,tab.id==id;local color=active and p.white or p.muted
    rect(x,35,w,26,active and p.tape or p.black)
    if active then rect(x,59,w,2,p.cyan)end
    local caption=id==5 and tab.id==5 and('TELEM / '..telemetryMode..' >')or selected==1 and i==1 and ('FM / '..tostring(d.flight or '--')) or tab.caption
    local available=w-12-(selected==4 and 90 or 0)
    local shown,font=fittedText(caption,available-24,SMLSIZE)
    local groupWidth=24+textWidth(shown,font);local gx=x+6+math.floor((available-groupWidth)/2)
    icon(tab.id==13 and 6 or tab.id,gx,38,color,18);vlabel(gx+24,35,24,shown,color,font)
   end
   if selected==4 then vlabel(468,35,24,vtxUi.attitude()and 'CONTROLS >'or 'ATTITUDE >',p.cyan,SMLSIZE,true)end
  end
  local flags,active,decodeError=armUi.status()
  local armText,armColor='FLAGS --',p.muted
  if active and flags then
   if #flags.reasons>0 then
    armText=flags.reasons[1].code..(#flags.reasons>1 and ' +'..(#flags.reasons-1)or '')
    armColor=p.orange
   else armText='NO FLAGS';armColor=p.white end
  elseif active and decodeError then armText='STATUS ERROR';armColor=p.orange
  elseif fcLink.state.active and fcLink.state.lastStatus and now>=fcLink.state.lastStatus and now-fcLink.state.lastStatus>800 then
   armText='STATUS OLD';armColor=p.orange
  end
  local warning=d.battery or(d.radioWarning and'RADIO BATTERY LOW')or d.link or not d.ok and(d.disabled and 'TELEMETRY DISABLED'or'NO CURRENT TELEMETRY')
  if alertTarget then
   rect(0,246,480,26,p.red)
   local shown,font=fittedText(warning..'  >',408,SMLSIZE)
   vlabel(9,246,26,shown,p.black,font)
  elseif notice and now<noticeUntil then
   rect(0,246,480,26,p.tape)
   local shown,font=fittedText(notice,408,SMLSIZE)
   vlabel(12,246,26,shown,p.cyan,font)
  else
   rect(0,246,480,26,p.black);rect(0,246,480,1,p.border)
   local mode,font=fittedText(tostring(d.displayFlight or d.flight or '--'),104,SMLSIZE)
   vlabel(8,247,24,mode,p.white,font)
   line(120,251,120,267,p.border);line(240,251,240,267,p.border)
   if id==1 then
    icon(0,128,250,p.muted,18);local dist=d.session and d.session.homeDistance
    flightValue(152,247,80,24,dist and round(dist)or '--','m',SMLSIZE)
    icon(14,248,250,d.sats and p.cyan or p.muted,18);flightValue(272,247,24,24,d.sats and round(d.sats)or '--','',SMLSIZE,d.sats and p.cyan or p.muted)
   else
    icon(3,128,250,d.battery and p.orange or p.muted,18);flightValue(152,247,80,24,d.v and string.format('%.1f',d.v)or'--','V',SMLSIZE)
    local quality=d.protocol and d.protocol.family=='FRSKY'and d.rssi or d.lq
    icon(9,248,250,d.link and p.orange or p.muted,18);flightValue(272,247,24,24,quality and round(quality)or'--','',SMLSIZE,d.link and p.orange or p.cyan)
   end
   line(304,251,304,267,p.border)
   local shown,size=fittedText(armText,112,SMLSIZE)
   vlabel(312,247,24,shown,armColor,size)
  end
  -- One persistent icon-only action; its visible cell, touch and key focus agree.
  rect(432,246,48,26,alertTarget and p.red or p.tape)
  line(432,246,432,271,alertTarget and p.black or p.border)
  icon(10,447,250,alertTarget and p.black or armColor,18)
  if id==10 then rect(433,270,46,2,p.cyan)end
  if not menuOpen and page~=10 then
   local item=focused();if item then outline(item[2],item[3],item[4],item[5],p.cyan)end
  end
 end
 return {cycleHeader=function()headerView=headerView%4+1 end,installReferences=installReferences,draw=draw,updateAlerts=updateAlerts,hit=hit,footerHit=footerHit,group=groupFor,controls=controls,enabled=enabled,focused=focused,move=moveControl,outline=outline,
  alert=function()return alertTarget end,notify=function(s)notice=s;noticeUntil=getTime()+150;lastFrame=-100 end}
end)()

local function chooseSection(id)
 if id==8 then
  if page~=8 or not configuration.isList()then configuration.openSection(nil)end
  configReturn=1
 end
 selectPage(id)
end
local function openArm()
 if page~=10 then armReturn=page;selectPage(10)end
end
local function activate(item)
 if not item then return end
 local action=item[1]
 if referenceUi and string.sub(action,1,5)=='guide'then referenceUi.guideAction(action);local state=referenceUi.snapshot();stickMode=state.mode;commandPage=state.guidePage
 elseif referenceUi and string.sub(action,1,3)=='arm'and action~='arm'then referenceUi.armAction(action)
 elseif string.sub(action,1,3)=='vtx' then
  local methods={vtxPanel='panel',vtxPick='pick',vtxPower='power',vtxPit='pit',vtxLpd='lpd',vtxBand='band',vtxMode='mode',vtxRefresh='refresh',vtxCancel='cancel',vtxApply='apply'}
  local ok,why=vtxUi.action(methods[action],item[7]);if not ok then shell.notify(tostring(why))end
 elseif action=='arm' then openArm()
 elseif action=='page' then selectPage(item[7])
 elseif action=='alert' then if sharedData and sharedData.radioWarning then diagnosticView=7 end;selectPage(shell.alert())
 elseif action=='telemetryMode'then telemetryMode=telemetryMode=='LIVE'and'MIN'or telemetryMode=='MIN'and'MAX'or'LIVE'
 elseif action=='gpsMode'then gpsView=gpsView=='DETAILS'and'SATELLITES'or gpsView=='SATELLITES'and'QUALITY'or gpsView=='QUALITY'and'RECOVERY'or'DETAILS';satellitePage=1
 elseif action=='satPrevious'then satellitePage=math.max(1,satellitePage-1)
 elseif action=='satNext'then satellitePage=satellitePage+1
 elseif action=='flightBank'then flightBank=(flightBank+1)%3
 elseif action=='inputStates'then selectPage(13)
 elseif action=='inputSetup'then configuration.openSection(6);configReturn=13;selectPage(8)
 elseif action=='modeSetup'then configuration.openSection(7);configReturn=13;selectPage(8)
 elseif action=='powerPack'then
  if configuration.hasChanges()then shell.notify('SAVE OR REVERT SETTINGS BEFORE PACK SELECTION')
  else
   if not packPicker then local chunk=loadScript and loadScript(ROOT..'quick-pack.lua');local factory=chunk and chunk();packPicker=factory and factory.new({lcd=lcd,palette=function()return palette end,fonts={small=SMLSIZE,tiny=TINSIZE},colorFlag=CUSTOM_COLOR,configget=configuration.get,selectPack=configuration.selectPack})or nil end
   if packPicker then packPicker.open()else shell.notify('PACK PICKER MODULE UNAVAILABLE')end
  end
 elseif action=='powerSources' then configuration.openSection(1,'voltage');configReturn=3;selectPage(8)
 elseif action=='powerLimits' then configuration.openSection(3);configReturn=3;selectPage(8)
 elseif action=='diagView'then diagnosticView=diagnosticView%7+1;if diagnosticView==5 then local state=runtimeServices.log();diagnosticLogIndex=state and math.max(1,#state.events)or 1 end
 elseif action=='logPrevious'then diagnosticLogIndex=math.max(1,diagnosticLogIndex-1)
 elseif action=='logNext'then local state=runtimeServices.log();if state then diagnosticLogIndex=math.min(#state.events,diagnosticLogIndex+1)end
 elseif action=='logSave'then
  local ok,why=runtimeServices.flush()
  if ok then shell.notify(why=='PENDING'and'SAVING ERROR LOG'or why=='UNCHANGED'and'ERROR LOG UP TO DATE'or'ERROR LOG SAVED')
  elseif why=='RATE LIMITED'then local state=runtimeServices.log();local wait=state and state.nextFlushAt and math.max(0,math.ceil((state.nextFlushAt-getTime())/100))or 30;shell.notify('LOG SAVE AVAILABLE IN '..wait..' SECONDS')
  else shell.notify('LOG SAVE FAILED / '..tostring(why))end
 elseif action=='restartMsp'then
  fcLink.init();shell.notify('MSP SESSION RESTARTED')
 elseif action=='reloadApp'then
  if configuration.hasChanges()then shell.notify('SAVE OR REVERT SETTINGS BEFORE RELOAD')else local ok,why=closeApp();if ok then referenceUi=nil;init();shell.notify('AERODECK RELOADED')else shell.notify('TIMER RELEASE FAILED / '..tostring(why))end end
 elseif action=='diagRefresh'then telemetry.refreshBindings();inputRuntime.refresh();if fcLink.client and fcLink.client.requestInfo then fcLink.client:requestInfo(true)end;shell.notify('REFRESHING LIVE SOURCES')
 elseif action=='mute'then if session then alertsMuted=session.toggleMuted();shell.notify(alertsMuted and 'AERODECK ALERTS MUTED'or'AERODECK ALERTS ENABLED')end
 elseif action=='newFlight'then
  if flightResetJob then shell.notify('RADIO STATISTICS RESET IN PROGRESS')
  elseif configuration.get('resetNativeTelemetry')==1 and type(model.resetSensor)~='function'then runtimeServices.record('NATIVE RESET','RADIO SENSOR RESET API UNAVAILABLE');shell.notify('RADIO SENSOR RESET API UNAVAILABLE')
  elseif inputRuntime.armedNow()==true or sharedData and sharedData.armed==true then shell.notify('DISARM BEFORE RESETTING FLIGHT')
  elseif newFlightUntil and getTime()<newFlightUntil then
   local ok,why;local owner=runtimeServices.timer();local owned=owner and owner.owned
   if not session then ok=false;why='SESSION UNAVAILABLE'
   else
    if owned then ok,why=runtimeServices.resetTimer()else ok=true end
    if ok then ok,why=session.newFlight({resetModelTimer=not owned and configuration.get('resetModelTimer')==1})end
   end
   newFlightUntil=nil
   if ok then
    if configuration.get('resetNativeTelemetry')==1 then flightResetJob={index=0};telemetry.clearStatistics();fcLink.stop()end
    if referenceUi then referenceUi.stop()end
    traces={};lastTrace=-100;fcLink.stop();telemetry.resetPower();telemetry.refresh();serviceData(true);shell.notify(flightResetJob and 'CLEARING RADIO STATISTICS / FC COUNTERS UNCHANGED'or'NEW LOCAL FLIGHT / TRACK RESET')else shell.notify(why or 'SESSION UNAVAILABLE')end
  else newFlightUntil=getTime()+300;shell.notify('PRESS NEW FLIGHT AGAIN TO RESET')end
 elseif action=='powerRefresh' then telemetry.refreshBindings();inputRuntime.refresh();shell.notify('SENSOR BINDINGS REFRESHED')
 elseif action=='refresh' then navAction('mode');shell.notify('SENSOR BINDINGS REFRESHED')
 elseif action=='zoom' then navAction('zoom')
 elseif action=='home' then navAction('home');shell.notify('LOCAL HOME SET')
 elseif action=='mode' then stickMode=stickMode%4+1
 elseif action=='previous' then commandPage=math.max(1,commandPage-1)
 elseif action=='next' then commandPage=math.min(2,commandPage+1)
 elseif action=='sensorMode'then sensorMode=sensorMode=='LIVE'and'MIN'or sensorMode=='MIN'and'MAX'or'LIVE'
 elseif action=='nextSensors' then sensorOffset=sensorOffset+5;scanSensors()
 elseif action=='refreshSensors' then telemetry.refreshBindings();inputRuntime.refresh();scanSensors();shell.notify('SENSOR BINDINGS REFRESHED')
 elseif action=='editFavourites' then
  configReturn=11;selectPage(8);configuration.openSection(configuration.canOpen(9) and 9 or 1)
 end
 if controlFocus>0 and not shell.focused()then controlFocus=0 end
 lastFrame=-100
end
local exitButtons={{60,'KEEP EDITING'},{245,'DISCARD / EXIT'}}
function quick.open()
 for i=1,#quick.rows do quick.rows[i]=nil end
 quick.rows[1]={'mute','MUTE / ENABLE ALERTS'};quick.rows[2]={'newFlight','RESET FLIGHT DATA'}
 local configured=configuration.get('fcType')~='Off'and configuration.get('fcType')~='Other'and configuration.get('mspMode')==1
 if configured then quick.rows[#quick.rows+1]={'restartMsp','RESTART MSP SESSION'}end
 if configured and configuration.get('vtxBackend')=='FC MSP'and configuration.get('vtxMode')>0 and configuration.get('fcType')~='INAV'then quick.rows[#quick.rows+1]={'vtxRefresh','READ VTX TABLES'}end
 quick.rows[#quick.rows+1]={'reloadApp','RELOAD AERODECK'}
 quick.active=true;quick.focus=1;quick.ignoreRelease=true
end
function quick.input(event,touch)
 local menu=(EVT_SYS_BREAK and event==EVT_SYS_BREAK)or(EVT_VIRTUAL_MENU and event==EVT_VIRTUAL_MENU)
 if menu and quick.ignoreRelease then quick.ignoreRelease=false;return end
 if event==EVT_VIRTUAL_EXIT or menu then quick.active=false;return end
 if event==EVT_VIRTUAL_NEXT then quick.focus=quick.focus%(#quick.rows+1)+1
 elseif event==EVT_VIRTUAL_PREV then quick.focus=(quick.focus-2)%(#quick.rows+1)+1
 elseif event==EVT_VIRTUAL_ENTER or event==EVT_TOUCH_TAP and touch then
  if touch then
   if touch.x>=8 and touch.x<472 and touch.y>=90 and touch.y<90+#quick.rows*25 then quick.focus=math.floor((touch.y-90)/25)+1
   elseif touch.x>=8 and touch.x<472 and touch.y>=222 and touch.y<244 then quick.focus=#quick.rows+1
   else return end
  end
  local row=quick.rows[quick.focus]
  if not row then quick.active=false;return end
  local confirm=row[1]=='newFlight'and not(newFlightUntil and getTime()<newFlightUntil)
  if row[1]=='vtxRefresh'then
   selectPage(11);quick.refreshVideo=true
  else activate(row)end
  if not confirm then quick.active=false end
 end
end
function quick.draw()
 if not quick.active then return end
 local p=palette;rect(5,62,470,182,p.black);rect(8,64,464,22,p.tape);vlabel(18,64,22,'QUICK ACTIONS',p.white)
 for i,row in ipairs(quick.rows)do
  local y=90+(i-1)*25;local selected=i==quick.focus;rect(8,y,464,24,selected and p.green or p.tape)
  local text=row[1]=='mute'and(alertsMuted and'ENABLE ALERTS'or'MUTE ALERTS')or row[1]=='newFlight'and newFlightUntil and getTime()<newFlightUntil and'CONFIRM RESET FLIGHT DATA'or row[2]
  vlabel(18,y,24,text,selected and p.black or p.white)
 end
 rect(8,222,464,21,quick.focus==#quick.rows+1 and p.green or p.tape);vlabel(18,222,21,'CANCEL / RTN',quick.focus==#quick.rows+1 and p.black or p.cyan)
end
local function exitDialog()
 local p=palette
 rect(49,75,382,145,p.border);rect(50,76,380,143,p.tape)
 label(68,92,'UNSAVED SETTINGS',p.white,MIDSIZE)
 label(68,132,'Keep editing, or discard before exiting.',p.muted)
 for i,b in ipairs(exitButtons)do
  rect(b[1],175,175,32,p.black);vlabel(b[1]+10,175,32,b[2],p.white)
  if exitChoice==i then shell.outline(b[1],175,175,32,p.cyan)end
 end
end

local function serviceFlightReset()
 if not flightResetJob then return end
 for _=1,16 do
  local ok,err=pcall(model.resetSensor,flightResetJob.index)
  if not ok or err==false then nativeResetError='SENSOR RESET FAILED '..tostring(err);flightResetJob=nil;shell.notify('RADIO RESET FAILED / PARTIAL');return end
  flightResetJob.index=flightResetJob.index+1
  if flightResetJob.index>=64 then flightResetJob=nil;nativeResetError=nil;telemetry.resetPower();shell.notify('RADIO STATISTICS CLEARED / FC COUNTERS UNCHANGED');return end
 end
end

local function run(event,touch)
 local serviceAtEntry=inputRuntime.serviceSerial
 if not started then init() end
 if inputRuntime.advanceStartup()then
  if event==EVT_VIRTUAL_EXIT and leaveFull()then return 1 end
  nativeLcd.clear();nativeLcd.drawText(12,20,'STARTING AERODECK',MIDSIZE)
  local state=inputRuntime.startup;nativeLcd.drawText(12,62,state and state.view.initializing or'READY',SMLSIZE)
  return 0
 end
 if displayError then nativeLcd.clear();nativeLcd.drawText(10,20,displayError,SMLSIZE);if event==EVT_VIRTUAL_EXIT then if leaveFull()then return 1 end end;return 0 end
 if display and touch then touch=display.touch(touch)end
 local info=model.getInfo();local identity=inputRuntime.modelIdentity(info);modelName=info.name or'MODEL'
 runtimeServices.modelInfo(info)
 if identity~=modelIdentity then fcLink.stop();init();if inputRuntime.startup then inputRuntime.progress('STARTING NEW MODEL');return 0 end end
 serviceFlightReset()
 foreground=true
 if not palette or appliedTheme~=configuration.get('theme')then
  palette={};appliedTheme=configuration.get('theme');appliedAccent=nil
  local colors={red={250,91,64},green={164,227,125},cyan={104,221,237},orange={255,174,98},white={232,242,245},muted={140,164,179},dim={42,64,79},border={57,84,100},sky={32,112,166},ground={117,88,49},horizon={157,208,221},ladder={128,173,191},black={5,12,19},tape={15,31,43},route={56,82,92}}
  if appliedTheme==1 then local overrides={red={174,23,10},green={48,102,25},cyan={0,88,108},orange={128,65,0},white={12,32,43},muted={58,81,92},dim={175,194,202},border={117,145,159},black={231,242,245},tape={207,224,232},ladder={220,237,244}};for k,v in pairs(overrides)do colors[k]=v end
  elseif appliedTheme==2 then local overrides={white={213,160,141},muted={147,103,94},dim={51,27,27},border={98,52,42},black={9,3,3},tape={27,10,10},sky={61,37,46},ground={89,41,23},horizon={184,114,88},ladder={178,122,104}};for k,v in pairs(overrides)do colors[k]=v end
  elseif appliedTheme==3 then local overrides={white={255,255,255},muted={210,218,224},dim={65,70,75},border={180,195,204},black={0,0,0},tape={12,17,22},sky={0,78,140},ground={89,48,12},ladder={230,240,249}};for k,v in pairs(overrides)do colors[k]=v end end
  for k,v in pairs(colors)do palette[k]=lcd.RGB(v[1],v[2],v[3])end
 end
 local accent=configuration.get('accent');if appliedAccent~=accent then local c=appliedTheme==1 and({{48,102,25},{0,88,108},{128,65,0}})[accent]or accents[accent];palette.green=lcd.RGB(c[1],c[2],c[3]);appliedAccent=accent end
 palette.bg=palette.black;palette.panel=palette.tape;uiTheme=palette
 if inputRuntime.deferred then
  local job=runtimeServices.log()
  if job and job.flushing then
   local ok,why=runtimeServices.stepLog()
   if not ok then shell.notify('LOG SAVE FAILED / '..tostring(why))elseif why~='PENDING'then shell.notify('ERROR LOG SAVED')end
   inputRuntime.progress(not ok and'ERROR LOG SAVE FAILED'or why=='PENDING'and'SAVING ERROR LOG'or'ERROR LOG SAVED');return 0
  end
 end
 local isTap=event==EVT_TOUCH_TAP and touch~=nil
 local menuEvent=(EVT_SYS_BREAK and event==EVT_SYS_BREAK)or(EVT_VIRTUAL_MENU and event==EVT_VIRTUAL_MENU)
 if packPicker and packPicker.active()then
  local handled,status=packPicker.input(event,touch)
  if status=='EDIT'then configuration.openSection(4,'pack');configReturn=3;selectPage(8)
  elseif status=='APPLIED'then shell.notify('PACK PROFILE SELECTED')end
  lastFrame=-100
 elseif inputRuntime.active()then inputRuntime.input(event,touch);lastFrame=-100
 elseif quick.active then quick.input(event,touch);lastFrame=-100
 elseif not exitOpen and((EVT_SYS_LONG and event==EVT_SYS_LONG)or(EVT_VIRTUAL_MENU_LONG and event==EVT_VIRTUAL_MENU_LONG))then quick.open();lastFrame=-100
 elseif exitOpen then
  if event==EVT_VIRTUAL_EXIT then exitOpen=false
  elseif event==EVT_VIRTUAL_NEXT or event==EVT_VIRTUAL_PREV or event==EVT_VIRTUAL_NEXT_PAGE or event==EVT_VIRTUAL_PREV_PAGE then exitChoice=3-exitChoice
  elseif event==EVT_VIRTUAL_ENTER or isTap and touch.y>=175 and touch.y<207 and touch.x>=60 and touch.x<420 then
   if isTap then exitChoice=touch.x<240 and 1 or 2 end
   if exitChoice==2 then if leaveFull()then configuration.discardAll();return 1 end;return 0 end
   exitOpen=false;configuration.openSection(nil);configReturn=1;selectPage(8)
  end
  lastFrame=-100
 elseif menuEvent then
  menuOpen=not menuOpen;menuIndex=shell.group(page);controlFocus=0;lastFrame=-100
 elseif isTap and touch.y<34 and touch.x>=40 and touch.x<104 then shell.cycleHeader();lastFrame=-100
 elseif isTap and touch.y<34 then
  local target=shell.hit(touch.x,touch.y,page)
  if target then chooseSection(target)end
 elseif isTap and touch.y>=246 then
  local target=shell.footerHit(touch.x,touch.y)
  if target==10 then openArm()elseif target then selectPage(target)end
 elseif menuOpen then
  if event==EVT_VIRTUAL_NEXT or event==EVT_VIRTUAL_NEXT_PAGE then menuIndex=menuIndex%6+1
  elseif event==EVT_VIRTUAL_PREV or event==EVT_VIRTUAL_PREV_PAGE then menuIndex=(menuIndex+4)%6+1
  elseif event==EVT_VIRTUAL_ENTER then chooseSection(sectionRoots[menuIndex])
  elseif event==EVT_VIRTUAL_EXIT then menuOpen=false end
  lastFrame=-100
 elseif event==EVT_VIRTUAL_EXIT then
  local footerFocus=page==8 and controlFocus>0;controlFocus=0
  if footerFocus then lastFrame=-100
  elseif page==8 and configuration.back()then lastFrame=-100
  elseif page~=1 then
   local parents={[2]=7,[3]=5,[9]=5,[10]=armReturn,[4]=6,[12]=6,[13]=1,[8]=configReturn}
   selectPage(parents[page]or 1)
  elseif configuration.hasChanges()then exitOpen=true;exitChoice=1;lastFrame=-100
  else if leaveFull()then return 1 end end
 elseif event==EVT_VIRTUAL_NEXT_PAGE or event==EVT_VIRTUAL_PREV_PAGE then
  local section=shell.group(page);local delta=event==EVT_VIRTUAL_NEXT_PAGE and 1 or -1
  chooseSection(sectionRoots[(section-1+delta)%6+1])
 elseif page==8 then
  if controlFocus>0 then
   if event==EVT_VIRTUAL_ENTER then activate(shell.focused())
   elseif event==EVT_VIRTUAL_NEXT or event==EVT_VIRTUAL_PREV then
    local nextFocus=controlFocus+(event==EVT_VIRTUAL_NEXT and 1 or -1)
    local item=shell.controls[8][nextFocus]
    controlFocus=item and shell.enabled(item)and nextFocus or 0
   elseif isTap then controlFocus=0;configuration.input(event,touch)end
  elseif event==EVT_VIRTUAL_PREV and configuration.atFooterBoundary()then shell.move(-1)
  else configuration.input(event,touch)end
  if event~=0 then lastFrame=-100 end
 elseif page==5 and isTap and touch.x<160 and touch.y>=35 and touch.y<61 then
  telemetryMode=telemetryMode=='LIVE'and'MIN'or telemetryMode=='MIN'and'MAX'or'LIVE';lastFrame=-100
 elseif page==11 and isTap and touch.x>=331 and touch.y>=35 and touch.y<61 then
  vtxUi.action('panel');lastFrame=-100
 elseif isTap and((page==1 and touch.y>=34 and touch.y<64)or(page~=1 and touch.y>=35 and touch.y<61))then
  local target=shell.hit(touch.x,touch.y,page);if target then selectPage(target)end
 elseif event==EVT_VIRTUAL_NEXT or event==EVT_VIRTUAL_PREV then
  shell.move(event==EVT_VIRTUAL_NEXT and 1 or -1);lastFrame=-100
 elseif event==EVT_VIRTUAL_ENTER then
  local item=shell.focused()
  if item then activate(item)else shell.move(1)end
  lastFrame=-100
 elseif isTap then
  for _,item in ipairs(shell.controls[page])do
   if touch.x>=item[2]and touch.x<item[2]+item[4]and touch.y>=item[3]and touch.y<item[3]+item[5]and shell.enabled(item)then activate(item);break end
  end
 end
 -- Reload can enter staged initialization from an action in this callback.
 -- A confirmed flight reset can also have performed a complete service pass.
 -- Either must yield before adding transport and a full render to its budget.
 if inputRuntime.deferred and(inputRuntime.startup or inputRuntime.serviceSerial~=serviceAtEntry or event~=0 and type(getUsage)=='function'and getUsage()>15)then inputRuntime.progress(inputRuntime.startup and'STARTING SESSION'or'UPDATING SETTINGS / FLIGHT DATA');return 0 end
 local historical=inputRuntime.deferred and page==5 and telemetryMode~='LIVE'
 if not historical and inputRuntime.historyActive then telemetry.cancelExtrema()end
 inputRuntime.historyActive=historical
 if historical and not telemetry.extremaReady()then
  telemetry.prepareExtrema();inputRuntime.progress('PREPARING NATIVE '..telemetryMode);return 0
 end
 fcLink.videoPage=page==11 or page==1 and flightBank==1;fcLink.infoPage=page==12;fcLink.gpsPage=(page==7 or page==1 and flightBank==2)and configuration.get('gpsEnabled')==1 and configuration.get('gps')~='None'
 -- Normal FC replies can use the margin needed by a slow sample phase. Give
 -- overdue sampling a transport-free callback; no RF writes occur while the
 -- dispatcher is deferred, and its guards are freshly read when it resumes.
 if not(inputRuntime.deferred and(inputRuntime.samplingPriority(getTime())or historical and telemetry.extremaOverdue(getTime())or page==2 and inputRuntime.navPlotPriority(getTime())))then fcLink.update(getTime())end
 inputRuntime.syncArm()
 if inputRuntime.deferred and type(getUsage)=='function'and getUsage()>25 then inputRuntime.progress('UPDATING FLIGHT CONTROLLER');return 0 end
 if quick.refreshVideo then
  quick.refreshVideo=false;local ok,why;if fcLink.service then ok,why=fcLink.service:refreshVideo()end
  shell.notify(ok and'READING LIVE VTX TABLES'or tostring(why or'VTX CLIENT UNAVAILABLE'))
 end
 if referenceUi then referenceUi.tick(getTime())end
 inputRuntime.tick()
 local pitch,roll=telemetry.pollAttitude()
 if pitch~=nil and roll~=nil and (pitch~=renderStats.pitch or roll~=renderStats.roll) then renderStats.changes=renderStats.changes+1 end
 renderStats.pitch=pitch;renderStats.roll=roll
 local now=getTime()
 -- LVGL supplies a fresh buffer on EVERY widget refresh. Always draw it.
 -- Acquire two field batches, derive and publish in four bounded callbacks; only a
 -- completed snapshot is displayed. Current attitude is independent of that
 -- 200ms cycle and is copied into the published picture every callback.
 if not inputRuntime.deferred and now-lastFrame<math.ceil(100/configuration.get('renderHz')) and now>=lastFrame then return 0 end;lastFrame=now
 local d
 if inputRuntime.deferred then
  local modal=inputRuntime.active()or quick.active or exitOpen or packPicker and packPicker.active()
  if modal or type(getUsage)~='function'or getUsage()<=10 then d=inputRuntime.serviceFrame(now)else d=inputRuntime.frameData()end
  inputRuntime.frameAttitude(pitch,roll)
 else
  -- Slow telemetry/session work follows its existing 200ms/revision cadence.
  -- pollAttitude above still updates the live horizon on every callback.
  d=serviceData(false,true)
 end
 if not d then inputRuntime.progress('READING CURRENT TELEMETRY');return 0 end
 -- Capture/rebuild bounded map data before painting; never reproject the whole
 -- growing trail inside a widget draw. Current aircraft position stays live.
 if page==2 and(not inputRuntime.deferred or type(getUsage)~='function'or getUsage()<=18)then inputRuntime.stepNavPlot(now)end
 -- History reads are bounded independently of painting and publish atomically.
 if historical and(type(getUsage)~='function'or getUsage()<=telemetry.extremaAllowance(telemetryMode,now))then telemetry.serviceExtrema(telemetryMode,now)end
 -- Cold source changes / FC table persistence can be an exceptional burst.
 -- Paint a real opaque app view for that callback, never return an empty LVGL
 -- buffer or attempt a full PFD with an already exhausted allowance.
 if inputRuntime.deferred and type(getUsage)=='function'and getUsage()>25 then inputRuntime.progress('UPDATING SOURCES / FLIGHT CONTROLLER');return 0 end
 shell.updateAlerts(d)
 if not backgroundReady and page~=5 then changePage(page)end
 do
  rect(0,34,480,212,palette.black)
  -- Modal controls own the body. Do not spend the widget budget drawing a PFD
  -- underneath an opaque picker/action/dialog panel that replaces that body.
  if not(inputRuntime.active()or quick.active or exitOpen or packPicker and packPicker.active())then
   if page==1 then cockpit(d) elseif page==5 then telemetryScreen(d) elseif page==2 then navigation(d) elseif page==3 then powerScreen(d) elseif page==4 then systemPage() elseif page==6 then stickCommands() elseif page==7 then gpsDetails(d) elseif page==8 then configuration.draw(controlFocus>0) elseif page==9 then linkScreen(d) elseif page==10 then statusScreen(d) elseif page==11 then vtxScreen(d) elseif page==12 then diagnostics(d)elseif page==13 then inputScreen(d)end
  end
 end
 shell.draw(page,d)
 if display and display.extra.h>0 then
  local area=display.extra;local raw=display.raw
  raw.setColor(CUSTOM_COLOR,palette.black);raw.drawFilledRectangle(area.x,area.y,area.w,area.h,CUSTOM_COLOR)
  raw.setColor(CUSTOM_COLOR,palette.border);raw.drawFilledRectangle(area.x,area.y,area.w,1,CUSTOM_COLOR)
  local _,height=raw.sizeText('Ag',SMLSIZE);local y=area.y+math.floor((area.h-height)/2)
  local source=d.protocol and d.protocol.id or 'PROTOCOL UNKNOWN'
  raw.setColor(CUSTOM_COLOR,palette.muted);raw.drawText(10,y,source,SMLSIZE+CUSTOM_COLOR)
  local value=string.format('TX %s V / %.1f fps',d.radioVoltage and string.format('%.1f',d.radioVoltage)or '--',renderStats.fps)
  raw.drawText(area.w-10,y,value,SMLSIZE+RIGHT+CUSTOM_COLOR)
 end
 inputRuntime.draw()
 if packPicker and packPicker.active()then packPicker.draw()end
 quick.draw()
 if exitOpen then exitDialog()end
 renderStats.frames=renderStats.frames+1;renderStats.cost=renderStats.cost+(getTime()-now)*10
 if now-renderStats.window>=200 then
  local seconds=(now-renderStats.window)/100
  renderStats.fps=renderStats.frames/seconds;renderStats.attitudeHz=renderStats.changes/seconds;renderStats.drawMs=renderStats.cost/renderStats.frames
  renderStats.frames=0;renderStats.changes=0;renderStats.cost=0;renderStats.window=now
  renderStats.ramKB=collectgarbage('count');renderStats.peakKB=math.max(renderStats.peakKB or 0,renderStats.ramKB)
  -- Metrics stay in memory. Never write to the SD card from the refresh loop.

 end
 return 0
end
local function background()
 if not started then init()end
 if inputRuntime.advanceStartup()then return end
 local info=model.getInfo();local identity=inputRuntime.modelIdentity(info);modelName=info.name or'MODEL'
 runtimeServices.modelInfo(info)
 if identity~=modelIdentity then fcLink.stop();init();if inputRuntime.startup then return end end
 serviceFlightReset();inputRuntime.discover(16)
 if foreground then inputRuntime.stop();if packPicker then packPicker.stop()end;fcLink.stop();if referenceUi then referenceUi.stop()end;telemetry.cancelExtrema();inputRuntime.historyActive=false;foreground=false end
 serviceData(false)
end
return {init=init,run=run,stop=fcLink.stop,close=closeApp,setRetained=function(value)retainedSession=value==true end,background=background,snapshot=function()return inputRuntime.startup and inputRuntime.startup.view or sharedData end}
