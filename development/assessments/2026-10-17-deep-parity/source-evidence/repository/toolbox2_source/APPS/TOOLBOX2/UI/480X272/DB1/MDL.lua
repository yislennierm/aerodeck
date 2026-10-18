-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "MDL.luac" was compiled with Lua 5.3 --

local G = ...
function T.getModelSize(w)
  local bh = D.UI.MDL.modelGfx
  local bw, bh = Bitmap.getSize(D.UI.MDL.modelGfx)
  local ws = G.round((w.w - 40) / bw, 2)
  local hs = G.round((w.h - 15) / bh, 2)
  local wn = bw * ws
  local hn = bh * ws
  return {w = bw, s = (((bw * ws > w.w - 40 and hs) or (bw * ws <= w.w - 40 and (hn > w.h - 7 and hs))) and hs or scale)}
end
function T.i(w)
  T.modelSize = T.modelSize or T.getModelSize(w)
end
function T.d(w)
  local armStopOn = D.S.ARM_STOP_TLM or D.S.ARM_STOP_MSP
  local xc = w.xl + w.w / 2
  local cTxt = D.C.MD_V
  local cBkg = D.C.MD_B
  if armStopOn then
    cTxt = D.C.INV_WR
    cBkg = D.C.INB_WR
  end
  if D.S.UI_THM_OV then
    X.RCF(w.xl, w.yt, w.w, 35, cBkg)
    X.RCF(w.xl + 9, w.yt + 35, w.w - 18, 28, cBkg)
    if not D.S.TLM_ON then
      X.RCF(w.xl, w.yt, w.w, 35, D.C.MD_B, D.UI.dimTLM)
      X.RCF(w.xl + 9, w.yt + 35, w.w - 18, 28, D.C.MD_B, D.UI.dimTLM)
    end
  else
    X.RCF(w.xl, w.yt, w.w, w.h, cBkg)
    if not D.S.TLM_ON then
      X.RCF(w.xl, w.yt, w.w, w.h, D.C.MD_B, D.UI.dimTLM)
    end
  end
  if D.UI.MDL.modelGfx then
    X.BM(D.UI.MDL.modelGfx, w.xc - T.modelSize.w * T.modelSize.s / 2, w.yt + 10, T.modelSize.s * 100)
  end
  if armStopOn then
    local label = D.S.mspReady and D.S.ARM_STOP_LIST or "Arming disabled"
    X.RCF(w.xl, w.yt, w.w, 16, D.C.SNB_C, 7)
    if D.TI.tick50 then
      X.TX(w.xc, w.yt, label, X.FONT_S, X.TEXT_CENTER, D.C.SNV_C)
    end
  else
    X.TX(w.xc, w.yt, D.UI.MDL.modelName, X.FONT_S, X.TEXT_CENTER, cTxt)
  end
  return
end
return

