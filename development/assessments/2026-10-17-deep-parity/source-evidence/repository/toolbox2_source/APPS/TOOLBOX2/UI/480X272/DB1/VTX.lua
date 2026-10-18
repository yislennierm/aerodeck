-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "VTX.luac" was compiled with Lua 5.3 --

local G = ...
function T.d(w)
  local l1, l2, cLbl, cTxt, cBkg
  if not G.fm.sxx then
    X.RCF(w.xl, w.yt, w.w, w.h, D.C.MD_B)
    return
  end
  if not D.S.MDL_RCP_ON then
    l1, l2 = "Config", "RC Link"
  elseif D.S.MDL_FC ~= 2 then
    if D.S.FC_FW_ID == "IN" then
    end
  else
    l1, l2 = "", ""
  end
  cLbl = D.C.MD_L
  cTxt = D.C.MD_V
  cBkg = D.C.MD_B
  if D.VTX and D.VTX.type then
    local vtxType = string.sub(D.VTX.type, 1, 3) or "FC" or "TBS" or ""
  end
  if l1 or l2 then
    X.RCF(w.xl, w.yt, w.w, w.h, cBkg)
    if not D.S.UI_THM_OV then
      X.TX(w.xl + 5, w.yt + 2, "VTX", X.FONT_S, X.TEXT_LEFT, cTxt)
    end
    X.TX(w.xl + 43, w.yt + 2, vtxType, X.FONT_S, X.TEXT_LEFT, cTxt)
    X.TX(w.xl + 110, w.yt + 1, l1, X.FONT_S, X.TEXT_CENTER, cTxt)
    X.TX(w.xl + 110, w.yt + 16, l2, X.FONT_S, X.TEXT_CENTER, cTxt)
  else
    if D.VTX.ready then
      if D.VTX.pwOn then
        do
          local on = not D.VTX.sPIT
        end
        if on then
          local lpd = D.S.ARMED or D.VTX.sPwID and D.VTX.sPwID > 1 and D.VTX.sLPD
          cLbl = D.C.INL_ON
          cTxt = D.C.INV_ON
          cBkg = D.C.INB_ON
        else
          cLbl = D.C.INL_WR
          cTxt = D.C.INV_WR
          cBkg = D.C.INB_WR
        end
      end
    end
    X.RCF(w.xl, w.yt, w.w, w.h, cBkg)
    if not D.S.UI_THM_OV then
      X.TX(w.xl + 5, w.yt + 2, "VTX", X.FONT_S, X.TEXT_LEFT, cTxt)
    end
    X.TX(w.xl + 43, w.yt + 2, D.VTX.type and string.sub(D.VTX.type, 1, 3) or "", X.FONT_S, X.TEXT_LEFT, cTxt)
    X.TX(w.xl + 43, w.yt + 16, D.VTX.dSrcT or "", X.FONT_S, X.TEXT_LEFT, cTxt)
    do
      local sPwMW, sUnit, sX = "", "", 142
      if D.VTX.sPwMW then
        if type(D.VTX.sPwMW) == "number" then
          if D.VTX.sPwMW < 1000 then
            sPwMW = D.VTX.sPwMW
            sUnit = "mW"
          else
            sPwMW = math.floor(tonumber(D.VTX.sPwMW) / 1000)
            sUnit = "W"
            sX = 154
          end
        else
          sX = 164
          sPwMW = tostring(D.VTX.sPwMW)
        end
      else
        local t10 = D.VTX.sPwID and "ID:" .. D.VTX.sPwID
        sPwMW = ""
      end
      X.TX(w.xl + sX, w.yt + 16, sPwMW, X.FONT_S, X.TEXT_RIGHT, cTxt)
      X.TX(w.xl + 168, w.yt + 16, sUnit, X.FONT_S, X.TEXT_RIGHT, cLbl)
      if D.VTX.sLPD then
        X.TRF(w.xl + 107, w.yt + 22, w.xl + 113, w.yt + 22, w.xl + 110, w.yt + 27, cTxt)
      end
      X.TX(w.xl + 71, w.yt + 3, D.VTX.chName or "", X.FONT_L, X.TEXT_LEFT, cTxt)
      X.TX(w.xl + 132, w.yt + 2, D.VTX.sFRQ or "", X.FONT_S, X.TEXT_RIGHT, cTxt)
      X.TX(w.xl + 162, w.yt + 2, "MHz", X.FONT_S, X.TEXT_RIGHT, cLbl)
      if not D.S.TLM_ON then
        X.RCF(w.xl + 37, w.yt + 0, w.xl + 137, w.yt + 36, D.C.MD_B, D.UI.dimTLM)
      end
    end
  end
  return
end
return

