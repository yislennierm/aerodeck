-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "MPN.luac" was compiled with Lua 5.3 --

local G = ...
function T.im(w)
  T.MODS = {"LITE"}
  if G.fm.sxx then
    T.MODS = {"AHR"}
    if D.S.MDL_BTV_ON then
      if G.fm.pgg then
        T.MODS[#T.MODS + 1] = "BFV"
      end
      if D.S.BT_MD_CELLS_V then
        T.MODS[#T.MODS + 1] = "BTC"
      end
    end
    if G.fm.pgg and D.S.MDL_VTX_ON then
      T.MODS[#T.MODS + 1] = "VFV"
    end
    T.MODS[#T.MODS + 1] = "FCD"
  end
  D.S.UI_DBD_MPN = math.min(D.S.UI_DBD_MPN, #T.MODS)
  T.m = T.MODS[D.S.UI_DBD_MPN]
end
function T.em(w)
  if D.evt == D.K.PN then
    D.S.UI_DBD_MPN = G.next(D.S.UI_DBD_MPN + 1, 1, #T.MODS, true)
    T.m = T.MODS[D.S.UI_DBD_MPN]
    G.loadE(G.PUI .. "UITSKCHG", T)
    return
  end
end
return

