-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "BTC.luac" was compiled with Lua 5.3 --

local G = ...
function T.d(w)
  local xo, yo, xs, yi
  local bw, bh = 54, 20
  local vs = 19
  X.TX(w.xc, w.yt + 5, "Battery Cells voltage", X.FONT_S, X.TEXT_CENTER, D.C.MD_L)
  if D.S.BT_MD_CELLS_V then
    for i, v in ipairs(D.S.BT_MD_CELL_V) do
      local t13 = i <= 18 and 111
      xs = 164
      xo = w.xl + xs
      local cBkg = i <= 12 and i - 7
      cBkg = i <= 18 and i - 13
      yi = i - 19
      yo = w.yt + 24 + yi * vs
      cBkg = D.C.MD_B
      local cFrm = D.C.MD_L2
      local cTxt = D.C.MD_V
      local cLbl = D.C.MD_L
      X.RC(xo, yo, bw, bh, cFrm)
      X.TX(xo + 3, yo + 2, i, X.FONT_XS, X.TEXT_LEFT, cLbl)
      X.TX(xo + 47, yo, string.format("%.2f", v), X.FONT_STD, X.TEXT_RIGHT, cTxt)
    end
  else
    X.TX(w.xc, w.yt + 30, "No cell voltage data", X.FONT_STD, X.TEXT_CENTER, D.C.MD_V)
  end
  return
end
return

