-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFGIND.luac" was compiled with Lua 5.3 --

local G = ...
T.pID = "IND"
T.pN = "INDICATORS"
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
local listSrc = {}
for i = 1, #D.RD.PT do
  table.insert(listSrc, D.RD.PT[i])
end
for i = 1, #D.RD.SL do
  table.insert(listSrc, D.RD.SL[i])
end
for i = 1, #D.RD.TR do
  table.insert(listSrc, D.RD.TR[i])
end
T.cv = {}
T.cv._AR_srct = {o = 1, l = "Arm indicator", v = 0, t = "L", lv = listInd}
T.cv._AR_swn = {o = 2, l = " switch name", v = 0, t = "NT", m = 0, x = #D.RD.SW, i = 1}
T.cv._AR_swp = {o = 3, l = " switch positon", v = 0, t = "L", lv = listSwPos}
T.cv._AR_lsn = {o = 4, l = " logical switch number", v = 1, t = "N", m = 1, x = 64, i = 1, f = "%1d"}
T.cv._TC_srct = {o = 5, l = "Throttle Cut indicator", v = 0, t = "L", lv = listInd2}
T.cv._TC_swn = {o = 6, l = " switch name", v = 0, t = "NT", m = 0, x = #D.RD.SW, i = 1}
T.cv._TC_swp = {o = 7, l = " switch positon", v = 0, t = "L", lv = listSwPos}
T.cv._TC_lsn = {o = 8, l = " logical switch number", v = 1, t = "N", m = 1, x = 64, i = 1, f = "%.0d"}
T.cv._TL_srct = {"NT", o = 9, l = "Throttle Limiter", v = 0, t = "NT", m = 0, x = #listSrc, i = 1}
T.cv._TMR_host = {o = 10, l = "Arm Timer host", v = 0, t = "L", lv = {"ToolBox", [0] = "OS"}}
T.cv._TMR_no = {o = 11, l = " Timer used", v = 1, t = "L", lv = {"Timer 1", "Timer 2", "Timer 3"}}
G.frun(G.PLIBCFG .. "CFGSWDE", T, "AR", D.S.IN_AR_src)
G.frun(G.PLIBCFG .. "CFGSWDE", T, "TC", D.S.IN_TC_src)
G.frun(G.PLIBCFG .. "CFGSRDE", T, "TL", D.S.IN_TL_src)
T.cv._TMR_host.v = D.S.TMR_host
T.cv._TMR_no.v = D.S.TMR_no
function T.updateDisp()
  local arSrcType = T.srcTypes and T.srcTypes[T.cv._AR_srct.v] or T.cv._AR_srct.v
  local tcSrcType = T.srcTypes and T.srcTypes[T.cv._TC_srct.v] or T.cv._TC_srct.v
  T.cv._AR_swn.h = arSrcType ~= 1 and true or nil
  T.cv._AR_swp.h = T.cv._AR_swn.v == 0 and true or nil
  T.cv._AR_swp.h = arSrcType ~= 1 and true or T.cv._AR_swp.h
  T.cv._AR_lsn.h = arSrcType ~= 2 and true or nil
  T.cv._AR_swn.dv = ((T.cv._AR_swn.v == 0 and "---") or (D.RD.SW[T.cv._AR_swn.v] and D.RD.SW[T.cv._AR_swn.v].cdv)) or "???"
  T.cv._AR_swp.dv = T.cv._AR_swn.v == 0 and "---" or T.cv._AR_swp.dv
  T.cv._TC_swn.h = tcSrcType ~= 1 and true or nil
  T.cv._TC_swp.h = T.cv._TC_swn.v == 0 and true or nil
  T.cv._TC_swp.h = tcSrcType ~= 1 and true or T.cv._TC_swp.h
  T.cv._TC_lsn.h = tcSrcType ~= 2 and true or nil
  T.cv._TC_swn.dv = ((T.cv._TC_swn.v == 0 and "---") or (D.RD.SW[T.cv._TC_swn.v] and D.RD.SW[T.cv._TC_swn.v].cdv)) or "???"
  T.cv._TC_swp.dv = T.cv._TC_swn.v == 0 and "---" or T.cv._TC_swp.dv
  if (T.cv._TL_srct.v ~= 0) or not "OFF" then
  end
  T.cv._TL_srct.dv = ((listSrc[T.cv._TL_srct.v] and listSrc[T.cv._TL_srct.v].cdv) or (listSrc[T.cv._TL_srct.v] and listSrc[T.cv._TL_srct.v].cdv)) or "???"
  if not G.fm.sxx then
    T.cv._TC_srct.h = true
    T.cv._TC_swn.h = true
    T.cv._TC_swp.h = true
    T.cv._TC_lsn.h = true
    T.cv._TL_srct.h = true
    T.cv._TMR_host.h = true
    T.cv._TMR_no.h = true
  end
end
function T.onSave()
  G.frun(G.PLIBCFG .. "CFGSWEN", T, "AR")
  G.frun(G.PLIBCFG .. "CFGSWEN", T, "TC")
  G.frun(G.PLIBCFG .. "CFGSREN", T, "TL", T.cv._TL_srct.v, listSrc[T.cv._TL_srct.v])
  D.S.TMR_host = T.cv._TMR_host.v
  D.S.TMR_no = T.cv._TMR_no.v
  table.insert(D.RINIT, {fn = G.PLIBTB .. "INDINIT"})
end
return

