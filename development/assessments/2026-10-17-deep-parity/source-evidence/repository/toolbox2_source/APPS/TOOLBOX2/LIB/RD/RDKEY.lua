-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "RDKEY.luac" was compiled with Lua 5.3 --

local G = ...
local KD = {}
KD.EX = EVT_EXIT_BREAK
KD.EXL = EVT_EXIT_LONG or -1
KD.EXR = EVT_EXIT_REPT or -1
KD.EN = EVT_ENTER_BREAK or EVT_VIRTUAL_ENTER or -1
KD.ENL = EVT_ENTER_LONG or -1
KD.ENR = EVT_ENTER_REPT or -1
KD.PN = EVT_PAGEDN_BREAK or EVT_VIRTUAL_NEXT_PAGE or -1
KD.PNL = EVT_PAGEDN_LONG or -1
KD.PNR = EVT_PAGEDN_REPT or -1
KD.PP = EVT_PAGEUP_BREAK or EVT_VIRTUAL_PREV_PAGE or -1
KD.PPL = EVT_PAGEUP_LONG or -1
KD.PPR = EVT_PAGEUP_REPT or -1
KD.RT = EVT_ROT_RIGHT or EVT_RIGHT_BREAK or EVT_PLUS_BREAK or EVT_VIRTUAL_NEXT or -1
KD.RTL = EVT_RIGHT_LONG or EVT_PLUS_LONG or -1
KD.RTR = EVT_RIGHT_REPT or EVT_PLUS_REPT or -1
KD.LT = EVT_ROT_LEFT or EVT_LEFT_BREAK or EVT_MINUS_BREAK or EVT_VIRTUAL_PREV or -1
KD.LTL = EVT_LEFT_LONG or EVT_MINUS_LONG or -1
KD.LTR = EVT_LEFT_REPT or EVT_LEFT_REPT or -1
KD.UP = EVT_UP_BREAK or EVT_PLUS_BREAK or EVT_VIRTUAL_DEC or -1
KD.UPL = EVT_UP_LONG or EVT_PLUS_LONG or -1
KD.UPR = EVT_UP_REPT or EVT_PLUS_REPT or -1
KD.DN = EVT_DOWN_BREAK or RVT_MINUS_BREAK or EVT_VIRTUAL_INC
KD.DNL = EVT_DOWN_LONG or EVT_MINUS_LONG or -1
KD.DNR = EVT_DOWN_REPT or EVT_MINUS_REPT or -1
KD.MN = EVT_MODEL_BREAK or EVT_VIRTUAL_MENU or -1
KD.MNL = EVT_MODEL_LONG or -1
KD.MNR = EVT_MODEL_REPT or -1
KD.SY = EVT_SYS_BREAK or -1
KD.SYL = EVT_SYS_LONG or -1
KD.SYR = EVT_SYS_REPT or -1
KD.TL = EVT_TELEM_BREAK or -1
KD.TLL = EVT_TELEM_LONG or -1
ks = EVT_TELEM_REPT or -1
KD.TLR = ks
D.K = {}
for k, v in pairs(KD) do
  D.K[k] = v
end
local ks
if D.RD.OSV_MAJOR <= 2 and D.RD.OSV_MINOR <= 10 and D.RD.MODEL == "nv14" or D.RD.MODEL == "el18" then
  t6 = {ENL = 2050,
          PN = 517,
          PNL = 2052,
          PNR = 1028,
          PP = 516,
          PPL = 2053,
          PPR = 1029,
          SY = 526,
          SYL = 2062,
          SYR = 1038,
          MN = 524,
          MNL = 2060,
          MNR = 1036,
          TL = 525,
          TLL = 2061,
          TLR = 1037}
  ks = t6
end
if D.RD.MODEL == "pa01" then
  G.dbg("RDKEY: pa01 model detected")
  t6 = {MN = 2059,
          MNL = -1,
          MNR = -1,
          SY = 525,
          SYL = -1,
          SYR = -1}
  ks = t6
end
ks = ks and ks and ks

