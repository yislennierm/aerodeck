-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFG.luac" was compiled with Lua 5.3 --

local G = ...
G.loadE(G.PLIBCFG .. "CFGFNUI", T)
function T.i(w)
  local tasks = {}
  local t2 = {}
  t2.f = nil
  local t3 = {}
  t3.xl = w.xl
  t3.yt = w.yt
  t3.w = w.w
  t3.h = 30
  t2.w = t3
  t3 = {}
  t3.f = nil
  local t4 = {}
  t4.xl = w.xl
  t4.yt = w.yt + 30
  t4.w = w.w
  t4.h = 26
  t3.w = t4
  t4 = {}
  t4.f = nil
  local t5 = {}
  t5.xl = w.xl
  t5.yt = w.yt + 56
  t5.w = w.w
  t5.h = w.h - 56
  t4.w = t5
  G.loadE(G.PUI .. "UITSKSET", tasks)
  D.UI.cfgSelVarN = D.UI.cfgSelVarN or 1
  D.UI.cfgSelLineN = D.UI.cfgSelLineN or 1
  D.UI.cfgSelTopLineN = D.UI.cfgSelTopLineN or 1
  T.cPages = {}
  T.lnMax = 8
  T.lnSpace = 22
  T.lnDispOffset = 1
  T.lnSelID = 1
  T.eMod = false
  G.loadE(G.PLIBCFG .. "CFGUPDP")
  T.changePage()
end
function T.d(w)
  if T.eMod and T.ONFN then
    T.ONFN(G, F, D, X, "editValue")
  end
  X.TX(w.xl + 10, w.yt + (D.S.UI_THM_OV and 0 or 4) + 30, T.pN, X.FONT_STD_BOLD, X.TEXT_LEFT, D.C.MN_TN)
  X.TX(w.xr - 10, w.yt + (D.S.UI_THM_OV and 0 or 4) + 30, D.S.UI_CFG_PN .. "/" .. #D.MODCFG.pagesVisible, X.FONT_STD_BOLD, X.TEXT_RIGHT, D.C.MN_TN)
  local itlx = w.xl + 8
  local itvxl = w.xr - T.dVxo
  local itvxr = w.xr - 8
  local itvxc = itvxl + (itvxr - itvxl) / 2
  local lineMax = math.min(#T.cvV - D.UI.cfgSelTopLineN + 1, T.lnMax)
  for lineN = 1, lineMax do
    local vVN = D.UI.cfgSelTopLineN + lineN - 1
    local vN = T.cvV[vVN]
    local vD = T.cvS[vN]
    local yo = 57
    if vD then
      local vSel = vN == D.UI.cfgSelVarN
      if vSel then
        local ctx = T.eMod and D.C.MN_TE
        ctx = ctx or D.C.MN_TS or D.C.MN_TN
      end
      if vSel then
        local cbg = T.eMod and D.C.MN_BE
        cbg = cbg or D.C.MN_BS or nil
      end
      local ity = w.yt + yo + (lineN - 1) * T.lnSpace
      X.LN(w.xl, ity + T.lnSpace, w.xr, ity + T.lnSpace, X.PEN_DOTTED, D.C.MD_L2)
      if cbg then
        X.RCF(w.xl, w.yt + yo + (lineN - 1) * T.lnSpace, w.w, T.lnSpace, cbg)
      end
      X.TX(itlx, ity, vD.l, X.FONT_STD_BOLD, X.TEXT_LEFT, ctx)
      X.TX(itvxc, ity, vD.dv, X.FONT_STD_BOLD, X.TEXT_CENTER, ctx)
      if vSel and T.eMod then
        local cond = vD.m and vD.m
        cond = true
        cond = vD.v == true
        X.TX(itvxl, ity, "<" or "", X.FONT_STD_BOLD, X.TEXT_LEFT, ctx)
        cond = vD.v == false
        X.TX(itvxr, ity, ">" or "", X.FONT_STD_BOLD, X.TEXT_RIGHT, ctx)
      end
      X.LN(w.xl, ity + T.lnSpace, w.xr, ity + T.lnSpace, X.PEN_DOTTED, D.C.MD_L2)
    end
  end
  return
end

