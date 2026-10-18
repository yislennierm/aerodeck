-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "GPS.luac" was compiled with Lua 5.3 --

local G = ...
function T.i(w)
  T.icSat = X.LMK(G.PGFXR .. "GPS_SAT_MASK.jpg")
  T.icHome = X.LMK(G.PGFXR .. "GPS_HOME_MASK.jpg")
  T.icDrone = X.LMK(G.PGFXR .. "GPS_DRON_MASK.jpg")
end
function T.d(w)
  local var
  X.MK(T.icSat, w.xl + 8, w.yt + 8, D.C.MD_V)
  X.MK(T.icDrone, w.xl + 8, w.yt + 33, D.C.MD_V)
  if G.fm.pgg then X.MK(T.icHome, w.xl + 8, w.yt + 83, D.C.MD_V) end
  local color, color2 = D.C.MD_V
  if D.S.GPS_DATA then
    local t4 = D.S.GPS_SATS and D.S.GPS_SATS
    var = 0
    t4 = var < 5 and D.C.WARN
    color2 = color
    X.TX(w.xl + 60, w.yt + 4, var, X.FONT_L, X.TEXT_RIGHT, color)
    t4 = D.S.GPS_HDOP and D.S.GPS_HDOP
    var = ""
    X.TX(w.xl + 64, w.yt + 8, "HDOP", X.FONT_XS, X.TEXT_LEFT, color)
    X.TX(w.xl + 101, w.yt + 4, var, X.FONT_S, X.TEXT_RIGHT, color)
    X.GA(w.xl + 64, w.yt + 21, 37, 5, D.S.GPS_HDOP or 0, 9, nil, color)
    local lat = D.S.POS_LAT and string.format("%3.6f", D.S.POS_LAT) or ""
    X.TX(w.xl + 101, w.yt + 29, lat, X.FONT_S, X.TEXT_RIGHT, color)
    local lon = D.S.POS_LON and string.format("%3.6f", D.S.POS_LON) or ""
    do
      X.TX(w.xl + 101, w.yt + 42, lon, X.FONT_S, X.TEXT_RIGHT, color)
      if D.S.POS_FIX then
        X.RCF(w.xl + 23, w.yt + 45, 9, 12, D.C.MD_B)
        X.RCF(w.xl + 25, w.yt + 50, 7, 6, D.C.OK)
        X.CR(w.xl + 28, w.yt + 49, 2, D.C.OK)
      end
      if G.fm.pgg and D.S.POS_LATH then
        local latH = string.format("%3.6f", D.S.POS_LATH) or ""
      end
      X.TX(w.xl + 101, w.yt + 81, latH, X.FONT_S, X.TEXT_RIGHT, color)
      if G.fm.pgg and D.S.POS_LONH then
        local lonH = string.format("%3.6f", D.S.POS_LONH) or ""
      end
      X.TX(w.xl + 101, w.yt + 94, lonH, X.FONT_S, X.TEXT_RIGHT, color)
      if G.fm.pgg and D.S.POS_FIXH then
        X.RCF(w.xl + 23, w.yt + 96, 9, 12, D.C.MD_B)
        X.RCF(w.xl + 25, w.yt + 101, 7, 6, D.C.OK)
        X.CR(w.xl + 28, w.yt + 99, 2, D.C.OK)
        local x0 = w.xl + 18
        local y0 = w.yt + 68
        local x1, y1, x2, y2, x3, y3, x4, y4
        local r = 10
        local tD = 2
        local getCoord = function(r, dd)
          dd = dd % 360
          local px = x0 + math.floor(r * math.sin(math.rad(dd)))
          local py = y0 - math.floor(r * math.cos(math.rad(dd)))
          return px, py
        end
        local gcHDir = D.S.DIR_RBH and D.S.DIR_RBH or 0
        x1, y1 = getCoord(r, gcHDir)
        x2, y2 = getCoord(r, gcHDir - 126)
        x3, y3 = getCoord(r, gcHDir + 126)
        x4, y4 = getCoord(tD, gcHDir + 180)
        X.TRF(x1, y1, x2, y2, x4, y4, color)
        X.TRF(x1, y1, x3, y3, x4, y4, color)
        if D.S.POS_DISTH then
          local distH = string.format("%.2f", D.S.POS_DISTH / 1000) or string.format("%3d", D.S.POS_DISTH) or ""
        end
        X.TX(w.xl + 82, w.yt + 60, distH, X.FONT_STD, X.TEXT_RIGHT, color)
        if D.S.POS_DISTH then
          local distU = D.S.POS_DISTH >= 1000 and "km"
          distU = distU or "m" or ""
        end
        X.TX(w.xl + 98, w.yt + 67, distU, X.FONT_XS, X.TEXT_RIGHT, color)
      end
    end
    local dim = D.S.MDL_RCP_ON and D.S.GPS_DATA
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

