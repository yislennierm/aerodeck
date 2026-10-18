-- toolName = TNS|AERODECK|TNE
-- AERODECK: integrated 480x272 TX16S cockpit and telemetry console.
-- Live telemetry only across flight, telemetry, power, link and GPS.
-- Read-only Betaflight MSP over CRSF; no model/FC settings writes. Absent telemetry is --.
-- Six stable icon sections. SYS/MDL focuses the bar; PAGE cycles sections; RTN backs out.
-- Config: 12 lists; application settings saved per model. VTX/FC writes unavailable.
-- Rotary focuses visible controls; ENTER activates. Settings Save/Revert work without touch.
-- Telemetry refresh never substitutes synthetic data.
-- Live attitude comes from current mapped sensors. Home returns Flight; unsaved exit is explicit.
local BUILD_ID='POWER-LIVE-20261017'
local renderStats={fps=0,attitudeHz=0,drawMs=0,frames=0,changes=0,window=0,cost=0,background='NOT LOADED'}
-- Toolbox's qualified telemetry-source binding avoids collisions with named inputs.
local fieldCache,telemetryFields={},{}
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
  f=findTelemetryField(name);telemetryFields[name]=f
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
  telemetryFields[name]=f;table.remove(missingSources,missingIndex)
 else missingIndex=missingIndex+1 end
 if missingIndex>#missingSources then missingIndex=1 end
end
local function refreshSources()
 fieldCache={};telemetryFields={};missingSources={};missingIndex=1;lastSourceRetry=getTime()
