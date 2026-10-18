-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "TLMINIT.luac" was compiled with Lua 5.3 --

local G = ...
F.SN_TLM = G.fnNIL
F.SN_ARM = G.fnNIL
F.SN_FM = G.fnNIL
F.SN_ATT = G.fnNIL
F.SN_RL = G.fnNIL
F.SN_BT = G.fnNIL
F.SN_BARO = G.fnNIL
F.SN_AIR = G.fnNIL
D.TLM = D.TLM or {}
G.clear(D, "+TLM*")
D.SEN = D.SEN or {}
G.clear(D, "+SEN*")
G.loadE(G.PLIBRD .. "BAT")
D.TLM.S = {}
D.TLM.SN = {}
D.TLM.SU = {}
D.TLM.SD = {}
D.TLM.I = {}
D.TLM.V = {}
D.TLM.VM = {}
D.TLM.VX = {}
D.S.TLM_ON_SRC = getSwitchIndex("Tele") or nil
D.S.TLM_ON = false
D.S.TLM_data = false
if D.S.RCP_pID == "OFF" or D.S.RCP_pverID == "OFF" then
  G.dbg("RC Link protocol or protocol version is OFF")
  return
end
D.S.TLM_enabled = true
if not D.S.MDL_RCP_ON then
  D.S.TLM_enabled = false
  return
end
G.loadE(G.PLIBTLM .. "TLMRST")
G.loadE(G.PLIBTLM .. "TLMSADD", "RL")
local sTypes = {"FC", "BTV", "BTA", "GYRO", "ACC", "BARO", "PITOT", "GPS", "COMP", "VTX"}
if G.MODE == "WG" then
  D.RINIT = D.RINIT or {}
end
for i, sType in ipairs(sTypes) do
  if D.S["MDL_" .. sType .. "_ON"] then
    if G.MODE == "WG" then
      t12 = {fn = G.PLIBTLM .. "TLMSADD", args = {sType}}
      table.insert(D.RINIT, t12)
    else
      G.loadE(G.PLIBTLM .. "TLMSADD", sType)
    end
  end
end
if G.MODE == "WG" then
  t7 = {fn = G.PLIBTLM .. "TLMUPDS"}
  table.insert(D.RINIT, t7)
else
  G.loadE(G.PLIBTLM .. "TLMUPDS")
end
return

