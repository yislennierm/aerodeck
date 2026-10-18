-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "BFV.luac" was compiled with Lua 5.3 --

local G = ...
T.battType = {"LiPo", "LiIon"}
local bF = G.split(D.CFGSTR.BTF, "|")
T.favs = {}
T.favs[0] = {type = 99, s = 0, capa = 0, id = 0}
T.selN = 0
for i = 1, 5 do
  local icfg = i * 3 - 2
  local favID = tonumber(bF[icfg])
  if favID and favID > 0 then
    T.favs[#T.favs + 1] = {}
    T.favs[#T.favs].bt = tonumber(bF[icfg])
    T.favs[#T.favs].s = tonumber(bF[icfg + 1])
    T.favs[#T.favs].capa = tonumber(bF[icfg + 2])
    T.favs[#T.favs].id = i
    if i == D.S.BT_FAV_SEL then
      T.selN = #T.favs
    end
  end
end
function T.e()
  if D.evt == D.K.EN then
    D.S.BT_FAV_SEL = T.favs[T.selN].id
    D.S.BT_FAV_CELLS = T.selN == 0 and 0 or T.favs[T.selN].s
    D.S.BT_FAV_CAPA = T.selN == 0 and 0 or T.favs[T.selN].capa
    G.loadE(G.PLIBCFG .. "CFGUPD", "BTFS")
    return true
  elseif D.evt == D.K.RT then
    T.selN = G.next(T.selN + 1, 0, #T.favs, true, true)
    return true
  elseif D.evt == D.K.LT then
    T.selN = G.next(T.selN - 1, 0, #T.favs, true, true)
    return true
  end
end
function T.d(w)
  local xo, yo
  local bw = 96
  local bh = 32
  X.TX(w.xc, w.yt + 5, "Battery Pack connected", X.FONT_S, X.TEXT_CENTER, D.C.MD_L)
  for i = 0, 5 do
    xo = w.xl + (i < 3 and 8 or 114)
    yo = w.yt + 29 + i % 3 * 37
    local favID = T.favs[i] and T.favs[i].id or 0
    local cBkg = T.selN == i and D.C.MD_V
    cBkg = (cBkg or (D.S.BT_FAV_SEL == favID and D.C.MD_L)) or D.C.MD_B
    local cFrm = T.selN == i and D.C.MD_V
    cFrm = (cFrm or (D.S.BT_FAV_SEL == favID and D.C.MD_L)) or D.C.MD_L2
    local cTxt = T.selN == i and D.C.MD_B
    cTxt = (cTxt or (D.S.BT_FAV_SEL == favID and D.C.MD_B)) or D.C.MD_V
    local cLbl = T.selN == i and D.C.MD_B
    cLbl = (cLbl or (D.S.BT_FAV_SEL == favID and D.C.MD_B)) or D.C.MD_L
    if i <= #T.favs then
      X.RCF(xo, yo, bw, bh, cBkg)
      X.RC(xo, yo, bw, bh, cFrm)
      X.RCF(xo + bw, yo + 6, 4, 20, cFrm)
      if T.selN == i then
        X.RC(xo, yo, bw, bh, cBkg)
        X.RCF(xo + bw, yo + 6, 4, 20, cBkg)
      end
      if i > 0 then
        local battType = T.battType[T.favs[i].bt]
        local battCapa = T.favs[i].capa
        local unit = "mAh"
        local capaVal = tonumber(battCapa)
        if i > 0 and capaVal > 999 then
          battCapa = string.format("%.3f", capaVal / 1000)
        end
        X.TX(xo + 3, yo + 1, battType, X.FONT_S, X.TEXT_LEFT, cTxt)
        X.TX(xo + 61, yo + 1, T.favs[i].s, X.FONT_S, X.TEXT_RIGHT, cTxt)
        X.TX(xo + 64, yo + 1, "S", X.FONT_S, X.TEXT_LEFT, cTxt)
        X.TX(xo + 61, yo + 15, battCapa, X.FONT_S, X.TEXT_RIGHT, cTxt)
        X.TX(xo + 64, yo + 15, unit, X.FONT_S, X.TEXT_LEFT, cTxt)
      else
        X.TX(xo + 48, yo + 1, "config", X.FONT_S, X.TEXT_CENTER, cTxt)
        X.TX(xo + 48, yo + 14, "auto sense", X.FONT_S, X.TEXT_CENTER, cTxt)
      end
    end
  end
  return
end
return

