-- Exact geodesic history projection. Existing geo/round/pi helpers are reused.
-- Session owns immutable track points; this cache never changes or truncates them.
local navPlot=(function()
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
 function api.step(home,pos,track,zoom,now)
  if not owned(home,track)then return s,0,0 end
  if not finite(zoom)or zoom%1~=0.0 or not scales[zoom]then s.error='INVALID ZOOM';return s,0,0 end
  if not job then
   local origin=home or(valid(pos)and pos or nil)
   if not origin then s.waiting=true;return s,0,0 end
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
  while job.at<=job.count and processed<32 and geometryCount<8 do
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
