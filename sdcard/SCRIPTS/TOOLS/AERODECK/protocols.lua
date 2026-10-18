-- Native telemetry conventions, independently implemented from Toolbox2's
-- original package. No sensor reads, freshness fallback, I/O or FC writes.
-- Evidence: development/assessments/2026-10-17-deep-parity/data-evidence/
-- LIB-TLM-{TBS,FRS}-{RL,BTV,BTA,GYRO*,GPS*,FC*}.txt and LIB-TLM-TLMRLD.txt.
-- Call profile() only when settings change; pass only current values to normalize.
local M={}
local function finite(v)return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function integer(v,max)return finite(v) and v>=0 and v%1==0.0 and v<=max end
local function bit(v,b)return math.floor(v/2^b)%2==1 end
local function key(v)return type(v)=='string' and string.lower(v) or '' end
local subtypeKeys={el2='EL2',['elrs 2.x']='EL2',['elrs 2']='EL2',el3='EL3',['elrs 3.x']='EL3',['elrs 3']='EL3',elg='ELG',['elrs gemini']='ELG',gemini='ELG',xf='XF',crossfire='XF',['tbs crossfire']='XF',trs='TRS',tracer='TRS',['tbs tracer']='TRS',accst='ACCST',['frsky accst']='ACCST',r9='R9',['frsky r9']='R9'}
local fieldKeys={voltage='v',current='a',consumed='mah',percent='pct',txPower='tx',rfMode='rf',groundSpeed='speed',gpsAltitude='alt',baroAltitude='baro',verticalSpeed='vspeed',airSpeed='aspd',receiverVoltage='rxV',flightMode='flight'}
local units={V='V',VOLT='V',VOLTS='V',A='A',AMPERE='A',AMPS='A',MA='mA',MILLIAMPERE='mA',MAH='mAh',MILLIAMPERE_HOUR='mAh',AH='Ah',AMPERE_HOUR='Ah',MW='mW',MILLIWATT='mW',W='W',WATT='W',['%']='%',PERCENT='%',DBM='dBm',DB='dB',DEGREE='deg',DEGREES='deg',DEG='deg',RADIAN='rad',RADIANS='rad',RAD='rad',KILOMETER_PER_HOUR='km/h',KMH='km/h',['KM/H']='km/h',MILE_PER_HOUR='mph',MPH='mph',KNOT='kt',KNOTS='kt',KTS='kt',KT='kt',METER_PER_SECOND='m/s',METERS_PER_SECOND='m/s',['M/S']='m/s',FOOT_PER_SECOND='ft/s',FEET_PER_SECOND='ft/s',['FT/S']='ft/s',METER='m',METERS='m',M='m',FOOT='ft',FEET='ft',FT='ft',NONE='NUMBER',NUMBER='NUMBER',GPS='GPS',TEXT='TEXT',STRING='TEXT',ENCODED='ENCODED',G='g'}
local function unitName(value,p)
 if type(value)=='number' then value=p.unitNames and p.unitNames[value] end
 if type(value)~='string' then return nil end
 return units[string.upper(value)]
end
local function descriptor(p,name,aliases,unit,convention,min,max,capability)
 local d={aliases=aliases,unit=unit,inputUnit=unit,convention=convention or 'REPORTED',min=min,max=max,capability=capability or 'REPORTED',provenance=p.id..' / '..table.concat(aliases,'|')}
 p.fields[name]=d;p.aliases[name]=aliases;p.capabilities[name]=d.capability
 return d
