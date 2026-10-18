-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFGMDL.luac" was compiled with Lua 5.3 --

local G = ...
T.pID = "MDL"
T.pN = "MODEL SETUP"
local list_MDL_RCP = ((LCD_W > 480 and 250) or (LCD_W > 320 and 150)) or 120
T.dVxo = list_MDL_RCP
local list_MDL_FC = D.RCP and D.RCP.pNames
T.list_SN = {"ON", [0] = "-"}
T.cv = {}
T.cv.MDL_RCP = {o = 1, l = "RC protocol", t = "L", lv = list_MDL_RCP}
T.cv.MDL_FC = {o = 2, l = "Flight controller", t = "L", lv = list_MDL_FC}
T.cv.MDL_BTV = {o = 3, l = "Battery sensor", t = "L", lv = T.list_SN}
T.cv.MDL_BTA = {o = 4, l = "Current sensor", t = "L", lv = T.list_SN}
T.cv.MDL_GYRO = {o = 5, l = "Gyroscope", t = "L", lv = T.list_SN}
T.cv.MDL_ACC = {o = 6, l = "Accelerometer", t = "L", lv = T.list_SN}
T.cv.MDL_BARO = {o = 7, l = "Barometer", t = "L", lv = T.list_SN}
T.cv.MDL_PITOT = {o = 8, l = "Pitot tube", t = "L", lv = T.list_SN}
T.cv.MDL_GPS = {o = 9, l = "GPS", t = "L", lv = T.list_SN}
T.cv.MDL_VTX = {o = 10, l = "VTX", t = "L", lv = T.list_SN}
T.readDS()
function T.updateDisp()
  if T.cv.MDL_RCP.v == 0 then
    T.cv.MDL_FC.h = true
    T.cv.MDL_BTV.h = true
    T.cv.MDL_BTA.h = true
    T.cv.MDL_GYRO.h = true
    T.cv.MDL_ACC.h = true
    T.cv.MDL_BARO.h = true
    T.cv.MDL_PITOT.h = true
    T.cv.MDL_GPS.h = true
    T.cv.MDL_VTX.h = true
  else
    if not G.fm.sxx then
      T.cv.MDL_FC.h = true
      T.cv.MDL_BTV.h = nil
      T.cv.MDL_BTA.h = true
      T.cv.MDL_GYRO.h = nil
      T.cv.MDL_ACC.h = true
      T.cv.MDL_BARO.h = true
      T.cv.MDL_PITOT.h = true
      T.cv.MDL_GPS.h = true
      T.cv.MDL_VTX.h = true
    else
      T.cv.MDL_FC.h = nil
      T.cv.MDL_BTV.h = nil
      T.cv.MDL_BTA.h = nil
      T.cv.MDL_GYRO.h = T.cv.MDL_RCP.v == 0
      T.cv.MDL_ACC.h = true
      T.cv.MDL_BARO.h = (G.fm.pgg and T.cv.MDL_RCP.v ~= 0) and false or true
      T.cv.MDL_PITOT.h = (G.fm.pgg and T.cv.MDL_RCP.v ~= 0) and false or true
      T.cv.MDL_GPS.h = T.cv.MDL_RCP.v == 0
      T.cv.MDL_VTX.h = T.cv.MDL_RCP.v == 0
      if T.cv.MDL_FC.v == 2 then
        T.cv.MDL_VTX.v = 0
        T.cv.MDL_VTX.h = true
      end
    end
  end
end
function T.cv.MDL_RCP.onSave()
  if T.cv.MDL_RCP.v == 0 then
    T.cv.MDL_FC.v = 0
    T.cv.MDL_BTV.v = 0
    T.cv.MDL_BTA.v = 0
    T.cv.MDL_GYRO.v = 0
    T.cv.MDL_ACC.v = 0
    T.cv.MDL_BARO.v = 0
    T.cv.MDL_PITOT.v = 0
    T.cv.MDL_GPS.v = 0
    T.cv.MDL_VTX.v = 0
  end
end
function T.cv.MDL_FC.onSave()
  if T.cv.MDL_FC.v == 2 then
    T.cv.MDL_VTX.v = 0
    D.S.MDL_VTX = 0
    D.S.MDL_VTX_ON = false
  end
  T.updateVars()
end
function T.onSave()
  if T.cv.MDL_FC.v == 2 then
    T.cv.MDL_VTX.v = 0
    D.S.MDL_VTX = 0
    D.S.MDL_VTX_ON = false
  end
  for k, v in pairs(T.cv) do
    D.S[k .. "_ON"] = v.v > 0
  end
  table.insert(D.RINIT, {fn = G.PLIBTB .. "DATAINIT"})
  table.insert(D.RINIT, {fn = G.PLIBFC .. "FCINIT"})
  table.insert(D.RINIT, {fn = G.PLIBTLM .. "RCPINIT"})
  table.insert(D.RINIT, {fn = G.PLIBGPS .. "GPSINIT"})
  table.insert(D.RINIT, {fn = G.PLIBTLM .. "TLMINIT"})
  table.insert(D.RINIT, {fn = G.PLIBMSP .. "MSPINIT"})
  table.insert(D.RINIT, {fn = G.PLIBVTX .. "VTXINIT"})
  table.insert(D.RINIT, {fn = G.PUI .. "MDUPD"})
  table.insert(D.RINIT, {fn = G.PLIBCFG .. "CFGUPDP"})
end
return

