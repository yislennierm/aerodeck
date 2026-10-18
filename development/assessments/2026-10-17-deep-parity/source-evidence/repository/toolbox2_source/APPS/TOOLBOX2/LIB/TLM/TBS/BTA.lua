-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "BTA.luac" was compiled with Lua 5.3 --

local G = ...
D.S.BT_MD_LEFT = nil
D.S.BT_MD_CURR = 0
D.S.BT_MD_CONS = 0
local sensors = {}
if add then
  D.SEN.SN22n = "LEFT"
  D.SEN.SN22m = 0
  D.SEN.SN22x = 100
  D.SEN.SN22l = 30
  D.SEN.SN22c = 10
  D.SEN.SN22u = "%"
  D.SEN.SN22v = nil
  D.SEN.SN22vs = "BT_MD_LEFT"
  D.SEN.SN23n = "CURR"
  D.SEN.SN23m = 0
  D.SEN.SN23x = 200
  D.SEN.SN23l = 80
  D.SEN.SN23c = 140
  D.SEN.SN23u = "A"
  D.SEN.SN23i = true
  D.SEN.SN23v = nil
  D.SEN.SN23vs = "BT_MD_CURR"
  D.SEN.SN24n = "CONSUMED"
  D.SEN.SN24m = 0
  D.SEN.SN24x = math.huge
  D.SEN.SN24l = math.huge
  D.SEN.SN24c = math.huge
  D.SEN.SN24u = "mAh"
  D.SEN.SN24i = true
  D.SEN.SN24f = "%d"
  D.SEN.SN24v = nil
  D.SEN.SN24vs = "BT_MD_CONS"
  local BT_MD_LEFT_fn = function()
    local curr = D.S.BT_MD_CURR or 0
    local cons = D.S.BT_MD_CONS or 0
    local left = D.S.BT_MD_LEFT or 0
    if D.S.BT_FAV_SEL > 0 and D.S.BT_FAV_CAPA > 0 then
      D.S.BT_MD_LEFT = math.floor(math.max(0, D.S.BT_FAV_CAPA - cons) / D.S.BT_FAV_CAPA * 100)
    end
    if (curr >= 100) or not curr then
      local t4 = math.floor(curr)
    end
    D.SEN.SN23vd = curr or t4
    D.SEN.SN23f = curr < 100 and "%.1f" or "%d"
    D.SEN.SN24u = cons >= 1000 and "Ah" or "mAh"
    local t5 = cons < 1000 and math.floor(cons)
    t4 = cons / 1000
    D.SEN.SN24vd = math.floor(cons) or t4
    D.SEN.SN24f = ((((cons < 1000 and "%d") or (cons < 10000 and "%.3f")) or (cons < 100000 and "%.2f")) or (cons < 1000000 and "%.1f")) or "%.0f"
  end
  table.insert(sensors, {sName = "BT_MD_CURR", pName = "Curr", sLabel = "Batt current", dUnit = "AMPERE", dDec = 1, sMin = 0, sMax = 400})
  table.insert(sensors, {sName = "BT_MD_CONS", pName = "Capa", sLabel = "Batt consumed", dUnit = "MILLIAMPERE_HOUR", sMin = 0, sMax = 200000})
  t9 = {sName = "BT_MD_LEFT", pName = "Bat%", sLabel = "Batt % left", dUnit = "PERCENT", sMin = 0, sMax = 100, uFN = BT_MD_LEFT_fn}
  table.insert(sensors, t9)
end
return sensors

