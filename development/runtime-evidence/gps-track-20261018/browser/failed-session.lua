-- Page-independent local flight state. Inputs must already be current telemetry.
-- No native sensor reads, transport calls, output writes or filesystem access.
local M={}
local function finite(v)
 return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge
end
local function position(v)
 return type(v)=='table' and finite(v.lat) and finite(v.lon)
  and math.abs(v.lat)<=90 and math.abs(v.lon)<=180
end
local function bounded(v,default,low,high)
 if not finite(v) then return default end
 return math.max(low,math.min(high,math.floor(v)))
end
local function atan2(y,x)
 if x>0 then return math.atan(y/x)
 elseif x<0 then return math.atan(y/x)+(y>=0 and math.pi or -math.pi)
 elseif y>0 then return math.pi/2 elseif y<0 then return -math.pi/2 end
 return 0
end
local function geometry(a,b)
 local r=math.pi/180;local la,lb=a.lat*r,b.lat*r
 local dl,dp=(b.lon-a.lon)*r,lb-la
 local h=math.sin(dp/2)^2+math.cos(la)*math.cos(lb)*math.sin(dl/2)^2
 h=math.max(0,math.min(1,h))
 local distance=6371000*2*atan2(math.sqrt(h),math.sqrt(1-h))
 local heading=(atan2(math.sin(dl)*math.cos(lb),math.cos(la)*math.sin(lb)-math.sin(la)*math.cos(lb)*math.cos(dl))/r+360)%360
 return distance,distance>=1 and heading or nil
end
local function timerIndex(v)
 if finite(v) and v%1==0.0 and v>=1 and v<=3 then return v end
end
local function copyTable(value)
 if type(value)~='table' then return value end
 local result={}
 for key,v in pairs(value) do
  if type(v)~='table' and type(v)~='function' and type(v)~='userdata' and type(v)~='thread' then result[key]=v end
 end
 return result
