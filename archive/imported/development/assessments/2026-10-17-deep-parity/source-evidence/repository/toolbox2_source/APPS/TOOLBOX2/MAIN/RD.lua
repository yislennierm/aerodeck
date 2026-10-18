-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "RD.luac" was compiled with Lua 5.3 --

local G = ...
local version, radio, major, minor, revision, name = getVersion()
D.RD = {}
D.RD.SIM = string.find(radio, "-simu")
D.RD.OSID = "etx"
D.RD.OSV_MAJOR = major
D.RD.OSV_MINOR = minor
D.RD.OSV = major .. "." .. minor .. "." .. revision
D.RD.MODEL = D.RD.SIM and string.sub(radio, 1, D.RD.SIM - 1) or radio
D.RD.SIM = D.RD.SIM and true or false
D.RD.LCDRES = LCD_W .. "X" .. LCD_H
D.RD.COLOR = lcd.RGB ~= nil
D.RD.CHMODE = 2

