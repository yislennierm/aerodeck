-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "MENU.luac" was compiled with Lua 5.3 --

local G = ...
local DU = D.UI
function T.i(w)
  T.menuActive = false
  T.selN = 1
  for i, v in ipairs(D.UI.MODS.visible) do
    if v.id == D.UI.MODS.selID then
      T.selN = i
      break
    end
  end
  T.logo = X.LMK(G.PGFXR .. "MD_FM2M_MASK.jpg")
  T.cMode = false
  T.nextN = T.selN
  T.nextN = G.next(T.nextN + 1, 1, #D.UI.MODS.visible, true)
  T.iconX = 58
  T.iconSpacing = 45
  T.iconW = 30
  T.iconH = 30
end
function T.e()
  if D.S.QM_ON then
  else
    if T.menuActive then
      if D.evt == D.K.EN then
        if T.selN ~= T.nextN then
          D.UI.MODS.selMenuN = T.nextN
          D.UI.MODS.nextID = D.UI.MODS.visible[T.nextN].id
          T.menuActive = false
          D.evt = 0
        end
      elseif D.evt == D.K.EX then
        T.nextN = T.selN
        T.nextN = G.next(T.nextN + 1, 1, #D.UI.MODS.visible, true)
        T.menuActive = false
        D.UI.TASKS.el = D.UI.TASKS.ell or 2
        D.evt = 0
      elseif D.evt ~= D.K.RT then
        if D.evt == D.K.SY then
        end
      else
        T.nextN = G.next(T.nextN + 1, 1, #D.UI.MODS.visible, true)
        if T.nextN == T.selN then
          T.nextN = G.next(T.nextN + 1, 1, #D.UI.MODS.visible, true)
        end
      end
    elseif D.evt == D.K.EX then
      D.UI.MODS.nextID = "DBD"
      D.evt = 0
    elseif D.evt == D.K.SY then
      T.menuActive = true
      D.UI.TASKS.el = 1
      D.evt = 0
    end
  end
end
function T.d(w)
  X.MK(T.logo, 9, 3, D.C.MD_ICS)
  if T.menuActive then
    X.RCF(46, 35, 388, 284, D.C.MD_B, D.UI.dimMENU)
  end
  for i = 1, #D.UI.MODS.visible do
    local item = D.UI.MODS.visible[i]
    local xi = T.iconX + (i - 1) * T.iconSpacing
    local y = 42
    if T.menuActive then
      X.TX(w.xc, y, string.upper(D.UI.MODS.visible[T.nextN].name), X.FONT_STD, X.TEXT_CENTER, D.C.MD_V)
    else
      X.TX(w.xc, y, string.upper(D.UI.MODS.visible[T.selN].name), X.FONT_STD, X.TEXT_CENTER, D.C.MD_V)
    end
    local name = "MD_" .. item.id .. "_MASK"
    if not T[name] then
      T[name] = X.LMK(G.PGFXR .. name .. ".jpg")
    end
    local yo = D.S.UI_THM_OV and 0 or 2
    local c = i == T.selN and D.C.MD_ICS or D.C.MD_IC
    X.MK(T[name], xi, yo, c)
    if T.menuActive and i == T.nextN then
      X.RCF(xi, yo + T.iconH, T.iconW, 3, D.C.MD_V)
    end
  end
  return
end
return

