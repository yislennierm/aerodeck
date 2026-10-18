-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "ABT.luac" was compiled with Lua 5.3 --

local G = ...
function T.i(w)
  local tasks = {{f = nil, w = {xl = w.xl, yt = w.yt, w = 110, h = 40}},
                 {f = nil, w = {xl = w.xl + 110, yt = w.yt, w = 168, h = 40}},
                 {f = nil, w = {xl = w.xl + 278, yt = w.yt, w = 110, h = 40}},
                 {f = nil, w = {xl = w.xl, yt = w.yt + 40, w = 225, h = 150}},
                 {f = nil, w = {xl = w.xl + 225, yt = w.yt + 40, w = 163, h = 120}},
                 {f = nil, w = {xl = w.xl + 225, yt = w.yt + 160, w = 163, h = 30}},
                 {f = nil, w = {xl = w.xl, yt = w.yb - 45, w = w.w, h = 46}}}
  G.loadE(G.PUI .. "UITSKSET", tasks)
  T.cup = X.LMK(G.PGFXR .. "ABT_CUP_MASK.jpg")
  T.fm2mSP = X.LBM(G.PGFXR .. "FM2M_SPLASH.png")
  T.mfgN = 1
  T.mfgData = {{name = "EdgeTX", logo = "ETX"}, {name = "BetaFlight", logo = "BF"}, {name = "iNav", logo = "INAV"}, {name = "ELRS", logo = "ELRS"}, {name = "Crossfire", logo = "CRSF"}, {name = "FrSky", logo = "FRS", xs = -10}}
  T.mfgName = "EdgeTX"
  T.mfgLogo = X.LBM(G.PGFXR .. "LG_ETX.png")
  T.logoXS = 0
  T.TS = D.TI.now
  T.delay = 200
  T.splashDelay = 400
  T.showSupporterDetail = false
end
function T.mfgLoad()
  local fName = G.PGFXR .. "LG_" .. T.mfgData[T.mfgN].logo .. ".png"
  T.mfgLogo = X.LBM(fName)
  T.mfgName = T.mfgData[T.mfgN].name
  T.logoXS = T.mfgData[T.mfgN].xs or 0
end
function T.e()
  if D.evt == D.K.EX then
    D.UI.MODS.nextID = "DBD"
    D.evt = 0
  elseif D.evt == D.K.PP then
    if D.AI.licenceDetail then
      T.showSupporterDetail = not T.showSupporterDetail
      D.evt = 0
    end
  elseif D.evt == D.K.PN then
    T.TS = D.TI.now
    T.mfgN = G.next(T.mfgN + 1, 1, #T.mfgData, true)
    T.mfgLoad()
  end
end
function T.d(w)
  local mxc = w.xl + math.floor(w.w / 2)
  local mxr = w.xl + w.w
  if D.TI.now > T.TS + T.delay then
    T.TS = D.TI.now
    T.mfgN = G.next(T.mfgN + 1, 1, #T.mfgData, true)
    T.mfgLoad()
  end
  X.TX(w.xl + 8, w.yt + 12, "FM2M ToolBox", X.FONT_S, X.TEXT_LEFT, D.C.MD_V)
  X.TX(mxr - 10, w.yt + 12, "ver " .. D.AI.VER .. " " .. D.AI.REL, X.FONT_S, X.TEXT_RIGHT, D.C.MD_V)
  X.BM(T.fm2mSP, w.xl, w.yt + 40)
  X.RCF(w.xl, w.yt + 40, 200, 24, D.C.BLACK, 8)
  X.TX(w.xl + 12, w.yt + 45, D.AI.SITE, X.FONT_S, X.TEXT_LEFT, D.C.WHITE)
  X.TX(w.xl + 310, w.yt + 45, "works with", X.FONT_S, X.TEXT_CENTER, D.C.MD_L)
  if T.mfgLogo then
    X.BM(T.mfgLogo, w.xl + 274 + T.logoXS, w.yt + 70)
    X.TX(w.xl + 310, w.yt + 130, T.mfgName, X.FONT_STD, X.TEXT_CENTER, D.C.MD_V)
  end
  local tier = G.fm.pgg and "PRO"
  tier = (tier or (G.fm.sxx and "SUP")) or nil
  if tier then
    X.TX(w.xl + 165, w.yt + 167, "Upgrade", X.FONT_S, X.TEXT_LEFT, D.C.MD_L)
    do
      local tw = X.TXS(tier, X.FONT_S) + 12
      X.RCF(w.xl + 225, w.yt + 160, tw, 30, D.C.INB_ON)
      X.TX(w.xl + 225 + tw / 2, w.yt + 167, tier, X.FONT_S, X.TEXT_CENTER, D.C.INV_ON)
    end
  end
  if G.fm.sxx then
    X.MK(T.cup, w.xl + 18, w.yb - 42, D.C.MD_V)
    local label = "JimB40 caffeinated by"
    local value = D.AI.un or "Unknown RC Maniac"
    do
      X.TX(w.xl + 70, w.yb - 40, label, X.FONT_S, X.TEXT_LEFT, D.C.MD_L)
      X.TX(w.xl + 70, w.yb - 24, value, X.FONT_S, X.TEXT_LEFT, D.C.MD_V)
    end
  else
    X.MK(T.cup, w.xl + 18, w.yb - 42, D.C.MD_V)
    X.TX(w.xl + 80, w.yb - 40, "FM2M is coffeeware", X.FONT_S, X.TEXT_LEFT, D.C.MD_V)
    X.TX(w.xl + 80, w.yb - 24, "Upgrade and support development", X.FONT_S, X.TEXT_LEFT, D.C.MD_V)
  end
  return
end
return

