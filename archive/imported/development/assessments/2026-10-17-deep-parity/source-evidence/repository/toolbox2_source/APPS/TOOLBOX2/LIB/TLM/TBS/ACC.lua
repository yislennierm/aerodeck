-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "ACC.luac" was compiled with Lua 5.3 --

local G = ...
D.S.ACC_X = nil
D.S.ACC_Y = nil
D.S.ACC_Z = nil
local sensors = {}
if add then
  table.insert(sensors, {sName = "ACC_X", pName = "AccX", sLabel = "Acceleration X", dUnit = "G", sMin = -32, sMax = 32})
  table.insert(sensors, {sName = "ACC_Y", pName = "AccY", sLabel = "Acceleration Y", dUnit = "G", sMin = -32, sMax = 32})
  t8 = {sName = "ACC_Z", pName = "AccZ", sLabel = "Acceleration Z", dUnit = "G", sMin = -32, sMax = 32}
  table.insert(sensors, t8)
end
return sensors

