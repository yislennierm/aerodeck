-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "INDUPD.luac" was compiled with Lua 5.3 --

local G = ...
function F.SN_IND()
  for indName, swID in pairs((D.IND_SW or {})) do
    local swVal = getSwitchValue(swID)
    D.S["IND_" .. indName] = swVal
  end
  for indName, srcID in pairs((D.IND_SR or {})) do
    D.S["IND_" .. indName] = getValue(srcID)
  end
  if D.S.IND_AR ~= nil then
    D.S.ARMED = D.S.IND_AR
  end
  if D.S.FC_FW_ID == "IN" then
    local fm = D.S.FC_FM
    D.S.IND_AM = fm == "AIR"
    D.S.IND_TU = fm == "TURT"
    D.S.IND_RTH = fm == "RTH" or fm == "WRTH"
    return
  end
  if D.S.IND_FMAC ~= nil or D.S.IND_FMHR ~= nil or D.S.IND_FMAN ~= nil then
    D.S.FC_FM = nil
    D.S.FC_FM_NAME = nil
    if D.S.IND_FMAC then
      D.S.FC_FM = "ACRO"
    else
      if D.S.IND_FMHR then
        D.S.FC_FM = "HOR"
      else
        if D.S.IND_FMAN then
          D.S.FC_FM = "STAB"
        end
      end
    end
    if D.S.FC_FM then
      D.S.FC_FM_NAME = D.S.FC_FM_MODES[D.S.FC_FM] or D.S.FC_FM
    end
  end
  return
end
return

