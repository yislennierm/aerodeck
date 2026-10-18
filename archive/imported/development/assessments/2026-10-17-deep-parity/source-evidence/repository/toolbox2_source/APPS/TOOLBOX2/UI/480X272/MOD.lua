-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "MOD.luac" was compiled with Lua 5.3 --

local G = ...
local modFile = "MOD" .. D.UI.MODS.selID
local tasks = {{f = modFile, w = {xl = 46, yt = 36, w = 388, h = 236}, el = 2},
               {f = "MODMENU", w = {xl = 0, yt = 0, w = 480, h = 36}, el = 1},
               {f = "MODRCL"},
               {f = nil, w = {xl = 0, yt = 36, w = 46, h = 76}},
               {f = nil, w = {xl = 0, yt = 112, w = 46, h = 56}},
               {f = nil, w = {xl = 0, yt = 168, w = 46, h = 56}},
               {f = nil, w = {xl = 0, yt = 224, w = 46, h = 48}},
               {f = "MODBAT"},
               {f = nil, w = {xl = 434, yt = 36, w = 46, h = 76}},
               {f = nil, w = {xl = 434, yt = 112, w = 46, h = 76}},
               {f = nil, w = {xl = 434, yt = 188, w = 46, h = 84}}}
G.loadE(G.PUI .. "UITSKSET", tasks)
tasks = {{f = "OV", w = {xl = 0, yt = 0, w = LCD_W, h = LCD_H}},
         {f = "QM", w = {xl = 0, yt = 0, w = LCD_W, h = LCD_H}, el = 0}}
G.loadE(G.PUI .. "UITSKSET", tasks)
G.loadE(G.PUI .. "UITSKINIT")
D.UI.TASKS.el = 2
D.UI.TASKS.ell = D.UI.TASKS.el
return

