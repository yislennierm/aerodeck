-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "RCL.luac" was compiled with Lua 5.3 --

local G = ...
function T.d(w)
  local dt
  if G.fm.sxx then
    if D.SEN.SN12n then
      dt = D.UI.SNV({s = "SN12"}, true)
      D.UI.DBAR(dt, {x = w.xl + 14, y = w.yt + 51, bg = true})
      t3 = {b = {w.xl, w.yt + 133, 38, 23, dt.cb},
                v = {w.xl + 37, w.yt + 141, dt.val, X.FONT_S, X.TEXT_RIGHT, dt.cv},
                l = {w.xl + 22, w.yt + 133, D.SEN.SN12n, X.FONT_XS, X.TEXT_CENTER, dt.cl}}
      D.UI.DIT(t3)
    end
    if D.SEN.SN13n then
      dt = D.UI.SNV({s = "SN13"}, true)
      D.UI.DBAR(dt, {x = w.xl + 57, y = w.yt + 51, bg = true})
      t3 = {b = {w.xl + 40, w.yt + 133, 34, 23, dt.cb},
                v = {w.xl + 63, w.yt + 141, dt.val, X.FONT_S, X.TEXT_RIGHT, dt.cv},
                l = {w.xl + 65, w.yt + 133, D.SEN.SN13n, X.FONT_XS, X.TEXT_RIGHT, dt.cl}}
      D.UI.DIT(t3)
    end
    if D.SEN.SN17n then
      local t3 = {}
      t3.s = "SN17"
      t3.pd = true
      dt = D.UI.SNV(t3, true)
      local x = w.xl + (D.SEN.SN17u == "mW" and 41 or 50)
      t4 = {b = {w.xl, w.yt + 158, w.w, 23, dt.cb},
                v = {x, w.yt + 166, dt.val, X.FONT_S, X.TEXT_RIGHT, dt.cv},
                l = {w.xl + 40, w.yt + 158, D.SEN.SN17n, X.FONT_XS, X.TEXT_CENTER, dt.cl},
                u = {x + 3, w.yt + 170, D.SEN.SN17u, X.FONT_XS, X.TEXT_LEFT, dt.cl}}
      D.UI.DIT(t4)
    end
    if D.SEN.SN18n then
      dt = D.UI.SNV({s = "SN18", pd = true})
      t3 = {b = {w.xl, w.yt + 185, w.w, 24, dt.cb},
                v = {w.xl + 38, w.yt + 193, dt.val, X.FONT_S, X.TEXT_CENTER, dt.cv},
                l = {w.xl + 38, w.yt + 185, D.SEN.SN18n, X.FONT_XXS, X.TEXT_CENTER, dt.cl}}
      D.UI.DIT(t3)
    end
  end
  return
end
return

