-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFGUPDP.luac" was compiled with Lua 5.3 --

local G = ...
for i, v in ipairs(D.MODCFG.pages) do
  v.vis = false
end
D.MODCFG.pagesByID.MDL.vis = true
D.MODCFG.pagesByID.IND.vis = true
if D.S.MDL_RCP_ON then
  D.MODCFG.pagesByID.RCL.vis = D.S.MDL_RCP_ON
  if G.fm.sxx then
    D.MODCFG.pagesByID.BAT.vis = D.S.MDL_BTV_ON
    D.MODCFG.pagesByID.BFV.vis = G.fm.pgg and D.S.MDL_BTV_ON
    D.MODCFG.pagesByID.FC.vis = D.S.MDL_FC_ON
    D.MODCFG.pagesByID.VTX.vis = D.S.MDL_VTX_ON
    D.MODCFG.pagesByID.VFV.vis = G.fm.pgg and D.S.MDL_VTX_ON and D.S.VTX_CONN_TYPE > 0
    D.MODCFG.pagesByID.INDBF.vis = false
    if D.S.MDL_FC_ON and D.S.MDL_FC == 1 then
      D.MODCFG.pagesByID.INDBF.vis = true
    end
    D.MODCFG.pagesByID.GPS.vis = D.S.MDL_GPS_ON and D.S.RCP_pID == "TBS"
  end
end
D.MODCFG.pagesByID.UI.vis = true
D.MODCFG.pagesByID.APP.vis = true
D.MODCFG.pagesVisible = {}
for i, v in ipairs(D.MODCFG.pages) do
  if v.vis then
    table.insert(D.MODCFG.pagesVisible, v)
  end
end

