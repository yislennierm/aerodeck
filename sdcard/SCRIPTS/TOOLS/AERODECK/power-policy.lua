-- Battery policy; all input values must already be current, normalized telemetry.
-- No sensor/SD/transport/timer access. Chemistry is metadata, never an invented
-- voltage curve. Original evidence: BTCNO, TBS/BTA, CFGBFV/BFV, MAIN/ML, RD/SND
-- in development/assessments/2026-10-17-deep-parity/{data,config}-evidence.
local M={}
local defaults={noPower=2.7,min=3,critical=3.4,low=3.6,max=4.2}
local thresholdKeys={'noPower','min','critical','low','max'}
local function finite(v)return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function integer(v,a,b)return finite(v) and v%1==0.0 and v>=a and v<=b end
local function chemistry(v)
 if v==0.0 or v=='OFF' then return 'OFF' end
 if v==1.0 or v=='LIPO' or v=='LiPo' then return 'LIPO' end
 if v==2.0 or v=='LIION' or v=='LiIon' or v=='Li-Ion' then return 'LIION' end
 return 'UNKNOWN'
end
local function quantize(v)return math.floor(v*10000+0.5)end --0.1mV/cell, nativefloat32 boundary-safe.
local function thresholdValues(t)
 t=t or defaults
 for _,k in ipairs(thresholdKeys)do if not finite(t[k]) or t[k]<0 or t[k]>6 then return nil end end
 if not (t.noPower<t.min and t.min<t.critical and t.critical<t.low and t.low<t.max)then return nil end
 return t
end
function M.fromLegacy(values,extra)
 if type(values)~='table' or not integer(values[1],0,12) or not integer(values[7],0,3) or not integer(values[8],0,1)then return nil,'INVALID LEGACY SETTINGS'end
 for i=2,6 do if not finite(values[i])then return nil,'INVALID LEGACY SETTINGS'end end
 local cfg={};for k,v in pairs(extra or {})do cfg[k]=v end
 cfg.cells=values[1];cfg.thresholds={noPower=values[2]/10,min=values[3]/10,critical=values[4]/10,low=values[5]/10,max=values[6]/10}
 cfg.alertType=values[7];cfg.audible=values[8]+1
 if not thresholdValues(cfg.thresholds)then return nil,'INVALID LEGACY THRESHOLDS'end
 return cfg
end
function M.inferCells(volts,maxCell,noPower)
 if not finite(volts) or volts<0 then return nil,'MISSING OR INVALID VOLTAGE'end
 if not finite(maxCell) or maxCell<=0 or not finite(noPower) or noPower<0 then return nil,'INVALID THRESHOLDS'end
 if quantize(volts)<=quantize(noPower) then return nil,'NO POWER'end
 -- Original first matching1..6 interval, with no fabricated1S fallback.
 for c=1,6 do if quantize(volts/c)<=quantize(maxCell)then return c,'VOLTAGE ESTIMATE'end end
 return nil,'OUTSIDE AUTO RANGE'
