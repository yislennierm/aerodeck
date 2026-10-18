-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFGINDBF.luac" was compiled with Lua 5.3 --

local G = ...
T.pID = "INDBF"
T.pN = "BETAFLIGHT INDICATORS"
local listInd = LCD_W > 480 and 350
listInd = (listInd or (LCD_W > 320 and 170)) or 100
T.dVxo = listInd
listInd = {"Switch", [0] = "OFF"}
local listInd2 = {"Switch", [0] = "OFF"}
if G.fm.pgg then t7 = {1, 2, 3, [0] = 0} end
T.srcTypes = t7 or {1, 3, [0] = 0}
if G.fm.pgg then
  table.insert(listInd, "Logic Switch")
  table.insert(listInd2, "Logic Switch")
end
if G.fm.sxx then table.insert(listInd, "Telemetry") end
local listSwPos = {"up", "mid", "down", "not up", "not mid", "not down", [0] = "---"}
function T.updateSwDisplay(iName)
  local uiSrcType = T.cv["_" .. iName .. "_srct"].v
  local srcType = T.srcTypes and T.srcTypes[uiSrcType] or uiSrcType
  T.cv["_" .. iName .. "_swn"].h = srcType ~= 1 and true or nil
  T.cv["_" .. iName .. "_swp"].h = T.cv["_" .. iName .. "_swn"].v == 0 and true or nil
  T.cv["_" .. iName .. "_swp"].h = srcType ~= 1 and true or T.cv["_" .. iName .. "_swp"].h
  T.cv["_" .. iName .. "_lsn"].h = srcType ~= 2 and true or nil
  T.cv["_" .. iName .. "_swn"].dv = ((T.cv["_" .. iName .. "_swn"].v == 0 and "---") or (D.RD.SW[T.cv["_" .. iName .. "_swn"].v] and D.RD.SW[T.cv["_" .. iName .. "_swn"].v].cdv)) or "???"
  T.cv["_" .. iName .. "_swp"].dv = T.cv["_" .. iName .. "_swn"].v == 0 and "---" or T.cv["_" .. iName .. "_swp"].dv
end
T.cv = {}
T.cv._FMAC_srct = {o = 1, l = "Acro mode", v = 0, t = "L", lv = listInd}
T.cv._FMAC_swn = {o = 2, l = " switch name", v = 0, t = "NT", m = 0, x = #D.RD.SW, i = 1}
T.cv._FMAC_swp = {o = 3, l = " switch positon", v = 0, t = "L", lv = listSwPos}
T.cv._FMAC_lsn = {o = 4, l = " logical switch number", v = 1, t = "N", m = 1, x = 64, i = 1, f = "%1d"}
T.cv._FMHR_srct = {o = 5, l = "Horizon mode", v = 0, t = "L", lv = listInd}
T.cv._FMHR_swn = {o = 6, l = " switch name", v = 0, t = "NT", m = 0, x = #D.RD.SW, i = 1}
T.cv._FMHR_swp = {o = 7, l = " switch positon", v = 0, t = "L", lv = listSwPos}
T.cv._FMHR_lsn = {o = 8, l = " logical switch number", v = 1, t = "N", m = 1, x = 64, i = 1, f = "%1d"}
T.cv._FMAN_srct = {o = 9, l = "Angle mode", v = 0, t = "L", lv = listInd}
T.cv._FMAN_swn = {o = 10, l = " switch name", v = 0, t = "NT", m = 0, x = #D.RD.SW, i = 1}
T.cv._FMAN_swp = {o = 11, l = " switch positon", v = 0, t = "L", lv = listSwPos}
T.cv._FMAN_lsn = {o = 12, l = " logical switch number", v = 1, t = "N", m = 1, x = 64, i = 1, f = "%1d"}
T.cv._AM_srct = {o = 13, l = "Air mode", v = 0, t = "L", lv = listInd2}
T.cv._AM_swn = {o = 14, l = " switch name", v = 0, t = "NT", m = 0, x = #D.RD.SW, i = 1}
T.cv._AM_swp = {o = 15, l = " switch positon", v = 0, t = "L", lv = listSwPos}
T.cv._AM_lsn = {o = 16, l = " logical switch number", v = 1, t = "N", m = 1, x = 64, i = 1, f = "%1d"}
T.cv._TU_srct = {o = 17, l = "Tutrtle mode", v = 0, t = "L", lv = listInd2}
T.cv._TU_swn = {o = 18, l = " switch name", v = 0, t = "NT", m = 0, x = #D.RD.SW, i = 1}
T.cv._TU_swp = {o = 19, l = " switch positon", v = 0, t = "L", lv = listSwPos}
T.cv._TU_lsn = {o = 20, l = " logical switch number", v = 1, t = "N", m = 1, x = 64, i = 1, f = "%1d"}
G.frun(G.PLIBCFG .. "CFGSWDE", T, "FMAC", D.S.IN_FMAC_src)
G.frun(G.PLIBCFG .. "CFGSWDE", T, "FMHR", D.S.IN_FMHR_src)
G.frun(G.PLIBCFG .. "CFGSWDE", T, "FMAN", D.S.IN_FMAN_src)
G.frun(G.PLIBCFG .. "CFGSWDE", T, "AM", D.S.IN_AM_src)
G.frun(G.PLIBCFG .. "CFGSWDE", T, "TU", D.S.IN_TU_src)
function T.updateDisp()
  T.updateSwDisplay("FMAC")
  T.updateSwDisplay("FMHR")
  T.updateSwDisplay("FMAN")
  T.updateSwDisplay("AM")
  T.updateSwDisplay("TU")
  if not G.fm.sxx then
    T.cv._AM_srct.h = true
    T.cv._AM_swn.h = true
    T.cv._AM_swp.h = true
    T.cv._AM_lsn.h = true
    T.cv._TU_srct.h = true
    T.cv._TU_swn.h = true
    T.cv._TU_swp.h = true
    T.cv._TU_lsn.h = true
  end
end
function T.onSave()
  G.frun(G.PLIBCFG .. "CFGSWEN", T, "FMAC")
  G.frun(G.PLIBCFG .. "CFGSWEN", T, "FMHR")
  G.frun(G.PLIBCFG .. "CFGSWEN", T, "FMAN")
  G.frun(G.PLIBCFG .. "CFGSWEN", T, "AM")
  G.frun(G.PLIBCFG .. "CFGSWEN", T, "TU")
  G.frun(G.PLIBTB .. "INDINIT")
end
return