end
function M.profile(rcProtocol,subtype,fcType)
 local rc,st=key(rcProtocol),key(subtype)
 local family,default='UNKNOWN',nil
 if rc=='elrs / crsf' or rc=='elrs' or rc=='crsf' then family='CRSF';default='EL3'
 elseif rc=='tbs crossfire' or rc=='crossfire' then family='CRSF';default='XF'
 elseif rc=='tbs tracer' or rc=='tracer' then family='CRSF';default='TRS'
 elseif rc=='frsky' or rc=='frsky accst' then family='FRSKY';default='ACCST'
 elseif rc=='frsky r9' or rc=='r9' then family='FRSKY';default='R9' end
 local selected=(st=='' or st=='auto') and default or subtypeKeys[st]
 local valid=family=='CRSF' and (selected=='EL2' or selected=='EL3' or selected=='ELG' or selected=='XF' or selected=='TRS')
  or family=='FRSKY' and (selected=='ACCST' or selected=='R9')
 local fc=key(fcType);fc=(fc=='betaflight' or fc=='bf') and 'BF' or (fc=='inav' or fc=='in') and 'INAV' or 'UNKNOWN'
 local p={family=family,subtype=selected or 'UNKNOWN',fcType=fc,supported=valid==true,fcSupported=fc~='UNKNOWN',fields={},aliases={},capabilities={fix='UNSUPPORTED',hdop='UNSUPPORTED',homeFix='UNSUPPORTED'},thresholds={},rfCaptions={},unitNames={},assumptions={}}
 p.id=p.family..' / '..p.subtype..' / '..p.fcType
 if not valid then p.error=family=='UNKNOWN' and 'UNKNOWN PROTOCOL' or 'UNKNOWN SUBTYPE';return p end
 if st=='' or st=='auto' then p.assumptions[1]='SUBTYPE DEFAULT '..selected end
 local frsky=family=='FRSKY'
 p.rssiUnit=frsky and '%' or 'dBm';p.mspTransport=frsky and 'SPORT' or 'CRSF'
 p.thresholds.rssiLow=frsky and 40 or -94;p.thresholds.rssiCrit=frsky and 30 or -102
 if not frsky then
  p.thresholds.lqLow=(selected=='XF' or selected=='TRS') and 80 or 20
  p.thresholds.lqCrit=(selected=='XF' or selected=='TRS') and 70 or 10
 end
 p.thresholds.txLqLow=30;p.thresholds.txLqCrit=10
 descriptor(p,'v',{frsky and 'VFAS' or 'RxBt'},'V',nil,0,120)
 descriptor(p,'a',{'Curr'},'A',nil,0,400)
 descriptor(p,'mah',{frsky and 'Fuel' or 'Capa'},'mAh',nil,0,200000)
 if frsky then
  descriptor(p,'rxV',{'RxBt'},'V',nil,0,20)
  for i=1,3 do descriptor(p,'a'..i,{'A'..i},'V',nil,0,30)end
  descriptor(p,'a4',{'A4'},'V','DIRECT CELL SENSOR',0,6)
  descriptor(p,'rssi',{'RSSI'},'%',nil,0,100)
  if selected=='R9' then descriptor(p,'tx',{'R9PW'},'mW',nil,0,5000)end
 else
  descriptor(p,'pct',{'Bat%'},'%',nil,0,100)
  descriptor(p,'lq',{'RQly'},'%',nil,0,100)
  descriptor(p,'rssi',{'1RSS'},'dBm',nil,-130,0)
  descriptor(p,'rssi2',{'2RSS'},'dBm',nil,-130,0)
  descriptor(p,'snr',{'RSNR'},'dB',nil,-50,50)
  descriptor(p,'txrssi',{'TRSS'},'dBm',nil,-130,0)
  descriptor(p,'txsnr',{'TSNR'},'dB',nil,-50,50)
  descriptor(p,'tx',{'TPWR'},'mW',nil,0,5000)
  descriptor(p,'rf',{'RFMD'},'NUMBER',nil,0,255).integer=true
  if selected=='XF' then p.rfCaptions={[0]='4','50','150'}
  elseif selected=='TRS' then p.rfCaptions={[0]='-','250'}
  elseif selected=='EL2' then p.rfCaptions={[0]='-','25','50','100','150','200','250','500'}
  elseif selected=='EL3' then p.rfCaptions={[0]='-','25','50','100','100F','150','200','250','333F','500','D250','D500','F500','F1k'}
  else p.rfCaptionError='NO VERIFIED GEMINI RF ENUM' end
 end
 descriptor(p,'txlq',{'TQly'},'%',nil,0,100)
 descriptor(p,'gps',{'GPS'},'GPS','COORDINATES')
 descriptor(p,'speed',{'GSpd'},'km/h',nil,0,999)
 descriptor(p,'alt',{'GAlt'},'m',nil,-9999,20000)
 descriptor(p,'baro',{'Alt'},'m',nil,-9999,20000)
 descriptor(p,'vspeed',{'VSpd'},'m/s',nil,-200,200)
 descriptor(p,'aspd',{'ASpd'},'km/h','AIR SPEED',0,1850).inputUnit='kt'
 descriptor(p,'hdg',{'Hdg'},'deg',nil,0,360)
 if not frsky then
  descriptor(p,'course',{'Hdg'},'deg','GPS GROUND COURSE',0,360)
  descriptor(p,'pitch',{'Ptch'},'deg','CRSF ANGLE',-180,180).requiresUnit=true
  descriptor(p,'roll',{'Roll'},'deg','CRSF ANGLE',-180,180).requiresUnit=true
  descriptor(p,'yaw',{'Yaw'},'deg','CRSF ANGLE',-180,360).requiresUnit=true
  descriptor(p,'sats',{'Sats'},'NUMBER',nil,0,255).integer=true
  if p.fcSupported then descriptor(p,'flight',{'FM'},'TEXT','CRSF FM')end
  p.capabilities.fix='UNSUPPORTED';p.capabilities.hdop='UNSUPPORTED';p.capabilities.homeFix='UNSUPPORTED'
 elseif p.fcSupported then
  local inav=fc=='INAV'
  descriptor(p,'pitch',{inav and '0430' or '5230'},'deg',inav and 'FRSKY INAV ANGLE' or 'FRSKY BF ANGLE',-180,180)
  descriptor(p,'roll',{inav and '0440' or '5240'},'deg',inav and 'FRSKY INAV ANGLE' or 'FRSKY BF ANGLE',-180,180)
  p.fields.pitch.inputUnit='NUMBER';p.fields.roll.inputUnit='NUMBER'
  descriptor(p,'yaw',{'Hdg'},'deg',nil,0,360)
  descriptor(p,'gpsStatus',{inav and '0480' or 'Tmp2'},'ENCODED','FRSKY GPS STATUS',0,9999,'ENCODED')
  descriptor(p,'flight',{inav and '0470' or 'Tmp1'},'ENCODED','FRSKY FC STATUS',0,inav and 9999999 or 99999,'ENCODED')
  descriptor(p,'homeDistance',{'0420'},'m','FC REPORTED',0,100000)
  if inav then
   descriptor(p,'course',{'0450'},'deg','FC REPORTED',0,360)
   descriptor(p,'homeBearing',{'0460'},'deg','FC REPORTED',0,360)
  end
  p.capabilities.fix='ENCODED';p.capabilities.hdop='UNSUPPORTED PHYSICAL HDOP'
  p.capabilities.qualityIndex='ENCODED';p.capabilities.homeFix=inav and 'ENCODED' or 'UNSUPPORTED'
 end
 -- Module existence is not proof of a reachable normal configuration/producer.
 p.capabilities.acceleration='CONDITIONAL / REFERENCE DISABLED'
 p.capabilities.individualCells='UNVERIFIED PRODUCER'
 return p
