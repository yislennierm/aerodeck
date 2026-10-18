-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFGRCL.luac" was compiled with Lua 5.3 --

local G = ...
T.pID = "RCL"
T.pN = "RC LINK"
local pverNameList = ((LCD_W > 480 and 300) or (LCD_W > 320 and 150)) or 120
T.dVxo = pverNameList
local setDefs = function(onChange)
  local pverID = pverIDList[T.cv.RCP_pv.v] or "OFF"
  local defs = G.loadE(G.PLIBTLM .. "TLMRLD", pverID)
  if onChange then
    T.cv.RL_RSI_L.v = defs.RSI_L[1]
  end
  T.cv.RL_RSI_L.m = defs.RSI_L[2]
  T.cv.RL_RSI_L.x = defs.RSI_L[3]
  T.cv.RL_RSI_L.u = defs.RSI_L[4]
  if onChange then
    T.cv.RL_RSI_C.v = defs.RSI_C[1]
  end
  T.cv.RL_RSI_C.m = defs.RSI_C[2]
  T.cv.RL_RSI_C.x = defs.RSI_C[3]
  T.cv.RL_RSI_C.u = defs.RSI_C[4]
  if onChange then
    T.cv.RL_RQL_L.v = defs.RQL_L[1]
  end
  T.cv.RL_RQL_L.m = defs.RQL_L[2]
  T.cv.RL_RQL_L.x = defs.RQL_L[3]
  T.cv.RL_RQL_L.u = defs.RQL_L[4]
  if onChange then
    T.cv.RL_RQL_C.v = defs.RQL_C[1]
  end
  T.cv.RL_RQL_C.m = defs.RQL_C[2]
  T.cv.RL_RQL_C.x = defs.RQL_C[3]
  T.cv.RL_RQL_C.u = defs.RQL_C[4]
end
T.cv = {}
T.cv.RCP_pv = {o = 1, l = "Protocol version", t = "L", lv = pverNameList}
T.cv.RL_RSI_L = {o = 2, l = "RSSI Low", t = "N", m = 1, x = 99, i = 1, f = "%0d", u = "%"}
T.cv.RL_RSI_C = {o = 3, l = "RSSI Critical", t = "N", m = 0, x = 98, i = 1, f = "%0d", u = "%"}
T.cv.RL_RQL_L = {o = 4, l = "RQLY Low", t = "N", m = 1, x = 99, i = 1, f = "%0d", u = "%"}
T.cv.RL_RQL_C = {o = 5, l = "RQLY Critical", t = "N", m = 0, x = 98, i = 1, f = "%0d", u = "%"}
T.cv.RL_SNR_L = {o = 6, l = "RSNR Low", t = "N", m = -5, x = 49, i = 1, f = "%0d", u = "dB"}
T.cv.RL_SNR_C = {o = 7, l = "RSNR Critical", t = "N", m = -6, x = 48, i = 1, f = "%0d", u = "dB"}
T.readDS()
setDefs()
function T.updateDisp()
  T.cv.RL_RSI_C.h = nil
  T.cv.RL_RSI_L.h = nil
  T.cv.RL_RQL_C.h = nil
  T.cv.RL_RQL_L.h = nil
  T.cv.RL_SNR_C.h = nil
  T.cv.RL_SNR_L.h = nil
  if D.S.RCP_pID == "FRS" and D.S.RCP_pverID == "ACCST" or D.S.RCP_pverID == "R9" then
    T.cv.RL_RQL_C.h = true
    T.cv.RL_RQL_L.h = true
    T.cv.RL_SNR_C.h = true
    T.cv.RL_SNR_L.h = true
  end
  if not G.fm.sxx then
    T.cv.RL_RSI_C.h = true
    T.cv.RL_RSI_L.h = true
    T.cv.RL_RQL_C.h = true
    T.cv.RL_RQL_L.h = true
    T.cv.RL_SNR_C.h = true
    T.cv.RL_SNR_L.h = true
  end
end
function T.cv.RCP_pv.onChange()
  setDefs(true)
end
function T.cv.RCP_pv.onSave()
  D.S.RCP_pv = T.cv.RCP_pv.v
  D.S.RCP_pverID = D.S.RCP_pverIDList[D.S.RCP_pv] or "OFF"
  D.S.RCP_pverName = D.S.RCP_pverNameList[D.S.RCP_pv] or ""
  table.insert(D.RINIT, {fn = G.PLIBTLM .. "RCPINIT"})
  table.insert(D.RINIT, {fn = G.PLIBTLM .. "TLMINIT"})
end
return

