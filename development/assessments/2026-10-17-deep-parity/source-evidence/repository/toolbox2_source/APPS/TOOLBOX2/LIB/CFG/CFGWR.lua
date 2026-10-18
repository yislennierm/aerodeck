-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFGWR.luac" was compiled with Lua 5.3 --

local G = ...
local cF = G.PCFG .. "MODEL/" .. D.RD.MODEL .. "_" .. model.getInfo().name .. ".cfg"
local cD = "local t=... \r\n"
for cN, cV in pairs(D.CFGSTR) do
  local cS = tostring(cV)
  if type(cV) == "string" then
    cS = "\"" .. cV .. "\""
  else
    if type(cV) == "boolean" then
      local t12 = cV and "true"
      cS = "false"
    end
  end
  cD = cD .. "t." .. cN .. "=" .. cS .. "\r\n"
end
G.loadE(G.PLIBFS .. "FSWF", cF, cD, "w")
return