end
function M.info(field,p)
 field=fieldKeys[field] or field
 local d=p and p.fields and p.fields[field]
 if d then return d end
 return nil,'UNSUPPORTED FIELD'
end
function M.normalize(field,raw,unit,p)
 field=fieldKeys[field] or field
 local d=p and p.fields and p.fields[field]
 if not d then return nil,'UNSUPPORTED FIELD' end
 local provenance=d.provenance
 if raw==nil then return nil,'MISSING',provenance end
 if d.unit=='GPS' then
  if type(raw)~='table' or not finite(raw.lat) or not finite(raw.lon) or math.abs(raw.lat)>90 or math.abs(raw.lon)>180 then return nil,'INVALID',provenance end
  return raw,nil,provenance -- Caller owns raw; the session factory copies coordinates.
 elseif d.unit=='TEXT' then
  if type(raw)~='string' or raw=='' or #raw>32 or string.find(raw,'[%c]') then return nil,'INVALID',provenance end
  return raw,nil,provenance
 end
 if not finite(raw) then return nil,'INVALID',provenance end
 local u=unitName(unit,p)
 if unit~=nil and not u then return nil,'UNKNOWN UNIT',provenance end
 if not u then
  if d.requiresUnit then return nil,'UNKNOWN UNIT',provenance end
  u=d.inputUnit
 end
 local value=raw
 if d.convention=='FRSKY INAV ANGLE' then
  if u~='deg' and u~='NUMBER' then return nil,'UNIT MISMATCH',provenance end
  value=raw/10*(field=='pitch' and -1 or 1)
 elseif d.convention=='FRSKY BF ANGLE' then
  if u~='deg' and u~='NUMBER' then return nil,'UNIT MISMATCH',provenance end
  value=raw/(u=='deg' and 1 or 10)*(field=='pitch' and -1 or 1)
 elseif d.convention=='CRSF ANGLE' then
  if u=='rad' then value=raw*180/math.pi*(field=='pitch' and -1 or 1)
  elseif u~='deg' then return nil,'UNIT MISMATCH',provenance end
 elseif d.unit=='km/h' then
  if u=='kt' then value=raw*1.852 elseif u=='mph' then value=raw*1.609344 elseif u=='m/s' then value=raw*3.6 elseif u=='ft/s' then value=raw*1.09728 elseif u~='km/h' then return nil,'UNIT MISMATCH',provenance end
 elseif d.unit=='m' then
  if u=='ft' then value=raw*0.3048 elseif u~='m' then return nil,'UNIT MISMATCH',provenance end
 elseif d.unit=='m/s' then
  if u=='ft/s' then value=raw*0.3048 elseif u~='m/s' then return nil,'UNIT MISMATCH',provenance end
 elseif d.unit=='A' then
  if u=='mA' then value=raw/1000 elseif u~='A' then return nil,'UNIT MISMATCH',provenance end
 elseif d.unit=='mAh' then
  if u=='Ah' then value=raw*1000 elseif u~='mAh' then return nil,'UNIT MISMATCH',provenance end
 elseif d.unit=='mW' then
  if u=='W' then value=raw*1000 elseif u~='mW' then return nil,'UNIT MISMATCH',provenance end
 elseif d.unit=='deg' then
  if u=='rad' then value=raw*180/math.pi elseif u~='deg' then return nil,'UNIT MISMATCH',provenance end
 elseif d.unit=='ENCODED' then
  if (u~='ENCODED' and u~='NUMBER') or raw%1~=0.0 then return nil,'UNIT MISMATCH',provenance end
 elseif u~=d.unit then return nil,'UNIT MISMATCH',provenance end
 if not finite(value) or d.min and value<d.min or d.max and value>d.max or d.integer and value%1~=0.0 then return nil,'OUT OF RANGE',provenance end
 value=value+0.0
 return value,nil,provenance
