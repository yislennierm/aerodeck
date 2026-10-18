-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "STK.luac" was compiled with Lua 5.3 --

local G = ...
T.lnDispShift = 1
T.lnMax = 7
T.lnSpace = 25
T.radioMode = D.RD.CHMODE
function T.i(w)
  local tasks = {{f = nil, w = {xl = w.xl, yt = w.yt, w = 110, h = 40}},
                 {f = nil, w = {xl = w.xl + 110, yt = w.yt, w = 168, h = 40}},
                 {f = nil, w = {xl = w.xl + 278, yt = w.yt, w = 110, h = 40}},
                 {f = nil, w = {xl = w.xl, yt = w.yt + 40, w = w.w, h = w.h - 40}}}
  G.loadE(G.PUI .. "UITSKSET", tasks)
  T.stickCmds = G.loadE(G.PLIBFC .. D.S.FC_FW_ID .. "/STK")
end
function T.drawStick(cmd, xPos, yPos, gSize, sSize)
  local label = cmd.l
  local vl = cmd.t
  local hl = cmd.y
  local vr = cmd.p
  local hr = cmd.r
  local x = T.radioMode ~= 1 and T.radioMode
  vl = cmd.p
  vr = cmd.t
  x = T.radioMode ~= 3 and T.radioMode
  hl = cmd.r
  hr = cmd.y
  x, y, c, d, o = 0, 0, 0, 0, 0
  local x1, y1, x2, y2 = xPos, yPos, xPos + gSize + 6, yPos
  d = math.floor(gSize / 2)
  X.RC(x1, y1, gSize, gSize, D.C.MD_L)
  X.RC(x2, y2, gSize, gSize, D.C.MD_L)
  local posX = {1, d - 3, 13}
  local posY = {14, d - 3, 1}
  local sx1, sy1, sx2, sy2 = 0, 0, 0, 0
  sy1 = y1 + posY[vl + 2]
  sx1 = x1 + posX[hl + 2]
  sy2 = y2 + posY[vr + 2]
  sx2 = x2 + posX[hr + 2]
  X.RCF(sx1, sy1, sSize, sSize, D.C.MD_V)
  X.RCF(sx2, sy2, sSize, sSize, D.C.MD_V)
  X.TX(x2 + gSize + 15, yPos, label, X.FONT_STD, X.TEXT_LEFT, D.C.MD_V)
end
function T.e()
  if D.evt == D.K.EX then
    D.UI.MODS.nextID = "DBD"
    D.evt = 0
  end
  if D.evt == D.K.RT then
    T.lnDispShift = G.next(T.lnDispShift + 1, 1, #T.stickCmds - T.lnMax + 1)
    return true
  elseif D.evt == D.K.LT then
    T.lnDispShift = G.next(T.lnDispShift - 1, 1, #T.stickCmds - T.lnMax + 1)
    return true
  elseif D.evt == D.K.PN then
    T.radioMode = G.next(T.radioMode + 1, 1, 4, true)
    return true
  elseif D.evt == D.K.PP then
    T.radioMode = G.next(T.radioMode - 1, 1, 4, true)
    return true
  end
end
function T.d(w)
  X.TX(w.xl + 10, w.yt + 12, "FC", X.FONT_S, X.TEXT_LEFT, D.C.MD_L)
  local fwName = D.S.FC_FW_ID == "BF" and "Betaflight"
  X.TX(w.xl + 90, w.yt + 12, (fwName or (D.S.FC_FW_ID == "IN" and "INAV")) or "", X.FONT_S, X.TEXT_RIGHT, D.C.MD_V)
  X.TX(w.xr - 90, w.yt + 12, "MODE", X.FONT_S, X.TEXT_LEFT, D.C.MD_L)
  X.TX(w.xr - 10, w.yt + 12, tostring(T.radioMode), X.FONT_S, X.TEXT_RIGHT, D.C.MD_V)
  local gSize = 20
  local sSize = 6
  local x = w.xl + 16
  local y = w.yt + 54
  for i = 1, T.lnMax do
    local cmd = T.stickCmds[T.lnDispShift + i - 1]
    T.drawStick(cmd, x, y - 2, gSize, sSize)
    y = y + T.lnSpace
  end
  return
end
return

