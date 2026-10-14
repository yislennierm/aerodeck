-- toolName = TNS|AERODECK|TNE
-- AERODECK: integrated 480x272 TX16S cockpit and telemetry console.
-- Live telemetry only across flight, telemetry, power, link and GPS.
-- No model writes or RF commands. Absent telemetry is shown as --.
-- MENU opens 12 native icon destinations; PAGE cycles screens. Footer switches source.
-- Config: 12 lists; application settings saved per model. FC/MSP and VTX writes unavailable.
-- Tools: ENTER/header cycles diagram mode 1-4; PREV/NEXT touchscreen buttons change list.
-- Telemetry refresh never substitutes synthetic data.
-- Live attitude comes from current mapped sensors. RTN closes menu, then exits.
local renderStats={fps=0,attitudeHz=0,drawMs=0,frames=0,changes=0,window=0,cost=0,background='NOT LOADED'}
-- Toolbox's qualified telemetry-source binding avoids collisions with named inputs.
local fieldCache,telemetryFields={},{}
local function cachedField(name)
 local f=fieldCache[name]
 if f==nil then f=getFieldInfo(name) or false;fieldCache[name]=f end
 return f or nil
end
local function cachedTelemetryField(name)
 local f=telemetryFields[name]
 if f==nil then
  if getSourceIndex and CHAR_TELEMETRY then
   local id=getSourceIndex(CHAR_TELEMETRY..name)
   f=type(id)=='number' and id>0 and {id=id} or false
  else f=getFieldInfo(name) or false end
  telemetryFields[name]=f
 end
 return f or nil
