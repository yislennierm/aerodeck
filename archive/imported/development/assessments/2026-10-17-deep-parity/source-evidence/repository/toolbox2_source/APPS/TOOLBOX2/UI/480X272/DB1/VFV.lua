-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "VFV.luac" was compiled with Lua 5.3 --

local G = ...
function T.i()
  local vfCfg = T.selN or 0
  T.selN = vfCfg
  vfCfg = G.split(D.CFGSTR.VTXF, "|")
  T.favs = {}
  for i, v in ipairs(vfCfg) do
    if tonumber(v) > 0 then
      T.favs[#T.favs + 1] = tonumber(v)
    end
  end
  T.selN = T.selN > #T.favs and 0 or T.selN
  T.vtxFavInit = nil
end
function T.e()
  if D.evt == D.K.EN then
    return true
  elseif D.evt == D.K.ENL then
    local vfid = T.favs[T.selN]
    if vfid > 0 and D.S.TLM_ON and D.VTX.setable and D.VTX.ready then
      local data = vfid
      local _, data = D.VTX.FN_FCH(data)
      local chFreq = data.frq or vfid
      local bid = data.bid or nil
      local cid = data.cid or nil
      F.SN_VTX("send", chFreq, bid, cid)
    end
    return true
  elseif D.evt == D.K.EX then
    if T.selN > 0 then
      T.selN = 0
      D.evt = 0
    end
  end
  if D.evt == D.K.RT then
    T.selN = G.next(T.selN + 1, 1, #T.favs, true, true)
    return true
  elseif D.evt == D.K.LT then
    T.selN = G.next(T.selN - 1, 1, #T.favs, true, true)
    return true
  end
end
function T.d(w)
  local xo, yo
  local tw = 46
  local th = 50
  T.selN = (D.VTX and (D.VTX.setable and (D.VTX.ready and D.S.TLM_ON))) and T.selN or 0
  X.TX(w.xc, w.yt + 5, "VTX Favourite channels", X.FONT_S, X.TEXT_CENTER, D.C.MD_L)
  if D.S.VTX_CONN_TYPE > 0 then
    for i, v in ipairs(T.favs) do
      local _ = i < 5 and 28
      yo = 83
      xo = 4 + (i - 1) % 4 * (tw + 6)
      local data = T.favs[i]
      _, data = D.VTX.FN_FCH(T.favs[i])
      local chName = data.cName or "U"
      local chFreq = data.frq or T.favs[i]
      local cTxt = D.VTX.ready and D.VTX.setable and D.S.TLM_ON and i <= #T.favs or D.C.MD_V
      cTxt = D.C.MD_L
      local cBkg = D.C.MD_B
      local tx, ty = w.xl + 6 + xo, w.yt + yo
      X.RC(tx, ty, tw, th, D.C.MD_L2, X.PEN_DOTTED)
      X.RC(tx, ty, tw, th, cTxt)
      if T.selN == i then
        cTxt = D.C.MD_B
        cBkg = D.C.MD_L
        cBkg = D.C.MD_L
        X.RCF(tx, ty, tw, th, cBkg)
      end
      X.TX(tx + 23, ty - 2, chName, X.FONT_XL, X.TEXT_CENTER, cTxt)
      X.TX(tx + 23, ty + 29, chFreq, X.FONT_STD_BOLD, X.TEXT_CENTER, cTxt)
    end
  else
    X.TX(w.xc, w.yt + 50, "Config", X.FONT_STD, X.TEXT_CENTER, D.C.MD_V)
    X.TX(w.xc, w.yt + 70, "VTX type", X.FONT_STD, X.TEXT_CENTER, D.C.MD_V)
  end
  return
end
return

