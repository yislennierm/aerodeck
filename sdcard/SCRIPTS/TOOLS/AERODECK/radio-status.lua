-- Read-only transmitter battery state, sampled at most once per second.
-- EdgeTX v2.12.4 api_general.cpp: getGeneralSettings already returns VOLTS;
-- tx-voltage is native g_vbat100mV * 0.1, not a model telemetry sensor.
-- edgetx.h GET_TXBATT_BARS / IS_TXBATT_WARNING use the configured min/max
-- range and an inclusive <= warning. Percentage is a RANGE estimate, not SOC.
-- Visual health follows Toolbox's lower-third/lower-fifth range bands; the
-- native warning is separate and always escalates the indicator to critical.
local M={}
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function decivolts(v)
 if finite(v)and v>0 and v<=25.55 then local n=math.floor(v*10+0.5);if n>=1 and n<=255 then return n end end
end
function M.new(opts)
 opts=opts or{}
 local read=type(opts.getSourceValue)=='function'and opts.getSourceValue or nil
 local legacy=not read and type(opts.getValue)=='function'and opts.getValue or nil
 local settings=type(opts.getGeneralSettings)=='function'and opts.getGeneralSettings or nil
 local clock=type(opts.getTime)=='function'and opts.getTime or nil
 local s={state='UNAVAILABLE',voltageState='UNAVAILABLE',limitsState='UNAVAILABLE',
  percentOrigin='NATIVE RANGE',derived=true,source='tx-voltage',unit='V',
  sourceApi=read and'getSourceValue'or legacy and'getValue'or nil,revision=0}
 local last=nil
 local api={}
 local function clear()
  s.voltage=nil;s.rawVoltage=nil;s.percent=nil;s.warning=nil;s.health=nil
  s.battMin=nil;s.battMax=nil;s.battWarn=nil
  s.voltageError=nil;s.settingsError=nil;s.error=nil
 end
 function api.snapshot()return s end -- Borrowed stable read-only table.
 function api.reset()
  last=nil;clear();s.sampleAt=nil;s.state='UNAVAILABLE';s.voltageState='UNAVAILABLE';s.limitsState='UNAVAILABLE'
 end
 function api.sample(now)
  if now==nil and clock then local ok,value=pcall(clock);if ok then now=value end end
  if not finite(now)or now<0 then
   if s.error~='CLOCK UNAVAILABLE'then s.revision=s.revision+1 end
   last=nil;clear();s.sampleAt=nil;s.error='CLOCK UNAVAILABLE';s.state='UNAVAILABLE';s.voltageState='UNAVAILABLE';s.limitsState='UNAVAILABLE'
   return s
  end
  if last and now>=last and now-last<100 then return s end
  last=now;clear();s.sampleAt=now;s.revision=s.revision+1
  local minimum,maximum,threshold
  if not settings then s.limitsState='UNSUPPORTED';s.settingsError='GENERAL SETTINGS API UNAVAILABLE'
  else
   local ok,value=pcall(settings)
   if not ok then s.limitsState='UNAVAILABLE';s.settingsError='GENERAL SETTINGS READ FAILED'
   elseif type(value)~='table'then s.limitsState='UNSUPPORTED';s.settingsError='GENERAL SETTINGS UNAVAILABLE'
   else
    minimum=decivolts(value.battMin);maximum=decivolts(value.battMax);threshold=decivolts(value.battWarn)
    if minimum and maximum and maximum>minimum and threshold then
     s.battMin=minimum/10;s.battMax=maximum/10;s.battWarn=threshold/10;s.limitsState='CURRENT'
    else
     minimum=nil;maximum=nil;threshold=nil;s.limitsState='INVALID';s.settingsError='INVALID NATIVE BATTERY LIMITS'
    end
   end
  end
  local voltage
  if not read and not legacy then s.voltageState='UNSUPPORTED';s.voltageError='TX VOLTAGE API UNAVAILABLE'
  else
   local ok,raw,current=pcall(read or legacy,'tx-voltage')
   if not ok then s.voltageState='UNAVAILABLE';s.voltageError='TX VOLTAGE READ FAILED'
   elseif raw==nil then s.voltageState='UNAVAILABLE';s.voltageError='TX VOLTAGE UNAVAILABLE'
   elseif not decivolts(raw)then s.voltageState='INVALID';s.voltageError='INVALID TX VOLTAGE'
   elseif read and current~=true then
    s.voltageState=current==false and'STALE'or'UNSUPPORTED';s.voltageError='TX VOLTAGE NOT CURRENT'
   else voltage=decivolts(raw);s.voltage=voltage/10;s.rawVoltage=raw;s.voltageState='CURRENT'end
  end
  if voltage and minimum then
   local range,offset=maximum-minimum,voltage-minimum
   local percent=math.floor(100*offset/range+0.5)
   s.percent=math.max(0,math.min(100,percent));s.warning=voltage<=threshold
   s.health=(s.warning or offset*5<=range)and'CRITICAL'or offset*3<=range and'LOW'or'NORMAL'
  end
  s.state=s.voltageState=='CURRENT'and(s.limitsState=='CURRENT'and'CURRENT'or'PARTIAL')or s.voltageState
  s.error=s.voltageError or s.settingsError
  return s
 end
 return api
end
return M
