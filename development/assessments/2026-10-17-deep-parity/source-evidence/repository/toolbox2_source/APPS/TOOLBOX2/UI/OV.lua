-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "OV.luac" was compiled with Lua 5.3 --

local G = ...
function T.d(w)
  if D.S.UI_THM_OV then
    D.UI.ov = D.UI.ov or X.LBM(D.UI.ovPath)
    if D.UI.ov then
      X.BM(D.UI.ov, w.xl, w.yt)
    end
  end
  return
end
return

