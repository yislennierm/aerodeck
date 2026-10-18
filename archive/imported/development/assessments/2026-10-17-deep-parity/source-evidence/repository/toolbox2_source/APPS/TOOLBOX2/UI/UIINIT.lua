-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "UIINIT.luac" was compiled with Lua 5.3 --

local G = ...
G.loadE(G.PUI .. "X")
D.UI = D.UI or {}
G.clear(D, "+UI")
D.UI.GFX = {}
D.CD = D.CD or {}
G.clear(D, "+CD")
D.C = D.C or {}
G.clear(D, "+C")
D.UI.TASKS = D.UI.TASKS or {}
G.clear(D.UI, "+TASKS")
D.UI.mute = false
D.UI.CHDEG = "\194\176"
D.UI.dimTLM = 11
D.UI.dimMENU = 7
D.UI.dimOFF = 7
D.UI.MDL = {}
D.UI.MDL.modelName = model.getInfo().name
D.UI.MDL.modelGfx = X.LBM("/IMAGES/" .. model.getInfo().bitmap)
local lcdFallback = LCD_W >= 800 and "800X480"
lcdFallback = (lcdFallback or (LCD_W >= 480 and "480X272")) or "320X240"
local radioUIP = G.PUI .. D.RD.LCDRES
local radioGFXP = G.PGFX .. D.RD.LCDRES
G.dbg("radioUIP", radioUIP)
local lcdSupp = G.fsCheck(radioUIP .. "/") and G.fsCheck(radioGFXP .. "/")
G.PUIDIR = (D.RD.LCDRES or lcdFallback) .. "/"
G.PUIR = G.PUI .. G.PUIDIR
G.dbg("G.PUIR", G.PUIR)
G.PGFXR = G.PAPP .. "ASSETS/GFX/" .. G.PUIDIR
G.dbg("G.PGFXR", G.PGFXR)
G.loadE(G.PUI .. "THMINIT")
G.loadE(G.PUI .. "THMLD")
G.frun(G.PUI .. "SNV")
G.frun(G.PUI .. "DBAR")
G.frun(G.PUI .. "DIT")
G.loadE(G.PUI .. "MDINIT")
D.UI.selDBD = "DB1"
D.UI.MODS.lastID = "CFG"
D.UI.MODS.nextID = "DBD"
return true