end
local function refreshSources()fieldCache={};telemetryFields={}end
local function openBackground(name)
 local root='/SCRIPTS/TOOLS/AERODECK/'
 if name=='flight' then
  local regions={{0,0,480,38},{0,38,96,208},{392,38,88,208},{96,38,296,44},{96,216,296,30}}
  local tiles={};local failed={}
  for i,r in ipairs(regions) do
   local b=Bitmap.open(root..'fc'..i..'.bmp');local w,h=Bitmap.getSize(b)
   if w~=r[3] or h~=r[4] then
    b=nil;collectgarbage('collect');b=Bitmap.open(root..'flight-chrome-'..i..'.png');w,h=Bitmap.getSize(b)
   end
   if w==r[3] and h==r[4] then tiles[#tiles+1]={b,r[1],r[2]} else failed[#failed+1]=tostring(i) end
  end
  renderStats.background=#failed==0 and '5/5 NATIVE' or 'FAILED '..table.concat(failed,',')

  return tiles,100
 end
 local b=Bitmap.open(root..name..'.png');local w,h=Bitmap.getSize(b)
 if w>0 and h>0 then return b,100 end
 b=nil;collectgarbage('collect')
 b=Bitmap.open(root..name..'-small.png');w,h=Bitmap.getSize(b)
 if w>0 and h>0 then return b,200 end
 return nil,100
end
local function drawBackground(b,scale)
 if type(b)=='table' then
  lcd.setColor(CUSTOM_COLOR,lcd.RGB(24,31,31));lcd.drawFilledRectangle(0,0,480,246,CUSTOM_COLOR)
  for _,t in ipairs(b)do lcd.drawBitmap(t[1],t[2],t[3])end
 elseif b then
  if scale==100 then lcd.drawBitmap(b,0,0) else lcd.drawBitmap(b,0,0,scale) end
 else
  lcd.setColor(CUSTOM_COLOR,lcd.RGB(7,15,22));lcd.drawFilledRectangle(0,0,480,272,CUSTOM_COLOR)
  lcd.setColor(CUSTOM_COLOR,lcd.RGB(235,243,245));lcd.drawText(12,10,'AERODECK',CUSTOM_COLOR+SMLSIZE)
 end
end

local batteryConfig=(function()
 local defaults={0,27,30,34,36,42,0,0}
 local active,draft,path,message,selected,editing,lastAlert={}, {},nil,'',1,false,-10000
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
  draft=copy(active);message='Select row; adjust; SAVE to apply';selected=1;editing=false
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
 local function input(event,touch)
  if event==EVT_VIRTUAL_ENTER then editing=not editing
  elseif EVT_VIRTUAL_NEXT and event==EVT_VIRTUAL_NEXT then if editing then adjust(1) else selected=selected%8+1 end
  elseif EVT_VIRTUAL_PREV and event==EVT_VIRTUAL_PREV then if editing then adjust(-1) else selected=(selected+6)%8+1 end
  elseif event==EVT_TOUCH_TAP and touch then
   if touch.y>=55 and touch.y<215 then selected=math.floor((touch.y-55)/20)+1;editing=true
   elseif touch.y>=222 and touch.y<245 then
    if touch.x<85 then adjust(-1) elseif touch.x<170 then adjust(1) elseif touch.x<320 then save() else draft=copy(active);message='Unsaved changes discarded';editing=false end
   end
  end
 end
 local function draw()
  local c={bg=lcd.RGB(7,15,22),panel=lcd.RGB(18,32,42),muted=lcd.RGB(144,165,178),white=lcd.RGB(235,243,245),green=lcd.RGB(164,227,125),orange=lcd.RGB(255,174,98)}
  local function box(x,y,w,h,col)lcd.setColor(CUSTOM_COLOR,col);lcd.drawFilledRectangle(x,y,w,h,CUSTOM_COLOR)end
  local function text(x,y,s,col,right)lcd.setColor(CUSTOM_COLOR,col);lcd.drawText(x,y,s,CUSTOM_COLOR+SMLSIZE+(right and RIGHT or 0))end
  box(137,3,339,31,c.bg);text(151,12,'CONFIGURATION',c.white);text(465,12,'MODEL BATTERY',c.green,true)
  box(5,38,470,207,c.bg);text(13,40,message,c.orange)
  for i,label in ipairs(labels) do
   local y=55+(i-1)*20
   box(10,y,460,19,i==selected and c.green or c.panel)
   local col=i==selected and c.bg or c.white
   text(17,y+3,label,col)
   local v=i==1 and (draft[i]==0 and 'Not set' or draft[i]..'S') or i<=6 and string.format('%.1f V',draft[i]/10) or i==7 and types[draft[i]+1] or (draft[i]==0 and 'Critical only' or 'Critical + Low')
   text(459,y+3,(editing and selected==i and '< '..v..' >' or v),col,true)
  end
  for _,b in ipairs({{10,70,'-'},{88,70,'+'},{172,140,'SAVE'},{320,150,'REVERT'}}) do box(b[1],222,b[2],21,c.panel);text(b[1]+16,227,b[3],c.green) end
 end
 local function check(volts,demo,override)
  local cells=demo and 4 or override or active[1]
  if not volts or cells==0 then return nil,cells end
  local v=volts/cells*10
  local status=v<=active[2] and 'NO PACK POWER' or v<active[3] and 'BELOW MINIMUM' or v<=active[4] and 'BATTERY CRITICAL' or v<=active[5] and 'BATTERY LOW' or v>active[6] and 'ABOVE MAXIMUM' or nil
  local warn=v>active[2] and (v<=active[4] or active[8]==1 and v<=active[5])
  if not demo and warn and active[7]>0 and getTime()-lastAlert>=1000 then
   lastAlert=getTime()
   if active[7]==1 or active[7]==3 then playTone(1500,150,0,0) end
   if active[7]==2 or active[7]==3 then playHaptic(15,0,0) end
  end
  return status,cells
 end
 return {init=init,input=input,draw=draw,check=check,save=save}
end)()

local configuration=(function()
 local active,draft,path={}, {},nil
 local section,selected,offset,editing=1,1,0,false
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
 sections[4]={name='BATTERY FAVOURITES',rows={item('pack','Active profile',0,0,3,1,{'Manual cells','Pack 1','Pack 2','Pack 3'})}}
 for i=1,3 do
  local r=sections[4].rows;r[#r+1]=item('cells'..i,'Pack '..i..' cells',4,1,12);r[#r+1]=item('capacity'..i,'Pack '..i..' capacity (mAh)',1500,100,30000,50)
 end
 sections[5]={name='FLIGHT CONTROLLER',rows={note('FC telemetry','Read via mapped sensors'),note('MSP connection','NOT IMPLEMENTED'),note('MSP polling / FC writes','Unavailable'),note('Configuration changes','Use Betaflight Configurator')}}
 local switchChoices={'None','SA','SB','SC','SD','SE','SF','SG','SH','L01','L02','L03','L04'}
 sections[6]={name='INDICATORS',rows={item('armSource','Arm indicator source','None',nil,nil,nil,switchChoices),item('armPosition','Arm active position',1,-1,1,1,{'Low','Centre','High'}),item('cutSource','Throttle cut source','None',nil,nil,nil,switchChoices),item('cutPosition','Cut active position',1,-1,1,1,{'Low','Centre','High'}),note('Arm state','NOT CONFIGURED'),note('Throttle cut state','NOT CONFIGURED'),note('Indicators are displays','Do not alter output channels')}}
 sections[7]={name='BETAFLIGHT INDICATORS',rows={sensor('flightmode','Flight mode telemetry'),note('Reported flight mode','--'),note('Acro / Angle / Horizon','Reported by FM source'),note('Air / Turtle control','No commands transmitted')}}
 sections[8]={name='VTX',rows={note('VTX connection','NOT IMPLEMENTED'),note('Channel / power writes','Unavailable'),note('VTX control','Use existing VTX tool'),note('Favourites','Offline frequency notes only')}}
 sections[9]={name='VTX FAVOURITES',rows={note('Purpose','Offline notes; no VTX writes')}}
 for i=1,5 do sections[9].rows[#sections[9].rows+1]=item('vtx'..i,'Favourite '..i..' frequency (MHz)',({5865,5732,5800,5806,5917})[i],5000,6000) end
 sections[10]={name='GPS',rows={item('autoHome','Capture first valid home',0,0,1,1,{'Off','On'}),item('homeSats','Minimum sats for auto home',8,4,64),item('trail','Track samples retained',90,10,180,10),item('zoom','Default track zoom',2,1,3,1,{'Wide','Medium','Close'}),note('Home reference','Local to AERODECK'),note('3D fix / constellation','Not provided by reader')}}
 sections[11]={name='USER INTERFACE',rows={item('accent','Highlight colour',1,1,3,1,{'Green','Cyan','Amber'}),item('renderHz','Redraw target (Hz)',25,5,30),item('startPage','Opening page',1,1,8,1,{'Flight','Telemetry','Nav','GPS','Power','System','Tools','Config'})}}
 sections[12]={name='APPLICATION',rows={note('Telemetry source','Live sensors only'),note('Settings scope','Per model name'),note('Saving','Verified SD file + backup'),note('Sound / haptic scope','While full app runs'),note('FC / radio model writes','None'),note('Settings reload','Reopen AERODECK')}}
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
 local function init()
  sensors={'Auto','None'}
  for i=0,63 do local s=model.getSensor(i);if s and s.name and s.name~='' then sensors[#sensors+1]=s.name end end
  for _,s in pairs(schema)do if s.choices and s.choices[1]=='Auto' then s.choices=sensors end end
  local name=model.getInfo().name or 'model';local key=''
  for i=1,#name do key=key..string.format('%02x',string.byte(name,i))end
  path='/SCRIPTS/TOOLS/AERODECK/settings-'..key..'.cfg'
  active=read(path) or read(path..'.bak') or {};for k,s in pairs(schema)do if active[k]==nil then active[k]=s.default end end
  draft=copy(active);section=1;selected=1;offset=0;editing=false;message='Select list using header arrows'
 end
 local function save()
  local ok,why=valid(draft);if not ok then message=why;return false end
  if not write(path..'.bak',active) or not write(path,draft) then message='SAVE FAILED - active settings unchanged';return false end
  active=copy(draft);message='SAVED - startup options apply on reopen';return true
 end
 local function change(delta)
  local list=visible(draft);local index=1
  for i,id in ipairs(list)do if id==section then index=i end end
  section=list[(index-1+delta)%#list+1];selected=1;offset=0;editing=false
 end
 local function adjust(delta)
  local s=sections[section].rows[selected];if not s or s.note then return end
  if type(s.default)=='number' then draft[s.key]=math.max(s.lo,math.min(s.hi,draft[s.key]+delta*s.step))
  else
   local index=1;for i,v in ipairs(s.choices)do if v==draft[s.key]then index=i end end
   draft[s.key]=s.choices[(index-1+delta)%#s.choices+1]
  end
  message='Unsaved changes - SAVE to apply'
 end
 local function input(event,touch)
  if event==EVT_TOUCH_TAP and touch and touch.y<36 then if touch.x<100 then change(-1) elseif touch.x>380 then change(1) end;return end
  if section==3 then batteryConfig.input(event,touch);return end
  local rows=sections[section].rows
  if event==EVT_VIRTUAL_ENTER then editing=not editing
  elseif (EVT_VIRTUAL_NEXT and event==EVT_VIRTUAL_NEXT) or (EVT_VIRTUAL_PREV and event==EVT_VIRTUAL_PREV) then
   local delta=event==EVT_VIRTUAL_NEXT and 1 or -1
   if editing then adjust(delta) else selected=(selected-1+delta)%#rows+1;offset=math.floor((selected-1)/7)*7 end
  elseif event==EVT_TOUCH_TAP and touch then
   if touch.y>=60 and touch.y<200 then selected=math.min(#rows,offset+math.floor((touch.y-60)/20)+1);editing=true
   elseif touch.y>=202 and touch.y<221 then offset=offset+7;if offset>=#rows then offset=0 end;selected=offset+1
   elseif touch.y>=222 and touch.y<245 then
    if touch.x<85 then adjust(-1) elseif touch.x<170 then adjust(1) elseif touch.x<320 then save() else draft=copy(active);message='Unsaved changes discarded' end
   end
  end
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
 local function draw()
  local list=visible(draft);local index
  for i,id in ipairs(list)do if id==section then index=i end end
  if not index then section=1;selected=1;offset=0;index=1 end
  if section==3 then batteryConfig.draw() end
  local c={bg=lcd.RGB(7,15,22),panel=lcd.RGB(18,32,42),white=lcd.RGB(235,243,245),green=lcd.RGB(164,227,125),orange=lcd.RGB(255,174,98),muted=lcd.RGB(144,165,178)}
  local function box(x,y,w,h,col)lcd.setColor(CUSTOM_COLOR,col);lcd.drawFilledRectangle(x,y,w,h,CUSTOM_COLOR)end
  local function text(x,y,s,col,right)lcd.setColor(CUSTOM_COLOR,col);lcd.drawText(x,y,tostring(s),CUSTOM_COLOR+SMLSIZE+(right and RIGHT or 0))end
  box(4,3,472,31,c.bg);text(13,12,'< LIST',c.green);text(92,12,sections[section].name,c.white);text(468,12,index..'/'..#list..'  >',c.green,true)
  if section==3 then return end
  box(5,38,470,207,c.bg);text(13,41,message,c.orange)
  local rows=sections[section].rows
  for i=1,7 do
   local index=offset+i;local s=rows[index]
   if s then
    local y=60+(i-1)*20;local chosen=index==selected
    box(10,y,460,19,chosen and c.green or c.panel);local col=chosen and c.bg or c.white
    local v=s.note or draft[s.key]
    if not s.note and s.choices and type(s.default)=='number' then v=s.choices[v-s.lo+1] end
    if section==6 and index==5 then v=indicator('arm') elseif section==6 and index==6 then v=indicator('cut')
    elseif section==7 and index==2 then v=value('FM') or '--' end
    text(17,y+3,s.label,col);text(459,y+3,(editing and chosen and not s.note) and '< '..tostring(v)..' >' or v,col,true)
   end
  end
  if #rows>7 then text(17,205,'MORE ROWS >   '..(offset+1)..'-'..math.min(offset+7,#rows)..' / '..#rows,c.green) end
  for _,b in ipairs({{10,70,'-'},{88,70,'+'},{172,140,'SAVE'},{320,150,'REVERT'}})do box(b[1],222,b[2],21,c.panel);text(b[1]+16,227,b[3],c.green)end
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
 return {init=init,input=input,draw=draw,get=get,resolve=resolve,value=value,linkStatus=linkStatus,indicator=indicator,save=save,visible=function() return visible(draft) end}
end)()

local telemetry=(function()
local root='/SCRIPTS/TOOLS/AERODECK/'
local bg,colors,start,last,mode,glyphs,minimum
local bgScale,bgTried=100,false
local units={}
local function scanUnits()
 refreshSources();units={}
 for i=0,63 do local sensor=model.getSensor(i);if sensor and sensor.name then units[sensor.name]=sensor.unit end end
end
local function init() start=getTime();last=-100;mode=1;glyphs={};minimum=nil;scanUnits() end
local function ink(c) lcd.setColor(CUSTOM_COLOR,c) end
local function box(x,y,w,h,c) ink(c);lcd.drawFilledRectangle(x,y,w,h,CUSTOM_COLOR) end
local function txt(x,y,s,c,right)
 ink(c);lcd.drawText(x,y,s,CUSTOM_COLOR+SMLSIZE+(right and RIGHT or 0))
end
local function number(x,y,s)
 s=tostring(s)
 for i=1,#s do
  local c=string.sub(s,i,i);local token=c=='.' and 'dot' or c=='-' and 'minus' or c
  local k='n22-'..token
  if not glyphs[k] then glyphs[k]=Bitmap.open(root..k..'.png') end
  lcd.drawBitmap(glyphs[k],x+(i-1)*13,y)
 end
end
local function read(names,kind)
 for _,original in ipairs(names) do
  local name=configuration.resolve(original)
  local f=name and cachedTelemetryField(name)
  if f then local v,current=getSourceValue(f.id);if current and type(v)=='number' then
   local unit=units[name]
   if kind=='speed' then
    if unit==UNIT_KTS then v=v*1.852 elseif unit==UNIT_MPH then v=v*1.609344 elseif unit==UNIT_METERS_PER_SECOND then v=v*3.6 elseif unit==UNIT_FEET_PER_SECOND then v=v*1.09728 elseif unit~=UNIT_KMH then return nil end
   elseif kind=='angle' then
    if unit==UNIT_RADIANS then v=v*180/math.pi elseif unit~=UNIT_DEGREE then return nil end
   elseif kind=='alt' then
    if unit==UNIT_FEET then v=v*.3048 elseif unit~=UNIT_METERS then return nil end
   end
   return v
  end end
 end
end
local function fmt(v,pattern,suffix)
 if type(v)~='number' then return '--' end
 return string.format(pattern or '%.0f',v)..(suffix or '')
end
local liveFields={{'v',{'RxBt','VFAS','Bat'}},{'a',{'Curr'}},{'mah',{'Capa'}},{'pct',{'Bat%'}},{'lq',{'RQly','LQ'}},{'rssi',{'1RSS','RSSI'}},{'snr',{'RSNR','SNR'}},{'power',{'TPWR'}},{'down',{'TQly'}},{'rf',{'RFMD'}},{'sats',{'Sats'}},{'speed',{'GSpd'},'speed'},{'alt',{'GAlt','Alt'},'alt'},{'hdg',{'Hdg'},'angle'},}
local liveData={}
local pitchNames,rollNames={'Ptch'},{'Roll'}
local attitudePitch,attitudeRoll
local function pollAttitude()
 attitudePitch=read(pitchNames,'angle');attitudeRoll=read(rollNames,'angle')
 return attitudePitch,attitudeRoll
end
local function getData(t)
 local d=liveData
 for _,f in ipairs(liveFields)do d[f[1]]=read(f[2],f[3])end
 d.pitch=attitudePitch;d.roll=attitudeRoll
 d.flight=configuration.value('FM') or '--';d.demo=false;d.estimated=nil

 local gpsCurrent=configuration.value('GPS')
 d.ok=d.v~=nil or d.lq~=nil or d.rssi~=nil or d.sats~=nil or d.pitch~=nil or type(gpsCurrent)=='table' or d.flight~='--'
 return d
end
local function sample()
 pollAttitude()
 local d=getData((getTime()-start)/100)
 if not d.ok then d.flight=nil end
 d.mode=mode
 local pack=configuration.get('pack');local override=pack>0 and configuration.get('cells'..pack) or nil
 if not d.demo and pack>0 and d.pct==nil and type(d.mah)=='number' then d.pct=math.max(0,math.min(100,100*(1-d.mah/configuration.get('capacity'..pack))));d.estimated=true end
 d.battery,d.cells=batteryConfig.check(d.v,d.demo,override)
 if d.cells==0 then d.cells=nil end
 d.link=configuration.linkStatus(d)
 return d
end
local function toggle()mode=1;last=-100;scanUnits()end
local function run(event,touch)
 if event==EVT_VIRTUAL_EXIT then return 1 end
 if not start then init() end
 local now=getTime();if now-last<10 and now>=last then return 0 end;last=now
 if not colors then colors={white=lcd.RGB(236,243,244),muted=lcd.RGB(142,162,175),gold=lcd.RGB(234,182,100),green=lcd.RGB(142,214,176),cyan=lcd.RGB(131,207,232),red=lcd.RGB(255,101,95),dark=lcd.RGB(10,17,23)} end
 local p=colors;if not bgTried then bg,bgScale=openBackground('console');bgTried=true end
 drawBackground(bg,bgScale)
 local d=getData((now-start)/100)
 -- Never retain old telemetry values after a link loss.
 if not d.ok then d.flight=nil end
 if d.v and (not minimum or d.v<minimum) then minimum=d.v end
 local status=mode==1 and (d.ok and 'LIVE SENSORS' or 'NO TELEMETRY') or (mode==3 and 'DEMO / LOW PACK' or mode==4 and 'DEMO / LINK LOSS' or 'DEMO / NORMAL')
 local pack=configuration.get('pack')
 local override=pack>0 and configuration.get('cells'..pack) or nil
 if not d.demo and pack>0 and d.pct==nil and type(d.mah)=='number' then d.pct=math.max(0,math.min(100,100*(1-d.mah/configuration.get('capacity'..pack))));d.estimated=true end
 local batteryStatus,cells=batteryConfig.check(d.v,d.demo,override)
 local linkStatus=configuration.linkStatus(d)
 if not batteryStatus and d.ok and linkStatus then status=(d.demo and 'DEMO / ' or '')..linkStatus end
 if batteryStatus then status=(d.demo and "DEMO / " or "")..batteryStatus end
 local alert=(batteryStatus~=nil or linkStatus~=nil or not d.ok)
 -- Status is right aligned to fit the fixed header slot.
 box(309,9,156,20,alert and p.red or p.dark);txt(460,13,status,alert and p.dark or p.gold,true)
 number(17,72,fmt(d.v,'%.2f'));number(176,72,fmt(d.lq));number(334,72,fmt(d.speed,'%.1f'))
 if cells==0 then cells=nil end
 local rows={
  {fmt(d.a,'%.1f',' A'),fmt(d.mah,'%.0f',' mAh'),fmt(d.pct,'%.0f',' %'),fmt(cells and d.v and d.v/cells,'%.2f',' V'),fmt(d.ok and minimum or nil,'%.2f',' V'),cells and (cells..'S'..(d.demo and ' / DEMO' or ' / SET')) or '--'},
  {fmt(d.rssi,'%.0f',' dBm'),fmt(d.snr,'%.0f',' dB'),fmt(d.power,'%.0f',' mW'),fmt(d.down,'%.0f',' %'),fmt(d.rf),d.ok and 'CONNECTED' or 'NO DATA'},
  {fmt(d.sats),fmt(d.alt,'%.0f',' m'),fmt(d.hdg,'%.0f',' deg'),fmt(d.pitch,'%.1f',' deg'),fmt(d.roll,'%.1f',' deg'),d.flight or '--'}
 }
 for col=1,3 do
  local c=col==1 and (mode==3 and p.red or p.gold) or col==2 and p.green or p.cyan
  for j=1,6 do txt(149+(col-1)*158,124+(j-1)*19,rows[col][j],d.ok and (j==6 and c or p.white) or p.muted,true) end
  local v=col==1 and d.pct or col==2 and d.lq or (d.sats and math.min(100,d.sats/20*100))
  for j=0,19 do if v and j<v/5 then box(16+(col-1)*158+math.floor(j*6.6),102,4,3,c) end end
 end
 box(8+(mode-1)*118,248,110,2,alert and p.red or p.gold)
 return 0
end
return {init=init,run=run,sample=sample,pollAttitude=pollAttitude,toggle=toggle,isDemo=function()return mode~=1 end,release=function() bg=nil;bgTried=false;glyphs={};collectgarbage('collect') end,refresh=function() last=-100 end}

end)()
local ROOT='/SCRIPTS/TOOLS/AERODECK/'
local started, page, background, palette, failure, modelName
local backgroundScale,backgroundReady=100,false
local glyphs={}
local widths={[30]=18,[22]=13,[16]=10,[11]=7}
local pages={'flight','nav','power','system','console','console','console','console'}
local order={1,5,2,7,3,9,10,6,8,4,11,12}
local function adjacent(delta)
 for i,v in ipairs(order) do if v==page then return order[(i-1+delta)%#order+1] end end
end
local bezel,ribbon
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
local function loadBitmap(file)
 local b=Bitmap.open(ROOT..file..'.png')
 local w,h=Bitmap.getSize(b)
 if w==0 or h==0 then
  local f=io.open(ROOT..file..'.png','r')
  if f then io.close(f);failure='Cannot decode / memory: '..file else failure='Missing file: '..file end
 end
 return b
end
local function digits(x,y,value,size)
 local s=tostring(value)
 for i=1,#s do
  local c=string.sub(s,i,i) -- EdgeTX does not expose string method indexing.
  local token=c=='.' and 'dot' or c==':' and 'colon' or c=='-' and 'minus' or c
  local key='n'..size..'-'..token
  if not glyphs[key] then glyphs[key]=loadBitmap(key) end
  lcd.drawBitmap(glyphs[key],x+(i-1)*widths[size],y)
 end
end
local function changePage(nextPage)
 if page==5 then telemetry.release() end
 page=nextPage
 -- Keep only one full-screen bitmap resident, plus the small glyph cache.
 background=nil;bezel=nil;ribbon=nil;glyphs={};backgroundReady=false;collectgarbage('collect')
 -- Flight uses native-resolution chrome pieces; never upscale a small background.
 if page==1 then background,backgroundScale=openBackground("flight") end
 backgroundReady=true
 if page==5 then telemetry.refresh() end;lastFrame=-100
end
local function init()
 batteryConfig.init();configuration.init();telemetry.init();modelName=model.getInfo().name or 'MODEL';started=getTime(); page=({1,5,2,7,3,4,6,8})[configuration.get('startPage')]; failure=nil; lastFrame=-100
 background=nil;backgroundReady=false;glyphs={};bezel=nil;ribbon=nil;sensorOffset=0;sensors={};scenario=1;zoom=2
end
local function smallText(x,y,s,c)
 ink(c);lcd.drawText(x,y,s,SMLSIZE+CUSTOM_COLOR)
end
local function bearing(x,y)
 local xx,yy=-y,-x
 if xx>0 then return math.atan(yy/xx)
 elseif xx<0 then return math.atan(yy/xx)+(yy>=0 and pi or -pi)
 elseif yy~=0 then return yy>=0 and pi/2 or -pi/2 end
 return 0
end
local navDemo,navHome,navTrack,navLast,navCurrent=false,nil,{},-100,nil
local navUnits={}
local navConfigured=false
local function navReset()
 navHome=nil;navTrack={};navLast=-100;navCurrent=nil;navUnits={}
 for i=0,63 do local s=model.getSensor(i);if s and s.name then navUnits[s.name]=s.unit end end
end
local function navRead(name,kind)
 name=configuration.resolve(name);if not name then return nil end
 local f=cachedTelemetryField(name);if not f or not getSourceValue then return nil end
 local v,current=getSourceValue(f.id)
 if not current then return nil end
 if kind=='gps' then
  if type(v)=='table' and type(v.lat)=='number' and type(v.lon)=='number' and v.lat==v.lat and v.lon==v.lon and math.abs(v.lat)<=90 and math.abs(v.lon)<=180 then return {lat=v.lat,lon=v.lon} end
  return nil
 end
 if type(v)~='number' or v~=v then return nil end
 local u=navUnits[name]
 if kind=='speed' then
  if u==UNIT_KTS then return v*1.852 elseif u==UNIT_MPH then return v*1.609344 elseif u==UNIT_METERS_PER_SECOND then return v*3.6 elseif u==UNIT_KMH then return v else return nil end
 elseif kind=='alt' then
  if u==UNIT_FEET then return v*.3048 elseif u==UNIT_METERS then return v else return nil end
 elseif kind=='angle' then
  if u==UNIT_RADIANS then return v*180/pi elseif u==UNIT_DEGREE then return v else return nil end
 end
 return v
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
local function navSnapshot()
 if not navConfigured then zoom=configuration.get('zoom');navReset();navConfigured=true end
 if navDemo~=telemetry.isDemo() then navDemo=telemetry.isDemo();navReset() end
 local now=getTime();local pos,speed,alt,sats,heading
 pos=navRead('GPS','gps');speed=navRead('GSpd','speed');alt=navRead('GAlt','alt') or navRead('Alt','alt');sats=navRead('Sats');heading=navRead('Hdg','angle')

 if not navDemo and not navHome and pos and sats and sats>=configuration.get('homeSats') and configuration.get('autoHome')==1 then navHome={lat=pos.lat,lon=pos.lon} end
 if not telemetry.sample().ok then pos=nil;speed=nil;alt=nil;sats=nil;heading=nil end
 navCurrent=pos
 if pos and now-navLast>=100 then
  navLast=now;navTrack[#navTrack+1]={lat=pos.lat,lon=pos.lon};if #navTrack>configuration.get('trail') then table.remove(navTrack,1) end
 end
 return pos,speed,alt,sats,heading
end
local function navigation(d)
 local p=palette
 local pos,speed,alt,sats,heading=navSnapshot()
 rect(137,3,339,31,p.black);smallText(148,12,'GPS / HOME',p.white)
 rect(330,7,139,23,p.tape);smallText(340,12,navDemo and 'DEMO GPS' or pos and 'LIVE POSITION' or 'NO CURRENT GPS',pos and p.green or p.orange)
 rect(5,38,470,206,p.black)
 local function val(v,fmt,unit) return type(v)=='number' and string.format(fmt or '%.0f',v)..(unit or '') or '--' end
 smallText(14,43,'SATS '..val(sats),p.green);smallText(125,43,val(speed,'%.1f',' km/h'),p.white);smallText(252,43,'GPS ALT '..val(alt,'%.0f',' m'),p.white)
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
 for _,b in ipairs({{10,100,'LIVE SENSORS'},{117,90,'ZOOM +'},{214,112,'SET HOME'},{333,137,'NORTH UP'}}) do
  rect(b[1],222,b[2],21,p.tape);smallText(b[1]+8,227,b[3],p.green)
 end
end

local function gpsDetails()
 local p=palette
 local pos,speed,alt,sats,heading=navSnapshot()
 local function val(v,f,u) return type(v)=='number' and string.format(f or '%.0f',v)..(u or '') or '--' end
 rect(137,3,339,31,p.black);smallText(155,12,'GPS DETAILS',p.white)
 rect(332,7,137,23,p.tape);smallText(341,12,navDemo and 'DEMO DATA' or pos and 'LIVE POSITION' or 'NO CURRENT GPS',pos and p.green or p.orange)
 rect(5,39,470,204,p.black)
 rect(9,43,132,173,p.tape);rect(148,43,323,173,p.tape)
 smallText(19,51,'SATELLITES',p.muted)
 digits(20,72,val(sats),30)
 smallText(20,112,'FIX TYPE',p.muted);smallText(20,130,'NOT REPORTED',p.orange)
 line(19,151,131,151,p.border)
 smallText(19,160,'PER-SATELLITE',p.muted)
 smallText(19,177,'DATA UNAVAILABLE',p.muted)
 smallText(19,195,navDemo and 'SIMULATED INPUT' or 'SENSOR TELEMETRY',p.cyan)
 local dist,angle
 if pos and navHome then dist,angle=geo(pos,navHome) end
 local rows={
 {'Aircraft LAT',pos and val(pos.lat,'%.7f') or '--'},
 {'Aircraft LON',pos and val(pos.lon,'%.7f') or '--'},
 {'Ground speed',val(speed,'%.1f',' km/h')},
 {'GPS altitude',val(alt,'%.0f',' m')},
 {'Aircraft course',val(heading,'%.0f',' deg')},
 {'Home LAT',navHome and val(navHome.lat,'%.7f') or '--'},
 {'Home LON',navHome and val(navHome.lon,'%.7f') or '--'},
 {'Home distance',val(dist,'%.0f',' m')},
 {'Bearing to home',dist and dist>=1 and val(angle,'%.0f',' deg') or '--'}
 }
 for i,row in ipairs(rows) do
  local y=49+(i-1)*18
  if i%2==0 then rect(150,y-2,319,18,p.black) end
  smallText(157,y,row[1],p.muted)
  ink(i>=6 and p.orange or p.white);lcd.drawText(462,y,row[2],CUSTOM_COLOR+SMLSIZE+RIGHT)
 end
 for _,b in ipairs({{10,132,'LIVE SENSORS'},{148,150,'SET LOCAL HOME'},{305,166,'VIEW TRACK'}}) do
  rect(b[1],222,b[2],21,p.tape);smallText(b[1]+9,227,b[3],p.green)
 end
end

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
 rect(0,0,480,246,p.black);rect(0,0,480,34,p.tape)
 smallText(12,12,'AERODECK / SENSOR INSPECTOR',p.white)
 smallText(345,12,tostring(#sensors)..' SOURCES',p.cyan)
 smallText(14,45,'SENSOR',p.muted);smallText(185,45,'VALUE',p.muted);smallText(358,45,'STATUS',p.muted)
 if #sensors==0 then smallText(20,100,'No sensors discovered in this radio model.',p.white);smallText(20,124,'Use the radio Telemetry > Discover New menu.',p.muted)end
 for row=1,5 do
  local s=sensors[sensorOffset+row]
  if s then
   local y=65+(row-1)*28;rect(10,y-2,460,26,p.tape)
   local value,current
   if s.source then value,current=getSourceValue(s.source)end
   local shown='--'
   if current then
    if type(value)=='number' then shown=string.format('%.'..clamp(s.prec,0,3)..'f',value)
    elseif type(value)=='table' then shown='GPS / TABLE'
    elseif type(value)=='string' then shown=string.sub(value,1,20)end
   end
   smallText(17,y+4,s.name,p.white);smallText(185,y+4,shown,p.cyan);smallText(358,y+4,current and 'CURRENT' or 'STALE / NONE',current and p.green or p.orange)
  end
 end
 rect(10,220,460,23,p.tape);smallText(20,225,'TAP HERE: NEXT SENSORS / REFRESH',p.green)
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
 rect(137,3,338,31,p.black)
 smallText(148,12,'STICK COMMANDS',p.white)
 rect(362,7,108,24,p.tape);smallText(374,12,'MODE '..stickMode,p.green)
 rect(5,38,470,207,p.black)
 smallText(14,43,'BETAFLIGHT / REFERENCE ONLY',p.orange)
 smallText(365,43,commandPage..' / 2',p.muted)
 local axes=stickAxes[stickMode]
 local function diagram(x,y,h,v)
  rect(x,y,21,21,p.border);rect(x+1,y+1,19,19,p.tape)
  line(x+10,y+2,x+10,y+18,p.dim);line(x+2,y+10,x+18,y+10,p.dim)
  rect(x+8+h*7,y+8-v*7,5,5,p.green)
 end
 for row=1,7 do
  local index=(commandPage-1)*7+row;local cmd=commands[index]
  if cmd then
   local y=63+(row-1)*22
   if row%2==1 then rect(10,y-1,460,22,p.tape) end
   diagram(18,y,cmd[axes[1]],cmd[axes[2]])
   diagram(47,y,cmd[axes[3]],cmd[axes[4]])
   smallText(83,y+4,cmd[1],p.white)
  end
 end
 rect(10,221,460,22,p.tape)
 smallText(17,226,'< PREV',p.cyan);smallText(108,226,'FC support varies*',p.muted);smallText(369,226,'NEXT >',p.cyan)
end

-- Original native-drawn icon family: no Toolbox graphics or bitmap allocation.
local function icon(id,x,y,c)
 local function l(a,b,d,e)line(x+a,y+b,x+d,y+e,c)end
 local function r(a,b,w,h)rect(x+a,y+b,w,h,c)end
 local function o(a,b,rad)circle(x+a,y+b,rad,c)end
 if id==1 then o(12,12,10);l(1,12,8,12);l(16,12,23,12);l(8,12,12,16);l(12,16,16,12);l(12,1,12,5)
 elseif id==5 then for i=0,3 do r(2+i*6,18-i*4,3,5+i*4)end
 elseif id==2 then l(3,20,7,7);l(7,7,18,17);l(18,17,22,3);o(3,20,2);o(22,3,2)
 elseif id==7 then o(12,12,8);o(12,12,3);l(12,0,12,6);l(12,18,12,24);l(0,12,6,12);l(18,12,24,12)
 elseif id==3 then l(2,5,20,5);l(20,5,20,20);l(20,20,2,20);l(2,20,2,5);r(21,9,3,7);r(5,8,3,9);r(10,8,3,9);r(15,8,3,9)
 elseif id==9 then l(12,9,12,24);l(7,24,17,24);o(12,6,3);l(5,2,2,6);l(2,6,5,11);l(19,2,22,6);l(22,6,19,11)
 elseif id==10 then o(12,12,10);l(12,5,12,12);l(12,12,18,15);r(9,0,6,2)
 elseif id==6 then for a=0,1 do l(a*13,3,a*13+10,3);l(a*13,3,a*13,21);l(a*13,21,a*13+10,21);l(a*13+10,21,a*13+10,3);r(a*13+3,8+a*5,4,4)end
 elseif id==8 then for a=0,2 do l(2,4+a*8,22,4+a*8);r(6+a*4,1+a*8,3,7)end
 elseif id==4 then l(0,13,5,13);l(5,13,8,4);l(8,4,12,22);l(12,22,16,9);l(16,9,20,13);l(20,13,24,13)
 elseif id==11 then l(2,5,22,5);l(22,5,22,20);l(22,20,2,20);l(2,20,2,5);l(8,1,12,5);l(12,5,16,1);l(9,9,16,12);l(16,12,9,16);l(9,16,9,9)
 else o(12,12,10);r(11,5,2,2);r(11,10,2,9)end
end
local menuOpen,menuIndex=false,1
local destinations={{1,'FLIGHT','Attitude / instruments'},{5,'TELEMETRY','Live sensor values'},{2,'NAVIGATION','Track / home vector'},{7,'GPS','Position / satellites'},{3,'POWER','Pack / current trace'},{9,'RC LINK','Quality / RF status'},{10,'FLIGHT STATUS','Indicators / timer'},{6,'STICK GUIDE','Betaflight reference'},{8,'CONFIGURATION','Model / preferences'},{4,'SENSORS','Discovery / inspection'},{11,'VIDEO / VTX','Saved channels / status'},{12,'DIAGNOSTICS','Capabilities / runtime'}}
local function label(x,y,s,c,size,right)
 ink(c);lcd.drawText(x,y,tostring(s),CUSTOM_COLOR+(size or SMLSIZE)+(right and RIGHT or 0))
end
local function numberText(v,fmt,unit)return type(v)=='number' and string.format(fmt or '%.0f',v)..(unit or '') or '--' end
local function frame(title,d)
 local p=palette
 rect(0,0,480,246,p.black);rect(0,0,480,34,p.tape);rect(0,33,480,1,p.border)
 label(12,9,'AERODECK',p.white,MIDSIZE);label(156,12,title,p.muted)
 local alert=d.battery or d.link
 local status=alert and string.gsub(alert,'BATTERY','BATT') or d.demo and 'DEMO' or d.ok and 'LIVE' or 'NO TELEMETRY'
 rect(356,7,112,21,alert and p.red or d.demo and p.orange or d.ok and p.green or p.red)
 label(461,11,status,p.black,SMLSIZE,true)
end
local function panel(x,y,w,h,title)
 rect(x,y,w,h,palette.tape);rect(x,y,w,1,palette.border);label(x+9,y+7,title,palette.muted)
end
local function launcher(d)
 frame('FLIGHT CONSOLE',d)
 for i,dest in ipairs(destinations)do
  local x=8+((i-1)%3)*157;local y=42+math.floor((i-1)/3)*49
  rect(x,y,150,44,palette.tape)
  if i==menuIndex then rect(x,y,3,44,palette.green)end
  icon(dest[1],x+9,y+10,i==menuIndex and palette.green or palette.cyan)
  label(x+43,y+9,dest[2],palette.white)
  local status=dest[1]==11 and 'REFERENCE ONLY' or dest[1]==6 and 'REFERENCE' or dest[1]==8 and 'PER MODEL' or dest[1]==12 and 'CHECK SYSTEM' or d.demo and 'DEMO / READY' or d.ok and 'LIVE / READY' or 'NO TELEMETRY'
  label(x+43,y+26,status,palette.muted)
 end
end
local function horizonMark(ox,oy,cs,sn,offset,half,c)
 local yy=oy+offset*cs;local xx=ox-offset*sn
 clip(xx-half*cs,yy-half*sn,xx+half*cs,yy+half*sn,164,315,64,215,c)
end
local function cockpit(d)
 local p=palette
 if not bezel then bezel=loadBitmap('bezel') end
 -- Preserve the original textured cockpit; replace demo-only labels with actual state.
 rect(282,2,99,30,p.tape);smallText(286,5,string.sub(modelName,1,14),p.white)
 smallText(286,21,d.demo and 'SIMULATION' or 'LIVE SENSORS',p.green)
 rect(393,7,72,20,d.demo and p.orange or d.ok and p.green or p.red)
 smallText(398,12,d.demo and 'DEMO DATA' or d.ok and 'LIVE DATA' or 'NO DATA',p.black)
 rect(398,43,74,16,p.tape);smallText(400,47,d.cells and d.cells..'S PACK' or 'FLIGHT PACK',p.green)
 rect(100,42,280,19,d.battery and p.red or p.tape)
 smallText(105,47,d.battery or d.link or (d.ok and (d.demo and 'DEMO / NORMAL' or 'LIVE TELEMETRY') or 'TELEMETRY LOST'),p.white)
 ink(p.white);lcd.drawText(375,47,tostring(d.flight or '--'),SMLSIZE+CUSTOM_COLOR+RIGHT)
 digits(16,64,d.lq and round(d.lq) or '--',30)
 digits(14,198,d.rssi and round(d.rssi) or '--',16)
 digits(398,64,d.v and string.format('%.1f',d.v) or '--.-',30)
 digits(434,120,d.v and d.cells and string.format('%.1f',d.v/d.cells) or '--',11)
 digits(438,158,d.pct and round(d.pct) or '--',11)
 digits(402,198,d.mah and round(d.mah) or '---',16)
 rect(11,222,74,17,p.tape);smallText(15,226,d.power and round(d.power)..' mW' or '-- mW',p.muted)
 rect(398,221,74,18,p.tape);smallText(400,226,d.estimated and 'EST. REMAINING' or d.demo and 'DEMO PACK' or 'LIVE PACK',p.muted)
 for i=0,14 do
  local c=i<4 and p.red or (i<7 and p.orange or p.green)
  if d.lq and i<d.lq*.15 then rect(17,169-i*5,27,3,c) end
  if d.pct and i<d.pct*.15 then rect(402,169-i*5,27,3,c) end
 end
 -- A native horizon behind a bitmap instrument bezel; no per-pixel Lua loop.
 local attitude=d.pitch~=nil and d.roll~=nil
 if attitude then
 rect(164,64,152,152,p.sky)
 ink(p.ground);lcd.drawHudRectangle(d.pitch,d.roll,164,316,64,216,CUSTOM_COLOR)
 local angle=-d.roll*pi/180
 local ox=240+math.sin(d.roll*pi/180)*d.pitch
 local oy=140+math.cos(d.roll*pi/180)*d.pitch*1.85
 local cs,sn=math.cos(angle),math.sin(angle)
 horizonMark(ox,oy,cs,sn,0,170,p.horizon)
 for i=-5,5 do if i~=0 then horizonMark(ox,oy,cs,sn,i*14,i%2==0 and 31 or 16,p.ladder) end end
 else rect(164,64,152,152,p.dim) end
 lcd.drawBitmap(bezel,164,64)
 local a=(-(d.roll or 0)-90)*pi/180
 if attitude then triangle(240+58*math.cos(a),140+58*math.sin(a),-d.roll,4,p.orange) end
 -- Fixed aircraft symbol with dark underlay and gold foreground.
 for dy=1,0,-1 do
  local c=dy==1 and p.black or p.orange
  line(208,148+dy,231,148+dy,c);line(231,148+dy,235,153+dy,c)
  line(245,153+dy,249,148+dy,c);line(249,148+dy,272,148+dy,c)
 end
 rect(238,144,4,4,p.orange)
 -- Instrument tapes remain outside the circular aperture.
 rect(103,82,41,131,p.tape);rect(336,82,41,131,p.tape)
 for offset=-30,30,10 do
  if d.speed then local v=math.floor(d.speed/10)*10+offset;local yy=149-(v-d.speed)*3
   if yy>88 and yy<204 then digits(107,yy-5,v,11);line(135,yy,142,yy,p.muted) end end
  if d.alt then local v=math.floor(d.alt/10)*10+offset;local yy=149-(v-d.alt)*3
   if yy>88 and yy<204 then digits(344,yy-5,v,11);line(338,yy,344,yy,p.muted) end end
 end
 rect(99,137,49,24,p.black);rect(332,137,49,24,p.black)
 line(99,137,145,137,p.green);line(335,137,381,137,p.green)
 digits(111,140,d.speed and round(d.speed) or '--',16);digits(344,140,d.alt and round(d.alt) or '--',16)
 if not attitude then
  rect(174,126,132,34,p.black);smallText(185,131,'ATTITUDE',p.muted);smallText(185,147,'UNAVAILABLE',p.muted)
 end
 local pos=navRead('GPS','gps');local dist=pos and navHome and geo(navHome,pos) or nil
 digits(132,227,dist and round(dist) or '---',11)
 digits(222,227,d.hdg and string.format('%03d',round(d.hdg)%360) or '---',11)
 digits(326,227,d.a and string.format('%.1f',d.a) or '--',11)
end
local traces,lastTrace={},-100
local flightSeconds,flightWasArmed,lastStatus=0,false,nil
local function statusUpdate(d)
 local now=getTime();local arm=configuration.indicator('arm')=='ACTIVE'
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
local function powerScreen(d)
 local p=palette;frame('POWER MONITOR',d)
 panel(8,43,175,191,'FLIGHT BATTERY')
 label(19,67,numberText(d.v,'%.2f'),p.white,DBLSIZE);label(149,98,'V',p.muted)
 label(19,123,'CELL AVG',p.muted);label(172,123,numberText(d.cells and d.v and d.v/d.cells,'%.2f',' V'),p.cyan,SMLSIZE,true)
 label(19,145,'CURRENT',p.muted);label(172,145,numberText(d.a,'%.1f',' A'),p.white,SMLSIZE,true)
 label(19,167,'USED',p.muted);label(172,167,numberText(d.mah,'%.0f',' mAh'),p.white,SMLSIZE,true)
 label(19,189,d.estimated and 'EST. LEFT' or 'LEFT',p.muted);label(172,189,numberText(d.pct,'%.0f',' %'),p.green,SMLSIZE,true)
 label(19,215,d.cells and d.cells..(d.demo and 'S / DEMO' or 'S / CONFIGURED') or 'SET CELL COUNT IN CONFIG',p.orange)
 panel(191,43,281,90,'VOLTAGE / '..#traces..' SAMPLES');panel(191,144,281,90,'CURRENT / '..#traces..' SAMPLES')
 local maximum=d.cells and d.cells*4.6 or 60
 trace(201,70,260,52,'v',0,maximum,p.cyan);trace(201,171,260,52,'a',0,100,p.orange)
end
local function linkScreen(d)
 local p=palette;frame('RC LINK',d)
 panel(8,43,146,91,'LINK QUALITY');panel(167,43,146,91,'SIGNAL STRENGTH');panel(326,43,146,91,'SIGNAL / NOISE')
 label(20,72,numberText(d.lq,'%.0f',' %'),p.green,DBLSIZE);label(179,72,numberText(d.rssi),p.white,DBLSIZE);label(277,112,'dBm',p.muted)
 label(338,72,numberText(d.snr),p.cyan,DBLSIZE);label(442,112,'dB',p.muted)
 panel(8,143,305,91,'LQ HISTORY / '..#traces..' SAMPLES');trace(18,171,285,52,'lq',0,100,p.green)
 panel(326,143,146,91,'RF STATUS');label(336,167,numberText(d.power,'%.0f',' mW'),p.white,MIDSIZE)
 label(336,191,'RFMD '..numberText(d.rf),p.muted);label(336,212,'DOWN '..numberText(d.down,'%.0f',' %'),p.cyan)
end
local function statusScreen(d)
 local p=palette;frame('FLIGHT STATUS',d)
 panel(8,43,226,92,'ARM INDICATOR');label(20,75,configuration.indicator('arm'),p.green,MIDSIZE)
 panel(246,43,226,92,'THROTTLE CUT');label(258,75,configuration.indicator('cut'),p.orange,MIDSIZE)
 panel(8,147,226,87,'REPORTED FLIGHT MODE');label(20,177,d.flight or '--',p.white,DBLSIZE)
 panel(246,147,226,87,'ARMED TIME / THIS SESSION');label(258,175,string.format('%02d:%02d',math.floor(flightSeconds/60),math.floor(flightSeconds%60)),p.cyan,DBLSIZE)
 label(256,216,'FROM CONFIGURED ARM SWITCH',p.muted)
end
local function vtxScreen(d)
 local p=palette;frame('VIDEO / VTX',d)
 panel(8,43,210,191,'CONTROL CONNECTION');label(20,73,'NOT CONNECTED',p.orange,MIDSIZE)
 label(20,111,'VTX transport not implemented.',p.muted);label(20,134,'These are saved reference',p.muted);label(20,151,'frequencies, not live channels.',p.muted)
 label(20,206,'CONFIG > VTX FAVOURITES',p.cyan)
 panel(230,43,242,191,'SAVED FREQUENCIES')
 for i=1,5 do label(243,76+(i-1)*29,'CHANNEL '..i,p.muted);label(460,76+(i-1)*29,configuration.get('vtx'..i)..' MHz',p.white,SMLSIZE,true)end
end
local function diagnostics(d)
 local p=palette;frame('DIAGNOSTICS',d)
 panel(8,43,464,191,'RUNTIME / CAPABILITIES')
 local rows={{'EdgeTX',tostring(getVersion())},{'Model',model.getInfo().name or '--'},{'Source mode',d.demo and 'DEMONSTRATION' or 'LIVE TELEMETRY'},{'GPS / sensor transport','EdgeTX current-value API'},{'MSP / FC diagnostics','NOT IMPLEMENTED'},{'VTX / FC writes','NOT IMPLEMENTED'},{'Background',renderStats.background},{'Draw / attitude changes',string.format('%.1f fps / %.1f Hz',renderStats.fps,renderStats.attitudeHz)}}
 for i,r in ipairs(rows)do label(20,70+(i-1)*20,r[1],p.muted);label(461,70+(i-1)*20,r[2],p.white,SMLSIZE,true)end
end

local accents={{164,227,125},{104,221,237},{255,174,98}}
local appliedAccent
local function selectPage(id)menuOpen=false;changePage(id);if id==4 then scanSensors()end end
local function run(event,touch)
 if not started then init() end
 if not palette then
  palette={}
  local colors={red={250,91,64},green={164,227,125},cyan={104,221,237},orange={255,174,98},white={232,242,245},muted={140,164,179},dim={42,64,79},border={57,84,100},sky={32,112,166},ground={117,88,49},horizon={157,208,221},ladder={128,173,191},black={5,12,19},tape={15,31,43},route={56,82,92}}
  for k,v in pairs(colors)do palette[k]=lcd.RGB(v[1],v[2],v[3])end
 end
 local accent=configuration.get('accent');if appliedAccent~=accent then local c=accents[accent];palette.green=lcd.RGB(c[1],c[2],c[3]);appliedAccent=accent end
 local footer=event==EVT_TOUCH_TAP and touch and touch.y>=248
 if event==EVT_VIRTUAL_EXIT then if menuOpen then menuOpen=false;lastFrame=-100 else return 1 end
 elseif footer then
  if touch.x<90 then menuOpen=not menuOpen;lastFrame=-100
  elseif touch.x<330 then telemetry.toggle();lastFrame=-100
  elseif touch.x<405 then selectPage(adjacent(-1)) else selectPage(adjacent(1))end
 elseif menuOpen then
  if event==EVT_VIRTUAL_NEXT or event==EVT_VIRTUAL_NEXT_PAGE then menuIndex=menuIndex%#destinations+1
  elseif event==EVT_VIRTUAL_PREV or event==EVT_VIRTUAL_PREV_PAGE then menuIndex=(menuIndex+#destinations-2)%#destinations+1
  elseif event==EVT_VIRTUAL_ENTER then selectPage(destinations[menuIndex][1])
  elseif event==EVT_TOUCH_TAP and touch and touch.x>=8 and touch.x<472 and touch.y>=42 and touch.y<238 then
   local col=math.floor((touch.x-8)/157);local row=math.floor((touch.y-42)/49);local n=row*3+col+1
   if n>=1 and n<=#destinations then menuIndex=n;selectPage(destinations[n][1])end
  end
  lastFrame=-100
 elseif event==EVT_VIRTUAL_NEXT_PAGE then selectPage(adjacent(1))
 elseif event==EVT_VIRTUAL_PREV_PAGE then selectPage(adjacent(-1))
 elseif page==8 then configuration.input(event,touch);if event~=0 then lastFrame=-100 end
 elseif event==EVT_VIRTUAL_ENTER then
  if page==6 then stickMode=stickMode%4+1 elseif page==4 then scanSensors() else telemetry.toggle()end;lastFrame=-100
 elseif event==EVT_TOUCH_TAP and touch then
  local x,y=touch.x,touch.y
  if page==6 and y<36 and x>=362 then stickMode=stickMode%4+1
  elseif page==6 and y>=221 then commandPage=3-commandPage
  elseif page==7 and y>=222 then if x<145 then navAction('mode') elseif x<302 then navAction('home')else selectPage(2)end
  elseif page==2 and y>=222 then if x<113 then navAction('mode') elseif x<211 then navAction('zoom') elseif x<330 then navAction('home')end
  elseif page==4 and y>=220 then sensorOffset=sensorOffset+5;scanSensors()
  elseif (page==1 or page==3 or page==5 or page>=9) and y<36 and x>=330 then telemetry.toggle();navReset()end
  lastFrame=-100
 end
 local pitch,roll=telemetry.pollAttitude()
 if pitch~=nil and roll~=nil and (pitch~=renderStats.pitch or roll~=renderStats.roll) then renderStats.changes=renderStats.changes+1 end
 renderStats.pitch=pitch;renderStats.roll=roll
 local now=getTime();if now-lastFrame<math.ceil(100/configuration.get('renderHz')) and now>=lastFrame then return 0 end;lastFrame=now
 local d=telemetry.sample()
 if traces.mode~=d.mode then traces={mode=d.mode};lastTrace=-100 end
 statusUpdate(d)
 if not backgroundReady and page~=5 then changePage(page)end
 if menuOpen then launcher(d)
 else
  if page==5 then telemetry.run(0) else drawBackground(background,backgroundScale)end
  if page==1 then cockpit(d) elseif page==2 then navigation(d) elseif page==3 then powerScreen(d) elseif page==4 then systemPage() elseif page==6 then stickCommands() elseif page==7 then gpsDetails() elseif page==8 then configuration.draw() elseif page==9 then linkScreen(d) elseif page==10 then statusScreen(d) elseif page==11 then vtxScreen(d) elseif page==12 then diagnostics(d)end
 end
 rect(0,246,480,26,palette.black);rect(0,246,480,1,palette.border)
 icon(8,9,247,palette.green);label(38,254,menuOpen and 'CLOSE' or 'MENU',palette.white)
 label(107,254,d.demo and (d.mode==3 and 'DEMO: LOW PACK' or d.mode==4 and 'DEMO: LINK LOSS' or 'DEMO: NORMAL') or 'LIVE TELEMETRY',d.demo and palette.orange or palette.green)
 label(346,254,'< PREV',palette.muted);label(421,254,'NEXT >',palette.muted)
 renderStats.frames=renderStats.frames+1;renderStats.cost=renderStats.cost+(getTime()-now)*10
 if now-renderStats.window>=200 then
  local seconds=(now-renderStats.window)/100
  renderStats.fps=renderStats.frames/seconds;renderStats.attitudeHz=renderStats.changes/seconds;renderStats.drawMs=renderStats.cost/renderStats.frames
  renderStats.frames=0;renderStats.changes=0;renderStats.cost=0;renderStats.window=now
  -- Metrics stay in memory. Never write to the SD card from the refresh loop.

 end
 return 0
end
return {init=init,run=run}
