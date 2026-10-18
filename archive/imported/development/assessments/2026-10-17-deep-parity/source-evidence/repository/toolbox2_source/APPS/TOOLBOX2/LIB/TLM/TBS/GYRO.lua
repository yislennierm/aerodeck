-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "GYRO.luac" was compiled with Lua 5.3 --

local G = ...
D.S.ATT_PITCH = nil
D.S.ATT_ROLL = nil
D.S.ATT_YAW = nil
local sensors = {}
if add then
  local ATT_PITCH_vFN = function(snData)
    local uUnitKey = D.UNITID[snData.uUnit] or "NONE"
    if type(snData.rVal) == "number" and uUnitKey == "RADIAN" then
    end
    return math.deg(snData.rVal) * -1 or snData.rVal
  end
  local ATT_vFN = function(snData)
    local uUnitKey = D.UNITID[snData.uUnit] or "NONE"
    return math.deg(snData.rVal) or snData.rVal
  end
  table.insert(sensors, {sName = "ATT_PITCH", pName = "Ptch", sLabel = "Pitch", dUnit = "DEGREE", dDec = 2, vFN = ATT_PITCH_vFN, sMin = -180, sMax = 180})
  table.insert(sensors, {sName = "ATT_ROLL", pName = "Roll", sLabel = "Roll", dUnit = "DEGREE", dDec = 2, vFN = ATT_vFN, sMin = -180, sMax = 180})
  t10 = {sName = "ATT_YAW", pName = "Yaw", sLabel = "Yaw", dUnit = "DEGREE", dDec = 2, vFN = ATT_vFN, sMin = -180, sMax = 180}
  table.insert(sensors, t10)
end
return sensors

