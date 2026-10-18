-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "X.luac" was compiled with Lua 5.3 --

local G = ...
G.dbg("UI/X loaded")
X.TEXT_LEFT = 0
X.TEXT_RIGHT = RIGHT
X.TEXT_CENTER = CENTER
X.PEN_SOLID = SOLID
X.PEN_DOTTED = DOTTED
X.FONT_XXS = TINSIZE
X.FONT_XS = TINSIZE
X.FONT_S = SMLSIZE
X.FONT_STD = 0
X.FONT_STD_BOLD = BOLD
X.FONT_L = MIDSIZE
X.FONT_XL = DBLSIZE
X.FONT_XXL = XXLSIZE
function X.RC(x, y, w, h, c, p)
  if not p then
    lcd.drawRectangle(x, y, w, h, c)
  else
    lcd.drawLine(x, y, x + w - 1, y, p, c)
    lcd.drawLine(x, y, x, y + h - 1, p, c)
    lcd.drawLine(x + w - 1, y, x + w - 1, y + h - 1, p, c)
    lcd.drawLine(x, y + h - 1, x + w - 1, y + h - 1, p, c)
  end
end
X.RCF = lcd.drawFilledRectangle
X.TR = lcd.drawTriangle
X.TRF = lcd.drawFilledTriangle
X.CR = lcd.drawCircle
X.CRF = lcd.drawFilledCircle
X.LN = lcd.drawLine
function X.TX(x, y, t, f, a, c)
  t = t or "NIL"
  f = f or 0
  a = a or 0
  c = c or 0
  lcd.drawText(x, y, t, f + a + c)
end
function X.TXL(x, y, w, h, t, f, a, c, th)
  lcd.drawTextLines(x, y, w, h, t, f + a + c)
end
function X.TXS(t, f)
  return lcd.sizeText(t, f)
end
function X.GA(x, y, w, h, v, vmax, p, c)
  lcd.drawGauge(x, y, w, h, v, vmax, c)
end
X.CLR = lcd.clear
X.HR = lcd.drawHudRectangle
X.LBM = Bitmap.open
function X.BM(b, x, y, s)
  if b then
    lcd.drawBitmap(b, x, y, s)
  end
end
function X.LMK(b)
  local bmp = X.LBM(b)
  local bmk = Bitmap.toMask(bmp)
  return bmk
end
function X.MK(b, x, y, c)
  if b then
    lcd.drawBitmapPattern(b, x, y, c)
  end
end
X.RGB = lcd.RGB
function X.RGBE(sHex)
  local c = lcd.RGB(tonumber(string.sub(sHex, 1, 2), 16), tonumber(string.sub(sHex, 3, 4), 16), tonumber(string.sub(sHex, 5, 6), 16))
  return c
end
function X.RGBD(val)
  local r = G.bit.rshift(G.bit.band(val, 63488), 11)
  local g = G.bit.rshift(G.bit.band(val, 2016), 5)
  local b = G.bit.band(val, 31)
  r = math.floor(r * 255 / 31 + 0.5)
  g = math.floor(g * 255 / 63 + 0.5)
  b = math.floor(b * 255 / 31 + 0.5)
  return r, g, b
end
return

