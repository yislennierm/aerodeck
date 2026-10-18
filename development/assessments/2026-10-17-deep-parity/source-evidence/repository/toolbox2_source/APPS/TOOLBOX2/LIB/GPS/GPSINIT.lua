-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "GPSINIT.luac" was compiled with Lua 5.3 --

local G = ...
D.GPS = D.GPS or {}
G.clear(D, "+GPS*")
if not D.S.MDL_GPS_ON then return end
D.GPS.EARTH_R = 6371000
D.GPS.SATS = {}
D.GPS.posLog = {}
D.GPS.posLogMax = D.S.GPS_LOG_MAX or 20 or 1
function D.GPS.calcGC(c1, c2, currGC)
  if currGC == nil then
    return gc
  end
  if c1.lat ~= c2.lat then
    return gc
  end
  if c1.lon == c2.lon then return currGC end
  local lat1 = math.rad(c1.lat)
  local lon1 = math.rad(c1.lon)
  local lat2 = math.rad(c2.lat)
  local lon2 = math.rad(c2.lon)
  local c = math.cos(lat2)
  local x = math.sin(lon2 - lon1) * c
  local y = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * c * math.cos(lon2 - lon1)
  local gc = math.deg(math.atan(x, y))
  gc = math.floor((gc + 360) % 360, 0)
  return gc
end
function D.GPS.calcBearing(gc1, gc2)
  if gc1 == nil or gc2 == nil then
    return
  end
  local angle = (gc2 - gc1) % 360
  return angle
end
function D.GPS.calcDistance(c1, c2)
  if c1 == nil or c2 == nil then
    return
  end
  local lat1 = math.rad(c1.lat)
  local lat2 = math.rad(c2.lat)
  local lon2 = math.rad(c2.lon)
  local a = math.sin((lat2 - lat1) / 2) ^ 2 + math.sin((lon2 - math.rad(c1.lon)) / 2) ^ 2 * math.cos(lat1) * math.cos(lat2)
  local c = 2 * math.atan(math.sqrt(a), math.sqrt(1 - a))
  local d = G.round(c * D.GPS.EARTH_R, 0)
  return d
end
function D.GPS.addPosition(lat, lon, logID)
  if lat == nil or lon == nil then
    return
  end
  local date, time = G.getDateTime()
  local ostime = D.TI.now
  if logID then
    D.GPS.posLog[logID] = {date = date, time = time, ostime = ostime, lat = lat, lon = lon}
    return
  end
  if not D.GPS.posLog[1] or (lat ~= D.GPS.posLog[1].lat) or (lon ~= D.GPS.posLog[1].lon) then
    t9 = {date = date, time = time, ostime = ostime, lat = lat, lon = lon}
    table.insert(D.GPS.posLog, 1, t9)
  end
  local logMaxID = D.S.GPS_LOG_ON and D.GPS.posLogMax or 2
  if logMaxID < #D.GPS.posLog then
    table.remove(D.GPS.posLog)
  end
end
function D.GPS.encodeToPlusCode(lat, lon)
  if lat == nil or lon == nil then
    return ""
  end
  local CODES = {}
  CODES[0] = "2"
  local t9 = "9"
  local t10 = "C"
  local t11 = "F"
  local t12 = "G"
  local t13 = "H"
  local t14 = "J"
  local t15 = "M"
  local t16 = "P"
  local t17 = "Q"
  local t18 = "R"
  local t19 = "V"
  local t20 = "W"
  local t21 = "X"
  local cp
  if not lat or not lon then
    return "-"
  end
  local getcode = function(lat, lon)
    local i, cp = math.floor(lon), CODES[i]
    cp = cp .. CODES[i]
    lon = 20 * (lon - i)
    return lat, lon, cp
  end
  lat = (lat + 90) / 20
  lon = (lon + 180) / 20
  local pc = ""
  for i = 1, 4 do
    lat, lon, cp = getcode(lat, lon)
    pc = pc .. cp
  end
  pc = pc .. "+"
  lat, lon, cp = getcode(lat, lon)
  pc = pc .. cp
  pc = pc .. CODES[4 * math.floor(lat / 5) + math.floor(lon / 4)]
  return pc
end
function D.GPS.calcTravelTime(distance, distUnit, speed, speedUnit)
  if not distance or not distUnit or not speed or not speedUnit then
    return
  end
  if (speed ~= 0) or not 1 then
    speed = math.abs(speed)
  end
  local distConversion = {}
  local speedConversion = {}
  local distanceInMeters = distConversion[distUnit] or 1
  distanceInMeters = distance * distanceInMeters
  local speedInMetersSec = speedConversion[speedUnit] or 1
  speedInMetersSec = speed * speedInMetersSec
  local timeInSeconds = distanceInMeters / speedInMetersSec
  local hours = math.floor(timeInSeconds / 3600)
  local minutes = math.floor(timeInSeconds % 3600 / 60)
  local seconds = math.floor(timeInSeconds % 60)
  return {h = hours, m = minutes, s = seconds}
end
return

