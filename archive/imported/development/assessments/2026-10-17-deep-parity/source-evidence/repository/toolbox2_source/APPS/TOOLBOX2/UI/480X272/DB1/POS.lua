-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "POS.luac" was compiled with Lua 5.3 --

local G = ...
function T.i(w)
  T.icHome = X.LBM(G.PGFXR .. "GPS_HOME.png")
  T.icPlane = X.LBM(G.PGFXR .. "GPS_PLANE.png")
end
function T.d(w)
  local sizeH = 40
  local sizeV = 27
  X.TX(w.xl + 6, w.yt + 7, "ETH", X.FONT_S, X.TEXT_LEFT, D.C.MD_L)
  if D.S.POS_TIMEH then
    if D.S.POS_TIMEH.h > 0 then
      X.TX(w.xl + 51, w.yt + 4, string.format("%02d", D.S.POS_TIMEH.h), X.FONT_STD, X.TEXT_RIGHT, D.C.MD_V)
      X.TX(w.xl + 51, w.yt + 7, "H", X.FONT_S, X.TEXT_LEFT, D.C.MD_L)
    end
    if D.S.POS_TIMEH.m > 0 or D.S.POS_TIMEH.h > 0 then
      X.TX(w.xl + 79, w.yt + 4, string.format("%02d", D.S.POS_TIMEH.m), X.FONT_STD, X.TEXT_RIGHT, D.C.MD_V)
      X.TX(w.xl + 80, w.yt + 7, "M", X.FONT_S, X.TEXT_LEFT, D.C.MD_L)
    end
    if D.S.POS_TIMEH.m > 0 or D.S.POS_TIMEH.h > 0 then
      X.TX(w.xl + 105, w.yt + 7, string.format("%02d", D.S.POS_TIMEH.s), X.FONT_S, X.TEXT_RIGHT, D.C.MD_V)
    else
      X.TX(w.xl + 92, w.yt + 4, string.format("%2d", D.S.POS_TIMEH.s), X.FONT_STD, X.TEXT_RIGHT, D.C.MD_V)
      X.TX(w.xl + 94, w.yt + 7, "S", X.FONT_S, X.TEXT_LEFT, D.C.MD_L)
    end
  end
  X.CRF(w.xc, w.yc, 3, D.C.WARN)
  X.CR(w.xc, w.yc, 3, D.C.BLACK)
  if D.S.POS_FIXH and D.GPS and D.GPS.posLog and D.GPS.posLog[0] and D.GPS.posLog[1] then
    do
      local xd = (D.GPS.posLog[1].lon - D.GPS.posLog[0].lon) * 1000
      xd = math.max(math.min(xd, sizeH), -sizeH)
      local yd = (D.GPS.posLog[1].lat - D.GPS.posLog[0].lat) * -1000
      yd = math.max(math.min(yd, sizeV), -sizeV)
      local plane = T.icPlane
      X.BM(plane, w.xc + xd - 10, w.yc + yd - 10)
    end
  end
  X.TX(w.xl + 6, w.yb - 20, "DIST", X.FONT_S, X.TEXT_LEFT, D.C.MD_L)
  if D.S.POS_DISTH then
    do
      local distH = string.format("%d", D.S.POS_DISTH)
      X.TX(w.xr - 25, w.yb - 23, distH, X.FONT_STD, X.TEXT_RIGHT, D.C.MD_V)
      local distU = D.S.POS_DISTH >= 1000 and "km" or "m"
      X.TX(w.xr - 22, w.yb - 16, distU, X.FONT_XS, X.TEXT_LEFT, D.C.MD_L)
    end
    local dim = D.S.MDL_RCP_ON and D.S.MDL_GPS_ON
    dim = true or true or nil
  end
  do
    if dim then
      X.RCF(w.xl, w.yt, w.w, w.h, D.C.MD_B, D.UI.dimTLM)
    end
    return
  end
end
return