end
function M.favourites(profiles)
 local list={}
 for i=1,5 do
  local p=type(profiles)=='table' and profiles[i]
  if type(p)=='table' and (chemistry(p.chemistry)=='LIPO' or chemistry(p.chemistry)=='LIION') and p.enabled~=false and integer(p.cells,1,99) and integer(p.capacity,100,100000)then
   list[#list+1]={id=i,chemistry=chemistry(p.chemistry),cells=p.cells,capacity=p.capacity}
  end
 end
 return list
end
function M.new(opts)
 opts=opts or {}
 local s={condition='NO DATA',muted=false,thresholds={},voltagePctOrigin='CELL VOLTAGE RANGE',cadence={criticalTicks=400,lowTicks=600,criticalSeconds=4,lowSeconds=6,
  provenance='Toolbox ML/SND repeat periods; first warning immediate',selectionAlsoGatesHaptic=true},alertSequence=0}
 local api={};local inferred,lastTick,lastKind,lastProfile,lastCells;local lastAlarm={}
 local lastModel,lastSource
 local criticalTones={{frequency=4000,durationMs=24,pauseMs=100,flags=0},{frequency=5000,durationMs=24,pauseMs=100,flags=0},{frequency=4000,durationMs=24,pauseMs=100,flags=0},{frequency=5000,durationMs=24,pauseMs=100,flags=0}}
 local lowTones={{frequency=4000,durationMs=24,pauseMs=200,flags=0},{frequency=4000,durationMs=24,pauseMs=200,flags=0}}
 -- EdgeTX2.12.4 haptic.play uses native arguments, despite its Lua docs saying
 -- milliseconds: stored length=(nativeDuration+2*hapticLength)*2, then both
 -- counters decrement each5ms. Preserve original10/150 calls exactly.
 local criticalHaptics={{nativeDuration=10,nativePause=150,heartbeatMs=5},{nativeDuration=10,nativePause=150,heartbeatMs=5}}
 local lowHaptics={{nativeDuration=10,nativePause=150,heartbeatMs=5,interrupt=true}}
 local function reset()
  inferred=nil;lastTick=nil;lastAlarm={};lastKind=nil;lastProfile=nil;lastCells=nil
  s.cells=nil;s.cellSource=nil;s.cellsEstimated=false;s.averageCell=nil;s.cell=nil;s.cellProvenance=nil
  s.v=nil;s.a=nil;s.mah=nil;s.reportedCell=nil;s.capacity=nil;s.remainingMah=nil;s.derivedPct=nil;s.reportedPct=nil;s.displayPct=nil;s.pctEstimated=false;s.voltagePct=nil
  s.condition='NO DATA';s.nextAlertAt=nil;s.alertDue=false;s.alert=nil;s.lastAlertAt=nil;s.error=nil
 end
 function api.reset()reset()end
 function api.snapshot()return s end -- Stable borrowed read-only view.
 function api.update(now,data,cfg)
  if not finite(now)then return s end
  data=data or {};cfg=cfg or {}
  if cfg.modelId~=nil and lastModel~=nil and cfg.modelId~=lastModel or cfg.sourceId~=nil and lastSource~=nil and cfg.sourceId~=lastSource then reset()end
  if cfg.modelId~=nil then lastModel=cfg.modelId end
  if cfg.sourceId~=nil then lastSource=cfg.sourceId end
  if lastTick and now<lastTick then lastAlarm={};lastKind=nil end
  lastTick=now;s.alertDue=false;s.nextAlertAt=nil;s.error=nil
  s.v=finite(data.v) and data.v>=0 and data.voltageCurrent~=false and data.telemetryCurrent~=false and data.v or nil
  s.a=finite(data.a) and data.a>=0 and data.currentCurrent~=false and data.telemetryCurrent~=false and data.a or nil
  s.mah=finite(data.mah) and data.mah>=0 and data.consumedCurrent~=false and data.telemetryCurrent~=false and data.mah or nil
  s.reportedPct=finite(data.reportedPct) and data.reportedPct>=0 and data.reportedPct<=100 and data.reportedPctCurrent~=false and data.telemetryCurrent~=false and data.reportedPct or nil
  s.reportedCell=finite(data.reportedCell) and data.reportedCell>=0 and data.reportedCell<=6 and data.reportedCellCurrent~=false and data.telemetryCurrent~=false and data.reportedCell or nil
  s.capacity=nil;s.remainingMah=nil;s.derivedPct=nil;s.displayPct=s.reportedPct;s.pctEstimated=false;s.voltagePct=nil
  s.cells=nil;s.cellSource=nil;s.cellsEstimated=false;s.averageCell=nil;s.cell=nil;s.cellProvenance=nil;s.chemistry='UNKNOWN'
  local profile=cfg.profile or 0;local cells=cfg.cells or 0
  s.profileId=profile
  if profile~=lastProfile or cells~=lastCells then inferred=nil;lastProfile=profile;lastCells=cells;lastAlarm={};lastKind=nil end
  local thresholds=thresholdValues(cfg.thresholds)
  local alertType,audible=cfg.alertType or 0,cfg.audible or 1
  if not thresholds or not integer(profile,0,5) or not integer(cells,0,12) or not integer(alertType,0,3) or not integer(audible,0,2)then s.condition='INVALID CONFIG';return s end
  for k,v in pairs(thresholds)do s.thresholds[k]=v end
  s.muted=cfg.muted==true or data.muted==true
  local selected=profile>0 and type(cfg.profiles)=='table' and cfg.profiles[profile]
  if profile>0 then
   if type(selected)~='table' then s.condition='INVALID PROFILE';return s end
   s.chemistry=chemistry(selected.chemistry)
   if s.chemistry=='UNKNOWN' then s.condition='INVALID PROFILE';return s end
   if s.chemistry=='OFF' or selected.enabled==false then s.condition='PROFILE OFF';return s end
   if not integer(selected.cells,1,99) or not integer(selected.capacity,100,100000)then s.condition='INVALID PROFILE';return s end
   s.cells=selected.cells;s.cellSource='FAVOURITE';s.capacity=selected.capacity
   if s.mah~=nil then
    s.remainingMah=math.max(0,s.capacity-s.mah);s.derivedPct=s.remainingMah/s.capacity*100 -- Retain precision; the view chooses rounding.
    s.displayPct=s.derivedPct;s.pctEstimated=true
   end
  elseif cells>0 then s.cells=cells;s.cellSource='MANUAL'
  else
   if s.v~=nil and quantize(s.v)<=quantize(thresholds.noPower) then inferred=nil end
   if not inferred and s.v~=nil then inferred=M.inferCells(s.v,thresholds.max,thresholds.noPower)end
   s.cells=inferred;s.cellSource=inferred and 'VOLTAGE ESTIMATE' or 'UNKNOWN';s.cellsEstimated=inferred~=nil
  end
  if s.cells and s.v~=nil then s.averageCell=s.v/s.cells end
  if s.reportedCell~=nil then s.cell=s.reportedCell;s.cellProvenance='REPORTED CELL'
  else s.cell=s.averageCell;s.cellProvenance=s.averageCell~=nil and (s.cellsEstimated and 'PACK / ESTIMATED CELLS' or 'PACK / CONFIGURED CELLS') or nil end
  -- A separate voltage-range indicator. This is neither remaining capacity nor
  -- chemical state of charge, and never replaces reported/capacity-derived %.
  if s.cell~=nil and quantize(s.cell)>quantize(thresholds.noPower)
   and(s.v==nil or quantize(s.v)>quantize(thresholds.noPower))then
   s.voltagePct=math.max(0,math.min(100,(s.cell-thresholds.min)/(thresholds.max-thresholds.min)*100))
  end
  if cfg.enabled==false then s.condition='DISABLED';return s end
  if s.v==nil and s.reportedCell==nil then s.condition='NO DATA';return s end
  if s.v~=nil and quantize(s.v)<=quantize(thresholds.noPower) then s.condition='NO POWER';return s end
  if s.cell==nil then s.condition='UNKNOWN CELLS';return s end
  local q=quantize(s.cell)
  if q<=quantize(thresholds.noPower)then s.condition='NO POWER'
  elseif q<quantize(thresholds.min)then s.condition='BELOW MIN'
  elseif q<=quantize(thresholds.critical)then s.condition='CRITICAL'
  elseif q<=quantize(thresholds.low)then s.condition='LOW'
  elseif q>quantize(thresholds.max)then s.condition='ABOVE MAX'
  else s.condition='OK' end
  local kind=(s.condition=='CRITICAL' or s.condition=='BELOW MIN') and 'CRITICAL' or s.condition=='LOW' and audible==2 and 'LOW' or nil
  if not kind or s.muted or alertType==0 or audible==0 then return s end
  local period=kind=='CRITICAL' and 400 or 600
  s.nextAlertAt=lastAlarm[kind] and lastAlarm[kind]+period or now
  if now<s.nextAlertAt then return s end
  lastAlarm[kind]=now;lastKind=kind;s.lastAlertAt=now;s.nextAlertAt=now+period;s.alertDue=true;s.alertSequence=s.alertSequence+1
  local sound=alertType==1 or alertType==3;local haptic=alertType==2 or alertType==3
  s.alert={sequence=s.alertSequence,kind=kind,tick=now,sound=sound,haptic=haptic,
   tones=sound and (kind=='CRITICAL' and criticalTones or lowTones) or nil,haptics=haptic and (kind=='CRITICAL' and criticalHaptics or lowHaptics) or nil,
   cell=s.cell,cells=s.cells,cellsEstimated=s.cellsEstimated,provenance=s.cellProvenance}
  if type(opts.onAlert)=='function' then local ok,err=pcall(opts.onAlert,s.alert);if not ok then s.error=tostring(err)end end
  return s
 end
 return api
end
return M
