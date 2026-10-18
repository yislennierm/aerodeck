-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "FM.luac" was compiled with Lua 5.3 --

local G = ...
function T.d(w)
  local color = D.S.TLM_ON and D.C.MD_V or D.C.MD_L
  X.TX(w.xc, w.yt + 5, D.S.FC_FM_NAME or "---", X.FONT_STD_BOLD, X.TEXT_CENTER, D.CFGSTR.iFMS == 0 and D.C.MD_V or color)
  return
end
return

