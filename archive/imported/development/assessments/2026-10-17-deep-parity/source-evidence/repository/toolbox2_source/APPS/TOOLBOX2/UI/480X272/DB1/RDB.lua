-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "RDB.luac" was compiled with Lua 5.3 --

local G = ...
function T.d(w)
  local val, dt
  local cl = D.C.MD_L
  local cb = D.C.MD_B
  local cv = D.C.MD_V
  local vD = {}
  vD.s = "SN01"
  vD.cvN = D.C.INV_ON
  vD.cbN = D.C.INB_ON
  vD.cvL = D.C.INV_AL
  vD.cbL = D.C.INB_AL
  vD.cvC = D.C.INV_WR
  vD.cbC = D.C.INB_WR
  vD.data = true
  vD.pc = true
  vD.pcv = D.SEN.SN01c
  dt = D.UI.SNV(vD, true)
  local vx = D.S.UI_THM_OV and 123 or 151
  local t9 = {}
  local t10 = {}
  t9.b = t10
  t10 = {}
  t9.v = t10
  t10 = {}
  t9.l = t10
  t10 = {}
  t9.u = t10
  D.UI.DIT(t9)
  t9 = {}
  t9.x = w.xl + 15
  t9.y = w.yt + 22
  t9.w = D.S.UI_THM_OV and 108 or bw
  t9.h = 7
  t9.oh = true
  t9.t = true
  t9.bg = true
  vD = t9
  D.UI.DBAR(dt, vD)
  local pctx = D.S.UI_THM_OV and 86 or 105
  X.TX(w.xl + pctx, w.yt + 1, math.floor(dt.pct), X.FONT_S, X.TEXT_RIGHT, dt.cv)
  X.TX(w.xl + pctx + 1, w.yt + 4, "%", X.FONT_XS, X.TEXT_LEFT, dt.cv)
  return
end
return