end
-- Compile only when profile, binding or its unit changes. The returned reader
-- owns this descriptor snapshot; changing p later requires a new reader.
-- Keep normalize() above as the independent, branch-based public oracle.
function M.reader(field,unit,p)
 field=fieldKeys[field]or field
 local d=p and p.fields and p.fields[field]
 if not d then return function()return nil,'UNSUPPORTED FIELD'end end
 local provenance=d.provenance
 if d.unit=='GPS'then
  return function(raw)
   if raw==nil then return nil,'MISSING',provenance end
   if type(raw)~='table'or not finite(raw.lat)or not finite(raw.lon)or math.abs(raw.lat)>90 or math.abs(raw.lon)>180 then return nil,'INVALID',provenance end
   return raw,nil,provenance
  end
 elseif d.unit=='TEXT'then
  return function(raw)
   if raw==nil then return nil,'MISSING',provenance end
   if type(raw)~='string'or raw==''or #raw>32 or string.find(raw,'[%c]')then return nil,'INVALID',provenance end
   return raw,nil,provenance
  end
 end
 local u=unitName(unit,p)
 local errorText,convert,encoded
 if unit~=nil and not u then errorText='UNKNOWN UNIT'
 elseif not u then
  if d.requiresUnit then errorText='UNKNOWN UNIT'else u=d.inputUnit end
 end
 if not errorText then
  local convention,target=d.convention,d.unit
  if convention=='FRSKY INAV ANGLE'then
   if u~='deg'and u~='NUMBER'then errorText='UNIT MISMATCH'
   else local sign=field=='pitch'and -1 or 1;convert=function(raw)return raw/10*sign end end
  elseif convention=='FRSKY BF ANGLE'then
   if u~='deg'and u~='NUMBER'then errorText='UNIT MISMATCH'
   else local divisor=u=='deg'and 1 or 10;local sign=field=='pitch'and -1 or 1;convert=function(raw)return raw/divisor*sign end end
  elseif convention=='CRSF ANGLE'then
   if u=='rad'then local pi=math.pi;local sign=field=='pitch'and -1 or 1;convert=function(raw)return raw*180/pi*sign end
   elseif u~='deg'then errorText='UNIT MISMATCH'end
  elseif target=='km/h'then
   local factor=({kt=1.852,mph=1.609344,['m/s']=3.6,['ft/s']=1.09728})[u]
   if factor then convert=function(raw)return raw*factor end elseif u~='km/h'then errorText='UNIT MISMATCH'end
  elseif target=='m'or target=='m/s'then
   if u==(target=='m'and'ft'or'ft/s')then convert=function(raw)return raw*.3048 end
   elseif u~=target then errorText='UNIT MISMATCH'end
  elseif target=='A'then
   if u=='mA'then convert=function(raw)return raw/1000 end elseif u~='A'then errorText='UNIT MISMATCH'end
  elseif target=='mAh'then
   if u=='Ah'then convert=function(raw)return raw*1000 end elseif u~='mAh'then errorText='UNIT MISMATCH'end
  elseif target=='mW'then
   if u=='W'then convert=function(raw)return raw*1000 end elseif u~='mW'then errorText='UNIT MISMATCH'end
  elseif target=='deg'then
   if u=='rad'then local pi=math.pi;convert=function(raw)return raw*180/pi end elseif u~='deg'then errorText='UNIT MISMATCH'end
  elseif target=='ENCODED'then
   if u~='ENCODED'and u~='NUMBER'then errorText='UNIT MISMATCH'else encoded=true end
  elseif u~=target then errorText='UNIT MISMATCH'end
 end
 local highInfinity,lowInfinity=math.huge,-math.huge
 local low,high,whole=d.min,d.max,d.integer
 if errorText then
  return function(raw)
   if raw==nil then return nil,'MISSING',provenance end
   if type(raw)~='number'or raw~=raw or raw==highInfinity or raw==lowInfinity then return nil,'INVALID',provenance end
   return nil,errorText,provenance
  end
 elseif convert then
  return function(raw)
   if raw==nil then return nil,'MISSING',provenance end
   if type(raw)~='number'or raw~=raw or raw==highInfinity or raw==lowInfinity then return nil,'INVALID',provenance end
   local value=convert(raw)
   if value~=value or value==highInfinity or value==lowInfinity or low and value<low or high and value>high or whole and value%1~=0.0 then return nil,'OUT OF RANGE',provenance end
   return value+0.0,nil,provenance
  end
 elseif encoded then
  return function(raw)
   if raw==nil then return nil,'MISSING',provenance end
   if type(raw)~='number'or raw~=raw or raw==highInfinity or raw==lowInfinity then return nil,'INVALID',provenance end
   if raw%1~=0.0 then return nil,'UNIT MISMATCH',provenance end
   if low and raw<low or high and raw>high or whole and raw%1~=0.0 then return nil,'OUT OF RANGE',provenance end
   return raw+0.0,nil,provenance
  end
 end
 return function(raw)
  if raw==nil then return nil,'MISSING',provenance end
  if type(raw)~='number'or raw~=raw or raw==highInfinity or raw==lowInfinity then return nil,'INVALID',provenance end
  if low and raw<low or high and raw>high or whole and raw%1~=0.0 then return nil,'OUT OF RANGE',provenance end
  return raw+0.0,nil,provenance
 end
