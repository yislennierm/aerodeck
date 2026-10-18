-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "AHR.luac" was compiled with Lua 5.3 --

local G = ...
function T.i(w)
  T.ahl = X.LBM(G.PGFXR .. "DBD_AHL.png")
  return
end
function T.d(w)
  local wpv = 60
  local xpvl = w.xl + wpv
  local xpvr = w.xr - wpv
  local hph = 20
  local ypht = w.yt + hph
  local yphb = w.yb - hph
  local pitch = D.S.ATT_PITCH and math.floor(D.S.ATT_PITCH) or nil
  local roll = D.S.ATT_ROLL and math.floor(D.S.ATT_ROLL) or nil
  local mainSpeedSensor = D.S.SPD_AIR and "SPD_AIR"
  mainSpeedSensor = (mainSpeedSensor or (D.S.SPD_GND and "SPD_GND")) or nil
  local mainSpeedName = "SPD"
  local mainSpeed
  local mainSpeedUnit = ""
  if mainSpeedSensor then
    local auxSpeedSensor = mainSpeedSensor == "SPD_AIR" and "A.SPD"
    mainSpeedName = "G.SPD"
    auxSpeedSensor = D.S[mainSpeedSensor] and math.floor(D.S[mainSpeedSensor])
    mainSpeed = nil
    mainSpeedUnit = "km/h"
  end
  auxSpeedSensor = nil
  local auxSpeedName = ""
  local auxSpeed
  local auxSpeedUnit = ""
  if mainSpeedSensor == "SPD_AIR" then
    local t17 = D.S.SPD_GND and "SPD_GND"
    auxSpeedSensor = nil
    t17 = D.S.SPD_GND and "G.SPD"
    auxSpeedName = ""
  end
  if auxSpeedSensor then
    t17 = D.S[auxSpeedSensor] and math.floor(D.S[auxSpeedSensor])
    auxSpeed = nil
    auxSpeedUnit = "km/h"
  end
  local mainAltSensor = D.S.ALT_GPS and "ALT_GPS"
  mainAltSensor = (mainAltSensor or (D.S.ALT_BARO and "ALT_BARO")) or nil
  local mainAltName = "ALT"
  local mainAlt
  local mainAltUnit = ""
  if mainAltSensor then
    local auxAltSensor = mainAltSensor == "ALT_BARO" and "B.ALT"
    mainAltName = ""
    auxAltSensor = D.S[mainAltSensor] and math.floor(D.S[mainAltSensor])
    mainAlt = nil
    mainAltUnit = "m"
  end
  auxAltSensor = nil
  local auxAltName = ""
  local auxAlt
  local auxAltUnit = ""
  if mainAltSensor == "ALT_GPS" then
    local t25 = D.S.ALT_BARO and "ALT_BARO"
    auxAltSensor = nil
    t25 = D.S.ALT_BARO and "B.ALT"
    auxAltName = ""
  end
  if auxAltSensor then
    local low = D.S[auxAltSensor] and math.floor(D.S[auxAltSensor])
    auxAlt = nil
    auxAltUnit = "m"
  end
  low = -3
  local high = 3
  local scale = 25
  local scaleCalib = -9
  local color = D.C.WHITE
  local drawScale = function(var, xnum, xmrk, step, dir, positive, font, align, color)
    local varR = var % step
    for i = low, high do
      local ss = math.floor(var / step) * step + i * step
      if positive then
        if not 0 then local step1 = -math.huge end
      end
      local shift = -scale / 2
      shift = (scale / step * varR - scale / 2 or shift) + scaleCalib
      local yl = w.yt + w.h - (i + 2) * scale + shift
      if yl + 8 < w.yb then
        X.TX(xnum, yl - 8, ss, font, align, color)
      end
      if yl < w.yb then
        if yl < ypht then
          return
        end
      end
      X.LN(xmrk, yl, xmrk + 5 * dir, yl, X.PEN_SOLID, color)
      yl = yl - scale / 4
      if yl < ypht then
        return
      end
      X.LN(xmrk, yl, xmrk + dir, yl, X.PEN_SOLID, color)
      yl = yl - scale / 4
      if yl < ypht then
        return
      end
      X.LN(xmrk, yl, xmrk + 3 * dir, yl, X.PEN_SOLID, color)
      yl = yl - scale / 4
      if yl < ypht then
        return
      end
      X.LN(xmrk, yl, xmrk + dir, yl, X.PEN_SOLID, color)
    end
  end
  local boxW = wpv - 6
  local boxH = 24
  local boxyt = -10
  local drawScaleBox = function(x, y, value, dir, cTxt)
    if dir == "L" then
      X.TRF(xpvl - 1, y, x + boxW - 1, y - 6, x + boxW - 1, y + 6, D.C.BLACK)
      X.TR(xpvl - 1, y, x + boxW - 1, y - 6, x + boxW - 1, y + 6, cTxt)
      X.RCF(x, y - boxH / 2, boxW, boxH, D.C.BLACK)
      X.RC(x, y - boxH / 2, boxW, boxH, cTxt)
      X.LN(x + boxW - 1, y - 5, x + boxW - 1, y + 5, X.PEN_SOLID, D.C.BLACK)
      X.TX(x + boxW / 2, y + boxyt, value, X.FONT_STD_BOLD, X.TEXT_CENTER, cTxt)
    else
      X.TRF(xpvr + 1, y, xpvr + 7, y - 6, xpvr + 7, y + 6, D.C.BLACK)
      X.TR(xpvr + 1, y, xpvr + 7, y - 6, xpvr + 7, y + 6, cTxt)
      X.RCF(x - boxW + 1, y - boxH / 2, boxW, boxH, D.C.BLACK)
      X.RC(x - boxW + 1, y - boxH / 2, boxW, boxH, cTxt)
      X.LN(xpvr + 7, y - 5, xpvr + 7, y + 5, X.PEN_SOLID, D.C.BLACK)
      X.TX(x - boxW / 2, y + boxyt, value, X.FONT_STD_BOLD, X.TEXT_CENTER, cTxt)
    end
  end
  local getColor = function(g, pitch)
    local s, color = math.floor(math.abs(pitch))
    if s < 90 then s = s or 90 end
    if g then
      color = lcd.RGB(20, 235 - s * 1.5, 20)
    else
      color = lcd.RGB(45 + s * 1.5, 45 + s * 1.5, 255)
    end
    return color
  end
  local pitch = D.S.ATT_PITCH or 0
  local roll = D.S.ATT_ROLL or 0
  X.RCF(w.xl, w.yt, w.w, w.h, getColor(false, pitch))
  X.HR(pitch, roll, w.xl, w.xl + w.w, w.yt, w.yt + w.h, getColor(true, pitch))
  local color = D.C.WHITE
  X.LN(w.xl, w.yc, w.xl + w.w, w.yc, X.PEN_DOTTED, D.C.WHITE)
  if D.S.TLM_ON then
    X.BM(T.ahl, w.xc - 15, w.yc - 1)
  end
  local hdgX = w.xc - 28
  X.RCF(w.xl, w.yt, wpv, w.h, D.C.BLACK, 12)
  local val = mainSpeed or 0
  color = D.C.GREY2
  drawScale(val, xpvl - 9, xpvl - 1, 5, -1, true, X.FONT_S, X.TEXT_RIGHT, color)
  color = D.C.GREY2
  drawScaleBox(w.xl, w.yc, val, "L", color)
  X.RCF(xpvr, w.yt, wpv, w.h, D.C.BLACK, 12)
  local val = mainAlt or 0
  color = D.C.GREY2
  drawScale(val, xpvr + 8, xpvr, 50, 1, false, X.FONT_S, X.TEXT_LEFT, color)
  color = D.C.GREY2
  drawScaleBox(w.xr, w.yc, val, "R", color)
  if G.fm.pgg and D.S.DIR_RBH then
    do
      local bhColor = D.C.WHITE
      local gcHDirDisp = math.floor(math.abs(D.S.DIR_RBH)) .. D.UI.CHDEG
      if D.S.DIR_RBH < -48 then
        X.TRF(xpvl + 7, w.yt + 21, xpvl + 2, w.yt + 26, xpvl + 7, w.yt + 31, bhColor)
        X.TX(xpvl + 14, w.yt + 18, gcHDirDisp, X.FONT_S, X.TEXT_LEFT, bhColor)
      elseif D.S.DIR_RBH > 48 then
        X.TRF(xpvr - 7, w.yt + 21, xpvr - 2, w.yt + 26, xpvr - 7, w.yt + 31, bhColor)
        X.TX(xpvr - 11, w.yt + 18, gcHDirDisp, X.FONT_S, X.TEXT_RIGHT, bhColor)
      else
        X.RCF(w.xc + D.S.DIR_RBH - 7, w.yt + 21, 13, 13, bhColor)
        X.TX(w.xc + D.S.DIR_RBH - 1, w.yt + 19, "H", X.FONT_S, X.TEXT_CENTER, D.C.BLACK)
      end
    end
    X.RCF(w.xl, w.yt, w.w, hph, D.C.BLACK, 5)
  end
  color = D.C.GREY2
  X.TX(w.xl + wpv / 2, w.yt + 3, mainSpeedName, X.FONT_S, X.TEXT_CENTER, color)
  X.RCF(w.xl, w.yt + hph, wpv, hph / 2, D.C.BLACK, 5)
  X.TX(w.xl + wpv / 2, w.yt + hph - 3, mainSpeedUnit, X.FONT_XS, X.TEXT_CENTER, color)
  color = D.C.GREY2
  X.TX(xpvr + wpv / 2, w.yt + 3, mainAltName, X.FONT_S, X.TEXT_CENTER, color)
  X.RCF(xpvr, w.yt + hph, wpv, hph / 2, D.C.BLACK, 5)
  X.TX(xpvr + wpv / 2, w.yt + hph - 3, mainAltUnit, X.FONT_XS, X.TEXT_CENTER, color)
  local spn = D.UI.TASKS_ID and D.UI.TASKS_ID.DB1SPN
  local spnID = spn and spn.m
  do
    if spnID == "CMP" then
      if G.fm.pgg then
        if D.S.POS_DISTH then
          local distH = string.format("%d", D.S.POS_DISTH)
          local distU = D.S.POS_DISTH >= 1000 and "km" or "m"
          X.TX(hdgX, w.yt + 7, "HOME", X.FONT_XS, X.TEXT_LEFT, D.C.GREY1)
          X.TX(hdgX + 54, w.yt + 3, distH, X.FONT_S, X.TEXT_RIGHT, D.C.WHITE)
          X.TX(hdgX + 58, w.yt + 7, distU, X.FONT_XS, X.TEXT_LEFT, D.C.GREY1)
        end
      end
    else
      if D.S.DIR_GC then
        X.TX(hdgX, w.yt + 7, "GC", X.FONT_XS, X.TEXT_LEFT, D.C.GREY1)
        X.TX(hdgX + 60, w.yt + 3, math.floor(D.S.DIR_GC) .. D.UI.CHDEG, X.FONT_S, X.TEXT_RIGHT, D.C.WHITE)
      end
    end
    X.RCF(w.xl, yphb, w.w, hph, D.C.BLACK, 5)
    if not pitch then
      if roll then
        color = D.C.WHITE
        if roll ~= 0 then
          local x = xpvl + 5
          if roll < 0 then
            X.TRF(x, w.yb - 10, x + 5, w.yb - 5, x + 5, w.yb - 15, color)
          else
            X.TRF(x + 5, w.yb - 10, x, w.yb - 5, x, w.yb - 15, color)
          end
        end
        if roll then
          local disp = string.format("%3d", math.abs(roll)) or "- "
        end
        X.TX(xpvl + 15, yphb + 2, disp .. D.UI.CHDEG, X.FONT_S, X.TEXT_LEFT, color)
        if pitch ~= 0 then
          local x = xpvr - 15
          if pitch < 0 then
            X.TRF(x + 5, w.yb - 7, x, w.yb - 12, x + 10, w.yb - 12, color)
          else
            X.TRF(x + 5, w.yb - 12, x, w.yb - 7, x + 10, w.yb - 7, color)
          end
        end
        if pitch then
          local disp = string.format("%3d", math.abs(pitch)) or "- "
        end
        X.TX(xpvr - 17, yphb + 2, disp .. D.UI.CHDEG, X.FONT_S, X.TEXT_RIGHT, color)
      end
    end
    if auxSpeedSensor then
      X.RCF(w.xl, w.yb - 2 * hph, wpv, hph, D.C.BLACK, 5)
      X.TX(w.xl + wpv / 2, w.yb - 2 * hph, auxSpeedName, X.FONT_S, X.TEXT_CENTER, D.C.GREY1)
      X.TX(w.xl + wpv / 2, w.yb - hph - 6, auxSpeedUnit, X.FONT_XS, X.TEXT_CENTER, D.C.GREY1)
      X.TX(w.xl + wpv / 2, w.yb - hph + 3, auxSpeed, X.FONT_STD, X.TEXT_CENTER, D.C.WHITE)
    end
    if auxAltSensor then
      X.RCF(xpvr, w.yb - 2 * hph, wpv, hph, D.C.BLACK, 5)
      X.TX(xpvr + wpv / 2, w.yb - 2 * hph, auxAltName, X.FONT_S, X.TEXT_CENTER, D.C.GREY1)
      X.TX(xpvr + wpv / 2, w.yb - hph - 6, auxAltUnit, X.FONT_XS, X.TEXT_CENTER, D.C.GREY1)
      X.TX(xpvr + wpv / 2, w.yb - hph + 3, auxAlt, X.FONT_STD, X.TEXT_CENTER, D.C.WHITE)
    end
    if not D.S.TLM_ON then
      X.RCF(w.xl, w.yt, w.w, w.h, D.C.MD_B, D.UI.dimTLM)
    end
    return
  end
end
return