end
local batteryConfig=(function()
 local defaults={0,27,30,34,36,42,0,0}
 local active,draft,path,message,selected,editing,lastAlert={}, {},nil,'',1,false,-10000
 local editValue
 local labels={'Pack cell count','Cell no-power voltage','Cell minimum voltage','Cell critical voltage','Cell low voltage','Cell maximum voltage','Cell alerts type','Audible alerts'}
 local types={'Visual only','Visual + Sound','Visual + Haptic','Visual + Both'}
 local function copy(a) local b={} for i,v in ipairs(a) do b[i]=v end return b end
 local function valid(a)
  if #a~=8 then return false end
  for i,v in ipairs(a) do if type(v)~='number' or v%1~=0 then return false end end
  return a[1]>=0 and a[1]<=12 and a[2]>=20 and a[6]<=46 and a[2]<a[3] and a[3]<a[4] and a[4]<a[5] and a[5]<a[6] and a[7]>=0 and a[7]<=3 and a[8]>=0 and a[8]<=1
 end
 local function encode(a) return 'ADBAT1 '..table.concat(a,',')..'\n' end
 local function read(p)
  local f=io.open(p,'r');if not f then return nil end
  local s=io.read(f,256);io.close(f)
  if not s or string.sub(s,1,7)~='ADBAT1 ' then return nil end
  local a={} for v in string.gmatch(string.sub(s,8),'[^,\r\n]+') do a[#a+1]=tonumber(v) or -999 end
  if valid(a) then return a end
 end
 local function write(p,a)
  local f=io.open(p,'w');if not f then return false end
  io.write(f,encode(a));io.close(f)
  local b=read(p);return b and encode(b)==encode(a)
 end
 local function init()
  local name=model.getInfo().name or 'model';local key=''
  for i=1,#name do key=key..string.format('%02x',string.byte(name,i)) end
  path='/SCRIPTS/TOOLS/AERODECK/battery-'..key..'.cfg'
  active=read(path) or read(path..'.bak') or copy(defaults)
  draft=copy(active);message='SAVE BATTERY applies only battery thresholds';selected=1;editing=false;editValue=nil
 end
 local function save()
  if not valid(draft) then message='Require: no power < min < critical < low < max';return false end
  if not write(path..'.bak',active) or not write(path,draft) then message='SAVE FAILED - previous settings retained';return false end
  active=copy(draft);message='SAVED for this model';return true
 end
 local function adjust(delta)
  local lo=selected==1 and 0 or selected<=6 and 20 or 0
  local hi=selected==1 and 12 or selected<=6 and 46 or selected==7 and 3 or 1
  draft[selected]=math.max(lo,math.min(hi,draft[selected]+delta));message='Unsaved changes - SAVE to apply'
 end
 local function hasChanges()
  for i,v in ipairs(active)do if draft[i]~=v then return true end end;return false
 end
 local function finishEdit()editing=false;editValue=nil end
 local function beginEdit()
  if selected>8 then return false end
  if not editing then editValue=draft[selected];editing=true end;return true
 end
 local function revert()
  draft=copy(active);finishEdit();message='Battery draft discarded'
 end
 local function back()
  if not editing then return false end
  draft[selected]=editValue;finishEdit();message='Value edit cancelled';return true
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
  local c={bg=lcd.RGB(7,15,22),panel=lcd.RGB(18,32,42),muted=lcd.RGB(144,165,178),white=lcd.RGB(235,243,245),green=lcd.RGB(164,227,125),orange=lcd.RGB(255,174,98)}
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
  if not demo and warn and active[7]>0 and getTime()-lastAlert>=1000 then
   lastAlert=getTime()
   if active[7]==1 or active[7]==3 then playTone(1500,150,0,0) end
   if active[7]==2 or active[7]==3 then playHaptic(15,0,0) end
  end
  return status,cells
 end
 return {message=function()return message end,init=init,input=input,draw=draw,check=check,save=save,back=back,revert=revert,hasChanges=hasChanges,isEditing=function()return editing end,open=function()finishEdit();selected=1 end}
end)()


-- The full app maintains the same read-only FC exchange used by Toolbox.
-- Its uplink requests also let ELRS provide reply bandwidth; attitude remains
-- real, current EdgeTX telemetry. Never request data while armed/unknown/offline.
local fcLink={native=false,state={status='NOT LOADED'}}
function fcLink.init()
 fcLink.native=false;fcLink.client=nil;fcLink.telemetrySwitch=getSwitchIndex and getSwitchIndex('Tele') or nil
 for i=0,63 do
  local sensor=model.getSensor(i)
  if sensor and sensor.type==0 and sensor.id==0x21 then fcLink.native=true end
 end
 if loadScript then
  local loader=loadScript('/SCRIPTS/TOOLS/AERODECK/crsf-msp.lua')
  if loader then
   local factory=loader()
   if factory and factory.new then
    fcLink.client=factory.new({push=crossfireTelemetryPush,pop=crossfireTelemetryPop})
    fcLink.state=fcLink.client:snapshot();return
   end
  end
 end
 fcLink.state={status='MODULE UNAVAILABLE'}
end
function fcLink.stop()if fcLink.client then fcLink.client:stop()end end
local configuration=(function()
 local active,draft,path={}, {},nil
 local section,selected,offset,editing=1,1,0,false
 local inList,listSelected,listOffset,editValue=true,1,0,nil
 local message='Changes apply after SAVE'
 local sensors={'Auto','None'}
 local schema,sections={},{}
 local function item(key,label,default,lo,hi,step,choices)
  local s={key=key,label=label,default=default,lo=lo,hi=hi,step=step or 1,choices=choices};schema[key]=s;return s
 end
 local function note(label,value)return {label=label,note=value}end
 local function sensor(key,label)return item(key,label,'Auto',nil,nil,nil,sensors)end
 sections[1]={name='MODEL SETUP',rows={
  item('rcProtocol','RC protocol profile','None',nil,nil,nil,{'None','ELRS / CRSF','TBS Crossfire','FrSky','Other'}),item('fcType','Flight controller','None',nil,nil,nil,{'None','Betaflight','INAV','Other'}),item('vtxMode','VTX reference lists',0,0,2,1,{'Off','Status only','Status + favourites'}),
  sensor('voltage','Battery voltage'),sensor('current','Battery current'),sensor('consumed','Consumed capacity'),sensor('remaining','Battery remaining'),sensor('gps','GPS position'),sensor('speed','Ground speed'),sensor('altitude','GPS altitude'),sensor('heading','Aircraft course'),sensor('pitch','Pitch'),sensor('roll','Roll'),sensor('flightmode','Flight mode'),note('Protocol profile is local','Does not change RF module'),note('Gyroscope / accelerometer','Use Pitch / Roll sources'),note('Barometer / pitot setup','NOT IMPLEMENTED')}}
 sections[2]={name='RC LINK',rows={
  sensor('rssi','RSSI source (dBm)'),sensor('lq','Link quality source (%)'),sensor('snr','SNR source (dB)'),item('rssiLow','RSSI low (dBm)',-95,-130,-1),item('rssiCrit','RSSI critical (dBm)',-105,-130,-1),item('lqLow','LQ low (%)',80,1,100),item('lqCrit','LQ critical (%)',60,0,99),item('snrLow','SNR low (dB)',0,-30,50),item('snrCrit','SNR critical (dB)',-5,-30,50),note('Protocol version','Configured in RF module')}}
 sections[3]={name='MODEL BATTERY',rows={}}
 sections[4]={name='BATTERY FAVOURITES',rows={item('pack','Active profile',0,0,5,1,{'Manual cells','Pack 1','Pack 2','Pack 3','Pack 4','Pack 5'})}}
 for i=1,5 do
  local r=sections[4].rows;r[#r+1]=item('cells'..i,'Pack '..i..' cells',4,1,12);r[#r+1]=item('capacity'..i,'Pack '..i..' capacity (mAh)',1500,100,30000,50)
 end
 sections[5]={name='FLIGHT CONTROLLER',rows={item('mspMode','Read-only FC connection',1,0,1,1,{'Off','Auto / CRSF'}),note('MSP status interval','3 seconds / disarmed'),note('MSP connection','--'),note('Detected firmware','--'),note('FC configuration writes','Unavailable')}}
 local switchChoices={'None','SA','SB','SC','SD','SE','SF','SG','SH','L01','L02','L03','L04'}
 sections[6]={name='INDICATORS',rows={item('armSource','Arm indicator source','None',nil,nil,nil,switchChoices),item('armPosition','Arm active position',1,-1,1,1,{'Low','Centre','High'}),item('cutSource','Throttle cut source','None',nil,nil,nil,switchChoices),item('cutPosition','Cut active position',1,-1,1,1,{'Low','Centre','High'}),note('Arm state','NOT CONFIGURED'),note('Throttle cut state','NOT CONFIGURED'),note('Indicators are displays','Do not alter output channels')}}
 sections[7]={name='BETAFLIGHT INDICATORS',rows={sensor('flightmode','Flight mode telemetry'),note('Reported flight mode','--'),note('Acro / Angle / Horizon','Reported by FM source'),note('Air / Turtle control','No commands transmitted')}}
 sections[8]={name='VTX',rows={note('VTX connection','NOT IMPLEMENTED'),note('Channel / power writes','Unavailable'),note('VTX control','Use existing VTX tool'),note('Favourites','Offline frequency notes only')}}
 sections[9]={name='VTX FAVOURITES',rows={note('Purpose','Offline notes; no VTX writes')}}
 for i=1,8 do sections[9].rows[#sections[9].rows+1]=item('vtx'..i,'Favourite '..i..' frequency (MHz)',({5865,5732,5800,5806,5917,5880,5790,5740})[i],5000,6000) end
 sections[10]={name='GPS',rows={item('autoHome','Capture first valid home',0,0,1,1,{'Off','On'}),item('homeSats','Minimum sats for auto home',8,4,64),item('trail','Track samples retained',90,10,180,10),item('zoom','Default track zoom',2,1,3,1,{'Wide','Medium','Close'}),note('Home reference','Local to AERODECK'),note('3D fix / constellation','Not provided by reader')}}
 sections[11]={name='USER INTERFACE',rows={item('accent','Highlight colour',1,1,3,1,{'Green','Cyan','Amber'}),item('renderHz','Redraw target (Hz)',25,5,30),item('startPage','Opening page',1,1,8,1,{'Flight','Telemetry','GPS track','GPS details','Power','Sensors','Stick guide','Setup'})}}
 sections[12]={name='APPLICATION',rows={note('Telemetry source','Live sensors only'),note('Settings scope','Per model name'),note('Saving','Verified SD file + backup'),note('Sound / haptic scope','While full app runs'),note('FC / radio model writes','None'),note('Settings reload','Reopen AERODECK')}}
 sections[12].rows[#sections[12].rows+1]=sections[5].rows[1]
 local function visible(t)
  local list={1}
  if t.rcProtocol~='None' then
   list[#list+1]=2
   if t.voltage~='None' then list[#list+1]=3;list[#list+1]=4 end
   if t.fcType~='None' then list[#list+1]=5 end
  end
  list[#list+1]=6
  if t.rcProtocol~='None' then
   if t.fcType=='Betaflight' then list[#list+1]=7 end
   if t.vtxMode>0 then list[#list+1]=8 end
   if t.vtxMode==2 then list[#list+1]=9 end
   if t.gps~='None' then list[#list+1]=10 end
  end
  list[#list+1]=11;list[#list+1]=12
  return list
 end
 local function copy(t)local c={} for k,v in pairs(t)do c[k]=v end return c end
 local function encode(t)
  local keys={} for k in pairs(schema)do keys[#keys+1]=k end;table.sort(keys)
  local s='ADCFG1\n';for _,k in ipairs(keys)do s=s..k..'='..tostring(t[k])..'\n' end;return s
 end
 local function valid(t)
  for k,s in pairs(schema)do
   local v=t[k]
   if type(s.default)=='number' then if type(v)~='number' or v%1~=0 or v<s.lo or v>s.hi then return false,'Invalid '..s.label end
   elseif type(v)~='string' or string.find(v,'[=\r\n]') then return false,'Invalid source name' end
  end
  if t.rssiCrit>=t.rssiLow or t.lqCrit>=t.lqLow or t.snrCrit>=t.snrLow then return false,'Link critical must be below low' end
  return true
 end
 local function read(p)
  local f=io.open(p,'r');if not f then return nil end
  local s=io.read(f,4096);io.close(f);if not s or string.sub(s,1,7)~='ADCFG1\n' then return nil end
  local t={} for k,d in pairs(schema)do t[k]=d.default end
  for k,v in string.gmatch(s,'([%w]+)=([^\r\n]*)')do if schema[k]then t[k]=type(schema[k].default)=='number' and tonumber(v) or v end end
  if valid(t)then return t end
 end
 local function write(p,t)
  local f=io.open(p,'w');if not f then return false end
  io.write(f,encode(t));io.close(f);local r=read(p);return r and encode(r)==encode(t)
 end
 local function refreshSensorChoices(names)
  sensors={'Auto','None'}
  for _,name in ipairs(names)do sensors[#sensors+1]=name end
  for _,s in pairs(schema)do if s.choices and s.choices[1]=='Auto' then s.choices=sensors end end
 end
 local function init()
  local names={}
  for i=0,63 do local s=model.getSensor(i);if s and s.name and s.name~='' then names[#names+1]=s.name end end
  refreshSensorChoices(names)
  local name=model.getInfo().name or 'model';local key=''
  for i=1,#name do key=key..string.format('%02x',string.byte(name,i))end
  path='/SCRIPTS/TOOLS/AERODECK/settings-'..key..'.cfg'
  active=read(path) or read(path..'.bak') or {};for k,s in pairs(schema)do if active[k]==nil then active[k]=s.default end end
  draft=copy(active);section=1;selected=1;offset=0;editing=false;editValue=nil;inList=true;listSelected=1;listOffset=0;message='Select a category; changes require explicit Save'
 end
 local function save()
  local ok,why=valid(draft);if not ok then message=why;return false end
  if not write(path..'.bak',active) or not write(path,draft) then message='SAVE FAILED - active settings unchanged';return false end
  active=copy(draft);message='SAVED - startup options apply on reopen';return true
 end
 local function hasChanges()
  for k,v in pairs(active)do if draft[k]~=v then return true end end;return false
 end
 local function finishEdit()editing=false;editValue=nil end
 local function revert()
  draft=copy(active);finishEdit();message='App settings draft discarded'
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
  if not editing then editValue=draft[row.key];editing=true end;return true
 end
 local function back()
  if inList then return false end
  if section==3 and batteryConfig.back()then return true end
  if editing then
   draft[sections[section].rows[selected].key]=editValue;finishEdit();message='Value edit cancelled';return true
  end
  inList=true;return true
 end
 local function adjust(delta)
  local s=sections[section].rows[selected];if not s or s.note then return end
  if type(s.default)=='number' then draft[s.key]=math.max(s.lo,math.min(s.hi,draft[s.key]+delta*s.step))
  else
   local index=1;for i,v in ipairs(s.choices)do if v==draft[s.key]then index=i end end
   draft[s.key]=s.choices[(index-1+delta)%#s.choices+1]
  end
  message='Unsaved settings; SAVE SETTINGS to apply'
 end
 local function activate()
  local rows=sections[section].rows
  if selected==#rows+1 then finishEdit();save()
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
  local keys={RxBt='voltage',VFAS='voltage',Bat='voltage',Curr='current',Capa='consumed',['Bat%']='remaining',GPS='gps',GSpd='speed',GAlt='altitude',Alt='altitude',Hdg='heading',Ptch='pitch',Roll='roll',FM='flightmode',['1RSS']='rssi',RSSI='rssi',RQly='lq',LQ='lq',RSNR='snr',SNR='snr'}
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
  local source=get(prefix..'Source');if source=='None' then return 'NOT CONFIGURED' end
  local f=cachedField(source);if not f then return 'SOURCE UNAVAILABLE' end
  local v=getValue(f.id);if type(v)~='number' then return '--' end
  local pos=v>300 and 1 or v< -300 and -1 or 0
  return pos==get(prefix..'Position') and 'ACTIVE' or 'INACTIVE'
 end
 local function draw(externalFocus)
  local c={bg=lcd.RGB(7,15,22),panel=lcd.RGB(18,32,42),white=lcd.RGB(235,243,245),green=lcd.RGB(164,227,125),orange=lcd.RGB(255,174,98),muted=lcd.RGB(144,165,178)}
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
    local v=s.note or draft[s.key]
    if not s.note and s.choices and type(s.default)=='number' then v=s.choices[v-s.lo+1]end
    if section==6 and index==5 then v=indicator('arm')elseif section==6 and index==6 then v=indicator('cut')
    elseif section==7 and index==2 then v=value('FM')or '--'
    elseif section==5 and index==3 then v=fcLink.state.status
    elseif section==5 and index==4 then v=fcLink.state.firmware or '--'end
    text(17,y,s.label,col,false,18);text(459,y,(editing and chosen)and '< '..tostring(v)..' >'or v,col,true,18)
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
 local function linkStatus(d)
  local low=false
  for _,v in ipairs(linkThresholds)do
   if type(d[v[1]])=='number' then
    if d[v[1]]<=get(v[2]) then return 'LINK CRITICAL' elseif d[v[1]]<=get(v[3]) then low=true end
   end
  end
  if low then return 'LINK LOW' end
 end
 return {canOpen=function(id)for _,v in ipairs(visible(draft))do if v==id then return true end end;return false end,
 openSection=openSection,isList=function()return inList end,back=back,
 atFooterBoundary=function()return inList and listSelected==1 end,
 hasChanges=function()return hasChanges()or batteryConfig.hasChanges()end,hasAppChanges=hasChanges,
 discardAll=discardAll,isEditing=function()return editing or batteryConfig.isEditing()end,
 init=init,input=input,draw=draw,get=get,resolve=resolve,value=value,linkStatus=linkStatus,indicator=indicator,save=save,refreshSensorChoices=refreshSensorChoices,
 visible=function()return visible(draft)end}

end)()


function fcLink.update(now)
 if not fcLink.client then return end
 local rc,fc=configuration.get('rcProtocol'),configuration.get('fcType')
 local enabled=configuration.get('mspMode')==1 and fcLink.native and
  (rc=='None' or rc=='ELRS / CRSF' or rc=='TBS Crossfire') and (fc=='None' or fc=='Betaflight')
 local fm,current
 if enabled then
  local name=configuration.resolve('FM');local field=name and cachedTelemetryField(name)
  if field then fm,current=getSourceValue(field.id)end
 end
 local reported=type(fm)=='string' and current==true
 if fcLink.telemetrySwitch and getSwitchValue then reported=reported and getSwitchValue(fcLink.telemetrySwitch)==true end
 local disarmed=reported and string.find(fm,'[!?*]')~=nil and string.find(fm,'FS',1,true)==nil
 fcLink.state=fcLink.client:tick(now,enabled,reported,disarmed)
end
local telemetry=(function()
local start,last,mode
local units,sourceStates={},{}
local function rememberSource(name,state,raw)
 local record=sourceStates[name]
 if not record then record={};sourceStates[name]=record end
 record.state=state;record.raw=type(raw)=='number'and raw or nil
end
local function scanUnits()
 refreshSources();units={};sourceStates={}
 local names={}
 for i=0,63 do
  local sensor=model.getSensor(i)
  if sensor and sensor.name and sensor.name~=''then units[sensor.name]=sensor.unit;names[#names+1]=sensor.name end
 end
 configuration.refreshSensorChoices(names)
end
local function init() start=getTime();last=-100;mode=1;scanUnits() end
local function read(names,kind)
 for _,original in ipairs(names) do
  local name=configuration.resolve(original)
  local f=name and cachedTelemetryField(name)
  if f then
   local v,current=getSourceValue(f.id)
   if current and type(v)=='number' then
   local unit=f.unit or units[name]
   rememberSource(name,'LIVE',v)
   if kind=='speed' then
    if unit==UNIT_KTS then v=v*1.852 elseif unit==UNIT_MPH then v=v*1.609344 elseif unit==UNIT_METERS_PER_SECOND then v=v*3.6 elseif unit==UNIT_FEET_PER_SECOND then v=v*1.09728 elseif unit~=UNIT_KMH then rememberSource(name,'INVALID',v);return nil end
   elseif kind=='angle' or kind=='pitch' then
    if unit==UNIT_RADIANS then
     v=v*180/math.pi
     -- CRSF pitch needs the same sign convention as Toolbox; Roll/Yaw do not.
     if kind=='pitch' then v=-v;if v==0 then v=0 end end
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
 if type(names)=='string'then local name,state,raw=sourceState(names);return name,state,raw end
 local bestName,bestState,bestRaw,bestRank=nil,'OFF',nil,0
 for _,original in ipairs(names)do
  local name,state,raw,rank=sourceState(original)
  if rank>bestRank then bestName,bestState,bestRaw,bestRank=name,state,raw,rank end
 end
 return bestName,bestState,bestRaw
end
local liveFields={{'v',{'RxBt','VFAS','Bat'}},{'a',{'Curr'}},{'mah',{'Capa'}},{'pct',{'Bat%'}},{'lq',{'RQly','LQ'}},{'rssi',{'1RSS','RSSI'}},{'snr',{'RSNR','SNR'}},{'power',{'TPWR'}},{'down',{'TQly'}},{'rf',{'RFMD'}},{'sats',{'Sats'}},{'speed',{'GSpd'},'speed'},{'alt',{'GAlt','Alt'},'alt'},{'hdg',{'Hdg'},'angle'},{'yaw',{'Yaw'},'angle'},{'rssi2',{'2RSS'}},{'trss',{'TRSS'}},{'tsnr',{'TSNR'}},{'vspeed',{'VSpd'},'vspeed'},{'airspeed',{'ASpd'},'speed'},}
local liveData={}
local pitchNames,rollNames={'Ptch'},{'Roll'}
local attitudePitch,attitudeRoll
local function pollAttitude()
 attitudePitch=read(pitchNames,'pitch');attitudeRoll=read(rollNames,'angle')
 return attitudePitch,attitudeRoll
end
local function getData(t)
 local d=liveData
 for _,f in ipairs(liveFields)do d[f[1]]=read(f[2],f[3])end
 d.pitch=attitudePitch;d.roll=attitudeRoll
 d.flight=configuration.value('FM') or '--';d.demo=false;d.estimated=nil

 local gpsCurrent=configuration.value('GPS');d.gps=gpsCurrent
 d.ok=d.v~=nil or d.lq~=nil or d.rssi~=nil or d.sats~=nil or d.pitch~=nil or type(gpsCurrent)=='table' or d.flight~='--'
 return d
end
local function sample()
 retryMissingSources()
 pollAttitude()
 local d=getData((getTime()-start)/100)
 if not d.ok then d.flight=nil end
 d.mode=mode
 local pack=configuration.get('pack');local override=pack>0 and configuration.get('cells'..pack) or nil
 d.capacity=nil;d.remainingMah=nil
 if not d.demo and pack>0 then
  local capacity=configuration.get('capacity'..pack)
  if type(capacity)=='number'and capacity>0 then
   d.capacity=capacity
   if type(d.mah)=='number'then
    d.remainingMah=math.max(0,capacity-d.mah)
    d.pct=math.max(0,math.min(100,100*(1-d.mah/capacity)));d.estimated=true
   end
  end
 end
 d.battery,d.cells=batteryConfig.check(d.v,d.demo,override)
 if d.cells==0 then d.cells=nil end
 d.link=configuration.linkStatus(d)
 return d
end
local function toggle()mode=1;last=-100;scanUnits()end
return {init=init,sample=sample,pollAttitude=pollAttitude,toggle=toggle,sourceStatus=sourceStatus,refreshBindings=function()last=-100;scanUnits()end,isDemo=function()return false end,release=function()end,refresh=function()last=-100 end}

end)()
local ROOT='/SCRIPTS/TOOLS/AERODECK/'
local started, page, palette, failure, modelName
local menuOpen,menuIndex,controlFocus,exitOpen,exitChoice,configReturn,armReturn=false,1,0,false,1,1,1
local backgroundReady=false
local pages={'flight','nav','power','system','console','console','console','console'}
local sectionRoots={1,5,7,11,8,6}
local scenario,zoom=1,2
local sensors,sensorOffset={},0
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
 page=nextPage
 -- Release page artwork only at navigation boundaries. No background tiles.
 backgroundReady=false;collectgarbage('collect')
 renderStats.background='FLAT / NATIVE'
 backgroundReady=true
 if page==5 then telemetry.refresh() end;lastFrame=-100
end
local function init()
 menuOpen=false;controlFocus=0;exitOpen=false;configReturn=1;armReturn=1
 batteryConfig.init();configuration.init();telemetry.init();fcLink.init();modelName=model.getInfo().name or 'MODEL';started=getTime(); page=({1,5,2,7,3,4,6,8})[configuration.get('startPage')]; failure=nil; lastFrame=-100
 backgroundReady=false;sensorOffset=0;sensors={};scenario=1;zoom=2
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
-- Measure with the radio font. Conservative fallback also supports LCD mocks.
local function textWidth(s,size)
 s=tostring(s);size=size or SMLSIZE
 if lcd.sizeText then
  local w=lcd.sizeText(s,size)
  if type(w)=='number' then return w end
 end
 return #s*(size==MIDSIZE and 16 or 8)
end
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
local function navReset()
 navHome=nil;navTrack={};navLast=-100;navCurrent=nil
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
local function navAction(action)
 if action=='mode' then telemetry.toggle()
 elseif action=='zoom' then zoom=zoom%3+1
 elseif action=='home' and navCurrent then navHome={lat=navCurrent.lat,lon=navCurrent.lon};navTrack={} end
 lastFrame=-100
end
local function navSnapshot(d)
 if not navConfigured then zoom=configuration.get('zoom');navReset();navConfigured=true end
 if navDemo~=telemetry.isDemo() then navDemo=telemetry.isDemo();navReset() end
 local now=getTime();local pos,speed,alt,sats,heading
 pos=gpsPosition(d.gps);speed=d.speed;alt=d.alt;sats=d.sats;heading=d.hdg

 if not navDemo and not navHome and pos and sats and sats>=configuration.get('homeSats') and configuration.get('autoHome')==1 then navHome={lat=pos.lat,lon=pos.lon} end
 if not d.ok then pos=nil;speed=nil;alt=nil;sats=nil;heading=nil end
 navCurrent=pos
 if pos and now-navLast>=100 then
  navLast=now;navTrack[#navTrack+1]={lat=pos.lat,lon=pos.lon};if #navTrack>configuration.get('trail') then table.remove(navTrack,1) end
 end
 return pos,speed,alt,sats,heading
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
 local cx,cy=104,141;local scale=({.35,.7,1.4})[zoom]
 circle(cx,cy,60,p.border);circle(cx,cy,30,p.border)
 smallText(16,69,'N',p.cyan);line(21,96,21,87,p.cyan);triangle(21,86,0,3,p.cyan)
 smallText(126,199,tostring(round(60/scale))..' m',p.muted)
 local origin=navHome or pos
 local function pt(a)
  local dist,angle=geo(origin,a);local rad=angle*pi/180
  return cx+dist*math.sin(rad)*scale,cy-dist*math.cos(rad)*scale
 end
 if origin then
  local px,py
  for _,a in ipairs(navTrack) do local x,y=pt(a);if px then clip(px,py,x,y,11,197,65,214,p.cyan) end;px,py=x,y end
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
  rect(4,64,100,153,p.tape);rect(4,64,3,153,p.cyan)
  smallText(13,70,'SATELLITES',p.muted)
  label(12,89,val(sats),type(sats)=='number' and p.green or p.muted,DBLSIZE)
  line(12,125,96,125,p.border)
  smallText(13,135,'FIX TYPE',p.muted)
  smallText(13,152,'NOT REPORTED',p.orange)
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
  button(10,132,'REFRESH SENSORS',true)
  button(148,150,'SET LOCAL HOME',pos~=nil)
  smallText(313,226,'LOCAL HOME',p.muted)
 end
end)()

local function scanSensors()
 sensors={}
 if not model or not model.getSensor then return end
 for i=0,63 do
  local sensor=model.getSensor(i)
  if sensor and sensor.name and sensor.name~='' then
   local info=getFieldInfo(sensor.name)
   sensors[#sensors+1]={name=sensor.name,source=info and info.id,prec=sensor.prec or 0}
  end
 end
 sensorOffset=sensorOffset%(math.max(1,math.ceil(#sensors/5))*5)
end
local function systemPage()
 local p=palette
 rect(0,61,480,185,p.black)
 local first=#sensors>0 and sensorOffset+1 or 0
 local last=math.min(sensorOffset+5,#sensors)
 smallText(14,66,'SENSOR '..first..'-'..last..' / '..#sensors,p.muted)
 smallText(185,66,'VALUE',p.muted);smallText(358,66,'STATUS',p.muted)
 if #sensors==0 then smallText(20,100,'No sensors discovered in this radio model.',p.white);smallText(20,124,'Use the radio Telemetry > Discover New menu.',p.muted)end
 for row=1,5 do
  local s=sensors[sensorOffset+row]
  if s then
   local y=84+(row-1)*26;rect(10,y-2,460,24,p.tape)
   local value,current
   if s.source then value,current=getSourceValue(s.source)end
   local shown='--'
   if current then
    if type(value)=='number' then shown=string.format('%.'..clamp(s.prec,0,3)..'f',value)
    elseif type(value)=='table' then shown='GPS / TABLE'
    elseif type(value)=='string' then shown=string.sub(value,1,20)end
   end
   vlabel(17,y-2,24,s.name,p.white);vlabel(185,y-2,24,shown,p.cyan);vlabel(358,y-2,24,current and 'CURRENT' or 'STALE / NONE',current and p.green or p.orange)
  end
 end
 rect(10,222,224,21,p.tape);vlabel(18,222,21,'NEXT SOURCES >',p.green)
 rect(242,222,228,21,p.tape);vlabel(250,222,21,'REFRESH',p.green)
end
-- Reference: betaflight.com/docs/wiki/guides/current/Controls
-- Axis order: throttle, yaw, pitch, roll; -1 low, 0 centre, +1 high.
local stickMode,commandPage=2,1
local commands={
 {'Save settings',-1,-1,-1,1},
 {'PID profile 1',-1,-1,0,-1},
 {'PID profile 2',-1,-1,1,0},
 {'PID profile 3',-1,-1,0,1},
 {'Calibrate gyroscope',-1,-1,-1,0},
 {'Calibrate accelerometer',1,-1,-1,0},
 {'Calibrate compass',1,1,-1,0},
 {'In-flight calibration*',-1,-1,1,1},
 {'Trim accelerometer left',1,0,0,-1},
 {'Trim accelerometer right',1,0,0,1},
 {'Trim accelerometer forward',1,0,1,0},
 {'Trim accelerometer back',1,0,-1,0}
}
local stickAxes={{3,4,5,2},{3,2,5,4},{5,4,3,2},{5,2,3,4}}
local function stickCommands()
 local p=palette
 rect(5,62,470,183,p.black)
 rect(0,35,480,26,p.black)
  rect(362,63,108,18,p.tape);vlabel(374,63,18,'MODE '..stickMode,p.green)
 vlabel(14,63,18,'BETAFLIGHT / REFERENCE',p.orange)
 vlabel(295,63,18,commandPage..' / 2',p.muted)

 local axes=stickAxes[stickMode]
 local function diagram(x,y,h,v)
  rect(x,y,18,18,p.border);rect(x+1,y+1,16,16,p.tape)
  line(x+8,y+2,x+8,y+15,p.dim);line(x+2,y+8,x+15,y+8,p.dim)
  rect(x+6+h*5,y+6-v*5,5,5,p.green)
 end
 for row=1,7 do
  local index=(commandPage-1)*7+row;local cmd=commands[index]
  if cmd then
   local y=84+(row-1)*19
   if row%2==1 then rect(10,y-1,460,19,p.tape) end
   diagram(18,y,cmd[axes[1]],cmd[axes[2]])
   diagram(47,y,cmd[axes[3]],cmd[axes[4]])
   vlabel(83,y,18,cmd[1],p.white)
  end
 end
 rect(10,221,460,22,p.tape)
 vlabel(18,221,22,'< PREV',commandPage>1 and p.cyan or p.muted)
 vlabel(108,221,22,'FC support varies*',p.muted)
 vlabel(369,221,22,'NEXT >',commandPage<2 and p.cyan or p.muted)
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
 local masks={}
 return function(id,x,y,c,size)
  if size~=30 and size~=18 then return false end
  local file=(size==18 and smallNames or names)[id];if not file then return false end
  local mask=masks[file]
  if mask==nil then
   mask=false
   if Bitmap.toMask and lcd.drawBitmapPattern then
    -- Release earlier decoded images before another cold load; no collection in warm draws.
    collectgarbage('collect')
    local b=Bitmap.open(ROOT..'icons/'..file..'.png');local w,h=Bitmap.getSize(b)
    if w==size and h==size then mask=Bitmap.toMask(b)end
   end
   masks[file]=mask
  end
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
local function frame(title,d)
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
local telemetryScreen=(function()
 local columns={
  {title='RADIO LINK',accent='green',rows={
   {'RFMD','rf','%.0f',''}, {'1RSS','rssi','%.0f','dBm'},
   {'2RSS','rssi2','%.0f','dBm'}, {'RQly','lq','%.0f','%'},
   {'RSNR','snr','%.0f','dB'}, {'TPWR','power','%.0f','mW'},
   {'TRSS','trss','%.0f','dBm'}, {'TQly','down','%.0f','%'},
   {'TSNR','tsnr','%.0f','dB'}}},
  {title='FLIGHT DATA',accent='orange',rows={
   {'RxBt','v','%.2f','V'}, {'Curr','a','%.1f','A'},
   {'Capa','mah','%.0f','mAh'}, {'Bat%','pct','%.0f','%'},
   {'CellAvg','cell','%.2f','V'}, {'Sats','sats','%.0f',''},
   {'GSpd','speed','%.1f','km/h'}, {'Alt','alt','%.0f','m'},
   {'FM','flight','text',''}}},
  {title='ATTITUDE / GPS',accent='cyan',rows={
   {'Ptch','pitch','%.1f','deg'}, {'Roll','roll','%.1f','deg'},
   {'Yaw','yaw','%.1f','deg'}, {'Hdg','hdg','%.0f','deg'},
   {'VSpd','vspeed','%.1f','m/s'}, {'ASpd','airspeed','%.1f','km/h'},
   {'Lat','gpsLat','%.7f',''}, {'Lon','gpsLon','%.7f',''},
   {'GPS','gpsState','text',''}}}
 }
 local function value(d,key)
  if key=='cell' then return d.v and d.cells and d.cells>0 and d.v/d.cells or nil end
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
  for col=1,3 do
   local spec=columns[col];local x=4+(col-1)*160;local w=152
   rect(x,64,w,180,p.tape);rect(x,64,w,16,p.black)
   rect(x,64,3,16,p[spec.accent]);line(x+3,64,x+w-1,64,p.border)
   smallText(x+9,66,spec.title,p[spec.accent])
   for row=1,9 do
    local r=spec.rows[row];local y=82+(row-1)*18
    rect(x,y,w,17,row%2==0 and p.black or p.tape)
    local v=value(d,r[2]);local shown='--'
    if r[3]=='text' then
     if type(v)=='string' and v~='' then shown=string.sub(v,1,16)end
    elseif type(v)=='number' and v==v then shown=string.format(r[3],v)end
    local key=r[1]
    if r[2]=='pct' and d.estimated then key='Est%' end
    vlabel(x+6,y,17,key,p.muted)
    local unit=r[4];local right=x+w-6
    if unit~='' then
     vlabel(right,y,17,unit,p.muted,SMLSIZE,true);right=right-textWidth(unit,SMLSIZE)-8
    end
    local color=shown=='--' and p.muted or p.white
    if r[2]=='lq' and d.link then color=p.orange end
    if (r[2]=='v' or r[2]=='cell') and d.battery then color=p.orange end
    if r[2]=='gpsState' and shown~='--' then color=p.green end
    shown=fittedText(shown,math.max(8,right-(x+6+textWidth(key,SMLSIZE)+8)),SMLSIZE)
    vlabel(right,y,17,shown,color,SMLSIZE,true)
   end
  end
 end
end)()

-- Fit live values inside their own cells; never let large telemetry overlap a neighbour.
local function flightValue(x,y,w,h,value,unit,size,c,center)
 local text=tostring(value);unit=unit or '';size=size or MIDSIZE
 local unitSize=TINSIZE or SMLSIZE
 local unitWidth=unit~='' and textWidth(unit,unitSize)+2 or 0
 if size==DBLSIZE and textWidth(text,size)+unitWidth>w then size=MIDSIZE end
 if textWidth(text,size)+unitWidth>w then size=SMLSIZE end
 if textWidth(text,size)+unitWidth>w and TINSIZE then size=TINSIZE end
 local shown,font=fittedText(text,w-unitWidth,size)
 if center then x=x+math.floor((w-textWidth(shown,font)-unitWidth)/2)end
 vlabel(x,y,h,shown,c or palette.white,font)
 if unit~='' then
  local _,height=lcd.sizeText('Ag',font);local _,unitHeight=lcd.sizeText('Ag',unitSize)
  height=height or(font==DBLSIZE and 38 or font==MIDSIZE and 29 or font==TINSIZE and 12 or 17);unitHeight=unitHeight or 12
  label(x+textWidth(shown,font)+2,y+math.floor((h-height)/2)+height-unitHeight,unit,palette.muted,unitSize)
 end
end
local function cockpit(d)
 local p=palette
 -- Three primary metrics per rail; radio power and calculated cell average are context.
 rect(4,35,70,209,p.tape);rect(406,35,70,209,p.tape)
 rect(4,35,70,1,p.border);rect(406,35,70,1,p.border)
 local lqColor=d.lq and(d.lq<=configuration.get('lqCrit')and p.red or d.lq<=configuration.get('lqLow')and p.orange or p.green)or p.muted
 local batteryColor=d.v and(d.battery and p.orange or p.green)or p.muted
 icon(9,8,39,lqColor,18);vlabel(31,36,23,'LINK',p.muted,TINSIZE or SMLSIZE)
 icon(3,410,39,batteryColor,18);vlabel(472,36,23,d.cells and d.cells..'S'or 'PACK',p.muted,TINSIZE or SMLSIZE,true)
 flightValue(8,61,62,34,d.lq and round(d.lq)or '--','%',MIDSIZE,lqColor)
 flightValue(410,61,62,34,d.v and string.format('%.1f',d.v)or '--','V',MIDSIZE,d.v and(d.battery and p.orange or p.white)or p.muted)
 -- Fit the percent before allocating its bar; estimated ~100% must also fit.
 local pct=d.pct and(d.estimated and '~'or '')..round(d.pct)..'%'or '--'
 local pctFont;pct,pctFont=fittedText(pct,58,TINSIZE or SMLSIZE)
 local meterWidth=math.max(0,math.min(36,62-textWidth(pct,pctFont)-4))
 rect(8,100,62,4,p.dim);rect(410,100,meterWidth,4,p.dim)
 if d.lq then rect(8,100,62*clamp(d.lq,0,100)/100,4,lqColor)end
 if d.pct then rect(410,100,meterWidth*clamp(d.pct,0,100)/100,4,d.battery and p.orange or p.green)end
 vlabel(472,95,12,pct,p.muted,pctFont,true)
 for _,x in ipairs({8,410})do
  rect(x,108,62,1,p.border);rect(x,159,62,1,p.border);rect(x,208,62,1,p.border)
 end
 vlabel(8,112,14,'RSSI dBm',p.muted,TINSIZE or SMLSIZE)
 vlabel(410,112,14,'USED mAh',p.muted,TINSIZE or SMLSIZE)
 flightValue(8,126,62,29,d.rssi and round(d.rssi)or '--','',MIDSIZE,d.rssi and p.white or p.muted)
 flightValue(410,126,62,29,d.mah and round(d.mah)or '--','',MIDSIZE,d.mah and p.white or p.muted)
 vlabel(8,163,14,'SNR dB',p.muted,TINSIZE or SMLSIZE)
 vlabel(410,163,14,'CURRENT A',p.muted,TINSIZE or SMLSIZE)
 flightValue(8,177,62,29,d.snr and string.format('%.0f',d.snr)or '--','',MIDSIZE,d.snr and p.white or p.muted)
 flightValue(410,177,62,29,d.a and string.format('%.1f',d.a)or '--','',MIDSIZE,d.a and p.white or p.muted)
 vlabel(8,210,14,'TX mW',p.muted,TINSIZE or SMLSIZE)
 vlabel(410,210,14,'AVG CELL V',p.muted,TINSIZE or SMLSIZE)
 flightValue(8,225,62,18,d.power and round(d.power)or '--','',SMLSIZE,d.power and p.white or p.muted)
 local cell=d.v and d.cells and d.cells>0 and d.v/d.cells or nil
 flightValue(410,225,62,18,cell and string.format('%.2f',cell)or '--','',SMLSIZE,cell and p.white or p.muted)
 -- One rectangular PFD: the horizon, aircraft and tape indexes share (240,154).
 local attitude=d.pitch~=nil and d.roll~=nil
 rect(78,35,324,209,p.tape)
 -- Near-heading references use larger type; minor ticks stay unlabelled.
 rect(78,34,324,30,p.black)
 if d.hdg then
  local hdg=d.hdg%360;local base=math.floor(hdg/30)*30
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
 flightValue(212,34,56,30,d.hdg and string.format('%03d',round(d.hdg)%360)or '--','',MIDSIZE,p.white,true)
 line(208,63,271,63,p.cyan)
 -- Wide native sky/ground is drawn once; no bitmap masks or Lua pixel loops.
 if attitude then
  rect(78,64,324,180,p.sky)
  ink(p.ground);lcd.drawHudRectangle(d.pitch,d.roll,78,402,64,244,CUSTOM_COLOR)
  local angle=-d.roll*pi/180;local cs,sn=math.cos(angle),math.sin(angle)
  local sr,cr=math.sin(d.roll*pi/180),math.cos(d.roll*pi/180)
  horizonMark(240+sr*d.pitch,154+cr*d.pitch*1.85,cs,sn,0,150,p.horizon)
  horizonMark(240+sr*d.pitch,154+cr*d.pitch*1.85,cs,sn,1,150,p.horizon)
  local base=math.floor(d.pitch/10)*10
  local captionX,captionY,captionW
  for degree=base-40,base+40,10 do if degree~=0 and degree>=-90 and degree<=90 then
   local ox=240+sr*(d.pitch-degree);local oy=154+cr*(d.pitch-degree)*1.85
   local half=degree%20==0 and 27 or 17
   horizonMark(ox,oy,cs,sn,0,half,p.ladder)
   if degree%20==0 then
    -- Major labels are readable at hand-held distance; keep every10-degree rung.
    local caption=tostring(degree);local width=textWidth(caption,SMLSIZE)
    local xx=round(ox+40*cs);local yy=round(oy+40*sn)-8
    if xx<288 and xx+width>193 and yy<165 and yy+17>150 then xx=292 end
    local crowded=captionX and xx<captionX+captionW+3 and xx+width>captionX-3 and yy<captionY+20 and yy+17>captionY-3
    local angleReadout=yy<84 and yy+17>64 and((xx<205 and xx+width>127)or(xx<353 and xx+width>285))
    if xx>=128 and xx+width<=352 and yy>=65 and yy+17<=241 and not crowded and not angleReadout then
     vlabel(xx,yy,17,caption,p.white,SMLSIZE)
     captionX,captionY,captionW=xx,yy,width
    end
   end
  end end
 else rect(78,64,324,180,p.dim)end
 -- Compact live angles replace the overlapping decorative bank guide.
 if attitude then
  vlabel(128,65,18,'P',p.horizon,TINSIZE or SMLSIZE)
  flightValue(141,65,63,18,string.format('%+.0f',d.pitch),'deg',SMLSIZE)
  vlabel(286,65,18,'R',p.horizon,TINSIZE or SMLSIZE)
  flightValue(300,65,52,18,string.format('%+.0f',d.roll),'deg',SMLSIZE)
 end
 -- Equal-width tapes overlay the same field, with readable primary numbers.
 rect(78,64,46,180,p.tape);rect(356,64,46,180,p.tape)
 vlabel(81,64,17,'GS km/h',p.muted,TINSIZE or SMLSIZE)
 vlabel(399,64,17,'ALT m',p.muted,TINSIZE or SMLSIZE,true)
 line(124,64,124,243,p.border);line(355,64,355,243,p.border)
 for offset=-40,40,10 do
  if d.speed then
   local value=math.floor(d.speed/10)*10+offset;local yy=round(154-(value-d.speed)*2.4)
   if value>=0 and yy>86 and yy<237 then
    local font=textWidth(value,SMLSIZE)<=32 and SMLSIZE or(TINSIZE or SMLSIZE)
    local tick=fittedText(value,32,font);local height=font==TINSIZE and 12 or 17;local top=yy-math.floor(height/2)
    if top>=82 and top+height<=242 and(top+height<=138 or top>=170)then vlabel(114,top,height,tick,p.muted,font,true)end;line(117,yy,123,yy,p.muted)
   end
  end
  if d.alt then
   local value=math.floor(d.alt/10)*10+offset;local yy=round(154-(value-d.alt)*2.4)
   if yy>86 and yy<237 then
    local font=textWidth(value,SMLSIZE)<=32 and SMLSIZE or(TINSIZE or SMLSIZE)
    local tick=fittedText(value,32,font);local height=font==TINSIZE and 12 or 17;local top=yy-math.floor(height/2)
    if top>=82 and top+height<=242 and(top+height<=138 or top>=170)then vlabel(397,top,height,tick,p.muted,font,true)end;line(357,yy,363,yy,p.muted)
   end
  end
 end
 rect(78,138,46,32,p.black);rect(356,138,46,32,p.black)
 for _,x in ipairs({78,356})do line(x,138,x+45,138,p.green);line(x,169,x+45,169,p.green)end
 flightValue(82,139,38,30,d.speed and round(d.speed)or '--','',MIDSIZE,nil,true)
 flightValue(360,139,38,30,d.alt and round(d.alt)or '--','',MIDSIZE,nil,true)
 if attitude then
  -- A wider two-pixel reference with a dark four-pixel halo is visible at a glance.
  for dy=-1,2 do
   line(196,154+dy,226,154+dy,p.black);line(226,154+dy,235,161+dy,p.black)
   line(245,161+dy,254,154+dy,p.black);line(254,154+dy,284,154+dy,p.black)
  end
  for dy=0,1 do
   line(196,154+dy,226,154+dy,p.orange);line(226,154+dy,235,161+dy,p.orange)
   line(245,161+dy,254,154+dy,p.orange);line(254,154+dy,284,154+dy,p.orange)
  end
  rect(236,150,8,8,p.black);rect(237,151,6,6,p.orange)
 else
  rect(160,131,160,42,p.black)
  vlabel(240-textWidth('ATTITUDE',SMLSIZE)/2,133,17,'ATTITUDE',p.muted,SMLSIZE)
  vlabel(240-textWidth('UNAVAILABLE',SMLSIZE)/2,152,17,'UNAVAILABLE',p.muted,SMLSIZE)
 end
 line(78,244,401,244,p.border)

end
local traces,lastTrace={},-100
local flightSeconds,flightWasArmed,lastStatus=0,false,nil
local radioArm,radioCut='NOT CONFIGURED','NOT CONFIGURED'
local function radioIndicator(v)return v=='ACTIVE' and 'ON' or v=='INACTIVE' and 'OFF' or '--'end
local function statusUpdate(d)
 local now=getTime();radioArm=configuration.indicator('arm');radioCut=configuration.indicator('cut');local arm=radioArm=='ACTIVE'
 if lastStatus and now>=lastStatus and flightWasArmed and arm then flightSeconds=flightSeconds+math.min((now-lastStatus)/100,1)end
 lastStatus=now;flightWasArmed=arm
 if now-lastTrace>=100 then
  lastTrace=now;local sample=#traces>=90 and table.remove(traces,1) or {};sample.v=d.v;sample.a=d.a;sample.lq=d.lq;traces[#traces+1]=sample
 end
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
  panel(8,64,175,154,'FLIGHT BATTERY')
  flightValue(19,89,153,38,d.v and string.format('%.2f',d.v)or '--','V',DBLSIZE,d.v and p.white or p.muted)
  row(132,'AVG CELL',numberText(d.cells and d.v and d.v/d.cells,'%.2f',' V'),p.cyan)
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
local function linkScreen(d)
 local p=palette;frame('RC LINK',d)
 panel(8,64,146,80,'LINK QUALITY');panel(167,64,146,80,'SIGNAL STRENGTH');panel(326,64,146,80,'SIGNAL / NOISE')
 label(20,96,numberText(d.lq,'%.0f',' %'),p.green,DBLSIZE);label(179,96,numberText(d.rssi),p.white,DBLSIZE)
 label(290,126,'dBm',p.muted,SMLSIZE,true);label(338,96,numberText(d.snr),p.cyan,DBLSIZE);label(460,126,'dB',p.muted,SMLSIZE,true)
 panel(8,153,305,90,'LQ HISTORY / '..#traces..' SAMPLES');trace(18,182,285,50,'lq',0,100,p.green)
 panel(326,153,146,90,'RF STATUS');label(336,177,numberText(d.power,'%.0f',' mW'),p.white,MIDSIZE)
 label(336,200,'RFMD '..numberText(d.rf),p.muted);label(336,220,'DOWN '..numberText(d.down,'%.0f',' %'),p.cyan)
end
local armUi=(function()
 local decoder,stamp,cached,decodeError,selected,offset=nil,nil,nil,nil,1,0
 local decoderTried=false
 local packet,apiMajor,apiMinor
 local detailLines,helpLines,titleLines={},{},{}
 local titleSize,titleHeight=MIDSIZE,29
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
   if not decoderTried then
    decoderTried=true
    if loadScript then local chunk=loadScript(ROOT..'arm-status.lua');if chunk then decoder=chunk()end end
   end
   if stamp~=state.lastStatus or packet~=state.statusData or apiMajor~=state.apiMajor or apiMinor~=state.apiMinor then
    local previous=cached and cached.reasons[selected] and cached.reasons[selected].bit
    stamp=state.lastStatus;packet=state.statusData;apiMajor=state.apiMajor;apiMinor=state.apiMinor
    if decoder then cached,decodeError=decoder.decode(packet,apiMajor,apiMinor)else cached=nil;decodeError='DECODER UNAVAILABLE'end
    local nextSelection=1
    if previous and cached then for i,r in ipairs(cached.reasons)do if r.bit==previous then nextSelection=i;break end end end
    choose(nextSelection)
   end
  else cached=nil;stamp=nil;packet=nil;apiMajor=nil;apiMinor=nil;decodeError=nil end
  return cached,active,decodeError
 end
 return {
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
local function statusScreen(d)armUi.draw(d)end
local vtxSelection=1
local vtxScreen=(function()
 local bands={
  {'A',{5865,5845,5825,5805,5785,5765,5745,5725}},
  {'B',{5733,5752,5771,5790,5809,5828,5847,5866}},
  {'E',{5705,5685,5665,5645,5885,5905,5925,5945}},
  {'F',{5740,5760,5780,5800,5820,5840,5860,5880}},
  {'R',{5658,5695,5732,5769,5806,5843,5880,5917}}
 }
 local cache={}
 local function channel(index,f)
  local old=cache[index];if old and old.frequency==f then return old.code,old.size end
  local code='CUSTOM'
  for _,band in ipairs(bands)do for i,value in ipairs(band[2])do if value==f then code=band[1]..i end end end
  local shown,size=fittedText(code,60,MIDSIZE)
  cache[index]={frequency=f,code=shown,size=size};return shown,size
 end
 return function(d)
  local p=palette;frame('VIDEO FAVOURITES',d)
  for i=1,8 do
   local x=8+((i-1)%4)*79;local y=66+math.floor((i-1)/4)*76
   local f=configuration.get('vtx'..i);local chosen=i==vtxSelection
   rect(x,y,74,69,p.tape);rect(x,y,74,1,chosen and p.cyan or p.border)
   if chosen then rect(x,y,2,69,p.cyan)end
   label(x+7,y+7,'FAV '..i,p.muted)
   local code,size=channel(i,f)
   vlabel(x+7,y+24,30,code,chosen and p.cyan or p.white,size)
   label(x+7,y+49,f..' MHz',p.white)
  end
  panel(331,66,141,145,'LIVE ATTITUDE')
  if d.pitch and d.roll then
   rect(341,90,121,73,p.sky);ink(p.ground);lcd.drawHudRectangle(d.pitch,d.roll,341,462,90,163,CUSTOM_COLOR)
   line(382,127,421,127,p.orange)
  else rect(341,90,121,73,p.dim);label(351,120,'NO ATTITUDE',p.muted)end
  label(341,175,'P '..numberText(d.pitch,'%.1f')..' / R '..numberText(d.roll,'%.1f'),p.white)
  label(341,195,'REFERENCE',p.orange)
  rect(8,222,311,21,p.tape);vlabel(16,222,21,'LOCAL NOTES / NO VTX COMMANDS',p.muted)
  rect(331,222,141,21,p.tape);vlabel(339,222,21,configuration.canOpen(9) and 'EDIT FAVOURITES >' or 'ENABLE IN SETUP',configuration.canOpen(9) and p.cyan or p.orange)
 end
end)()
local function diagnostics(d)
 local p=palette;frame('DIAGNOSTICS',d)
 panel(8,64,464,179,'RUNTIME / CAPABILITIES')
 local rows={{'EdgeTX',tostring(getVersion())},{'Build',BUILD_ID},{'Model',modelName},{'Source','LIVE TELEMETRY'},{'MSP connection',fcLink.state.status},{'FC / API',(fcLink.state.firmware or '--')..' / '..(fcLink.state.api or '--')},{'VTX / FC writes','UNAVAILABLE'},{'Background',renderStats.background},{'Draw / value changes',string.format('%.1f fps / %.1f Hz',renderStats.fps,renderStats.attitudeHz)}}
 for i,r in ipairs(rows)do label(20,88+(i-1)*17,r[1],p.muted);label(461,88+(i-1)*17,r[2],p.white,SMLSIZE,true)end
end

local accents={{164,227,125},{104,221,237},{255,174,98}}
local appliedAccent
-- Six stable sections. The same bar is used by touch, SYS and PAGE.
local function selectPage(id)
 menuOpen=false;controlFocus=0
 if id==page and backgroundReady then lastFrame=-100;return end
 changePage(id);if id==4 then scanSensors()end
end
local shell=(function()
 local groups={
  {title='FLIGHT',icon=1,tabs={{1,'INSTRUMENTS'},{10,'ARM INFO'}}},
  {title='DATA',icon=5,tabs={{5,'TELEMETRY'},{3,'POWER'},{9,'RC LINK'}}},
  {title='GPS',icon=7,tabs={{7,'GPS DETAILS'},{2,'TRACK / HOME'}}},
  {title='VIDEO',icon=11,tabs={{11,'SAVED VTX FAVOURITES'}}},
  {title='SETUP',icon=8,tabs={{8,'CONFIGURATION'}}},
  {title='TOOLS',icon=13,tabs={{6,'STICK GUIDE'},{4,'SENSORS'},{12,'DIAGNOSTICS'}}}
 }
 local clockAt,clock=-100,'--:--'
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
 for id=1,12 do
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
  [3]={{'powerSources',8,222,152,21,'BATTERY SOURCES'},{'powerRefresh',168,222,152,21,'REFRESH'},{'powerLimits',328,222,144,21,'CELL LIMITS'}},
  [2]={{'refresh',10,222,100,21,'REFRESH'},{'zoom',117,222,90,21,'ZOOM +'},{'home',214,222,112,21,'SET HOME'}},
  [7]={{'refresh',10,222,132,21,'REFRESH SENSORS'},{'home',148,222,150,21,'SET LOCAL HOME'}},
  [6]={{'mode',362,63,108,18,'STICK MODE'},{'previous',10,221,85,22,'PREVIOUS COMMANDS'},{'next',350,221,120,22,'NEXT COMMANDS'}},
  [4]={{'nextSensors',10,222,224,21,'NEXT SOURCES'},{'refreshSensors',242,222,228,21,'REFRESH'}},
  [11]={{'editFavourites',331,222,141,21,'EDIT FAVOURITES'}}
 }
 -- Control geometry is built once, never in the telemetry/render loop.
 local controls={}
 for id=1,12 do
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
 local function enabled(item)
  if item[1]=='arm' then return page~=10 end
  if item[1]=='alert' then return alertTarget~=nil end
  if item[1]=='powerLimits' then return configuration.canOpen(3)end
  if item[1]=='home' then return navCurrent~=nil end
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
  alertTarget=d.battery and 3 or d.link and 9 or not d.ok and 12 or nil
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
   if getDateTime then local date=getDateTime();if date then clock=string.format('%02d:%02d',date.hour,date.min)end end
   clockAt=now
  end
  vlabel(43,0,18,clock,p.white)
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
    local caption=selected==1 and i==1 and ('FM / '..tostring(d.flight or '--')) or tab.caption
    local available=w-12-(selected==4 and 90 or 0)
    local shown,font=fittedText(caption,available-24,SMLSIZE)
    local groupWidth=24+textWidth(shown,font);local gx=x+6+math.floor((available-groupWidth)/2)
    icon(tab.id,gx,38,color,18);vlabel(gx+24,35,24,shown,color,font)
   end
   if selected==4 then vlabel(468,35,24,'REFERENCE',p.orange,SMLSIZE,true)end
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
  local warning=d.battery or d.link or not d.ok and 'NO CURRENT TELEMETRY'
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
   local mode,font=fittedText(tostring(d.flight or '--'),104,SMLSIZE)
   vlabel(8,247,24,mode,p.white,font)
   line(120,251,120,267,p.border);icon(0,128,250,p.muted,18)
   local pos=gpsPosition(d.gps);local dist=pos and navHome and geo(navHome,pos)or nil
   flightValue(152,247,80,24,dist and round(dist)or '--','m',SMLSIZE)
   line(240,251,240,267,p.border);icon(14,248,250,d.sats and p.cyan or p.muted,18)
   flightValue(272,247,24,24,d.sats and round(d.sats)or '--','',SMLSIZE,d.sats and p.cyan or p.muted)
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
 return {draw=draw,updateAlerts=updateAlerts,hit=hit,footerHit=footerHit,group=groupFor,controls=controls,enabled=enabled,focused=focused,move=moveControl,outline=outline,
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
 if action=='arm' then openArm()
 elseif action=='page' then selectPage(item[7])
 elseif action=='alert' then selectPage(shell.alert())
 elseif action=='powerSources' then configuration.openSection(1,'voltage');configReturn=3;selectPage(8)
 elseif action=='powerLimits' then configuration.openSection(3);configReturn=3;selectPage(8)
 elseif action=='powerRefresh' then telemetry.refreshBindings();shell.notify('SENSOR BINDINGS REFRESHED')
 elseif action=='refresh' then navAction('mode');shell.notify('SENSOR BINDINGS REFRESHED')
 elseif action=='zoom' then navAction('zoom')
 elseif action=='home' then navAction('home');shell.notify('LOCAL HOME SET')
 elseif action=='mode' then stickMode=stickMode%4+1
 elseif action=='previous' then commandPage=math.max(1,commandPage-1)
 elseif action=='next' then commandPage=math.min(2,commandPage+1)
 elseif action=='nextSensors' then sensorOffset=sensorOffset+5;scanSensors()
 elseif action=='refreshSensors' then telemetry.refreshBindings();scanSensors();shell.notify('SENSOR BINDINGS REFRESHED')
 elseif action=='editFavourites' then
  configReturn=11;selectPage(8);configuration.openSection(configuration.canOpen(9) and 9 or 1)
 end
 if controlFocus>0 and not shell.focused()then controlFocus=0 end
 lastFrame=-100
end
local exitButtons={{60,'KEEP EDITING'},{245,'DISCARD / EXIT'}}
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

local function run(event,touch)
 if not started then init() end
 if not palette then
  palette={}
  local colors={red={250,91,64},green={164,227,125},cyan={104,221,237},orange={255,174,98},white={232,242,245},muted={140,164,179},dim={42,64,79},border={57,84,100},sky={32,112,166},ground={117,88,49},horizon={157,208,221},ladder={128,173,191},black={5,12,19},tape={15,31,43},route={56,82,92}}
  for k,v in pairs(colors)do palette[k]=lcd.RGB(v[1],v[2],v[3])end
 end
 local accent=configuration.get('accent');if appliedAccent~=accent then local c=accents[accent];palette.green=lcd.RGB(c[1],c[2],c[3]);appliedAccent=accent end
 local isTap=event==EVT_TOUCH_TAP and touch~=nil
 local menuEvent=(EVT_SYS_BREAK and event==EVT_SYS_BREAK)or(EVT_VIRTUAL_MENU and event==EVT_VIRTUAL_MENU)
 if exitOpen then
  if event==EVT_VIRTUAL_EXIT then exitOpen=false
  elseif event==EVT_VIRTUAL_NEXT or event==EVT_VIRTUAL_PREV or event==EVT_VIRTUAL_NEXT_PAGE or event==EVT_VIRTUAL_PREV_PAGE then exitChoice=3-exitChoice
  elseif event==EVT_VIRTUAL_ENTER or isTap and touch.y>=175 and touch.y<207 and touch.x>=60 and touch.x<420 then
   if isTap then exitChoice=touch.x<240 and 1 or 2 end
   if exitChoice==2 then configuration.discardAll();fcLink.stop();return 1 end
   exitOpen=false;configuration.openSection(nil);configReturn=1;selectPage(8)
  end
  lastFrame=-100
 elseif menuEvent then
  menuOpen=not menuOpen;menuIndex=shell.group(page);controlFocus=0;lastFrame=-100
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
   local parents={[2]=7,[3]=5,[9]=5,[10]=armReturn,[4]=6,[12]=6,[8]=configReturn}
   selectPage(parents[page]or 1)
  elseif configuration.hasChanges()then exitOpen=true;exitChoice=1;lastFrame=-100
  else fcLink.stop();return 1 end
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
 elseif isTap and((page==1 and touch.y>=34 and touch.y<64)or(page~=1 and touch.y>=35 and touch.y<61))then
  local target=shell.hit(touch.x,touch.y,page);if target then selectPage(target)end
 elseif page==10 then
  if event==EVT_VIRTUAL_NEXT or event==EVT_VIRTUAL_PREV then armUi.move(event==EVT_VIRTUAL_NEXT and 1 or -1)
  elseif isTap then armUi.tap(touch.x,touch.y)end
  if event~=0 then lastFrame=-100 end
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
 fcLink.update(getTime())
 local pitch,roll=telemetry.pollAttitude()
 if pitch~=nil and roll~=nil and (pitch~=renderStats.pitch or roll~=renderStats.roll) then renderStats.changes=renderStats.changes+1 end
 renderStats.pitch=pitch;renderStats.roll=roll
 local now=getTime();if now-lastFrame<math.ceil(100/configuration.get('renderHz')) and now>=lastFrame then return 0 end;lastFrame=now
 local d=telemetry.sample()
 if traces.mode~=d.mode then traces={mode=d.mode};lastTrace=-100 end
 statusUpdate(d)
 shell.updateAlerts(d)
 if not backgroundReady and page~=5 then changePage(page)end
 do
  rect(0,34,480,212,palette.black)
  if page==1 then cockpit(d) elseif page==5 then telemetryScreen(d) elseif page==2 then navigation(d) elseif page==3 then powerScreen(d) elseif page==4 then systemPage() elseif page==6 then stickCommands() elseif page==7 then gpsDetails(d) elseif page==8 then configuration.draw(controlFocus>0) elseif page==9 then linkScreen(d) elseif page==10 then statusScreen(d) elseif page==11 then vtxScreen(d) elseif page==12 then diagnostics(d)end
 end
 shell.draw(page,d)
 if exitOpen then exitDialog()end
 renderStats.frames=renderStats.frames+1;renderStats.cost=renderStats.cost+(getTime()-now)*10
 if now-renderStats.window>=200 then
  local seconds=(now-renderStats.window)/100
  renderStats.fps=renderStats.frames/seconds;renderStats.attitudeHz=renderStats.changes/seconds;renderStats.drawMs=renderStats.cost/renderStats.frames
  renderStats.frames=0;renderStats.changes=0;renderStats.cost=0;renderStats.window=now
  -- Metrics stay in memory. Never write to the SD card from the refresh loop.

 end
 return 0
end
return {init=init,run=run,stop=fcLink.stop}
