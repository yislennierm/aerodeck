-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "CFGGPS.luac" was compiled with Lua 5.3 --

local G = ...
T.pID = "GPS"
T.pN = "GPS"
T.dVxo = ((LCD_W > 480 and 350) or (LCD_W > 320 and 200)) or 80
T.cv = {}
T.cv.GPS_SATS2FIX = {o = 1, l = "Sats number to fix home", t = "N", m = 1, x = 64, i = 1, f = "%1d"}
T.readDS()
return

