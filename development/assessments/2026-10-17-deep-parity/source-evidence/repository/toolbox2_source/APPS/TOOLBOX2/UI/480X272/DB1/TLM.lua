-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "TLM.luac" was compiled with Lua 5.3 --

local G = ...
function T.d(w)
  local dt
  if G.fm.sxx and D.TLM.I.TX_QLY_CH1 then
    do
      local vD = {s = "SN19",
                      cbN = D.C.INB_ON,
                      cvN = D.C.INV_ON,
                      pc = true}
      if not D.S.TLM_ON then
        vD.vo = 0
        vD.vd = "TLM"
      end
      dt = D.UI.SNV(vD)
      local y = w.yt + (D.S.UI_THM_OV and 3 or 5)
      local vD = {}
      local t5 = {}
      vD.b = t5
      t5 = {}
      vD.v = t5
      t5 = {}
      vD.l = t5
      t5 = {}
      local t6 = w.xl + 62
      local t7 = y + 4
      local t8 = dt.unit
      local t9 = X.FONT_XS
      local t10 = X.TEXT_CENTER
      local t11 = dt.cv
      vD.u = t5
      if D.S.TLM_data and not D.S.TLM_ON or D.TLM.V.TX_QLY_CH1 <= 0 then
        vD.u = nil
        vD.v[1] = w.xl + 63
        vD.v[3] = (D.S.UI_THM_OV and "TLM") or "OFF" or ""
      end
      D.UI.DIT(vD)
    end
  else
    local cT = D.C.SNV_C
    local cB = D.C.SNB_C
    local label = D.S.UI_THM_OV and "TLM" or "TLM OFF"
    local x = D.TI.tick50 and "" and ""
    local y = D.S.UI_THM_OV and 49 or 37
    x = w.xl + y
    y = w.yt + (D.S.UI_THM_OV and 3 or 5)
    do
      X.RCF(w.xl, w.yt, w.w, w.h, cB)
      X.TX(x, y, label, X.FONT_S, X.TEXT_CENTER, cT)
    end
  end
  if not D.S.TLM_ON then
    X.RCF(w.xl, w.yt, w.w, w.h, D.C.MD_B, D.UI.dimTLM)
  end
  return
end
return

