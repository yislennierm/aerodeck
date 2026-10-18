-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "M.luac" was compiled with Lua 5.3 --

print("*** TOOLBOX START ***")
local arg = ...
local G = {}
local F = {}
local D = {}
local X = {}
local AP = arg.MODE or "OT"
G.MODE = AP
local AP = arg.FP or "/FM2M/"
G.FP = AP
AP = arg.AP or "TOOLBOX2/"
G.PAPP = G.FP .. "APPS/" .. AP
G.PGFX = G.PAPP .. "ASSETS/GFX/"
G.PTHM = G.PAPP .. "ASSETS/THEMES/"
G.PMAIN = G.PAPP .. "MAIN/"
G.PUI = G.PAPP .. "UI/"
G.PUSER = G.FP .. "USER/" .. AP
G.PLOGS = G.PUSER .. "LOGS/"
G.PKEYS = G.FP .. "KEYS/"
G.PCFG = G.PUSER .. "CONFIGS/"
G.PLIB = G.PAPP .. "LIB/"
local libs = {"CFG",
              "FC",
              "FS",
              "GPS",
              "MSP",
              "OS",
              "RD",
              "TB",
              "TLM",
              "VTX"}
for _, v in ipairs(libs) do
  G["PLIB" .. v] = G.PLIB .. v .. "/"
end
G.SLM = arg.SLM or "bx"
G.SLC = string.upper(string.sub(G.SLM, 1, 1)) == "B"
G.appExit = 0
G.UIR = false
G.evt = nil
G.DEVON = arg.DEVON or false
G.DEVFULL = arg.DEVFULL or false
G.LOGINIT = false
G.LOGQ = {}
G.LOGQP = 0
G.MSPLOGQ = {}
G.MSPLOGQP = 0
if G.DEVON then
  G.LOGDEBUGSW = "sd"
  G.LOGDEBUG = getValue(G.LOGDEBUGSW) > 50
end
local estat
local t8 = {}
local initLogoName = {}
t8.list = initLogoName
G.ERR = t8
local lcdw = LCD_W >= 800 and 800
lcdw = (lcdw or (LCD_W >= 480 and 480)) or 320
local initLogoName = G.PGFX .. "FM2M_LOGO" .. lcdw .. ".png"
G.initLogo = Bitmap.open(initLogoName)
G.initLogoH = 0
G.initLogoW = 0
if G.initLogo then
  G.initLogoH = t11
  G.initLogoW = Bitmap.getSize(G.initLogo)
end
loadScript(G.PMAIN .. "GF", G.SLM)(G, F, D, X)
if G.DEVON then
  G.print("arg", "FP", arg.FP)
  G.print("arg", "AP", arg.AP)
  G.print("arg", "MODE", arg.MODE)
  G.print("arg", "SLM", arg.SLM)
  G.print("---")
  G.print("TOOLBOX DEV MODE ON")
  G.print("G.PAPP", G.PAPP)
  G.print("G.PGFX", G.PGFX)
  G.print("G.PLIB", G.PLIB)
  G.print("G.PMAIN", G.PMAIN)
  G.print("G.PUI", G.PUI)
  G.print("G.PUSER", G.PUSER)
  G.print("G.PLOGS", G.PLOGS)
  G.print("G.PKEYS", G.PKEYS)
  G.print("G.PCFG", G.PCFG)
  G.print("G.PTHM", G.PTHM)
  G.print("G.SLM", G.SLM)
  G.print("G.SLC", G.SLC)
  G.print("G.DEVON", G.DEVON)
  G.print("G.DEVFULL", G.DEVFULL)
  G.print("G.appExit", G.appExit)
  G.print("---")
  G.print("")
  G.logWrite()
end
G.memC = 0
G.memX = 0
function G.xpc(fn, ...)
  return fn(...)
end
function G.init(G, F, D, X)
  D.INIT_do = true
  lcd.clear(BLACK)
  lcd.drawBitmap(G.initLogo, LCD_W / 2 - G.initLogoW / 2, LCD_H / 2 - G.initLogoH)
  lcd.drawText(LCD_W / 2, LCD_H / 2, "ToolBox", MIDSIZE + CENTER + WHITE)
  lcd.drawText(LCD_W / 2, LCD_H / 2 + 45, "Loading", CENTER + WHITE)
  if G.initStep == "clr" then
    if G.MODE == "WG" then
      if not G.initClrStep then
        G.clear(F, "*")
        G.initClrStep = "d"
        return
      elseif G.initClrStep == "d" then
        G.clear(D, "*")
        G.initClrStep = "x"
        return
      elseif G.initClrStep == "x" then
        G.clear(X, "*")
        G.initClrStep = nil
      end
    end
    G.clear(F, "*")
    G.clear(D, "*")
    G.clear(X, "*")
    G.LOG = {}
    G.initStep = "rd"
  elseif G.initStep == "rd" then
    G.loadE(G.PMAIN .. "RD")
    G.initStep = "lib"
  else
    if G.initStep == "lib" then
      G.initStep = "dev"
    elseif G.initStep == "dev" then
      if G.DEVON then
        G.PLIBDEV = G.PAPP .. "DEV/"
        G.loadE(G.PLIBDEV .. "DEV")
      end
      G.initStep = "rdkey"
    elseif G.initStep == "rdkey" then
      G.loadE(G.PLIBRD .. "RDKEY")
      G.initStep = "rdinp"
    elseif G.initStep == "rdinp" then
      G.loadE(G.PLIBRD .. "RDINP")
      G.initStep = "app"
    elseif G.initStep == "app" then
      G.loadE(G.PMAIN .. "AI")
      G.ML = G.loadE(G.PMAIN .. "ML")
      G.initStep = nil
      G.initDone = true
    end
  end
  return
end
function G.run(evt, ts)
  G.logWrite()
  D.evt = evt
  if not G.initDone then
    G.initStep = G.initStep or "clr"
    estat = G.xpc(G.init, G, F, D, X)
  else
    estat = G.xpc(G.ML.run, evt)
    if G.DEVON and G.DEV and G.DEV.run then
      estat = G.xpc(G.DEV.run, G, F, D, X, evt)
    end
    G.cg()
  end
  return G.appExit
end
if G.MODE == "OT" then
  return G.run
elseif G.MODE == "WG" then
  return {G = G, F = F, D = D, X = X}
else
  assert(false, "Unknown FM2M app mode: " .. G.MODE)
end

