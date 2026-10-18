-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "TLM.luac" was compiled with Lua 5.3 --

local G = ...
function T.i(w)
  local tasks = {{f = nil, w = {xl = w.xl, yt = w.yt, w = 108, h = 40}},
                 {f = nil, w = {xl = w.xl + 108, yt = w.yt, w = 172, h = 40}},
                 {f = nil, w = {xl = w.xl + 280, yt = w.yt, w = 108, h = 40}},
                 {f = nil, w = {xl = w.xl, yt = w.yt + 40, w = w.w, h = 216}},
                 {f = nil, w = {xl = w.xl, yt = w.yb - 27, w = 120, h = 28}},
                 {f = nil, w = {xl = w.xl + 120, yt = w.yb - 27, w = 268, h = 28}}}
  G.loadE(G.PUI .. "UITSKSET", tasks)
  T.topID = 1
  T.units = G.loadE(G.PLIBOS .. "/u" .. D.RD.OSID)
  T.lnDispShift = 1
  T.lnMax = 7
  T.sMax = T.lnMax * 3 - 1
  T.lnSpace = 23
  if G.fm.pgg then t2 = {"LIVE", "MIN", "MAX"} end
  T.svTypeL = t2 or {"LIVE"}
  if G.fm.pgg then t2 = {"", "Min", "Max"} end
  T.svTypeT = t2 or {""}
  T.svTypeN = 1
  T.svTypeS = ""
end
function T.e()
  if D.evt == D.K.EX then
    D.UI.MODS.nextID = "DBD"
    D.evt = 0
  end
  if D.evt == D.K.PN then
    T.svTypeN = G.next(T.svTypeN + 1, 1, #T.svTypeL, true)
    T.svTypeS = T.svTypeT[T.svTypeN]
    return true
  elseif D.evt == D.K.PP then
    T.svTypeN = G.next(T.svTypeN - 1, 1, #T.svTypeL, true)
    T.svTypeS = T.svTypeT[T.svTypeN]
    return true
  elseif #D.TLM.SN > T.sMax then
    if D.evt == D.K.RT then
      if T.topID < #D.TLM.SN - T.sMax then
        T.topID = G.next(T.topID + 1, 1, (#D.TLM.SN or 0) - T.lnMax + 1)
      end
    end
    if D.evt == D.K.LT then
      if T.topID < #D.TLM.SN - T.sMax + 1 then
        T.topID = G.next(T.topID - 1, 1)
      end
    end
  end
end
function T.d(w)
  local mxc = w.xl + math.floor(w.w / 2)
  local lnDispShift = math.min(#D.TLM.SN - T.lnMax + 1, T.lnDispShift)
  local cTxt
  if not D.S.MDL_RCP_ON then
    X.TX(mxc, w.yt + 47, "Set RC Link", X.FONT_STD, X.TEXT_CENTER, D.C.MD_V)
    X.TX(mxc, w.yt + 66, "in Config", X.FONT_STD, X.TEXT_CENTER, D.C.MD_V)
  elseif #D.TLM.SN == 0 then
    X.TX(mxc, w.yt + 47, "Discover telemetry", X.FONT_STD, X.TEXT_CENTER, D.C.MD_V)
    X.TX(mxc, w.yt + 66, "sensors in OS", X.FONT_STD, X.TEXT_CENTER, D.C.MD_V)
  else
    X.TX(w.xl + 10, w.yt + 12, D.S.RCP_pverName, X.FONT_S, X.TEXT_LEFT, D.C.MD_V)
    X.TX(w.xr - 93, w.yt + 12, "VALUES", X.FONT_S, X.TEXT_LEFT, D.C.MD_L)
    local svTypeName = D.S.TLM_ON or T.svTypeN == 1 or "LAST"
    svTypeName = T.svTypeL[T.svTypeN]
    X.TX(w.xr - 10, w.yt + 12, svTypeName, X.FONT_S, X.TEXT_RIGHT, D.C.MD_V)
    X.LN(w.xl + 133, w.yt + 40, w.xl + 133, w.yb - 28, X.PEN_DOTTED, D.C.MD_L2)
    X.LN(w.xl + 260, w.yt + 40, w.xl + 260, w.yb - 28, X.PEN_DOTTED, D.C.MD_L2)
    for i = T.topID, math.min(T.topID + T.sMax, #D.TLM.SN) do
      local snData, sVal = D.TLM.SN[i]
      if snData.sActive then
        local var = "rVal" .. T.svTypeS
        sVal = snData[var] or "-"
      end
      if type(sVal) == "table" then
        sVal = "multi"
      else
        if type(sVal) == "number" then
          sVal = tostring(sVal)
        end
      end
      local ci = i - T.topID + 1
      local y = w.yt + T.lnSpace + ((ci - 1) % T.lnMax + 1) * T.lnSpace
      local xsh = 10
      if ci > 2 * T.lnMax then
        xsh = 264
      elseif ci > T.lnMax then
        xsh = 137
      end
      local x = w.xl + xsh
      if ci < T.lnMax then
        X.LN(w.xl, y + T.lnSpace, w.xr, y + T.lnSpace, X.PEN_DOTTED, D.C.MD_L2)
      end
      local cLbl = snData.sActive and D.C.MD_L or D.C.INV_WR
      if snData.sActive then
        local cTxt = D.S.TLM_ON and D.C.MD_V
        cTxt = cTxt or D.C.MD_L or D.C.INV_WR
      end
      X.TX(x, y + 4, snData.pName or "-", X.FONT_S, X.TEXT_LEFT, cLbl)
      X.TX(x + (112 or 93), y + 1, sVal or "-", X.FONT_STD_BOLD, X.TEXT_RIGHT, cTxt)
      X.TX(x + 98, y + 8, D.UNITSB[snData.dUnit] or "", X.FONT_XS, X.TEXT_LEFT, cLbl)
    end
  end
  return
end
return

