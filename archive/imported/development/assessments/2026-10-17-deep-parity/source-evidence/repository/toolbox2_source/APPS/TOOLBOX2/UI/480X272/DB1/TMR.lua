-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "TMR.luac" was compiled with Lua 5.3 --

local G = ...
function T.d(w)
  local tmrID = D.S.TMR_no - 1
  local timer = model.getTimer(tmrID) or {}
  local running = timer.mode == 1
  if running then
    local colon = D.TI.tick100 and ":"
    colon = colon or "" or ":"
  end
  if D.S.TMR_host == 1 then
    if not "Arm Timer " .. D.S.TMR_no then
      local label = "Timer " .. D.S.TMR_no
    end
  end
  local color = D.S.TLM_ON and D.C.MD_V or D.C.MD_L
  X.TX(w.xr - 8, w.yt + 8, label, X.FONT_S, X.TEXT_RIGHT, color)
  local v = timer.value or 0
  local min = string.format("%.2d", v / 60 % 60)
  local sec = string.format("%.2d", v % 60)
  X.TX(w.xr - 50, w.yt + 18, min, X.FONT_XL, X.TEXT_RIGHT, color)
  X.TX(w.xr - 40, w.yt + 17, colon, X.FONT_XL, X.TEXT_RIGHT, color)
  X.TX(w.xr - 4, w.yt + 18, sec, X.FONT_XL, X.TEXT_RIGHT, color)
  return
end
return

