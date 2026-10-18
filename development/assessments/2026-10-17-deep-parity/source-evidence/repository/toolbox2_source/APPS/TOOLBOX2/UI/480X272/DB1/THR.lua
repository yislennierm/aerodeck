-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "THR.luac" was compiled with Lua 5.3 --

local G = ...
function T.d(w)
  local thrValV = getValue("thr")
  local thrVal = math.floor((thrValV + 1024) / 20.4799995422363)
  local limValRaw = 100
  local limVal = 100
  local limThrMin = 0
  local limThrMax = 100
  local gaugeW = D.S.IND_THL and 45 or 107
  local gaugeH = 9
  if G.fm.sxx then
    limValRaw = D.S.IND_THL
    if limValRaw ~= nil then
      do
        local limValRawNorm = math.min(math.max(limValRaw, -1024), 1024)
        limVal = math.floor((limValRawNorm + 1024) / 20.4799995422363)
      end
    end
    limThrMin = 0
    limThrMax = math.floor(limVal * (100 - limThrMin) / 100 + limThrMin)
  end
  local gaugeLimW = math.max(math.floor(limThrMax * gaugeW / 100), 2)
  local barW = math.max(math.floor(gaugeLimW * thrVal / 100) - 1, 1)
  local color = D.C.MD_V
  if not D.S.ARMED and D.S.THR_CUT or D.S.IND_TC then
    X.RCF(w.xl, w.yt, 42, 34, D.C.INB_WR)
    local xo = D.S.UI_THM_OV and 24 or 21
    do
      X.TX(w.xl + xo, w.yt + 8, "THR", X.FONT_XXS, X.TEXT_CENTER, D.C.INV_WR)
      X.TX(w.xl + xo, w.yt + 16, "CUT", X.FONT_XXS, X.TEXT_CENTER, D.C.INV_WR)
      color = D.C.MD_L
    else
      X.RCF(w.xl, w.yt, 42, 34, D.C.MD_L)
      X.TX(w.xl + 35, w.yt + 9, "THR", X.FONT_S, X.TEXT_RIGHT, D.C.MD_B)
    end
    X.TX(w.xl + 71, w.yt + 7, thrVal, X.FONT_STD, X.TEXT_RIGHT, color)
    X.TX(w.xl + 72, w.yt + 10, "%", X.FONT_S, X.TEXT_LEFT, color)
    if limVal < 100 then
      X.RC(w.xl + 86, w.yt + 14, gaugeW, gaugeH, D.C.MD_L, X.PEN_DOTTED)
    end
    X.GA(w.xl + 86, w.yt + 14, gaugeLimW, gaugeH, barW, gaugeLimW, X.PEN_SOLID, color)
    if D.S.IND_THL then
      local cVal = limVal < 99 and D.C.INV_AL or D.C.MD_B
      if limVal < 100 then
        X.RCF(w.xl + 135, w.yt, 66, 34, D.C.INB_AL)
        X.TX(w.xl + 173, w.yt + 9, "LIM", X.FONT_S, X.TEXT_LEFT, D.C.INV_AL)
        X.TX(w.xl + 158, w.yt + 10, "%", X.FONT_S, X.TEXT_LEFT, cVal)
      else
        X.RCF(w.xl + 135, w.yt, 66, 34, D.C.MD_L)
        X.TX(w.xl + 173, w.yt + 9, "LIM", X.FONT_S, X.TEXT_LEFT, D.C.MD_B)
        limVal = ""
      end
      X.TX(w.xl + 157, w.yt + 7, tostring(limVal), X.FONT_STD, X.TEXT_RIGHT, cVal)
    end
    return
  end
end
return

