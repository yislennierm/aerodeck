-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFGFC.luac" was compiled with Lua 5.3 --

local G = ...
T.pID = "FC"
T.pN = "FLIGHT CONTROLLER"
local fw = LCD_W > 480 and 300
fw = (fw or (LCD_W > 320 and 180)) or 80
T.dVxo = fw
fw = {"BetaFlight"}
local fwID = {"BF"}
T.cv = {}
T.cv.FC_MSP_ON = {o = 1, l = " MSP", t = "S"}
T.cv.FC_MSP_VER = {o = 2, l = "  version", t = "N", m = 2, x = 2, i = 1, f = "%1d"}
T.cv.FC_MSP_ERR_INTVAL = {o = 3, l = "  FC status read every", t = "N", m = 0, x = 5, i = 1, f = "%1d", u = "s"}
T.cv.FC_MSP_VTX_INTVAL = {o = 4, l = "  VTX read every", t = "N", m = 0, x = 10, i = 1, f = "%1d", u = "s"}
T.readDS()
function T.updateDisp()
  if D.S.MDL_FC ~= 2 then local inav = true end
  inav = D.S.FC_FW_ID == "IN"
  T.cv.FC_MSP_VER.v = 2
  T.cv.FC_MSP_VER.h = true
  T.cv.FC_MSP_ERR_INTVAL.h = T.cv.FC_MSP_ON.v == 0 and true or nil
  T.cv.FC_MSP_VTX_INTVAL.h = (T.cv.FC_MSP_ON.v == 0 or inav) and true or nil
  local cond = D.S.FC_ON
  T.cv.FC_MSP_ON.h = cond and true or nil
  T.cv.FC_MSP_VER.h = cond and true or T.cv.FC_MSP_VER.h
  T.cv.FC_MSP_ERR_INTVAL.h = cond and true or T.cv.FC_MSP_ERR_INTVAL.h
  T.cv.FC_MSP_VTX_INTVAL.h = cond and true or T.cv.FC_MSP_VTX_INTVAL.h
end
function T.cv.FC_MSP_ON.onSave()
  table.insert(D.RINIT, {fn = G.PLIBMSP .. "MSPINIT"})
end
T.cv.FC_MSP_VER.onSave = T.cv.FC_MSP_ON.onSave
return

