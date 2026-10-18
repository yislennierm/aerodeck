-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFGUI.luac" was compiled with Lua 5.3 --

local G = ...
T.pID = "UI"
T.pN = "USER INTERFACE"
local listThNames = LCD_W > 480 and 350
listThNames = (listThNames or (LCD_W > 320 and 150)) or 110
T.dVxo = listThNames
listThNames = T.getList(D.UI.THM.names)
local listThIDs = T.getList(D.UI.THM.ids)
T.cv = {}
local t8 = {}
t8.o = 1
t8.l = "Theme"
t8.t = "L"
t8.lv = listThNames
T.cv._theme = t8
t8 = {}
t8.o = 2
t8.l = "Draw GFX overlay"
t8.t = "S"
T.cv._ov = t8
T.cv._theme.v = D.UI.THM.selN or 1
T.cv._ov.v = D.S.UI_THM_OV and 1 or 0
function T.cv._theme.onSave()
  local nThID = listThIDs[T.cv._theme.v]
  if nThID then
    D.UI.thmN = T.cv._theme.v
    D.S.UI_THM_ID = nThID
  end
  G.loadE(G.PLIBCFG .. "CFGUPD", "UI")
  G.loadE(G.PUI .. "THMLD")
  G.initDone = nil
end
function T.cv._ov.onSave()
  D.S.UI_THM_OV = T.cv._ov.v == 1
  G.loadE(G.PLIBCFG .. "CFGUPD", "UI")
end
return

