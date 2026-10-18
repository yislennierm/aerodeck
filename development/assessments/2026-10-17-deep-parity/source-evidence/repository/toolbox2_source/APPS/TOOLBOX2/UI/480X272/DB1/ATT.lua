-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "ATT.luac" was compiled with Lua 5.3 --

local G = ...
function T.i(w)
  T.cpd = X.LMK(G.PGFXR .. "DBD_ATT_MASK.jpg")
  T.cpd2 = X.LMK(G.PGFXR .. "DBD_ATTB_MASK.jpg")
end
function T.d(w)
  local getColor = function(g, pitch)
    local s, color = math.floor(math.abs(pitch))
    if s < 90 then s = s or 90 end
    if g then
      color = D.C.DB_AHG
    else
      color = D.C.DB_AHS
    end
    return color
  end
  local pitch = D.S.ATT_PITCH or 0
  local roll = D.S.ATT_ROLL or 0
  X.RCF(w.xl + 2, w.yt + 5, w.w - 4, w.h - 10, getColor(false, pitch))
  X.HR(pitch, roll, w.xl + 2, w.xr - 1, w.yt + 5, w.yb - 6, getColor(true, pitch))
  X.RCF(w.xl, w.yt, w.w, w.h, D.C.MD_B, 5)
  X.MK(T.cpd2, w.xl, w.yt + 5, D.C.MD_B)
  X.MK(T.cpd, w.xl, w.yt + 5, D.C.MD_V)
  X.LN(w.xl, w.yc - 1, w.xl + w.w, w.yc - 1, X.PEN_DOTTED, D.C.WHITE)
  if G.fm.sxx and D.S.ATT_PITCH then
    do
      local pitchDisp = math.floor(D.S.ATT_PITCH) .. D.UI.CHDEG
      X.TX(w.xl + 39, w.yt + 31, "PITCH", X.FONT_XS, X.TEXT_CENTER, D.C.MD_V)
      X.TX(w.xl + 54, w.yt + 40, pitchDisp, X.FONT_S, X.TEXT_RIGHT, D.C.MD_V)
    end
    if G.fm.sxx and D.S.ATT_ROLL then
    end
    do
      local pitchDisp = math.floor(D.S.ATT_ROLL) .. D.UI.CHDEG
      X.TX(w.xl + 84, w.yt + 31, "ROLL", X.FONT_XS, X.TEXT_RIGHT, D.C.MD_V)
      X.TX(w.xl + 86, w.yt + 40, pitchDisp, X.FONT_S, X.TEXT_RIGHT, D.C.MD_V)
    end
  end
  if D.S.ATT_YAW then
    if G.fm.sxx then
      do
        local yawDisp = math.floor(D.S.ATT_YAW) .. D.UI.CHDEG
        X.TX(w.xl + 56, w.yt + 75, "YAW", X.FONT_XS, X.TEXT_CENTER, D.C.MD_V)
        X.TX(w.xl + 58, w.yt + 59, yawDisp, X.FONT_S, X.TEXT_CENTER, D.C.MD_V)
      end
      local r = 47
      local xd = 0
      local yd = 0
      local yawRad = D.S.ATT_YAW and math.rad(D.S.ATT_YAW) or 0
    end
    do
      xd = math.floor(r * math.sin(yawRad)) + 1
      yd = math.floor(r * math.cos(yawRad)) * -1
      X.CRF(w.xc + xd, w.yc + yd, 4, D.C.OK)
    end
  end
end