end
function M.new(opts)
 opts=opts or {}
 local maximum=bounded(opts.maxHistory,180,1,180)
 local historyInterval=bounded(opts.historyInterval,100,100,6000)
 local s={track={},flightSeconds=0,muted=false,resetCount=0,clockEpoch=0}
 local api={}
 local now,lastUpdate,lastArmed,lastHistory,lastTimer,lastTimerIndex
 local geometryLat,geometryLon,geometryHome,cachedDistance,cachedBearing
 local currentSettings={}
 local function call(fn,...)
  if type(fn)~='function' then return true end
  local ok,result,err=pcall(fn,...)
  if not ok then s.lastError=tostring(result);return false,s.lastError end
  if result==false then s.lastError=tostring(err or 'CALLBACK REJECTED');return false,s.lastError end
  return true,result
 end
 local function point(pos,source)
  local result={lat=pos.lat+0.0,lon=pos.lon+0.0,tick=now,seconds=now and now/100 or nil,clockEpoch=s.clockEpoch,source=source}
  return result
 end
 local function stamp(p)
  if type(opts.getDateTime)=='function' then
   local ok,value=pcall(opts.getDateTime)
   if ok and type(value)=='table' then p.dateTime=copyTable(value) end
  end
  return p
 end
 local function clearNavigation(reason)
  s.current=nil;s.lastKnown=nil;s.home=nil;s.track={}
  s.speed=nil;s.alt=nil;s.sats=nil;s.hdg=nil;s.fix=nil
  s.homeDistance=nil;s.homeBearing=nil
  geometryLat=nil;geometryLon=nil;geometryHome=nil;cachedDistance=nil;cachedBearing=nil
  lastHistory=nil
  s.resetReason=reason;s.resetCount=s.resetCount+1
 end
 local function clear(reason)
  clearNavigation(reason)
  s.flightSeconds=0;s.armed=nil;s.modelTimer=nil;s.timerError=nil;s.lastError=nil
  lastUpdate=nil;lastArmed=nil;lastHistory=nil;lastTimer=nil;lastTimerIndex=nil
 end
 local function setHome(source)
  if s.fix==false then return false,'NO REPORTED GNSS FIX'end
  if not s.current then return false,'NO CURRENT GPS' end
  s.home=stamp(point(s.current,source));s.home.satsAtSet=s.sats
  s.track={};lastHistory=nil
  s.homeDistance=0;s.homeBearing=nil
  geometryLat=s.current.lat;geometryLon=s.current.lon;geometryHome=s.home
  cachedDistance=0;cachedBearing=nil
  return true
 end
 local function readTimer(index)
  if not index then
   s.modelTimer=nil;s.timerError=nil;lastTimer=nil;lastTimerIndex=nil
   return
  end
  if lastTimerIndex==index and lastTimer and now-lastTimer<100 then return end
  lastTimer=now;lastTimerIndex=index;s.modelTimer=nil;s.timerError=nil
  if type(opts.getTimer)~='function' then s.timerError='TIMER API UNAVAILABLE';return end
  local ok,value=pcall(opts.getTimer,index-1)
  if not ok then s.timerError=tostring(value)
  elseif type(value)~='table' or not finite(value.value) then s.timerError='INVALID TIMER'
  else s.modelTimer=copyTable(value);s.modelTimer.index=index;s.modelTimer.sampleTick=now end
 end
 function api.update(tick,data,settings)
  if not finite(tick) then return s end
  data=data or {};settings=settings or {};currentSettings=settings
  local modelChanged=settings.modelId~=nil and s.modelId~=nil and settings.modelId~=s.modelId
  local sourceChanged=settings.sourceId~=nil and s.sourceId~=nil and settings.sourceId~=s.sourceId
  if modelChanged then clear('MODEL CHANGED');s.muted=false
  elseif sourceChanged then clearNavigation('SOURCE CHANGED') end
  if settings.modelId~=nil then s.modelId=settings.modelId end
  if settings.sourceId~=nil then s.sourceId=settings.sourceId end
  now=tick
  if lastUpdate and now<lastUpdate then
   lastUpdate=nil;lastArmed=nil;lastHistory=nil;lastTimer=nil
   s.clockEpoch=s.clockEpoch+1
  end
  local armed
  if type(data.armed)=='boolean' then armed=data.armed end
  if lastUpdate and lastArmed==true and armed==true then s.flightSeconds=s.flightSeconds+(now-lastUpdate)/100 end
  lastUpdate=now;lastArmed=armed;s.armed=armed
  s.fix=type(data.fix)=='boolean'and data.fix or nil
  if data.fix==false then s.fix=false end
  s.sats=finite(data.sats) and data.sats>=0 and data.sats or nil
  s.speed=finite(data.speed) and data.speed or nil
  s.alt=finite(data.alt) and data.alt or nil
  s.hdg=finite(data.hdg) and data.hdg or nil
  local pos=data.fix~=false and data.gpsCurrent~=false and position(data.gps) and data.gps or nil
  local latitude=pos and(pos.lat+0.0);local longitude=pos and(pos.lon+0.0)
  if pos then
   -- Keep current and last-known distinct; never retain the caller's table.
   if not s.current then s.current=point(pos,'CURRENT') end
   s.current.lat=latitude;s.current.lon=longitude
   s.current.tick=now;s.current.seconds=now/100;s.current.clockEpoch=s.clockEpoch
   if not s.lastKnown then s.lastKnown=point(pos,'LAST KNOWN') end
   s.lastKnown.lat=latitude;s.lastKnown.lon=longitude
   s.lastKnown.tick=now;s.lastKnown.seconds=now/100;s.lastKnown.clockEpoch=s.clockEpoch
  else s.current=nil end
  local auto=settings.autoHome==1 or settings.autoHome==true
  local requireArm=settings.homeRequiresArmed==1 or settings.homeRequiresArmed==true
  if auto and not s.home and s.fix~=false and s.current and s.sats and s.sats>=bounded(settings.homeSats,8,0,255) and (not requireArm or armed==true) then setHome('LOCAL AUTO') end
  local limit=bounded(settings.trail,maximum,1,maximum)
  while #s.track>limit do table.remove(s.track,1) end
  if s.current and (not lastHistory or now-lastHistory>=historyInterval) then
   lastHistory=now
   local previous=s.track[#s.track]
   if not previous or previous.lat~=latitude or previous.lon~=longitude then
    if #s.track>=limit then table.remove(s.track,1) end
    s.track[#s.track+1]=stamp(point(pos,'TRACK'))
   end
  end
  s.homeDistance=nil;s.homeBearing=nil
  if s.current and s.home then
   if geometryHome~=s.home or geometryLat~=s.current.lat or geometryLon~=s.current.lon then
    cachedDistance,cachedBearing=geometry(s.current,s.home)
    geometryLat=s.current.lat;geometryLon=s.current.lon;geometryHome=s.home
   end
   s.homeDistance=cachedDistance;s.homeBearing=cachedBearing
  end
  readTimer(timerIndex(settings.timerIndex))
  return s
 end
 function api.snapshot()return s end -- Borrowed read-only view; stable between calls.
 function api.setHome()return setHome('LOCAL MANUAL') end
 function api.reset()
  clear('EXPLICIT RESET')
  return call(opts.onReset,'EXPLICIT RESET')
 end
 function api.newFlight(options)
  options=options or {}
  local selected=timerIndex(currentSettings.timerIndex)
  if options.resetModelTimer==true then
   if not selected then s.lastError='NO MODEL TIMER SELECTED';return false,s.lastError end
   if type(opts.resetTimer)~='function' then s.lastError='TIMER RESET API UNAVAILABLE';return false,s.lastError end
   local resetOk,resetErr=call(opts.resetTimer,selected-1)
   if not resetOk then return false,resetErr end
  end
  clear('NEW FLIGHT')
  return call(opts.onNewFlight,options)
 end
 function api.setMuted(value)s.muted=value==true;return s.muted end
 function api.toggleMuted()s.muted=not s.muted;return s.muted end
 return api
end
return M
