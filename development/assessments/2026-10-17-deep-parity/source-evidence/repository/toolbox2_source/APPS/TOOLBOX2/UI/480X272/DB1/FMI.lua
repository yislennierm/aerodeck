-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "FMI.luac" was compiled with Lua 5.3 --

local G = ...
function T.i(w)
  T.icAir = X.LMK(G.PGFXR .. "DBD_AM_MASK.jpg")
  T.icTm = X.LMK(G.PGFXR .. "DBD_TM_MASK.jpg")
  T.icRTH = X.LMK(G.PGFXR .. "DBD_RTH_MASK.jpg")
end
function T.d(w)
  if D.S.IND_AM then
    X.RCF(w.xl, w.yt, 35, 30, D.C.INB_ON)
    X.MK(T.icAir, w.xl + 9, w.yt + 7, D.C.INV_ON)
  end
  if D.S.IND_RTH then
    X.RCF(w.xl + 36, w.yt, 35, 30, D.C.INB_AL)
    X.MK(T.icRTH, w.xl + 41, w.yt + 7, D.C.INV_AL)
  else
    if D.S.IND_TU then
      X.RCF(w.xl + 36, w.yt, 35, 30, D.C.INB_AL)
      X.MK(T.icTm, w.xl + 41, w.yt + 7, D.C.INV_AL)
    end
  end
  return
end
return

