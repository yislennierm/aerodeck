-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFGAPP.luac" was compiled with Lua 5.3 --

local G = ...
T.pID = "APP"
T.pN = "LUA APPLICATION"
T.dVxo = ((LCD_W > 480 and 300) or (LCD_W > 320 and 150)) or 80
T.cv = {}
T.cv.APP_errLog = {o = 1, l = "Log errors to file", t = "S"}
T.readDS()
return

