-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "BAT.luac" was compiled with Lua 5.3 --

local G = ...
function T.d(w)
  local val, dt
  if D.S.MDL_BTV_ON and D.SEN.SN21n then
    local t4 = {}
    t4.s = "SN21"
    dt = D.UI.SNV(t4, true)
    local t5 = {}
    t5.x = w.xl + 24
    t5.y = w.yt + 51
    t5.w = 28
    t5.bg = true
    t5.t = true
    D.UI.DBAR(dt, t5)
    t4 = {}
    t5 = {}
    t4.b = t5
    t5 = {}
    t4.v = t5
    t5 = {}
    t4.l = t5
    D.UI.DIT(t4)
    val = D.S.BT_MD_V or 0
    dt = D.UI.SNV({s = "SN21", vd = val})
    t4 = {b = {w.xl, w.yt + 185, w.w, 24, dt.cb},
            v = {w.xl + 49, w.yt + 193, dt.val, X.FONT_S, X.TEXT_RIGHT, dt.cv},
            l = {w.xl + 38, w.yt + 185, "BATT", X.FONT_XXS, X.TEXT_CENTER, dt.cl},
            u = {w.xl + 51, w.yt + 197, "V", X.FONT_XXS, X.TEXT_LEFT, dt.cl}}
    D.UI.DIT(t4)
  end
  if G.fm.sxx and D.S.MDL_BTA_ON then
    if D.SEN.SN22n then
      dt = D.UI.SNV({s = "SN22"}, true)
      D.UI.DBAR(dt, {x = w.xl + 13, y = w.yt + 51, bg = true})
      t4 = {b = {w.xl, w.yt + 133, 37, 23, dt.cb},
                v = {w.xl + 32, w.yt + 141, dt.val, X.FONT_S, X.TEXT_RIGHT, dt.cv},
                l = {w.xl + 12, w.yt + 133, D.SEN.SN22n, X.FONT_XXS, X.TEXT_LEFT, dt.cl}}
      D.UI.DIT(t4)
    end
    if D.SEN.SN23n then
      dt = D.UI.SNV({s = "SN23"}, true)
      D.UI.DBAR(dt, {x = w.xl + 56, y = w.yt + 51, bg = true})
      t4 = {b = {w.xl + 39, w.yt + 133, 36, 23, dt.cb},
                v = {w.xl + 65, w.yt + 141, dt.val, X.FONT_S, X.TEXT_RIGHT, dt.cv},
                l = {w.xl + 67, w.yt + 133, D.SEN.SN23n, X.FONT_XXS, X.TEXT_RIGHT, dt.cl}}
      D.UI.DIT(t4)
    end
    if D.SEN.SN24n then
      t4 = {}
      t4.s = "SN24"
      dt = D.UI.SNV(t4)
      local x = w.xl + (D.SEN.SN24u == "Ah" and 48 or 40)
      t5 = {b = {w.xl, w.yt + 158, w.w, 23, dt.cb},
                v = {x, w.yt + 166, dt.val, X.FONT_S, X.TEXT_RIGHT, dt.cv},
                l = {w.xl + 38, w.yt + 158, D.SEN.SN24n, X.FONT_XXS, X.TEXT_CENTER, dt.cl},
                u = {x + 3, w.yt + 170, dt.unit, X.FONT_XXS, X.TEXT_LEFT, dt.cl}}
      D.UI.DIT(t5)
    end
  end
  if not D.S.TLM_ON then
    X.RCF(w.xl, w.yt, w.w, w.h, D.C.MD_B, D.UI.dimTLM)
  end
  return
end
return

