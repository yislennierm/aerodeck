-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "SYS.luac" was compiled with Lua 5.3 --

local G = ...
function T.i(w)
  T.icLock = X.LMK(G.PGFXR .. "SYS_LOCK_MASK.jpg")
  T.icMute = X.LMK(G.PGFXR .. "SYS_MUTE_MASK.jpg")
end
function T.d(w)
  if D.evt == nil then
    X.RCF(w.xl, w.yt, 30, 35, D.C.INB_WR)
    local xo = D.S.UI_THM_OV and 12 or 8
    do
      X.MK(T.icLock, w.xl + xo, w.yt + 9, D.C.INV_WR)
    end
  end
  if D.UI.mute then
    local xo = D.S.UI_THM_OV and 38 or 38
    do
      X.RCF(w.xl + 31, w.yt, 30, 34, D.C.INB_WR)
      X.MK(T.icMute, w.xl + xo, w.yt + 9, D.C.INV_WR)
    end
  end
  if G.fm.sxx then
    if D.S.mspFcReady then
      local cTxt = D.S.mspReady and D.C.INV_ON
      cTxt = cTxt or D.C.INV_AL or D.C.INV_WR
    end
    do
      if D.S.mspFcReady then
        local cBkg = D.S.mspReady and D.C.INB_ON
        cBkg = cBkg or D.C.INB_AL or D.C.INB_WR
      end
      if D.S.mspTxReady then
        local xo = D.S.UI_THM_OV and 108 or 110
        X.RCF(w.xl + 91, w.yt, 38, 34, cBkg)
        X.TX(w.xl + xo, w.yt + 9, "MSP", X.FONT_S, X.TEXT_CENTER, cTxt)
      end
    end
  end
  if not D.S.TLM_ON then
    X.RCF(w.xl + 91, w.yt, 38, 34, D.C.MD_B, D.UI.dimTLM)
  end
  return
end
return

