-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "TIM.luac" was compiled with Lua 5.3 --

local G = ...
function T.d(w)
  local dt = getDateTime()
  local date = string.format("%.4d-%.2d-%.2d", dt.year, dt.mon, dt.day)
  local hour = string.format("%.2d", dt.hour)
  local min = string.format("%.2d", dt.min)
  local color = D.C.MD_V
  X.TX(w.xl + 11, w.yt + 8, date, X.FONT_S, X.TEXT_LEFT, color)
  X.TX(w.xl + 9, w.yt + 18, hour, X.FONT_XL, X.TEXT_LEFT, color)
  X.TX(w.xl + 46, w.yt + 17, ":", X.FONT_XL, X.TEXT_LEFT, color)
  X.TX(w.xl + 55, w.yt + 18, min, X.FONT_XL, X.TEXT_LEFT, color)
  return
end
return

