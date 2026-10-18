-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "GPS.luac" was compiled with Lua 5.3 --

local G = ...
D.S.GPS_DATA = nil
D.S.GPS_SATS = nil
D.S.GPS_HDOP = nil
D.S.GPS_STAT = nil
D.S.ALT_GPS = nil
D.S.SPD_GND = nil
D.S.POS_FIX = nil
D.S.POS_LAT = nil
D.S.POS_LON = nil
D.S.POS_FIXH = nil
D.S.POS_LATH = nil
D.S.POS_LONH = nil
D.S.POS_DISTH = nil
D.S.POS_TIMEH = nil
D.S.DIR_GC = nil
D.S.DIR_GCH = nil
D.S.DIR_RBH = nil
D.S.DIR_HDG = nil
D.S.GPS_DATA = nil
F.SN_GPS = nil
local sensors = {}
if add then
  local GPS_DATA_fn = function()
    D.S.GPS_data = type(D.S.GPS_DATA) == "table" or nil
    D.S.POS_LAT = D.S.GPS_DATA and D.S.GPS_DATA.lat or nil
    D.S.POS_LON = D.S.GPS_DATA and D.S.GPS_DATA.lon or nil
    D.S.DIR_GC = D.S.DIR_HDG and (D.S.DIR_HDG + 360) % 360 or nil
    D.S.POS_FIX = (D.S.GPS_SATS or 0) > (D.S.GPS_SATS2FIX or 0)
    D.S.GPS_HDOP = math.max(0, math.min(9, (D.S.GPS_SATS or 0) - 4)) or nil
    if D.S.POS_LAT and D.S.POS_LON and D.GPS and D.GPS.addPosition then
      if D.S.GPS_data then
        if D.S.POS_FIXH then
          D.S.DIR_GCH = D.GPS.calcGC(D.GPS.posLog[1], D.GPS.posLog[0], D.S.DIR_GCH)
          D.S.POS_DISTH = D.GPS.calcDistance(D.GPS.posLog[1], D.GPS.posLog[0])
          D.S.DIR_RBH = D.GPS.calcBearing(D.S.DIR_GC, D.S.DIR_GCH)
          D.S.POS_TIMEH = D.GPS.calcTravelTime(D.S.POS_DISTH, "m", D.S.SPD_GND, "km/h")
          D.GPS.addPosition(D.S.POS_LAT, D.S.POS_LON)
        else
          D.S.POS_LONH = D.S.POS_LON
          D.S.POS_LATH = D.S.POS_LAT
          D.GPS.addPosition(D.S.POS_LATH, D.S.POS_LONH, 0)
          D.GPS.addPosition(D.S.POS_LAT, D.S.POS_LON, 1)
          D.S.POS_FIXH = D.S.POS_FIX and D.S.ARMED
        end
      else
        D.S.POS_LONH = D.S.POS_LON
        D.S.POS_LATH = D.S.POS_LAT
        D.GPS.addPosition(D.S.POS_LAT, D.S.POS_LON, 0)
        D.GPS.addPosition(D.S.POS_LAT, D.S.POS_LON, 1)
        D.S.GPS_data = true
      end
    end
  end
  table.insert(sensors, {sName = "GPS_DATA", pName = "GPS", sLabel = "GPS data", uFN = GPS_DATA_fn})
  table.insert(sensors, {sName = "GPS_SATS", pName = "Sats", sLabel = "GPS Sats", sMin = 0, sMax = 100})
  table.insert(sensors, {sName = "SPD_GND", pName = "GSpd", sLabel = "GPS speed", dUnit = "KILOMETER_PER_HOUR", dDec = 1, sMin = 0, sMax = 999})
  table.insert(sensors, {sName = "ALT_GPS", pName = "GAlt", sLabel = "GPS alttitude", dUnit = "METER", dDec = 0, sMin = -9999, sMax = 20000})
  t9 = {sName = "DIR_HDG", pName = "Hdg", sLabel = "Heading", dUnit = "DEGREE", dDec = 2, sMin = -180, sMax = 180}
  table.insert(sensors, t9)
end
return sensors

