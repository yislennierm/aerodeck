-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFGBAT.luac" was compiled with Lua 5.3 --

local G = ...
T.pID = "BAT"
T.pN = "MODEL BATTERY"
T.dVxo = ((LCD_W > 480 and 300) or (LCD_W > 320 and 170)) or 115
T.cv = {}
T.cv.BT_CELL_NOPWR = {o = 1, l = "Cell \"no pwr\" voltage", t = "N", m = 2, x = 2.70000004768372, i = 0.100000001490116, f = "%.1f", u = "V"}
T.cv.BT_CELL_MIN = {o = 2, l = "Cell min voltage", t = "N", m = 2, x = 4.30000019073486, i = 0.100000001490116, f = "%.1f", u = "V"}
T.cv.BT_CELL_CRIT = {o = 3, l = "Cell critical voltage", t = "N", m = 3, x = 4, i = 0.100000001490116, f = "%.1f", u = "V"}
T.cv.BT_CELL_LOW = {o = 4, l = "Cell low voltage", t = "N", m = 3.09999990463257, x = 4.09999990463257, i = 0.100000001490116, f = "%.1f", u = "V"}
T.cv.BT_CELL_MAX = {o = 5, l = "Cell max voltage", t = "N", m = 2.29999995231628, x = 4.59999990463257, i = 0.100000001490116, f = "%.1f", u = "V"}
T.cv.BT_CELL_WARN_TYPE = {o = 6, l = "Cell alerts type", t = "L", lv = {"Visual & Sound", "Visual & Haptic", "All", [0] = "Visual only"}}
T.cv.BT_CELL_WARN_SND = {o = 7, l = " audible alerts type", t = "L", lv = {"Critical only", "Critical & Low"}}
T.readDS()
function T.updateDisp()
  T.cv.BT_CELL_WARN_SND.h = T.cv.BT_CELL_WARN_TYPE.v == 0 and true or nil
end
function T.cv.BT_CELL_MIN.onChange()
  if T.cv.BT_CELL_MIN.v >= T.cv.BT_CELL_MAX.v - 0.300000011920929 then
    T.cv.BT_CELL_MIN.v = T.cv.BT_CELL_MAX.v - 0.300000011920929
  end
  if T.cv.BT_CELL_NOPWR.v >= T.cv.BT_CELL_MIN.v - 0.300000011920929 then
    T.cv.BT_CELL_NOPWR.v = T.cv.BT_CELL_MIN.v - 0.300000011920929
  end
  T.cv.BT_CELL_NOPWR.x = T.cv.BT_CELL_MIN.v - 0.300000011920929
  if T.cv.BT_CELL_CRIT.v <= T.cv.BT_CELL_MIN.v + 0.100000001490116 then
    T.cv.BT_CELL_CRIT.v = T.cv.BT_CELL_MIN.v + 0.100000001490116
  end
  T.cv.BT_CELL_CRIT.m = T.cv.BT_CELL_MIN.v + 0.100000001490116
  if T.cv.BT_CELL_LOW.v <= T.cv.BT_CELL_MIN.v + 0.200000002980232 then
    T.cv.BT_CELL_LOW.v = T.cv.BT_CELL_MIN.v + 0.200000002980232
  end
  T.cv.BT_CELL_MAX.m = T.cv.BT_CELL_MIN.v + 0.200000002980232
end
function T.cv.BT_CELL_MAX.onChange()
  if T.cv.BT_CELL_MAX.v <= T.cv.BT_CELL_MIN.v + 0.300000011920929 then
    T.cv.BT_CELL_MAX.v = T.cv.BT_CELL_MIN.v + 0.300000011920929
  end
  if T.cv.BT_CELL_CRIT.v >= T.cv.BT_CELL_MAX.v - 0.200000002980232 then
    T.cv.BT_CELL_CRIT.v = T.cv.BT_CELL_MAX.v - 0.200000002980232
  end
  T.cv.BT_CELL_CRIT.x = T.cv.BT_CELL_MAX.v - 0.200000002980232
  if T.cv.BT_CELL_LOW.v >= T.cv.BT_CELL_MAX.v - 0.100000001490116 then
    T.cv.BT_CELL_LOW.v = T.cv.BT_CELL_MAX.v - 0.100000001490116
  end
  T.cv.BT_CELL_LOW.x = T.cv.BT_CELL_MAX.v - 0.100000001490116
end
function T.cv.BT_CELL_WARN_TYPE.onChange()
  if T.cv.BT_CELL_WARN_TYPE.v == 0 then
    T.cv.BT_CELL_WARN_SND.v = 0
  end
end
function T.cv.BT_CELL_CRIT.onChange()
  if T.cv.BT_CELL_CRIT.v >= T.cv.BT_CELL_LOW.v then
    T.cv.BT_CELL_LOW.v = T.cv.BT_CELL_CRIT.v + T.cv.BT_CELL_LOW.i
  end
end
function T.cv.BT_CELL_LOW.onChange()
  if T.cv.BT_CELL_LOW.v <= T.cv.BT_CELL_CRIT.v then
    T.cv.BT_CELL_CRIT.v = T.cv.BT_CELL_LOW.v - T.cv.BT_CELL_CRIT.i
  end
end
return

