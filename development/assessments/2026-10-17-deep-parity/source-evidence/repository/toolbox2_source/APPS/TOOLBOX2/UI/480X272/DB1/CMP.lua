-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CMP.luac" was compiled with Lua 5.3 --

local G = ...
function T.i(w)
  T.cpd = X.LMK(G.PGFXR .. "DBD_CMP_MASK.jpg")
end
function T.d(w)
  X.MK(T.cpd, w.xl, w.yt + 4, D.C.MD_V)
  if D.S.GPS_DATA then
    local r = 47
    local xd = 0
    local yd = 0
    if G.fm.pgg and D.S.DIR_GCH then
      do
        local gcHRad = math.rad(D.S.DIR_GCH)
        xd = math.floor(r * math.sin(gcHRad)) + 1
        yd = math.floor(r * math.cos(gcHRad)) * -1
        X.CRF(w.xc + xd, w.yc + yd, 6, D.C.WARN)
      end
      if D.S.DIR_GC then
        local gcDisp = math.floor(D.S.DIR_GC) .. D.UI.CHDEG
        X.TX(w.xc + 5, w.yt + 34, gcDisp, X.FONT_STD, X.TEXT_CENTER, D.C.MD_V)
        X.TX(w.xc + 1, w.yt + 52, "GC", X.FONT_S, X.TEXT_CENTER, D.C.MD_L)
        local gcRad = math.rad(D.S.DIR_GC)
        xd = math.floor(r * math.sin(gcRad)) + 1
        yd = math.floor(r * math.cos(gcRad)) * -1
        X.CRF(w.xc + xd, w.yc + yd, 4, D.C.OK)
      end
    end
    local dim = D.S.MDL_RCP_ON and D.S.DIR_GC
    dim = true or true or nil
  end
  do
    if dim then
      X.RCF(w.xl, w.yt, w.xr - w.xl, w.yb - w.yt, D.C.MD_B, D.UI.dimTLM)
    end
    return
  end
end
return

