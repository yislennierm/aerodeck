-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFGVFV.luac" was compiled with Lua 5.3 --

local G = ...
T.pID = "VFV"
T.pN = "VTX FAVS"
local favID = ((LCD_W > 480 and 300) or (LCD_W > 320 and 170)) or 80
T.dVxo = favID
T.favs = G.split(D.CFGSTR.VTXF, "|")
T.favsID = {}
T.list_FRQ = {[0] = 0}
T.list_CH = {[0] = "OFF"}
favID = 0
for i, v in ipairs(D.VTX.TBLR) do
  for fi, frq in ipairs(v.f) do
    favID = (i - 1) * 8 + fi
    if frq > 0 then
      T.list_FRQ[#T.list_FRQ + 1] = frq
      local lv = " ("
      T.list_CH[#T.list_CH + 1] = v.bl .. fi .. " (" .. frq .. ")"
      for li, lv in ipairs(T.favs) do
        if tostring(lv) == tostring(frq) then
          T.favsID[li] = favID
          break
        end
      end
    end
  end
end
T.cv = {}
for i = 1, 8 do
  local t12 = {}
  t12.o = i
  t12.l = "Fav channel " .. i
  t12.v = T.favsID[i] or 0
  t12.t = "L"
  t12.lv = T.list_CH
  T.cv["_f" .. i] = t12
end
function T.onSave()
  local vV = ""
  for i = 1, 8 do
    local frqID = T.cv["_f" .. i].v
    local frq = frqID > 0 and T.list_FRQ[frqID] or 0
    vV = vV .. frq .. "|"
  end
  vV = string.sub(vV, 1, -2)
  D.CFGSTR.VTXF = vV
end
return

