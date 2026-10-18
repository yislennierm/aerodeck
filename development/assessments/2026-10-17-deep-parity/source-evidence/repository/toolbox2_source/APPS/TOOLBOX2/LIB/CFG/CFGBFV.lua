-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFGBFV.luac" was compiled with Lua 5.3 --

local G = ...
T.pID = "BFV"
T.pN = "BATTERY FAVS"
local battCfg = LCD_W > 480 and 300
T.dVxo = (battCfg or (LCD_W > 320 and 170)) or 120
battCfg = G.split(D.CFGSTR.BTF, "|")
T.cv = {}
for i = 1, 5 do
  local icfg = i * 3 - 2
  local t13 = {}
  t13.o = icfg
  t13.l = "Fav battery " .. i
  t13.v = tonumber(battCfg[icfg])
  t13.t = "L"
  local t14 = {}
  t14[0] = "OFF"
  t13.lv = t14
  T.cv["_f" .. icfg] = t13
  local vis = T.cv["_f" .. icfg].v == 0 and 0 or 1
  T.cv["_f" .. icfg + 1] = {o = icfg + 1, l = " Cell number", v = tonumber(battCfg[icfg + 1]), t = "N", m = 1, x = 99, i = 1, f = "%1d"}
  T.cv["_f" .. icfg + 2] = {o = icfg + 2, l = " Capacity", v = tonumber(battCfg[icfg + 2]), t = "N", m = 100, x = 100000, i = 50, f = "%1d", u = "mAh"}
end
function T.updateDisp()
  for i = 1, 5 do
    local icfg = i * 3 - 2
    T.cv["_f" .. icfg + 1].h = T.cv["_f" .. icfg].v == 0 and true or nil
    T.cv["_f" .. icfg + 2].h = T.cv["_f" .. icfg].v == 0 and true or nil
  end
end
function T.onSave()
  local btf = ""
  for i = 1, 5 do
    local icfg = i * 3 - 2
    btf = btf .. T.cv["_f" .. icfg].v .. "|"
    btf = btf .. T.cv["_f" .. icfg + 1].v .. "|"
    btf = btf .. T.cv["_f" .. icfg + 2].v .. "|"
  end
  btf = string.sub(btf, 1, -2)
  D.CFGSTR.BTF = btf
end
return