end

function M.decodeGPS(raw,p)
 if not p or p.family~='FRSKY' or not p.fields.gpsStatus then return nil,'UNSUPPORTED GPS STATUS' end
 if raw==nil then return nil,'MISSING' end
 if not integer(raw,9999) then return nil,'INVALID GPS STATUS' end
 -- Original GPS_BF/GPS_IN main/0: A=status bits, B=quality digit, CD=sats.
 local a=math.floor(raw/1000);local b=math.floor(raw/100)%10
 local result={fix=bit(a,0),sats=raw%100,qualityIndex=b,qualityKind='REPORTED ENCODED INDEX',source=p.fields.gpsStatus.aliases[1],provenance=p.fields.gpsStatus.provenance}
 if p.fcType=='INAV' then result.homeFix=bit(a,1)end
 return result
end
function M.decodeFC(raw,p)
 if not p or not p.fcSupported or not p.fields.flight then return nil,'UNSUPPORTED FC STATUS' end
 if raw==nil then return nil,'MISSING' end
 local result={source=p.fields.flight.aliases[1],provenance=p.fields.flight.provenance}
 if p.family=='CRSF' then
  if type(raw)~='string' or raw=='' or #raw>32 or string.find(raw,'[%c]') then return nil,'INVALID FC STATUS' end
  result.mode=string.gsub(raw,'[!?*]','');result.armBlocked=string.find(raw,'!',1,true)~=nil
  if result.mode=='' then return nil,'INVALID FC STATUS' end
  if p.fcType=='INAV' then result.armed=raw~='OK' and raw~='WAIT' and raw~='0' and not result.armBlocked
  else result.armed=string.find(raw,'[!?*]')==nil end
 else
  local max=p.fcType=='INAV' and 9999999 or 99999
  if not integer(raw,max) then return nil,'INVALID FC STATUS' end
  local ones=raw%10
  result.armed=bit(ones,2);result.armBlocked=bit(ones,1)
  if p.fcType=='BF' then
   local tens=math.floor(raw/10)%10
   result.mode=result.armBlocked and 'ERR' or tens==4 and 'PASS' or tens==2 and 'HOR' or tens==1 and 'ANGL' or 'ACRO'
  else
   local a=math.floor(raw/1000000)%10;local b=math.floor(raw/100000)%10
   local c=math.floor(raw/10000)%10;local d=math.floor(raw/1000)%10
   local e=math.floor(raw/100)%10;local f=math.floor(raw/10)%10
   result.mode='OK'
   if result.armed then
    -- Original FC_IN main/0 PCs112–272 establishes this strict priority.
    result.mode=bit(c,2) and 'FS' or bit(f,2) and 'MANU' or bit(a,0) and 'WRTH' or bit(a,1) and 'ANGH'
     or bit(b,1) and 'TURT' or bit(b,0) and 'LAND' or bit(b,2) and 'GEO' or bit(b,3) and 'LOTR'
     or bit(d,0) and 'RTH' or bit(d,1) and 'WP' or bit(d,2) and 'HEAD' or bit(d,3) and 'CRSH'
     or bit(e,2) and 'HOLD' or bit(e,0) and bit(e,1) and 'CRUZ' or bit(e,1) and 'ALT'
     or bit(f,0) and 'ANGL' or bit(f,1) and 'HOR' or 'ACRO'
   elseif result.armBlocked then result.mode='ERR' end
  end
 end
 result.failsafe=result.mode=='FS';return result
end
function M.rfCaption(raw,p)
 if raw==nil then return nil,'MISSING' end
 if not integer(raw,255) then return nil,'INVALID RF MODE' end
 local caption=p and p.rfCaptions and p.rfCaptions[raw]
 if caption then return caption end
 return tostring(raw),'UNKNOWN RF MODE'
end
function M.bestRssi(first,second,p)
 local field=p and p.fields and p.fields.rssi
 if not field then return nil,'UNSUPPORTED FIELD' end
 local function valid(v)return finite(v) and v>=field.min and v<=field.max end
 if p.family=='CRSF' and valid(second) and second<0 then
  if valid(first) then return math.max(first,second) end
  return second
 end
 if valid(first) then return first end
 return nil,'MISSING OR INVALID'
end
return M
