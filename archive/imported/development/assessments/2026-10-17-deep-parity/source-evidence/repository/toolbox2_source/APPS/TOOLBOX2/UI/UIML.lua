-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "UIML.luac" was compiled with Lua 5.3 --

local G = ...
function F.UIML()
  if (not D.UI.MODS.nextID) then
    return
  end
  if D.UI.MODS.selID and D.UI.MODS.selID ~= "" then
    G.clear(D.UI, "T_*")
    G.clear(D.UI, "+TASKS")
  end
  D.UI.MODS.selID = D.UI.MODS.nextID
  D.UI.MODS.lastID = D.UI.MODS.selID == "DBD" and D.UI.MODS.lastID or D.UI.MODS.selID
  D.UI.MODS.lastID = D.UI.MODS.lastID == "DBD" and "CFG" or D.UI.MODS.lastID
  if D.UI.MODS.selID == "DBD" then
    if not G.PUIR .. D.UI.MODS.selID then local modFile = G.PUIR .. "MOD" end
  end
  G.loadE(modFile)
  local ovName = D.UI.MODS.selID == "DBD" and D.UI.selDBD or D.UI.MODS.selID
  D.UI.ov = nil
  D.UI.ovPath = G.PTHMSR .. "OV_" .. ovName .. ".png"
  D.UI.MODS.nextID = nil
  G.cg()
  if G.MODE == "WG" then
    X.CLR(D.C.MD_B)
    return
  end
  X.CLR(D.C.MD_B)
  G.frun(G.PUI .. "UITSKRUN")
  return
end
F.UIML()

