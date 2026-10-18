-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "THMINIT.luac" was compiled with Lua 5.3 --

local G = ...
D.UI.THM = {}
D.UI.THM.ids = {}
D.UI.THM.names = {}
D.UI.THM.selN = 1
D.UI.THM.selID = "CARBON_PLATE"
local thmPresent = G.loadE(G.PLIBFS .. "FSDIR", G.PTHM)
if #thmPresent == 0 then
  error("No themes found in " .. G.PTHM)
  return
end
table.sort(thmPresent)
for i, thmID in ipairs(thmPresent) do
  local thmData = G.loadE(G.PTHM .. thmID .. "/C", true)
  local pvl = G.fm.pgg and 2
  pvl = (pvl or (G.fm.sxx and 1)) or 0
  if pvl >= thmData[3] then
    D.UI.THM.names[#D.UI.THM.names + 1] = thmData[1]
    D.UI.THM.ids[#D.UI.THM.ids + 1] = thmData[2]
  end
end
for i, thmID in ipairs(D.UI.THM.ids) do
  if thmID == D.S.UI_THM_ID then
    G.dbg("Theme " .. thmID .. " found")
    D.UI.THM.selN = i
    D.UI.THM.selID = thmID
    break
  end
end
return

