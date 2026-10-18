-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFGVTX.luac" was compiled with Lua 5.3 --

local G = ...
T.pID = "VTX"
T.pN = "VTX"
local list_VTX_CONN_TYPE = LCD_W > 480 and 300
list_VTX_CONN_TYPE = (list_VTX_CONN_TYPE or (LCD_W > 320 and 150)) or 120
T.dVxo = list_VTX_CONN_TYPE
list_VTX_CONN_TYPE = {[0] = "None",
                      [1] = "FC MSP",
                      [2] = "TBS RX"}
T.cv = {}
T.cv.VTX_CONN_TYPE = {o = 1, l = " VTX connection", t = "L", lv = list_VTX_CONN_TYPE}
T.cv.VTX_MODEL = {o = 2, l = "  VTX model", t = "L", lv = list_VTX_MODEL}
T.cv.VTX_PROXY_ON = {o = 3, l = "  proxy", t = "S"}
T.cv.VTX_FRQ_RANGE = {o = 4, l = "Frequency range", t = "L", lv = {"ALL (5600-5900)", "EU (5650-5850)", "US (5650-5925)"}}
T.readDS()
function T.updateDisp()
  T.cv.VTX_MODEL.h = T.cv.VTX_CONN_TYPE.v <= 1
  T.cv.VTX_PROXY_ON.h = T.cv.VTX_CONN_TYPE.v ~= 1
  T.cv.VTX_FRQ_RANGE.h = not D.S.MDL_VTX_ON
end
function T.cv.VTX_CONN_TYPE.onChange()
  if T.cv.VTX_CONN_TYPE.v == 2 then
    T.cv.VTX_MODEL.v = 1
    T.cv.VTX_MODEL.x = nil
    T.cv.VTX_PROXY_ON.v = 0
  elseif T.cv.VTX_CONN_TYPE.v == 1 then
    T.cv.VTX_MODEL.v = 1
    T.cv.VTX_MODEL.x = nil
    T.cv.VTX_PROXY_ON.v = 1
  elseif T.cv.VTX_CONN_TYPE.v == 0 then
    T.cv.VTX_MODEL.v = 1
    T.cv.VTX_MODEL.x = nil
    T.cv.VTX_PROXY_ON.v = 0
  end
end
function T.cv.VTX_CONN_TYPE.onSave()
  table.insert(D.RINIT, {fn = G.PLIBVTX .. "VTXINIT"})
  table.insert(D.RINIT, {fn = G.PUI .. "MDUPD"})
  table.insert(D.RINIT, {fn = G.PLIBCFG .. "CFGUPDP"})
end
return

