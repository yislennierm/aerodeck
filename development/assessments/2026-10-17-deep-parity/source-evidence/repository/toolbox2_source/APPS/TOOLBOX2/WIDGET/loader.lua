-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "loader.luac" was compiled with Lua 5.3 --

local arg = ...
local WNAME = arg.WNAME or "FM2M TB2"
local FP = arg.FP or "/FM2M/"
local AP = arg.AP or "TOOLBOX2/"
local MODE = arg.MODE or "WG"
local SLM = arg.SLM or "bx"
local DEVON = arg.DEVON or false
local SP = FP .. "APPS/" .. AP
local WP = SP .. "WIDGET/"
local modelName = model.getInfo().name
local GS = {}
local name = WNAME
local options = {}
local create = function(zone, options)
  local wgt = {GS = GS,
               o = options,
               zone = zone}
  return wgt
end
local update = function(wgt, options)
  wgt.o = options
end
local refresh = function(wgt, evt, ts)
  wgt.fullsize = wgt.zone.w == LCD_W and wgt.zone.h == LCD_H
  if wgt.fullsize then
    if wgt.APP then
      if wgt.APP.G.run then
        wgt.APP.G.run(evt, ts)
      end
    else
      -- Corrected temporary-table emission against the original bytecode.
      wgt.APP = loadScript(SP .. "M", SLM)({FP = FP, AP = AP, MODE = "WG", SLM = SLM, DEVON = DEVON})
    end
  else
    lcd.drawText(2, 2, WNAME, RED)
    lcd.drawText(2, 20, "Select APP mode layout", RED)
  end
end
local background = function(WGT)
  if WGT.APP and WGT.APP.initDone then
    WGT.refreshTS = nil
    WGT.dispInfo = false
    WGT.APP.G.ML.bg()
  end
end
return {name = name, options = options, create = create, update = update, refresh = refresh, background = background}

