-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "AST.luac" was compiled with Lua 5.3 --

local G = ...
function T.i(w)
  local tasks = {}
  local t2 = {}
  t2.f = nil
  local t3 = {}
  t3.xl = w.xl
  t3.yt = w.yt
  t3.w = 110
  t3.h = 40
  t2.w = t3
  t3 = {}
  t3.f = nil
  local t4 = {}
  t4.xl = w.xl + 110
  t4.yt = w.yt
  t4.w = 168
  t4.h = 40
  t3.w = t4
  t4 = {}
  t4.f = nil
  local t5 = {}
  t5.xl = w.xl + 278
  t5.yt = w.yt
  t5.w = 110
  t5.h = 40
  t4.w = t5
  t5 = {}
  t5.f = nil
  local t6 = {}
  t6.xl = w.xl
  t6.yt = w.yt + 40
  t6.w = 140
  t6.h = 168
  t5.w = t6
  t6 = {}
  t6.f = nil
  local t7 = {}
  t7.xl = w.xl
  t7.yt = w.yb - 27
  t7.w = 140
  t7.h = 28
  t6.w = t7
  t7 = {}
  t7.f = nil
  local t8 = {}
  t8.xl = w.xl + 140
  t8.yt = w.yt + 40
  t8.w = 248
  t8.h = 98
  t7.w = t8
  t8 = {}
  t8.f = nil
  local t9 = {}
  t9.xl = w.xl + 140
  t9.yt = w.yb - 97
  t9.w = 248
  t9.h = 96
  t8.w = t9
  G.loadE(G.PUI .. "UITSKSET", tasks)
  T.lnDispShift = 1
  T.lnMax = 7
  T.lnSpace = 24
  T.lnSelID = 1
  T.armStops = D.FC_ARMSTOPS and #D.FC_ARMSTOPS or 0
  T.armStopsLast = T.armStops
  T.asList = G.loadE(G.PLIBFC .. D.S.FC_FW_ID .. "/ASC")
  T.asSelID = 1
end
function T.splitTxt(str, len)
  local retVal = {}
  while #str > 0 do
    local div = #str + 1
    if len < #str then
      local fl = string.reverse(string.sub(str, 1, len + 1))
      local sp = string.find(fl, " ", 1)
      local t6 = sp and len + 1 - sp
      do
        div = len
      end
    end
    do
      local line = string.sub(str, 1, div)
      str = string.sub(str, div + 2)
      retVal[#retVal + 1] = line
    end
  end
  return retVal
end
function T.playAsCode(id)
  local bLong = math.floor(id / 5)
  local bShort = id % 5
  for i = 1, bLong do
    local pause = i == bLong and 400 or 200
    playTone(2400, 350, pause)
  end
  for i = 1, bShort do
    playTone(2400, 100, 200)
  end
end
function T.e()
  if D.evt == D.K.EX then
    D.UI.MODS.nextID = "DBD"
    D.evt = 0
  end
  if D.evt == D.K.RT then
    T.lnSelID = math.min(#T.asList, T.lnSelID + 1)
    if T.lnSelID >= T.lnDispShift + T.lnMax then
      T.lnDispShift = T.lnDispShift + 1
    elseif T.lnSelID < T.lnDispShift then
      T.lnDispShift = T.lnDispShift - 1
    end
  end
  if D.evt == D.K.LT then
    T.lnSelID = math.max(1, T.lnSelID - 1)
    if T.lnSelID < T.lnDispShift then
      T.lnDispShift = T.lnDispShift - 1
    end
    return true
  elseif D.evt == D.K.EN then
    local asID = T.asList[T.lnSelID][4]
    T.playAsCode(asID)
    return true
  end
end
function T.d(w)
  T.armStops = D.FC.ARMSTOPS and #D.FC.ARMSTOPS or 0
  if T.armStopsLast ~= T.armStops then
    T.asList = G.loadE(G.PLIBFC .. D.S.FC_FW_ID .. "/ASC")
    T.armStopsLast = T.armStops
    T.lnSelID = ((T.armStops == 0 and 1) or (T.lnSelID > T.armStops and T.armStops)) or T.lnSelID
    T.lnDispShift = 1
  end
  X.TX(w.xl + 10, w.yt + 12, "FC", X.FONT_S, X.TEXT_LEFT, D.C.MD_L)
  local fwName = D.S.FC_FW_ID == "BF" and "Betaflight"
  X.TX(w.xl + 90, w.yt + 12, (fwName or (D.S.FC_FW_ID == "IN" and "INAV")) or "", X.FONT_S, X.TEXT_RIGHT, D.C.MD_V)
  local lastLn = math.min(T.lnDispShift + T.lnMax, #T.asList + 1)
  for i = T.lnDispShift, T.lnDispShift + T.lnMax do
    local name = T.asList[i][1]
    local y = w.yt + 42 + (i - T.lnDispShift) * T.lnSpace
    if i == T.lnSelID then
      local cTxt = T.armStops > 0 and D.C.SNV_C
      if not D.C.MN_TS then
        cTxt = ((cTxt or (T.armStops > 0 and D.C.INV_WR)) or (T.armStops > 0 and D.C.INV_WR)) or D.C.MN_TN
      end
    end
    if i == T.lnSelID then
      local cbg = T.armStops > 0 and D.C.SNB_C
      if not D.C.MN_BS then
        cbg = ((cbg or (T.armStops > 0 and D.C.INB_WR)) or (T.armStops > 0 and D.C.INB_WR)) or nil
      end
    end
    if cbg then
      X.RCF(w.xl, y - 2, 140, T.lnSpace - 1, cbg)
    end
    X.TX(w.xl + 74, y - 1, name, X.FONT_STD_BOLD, X.TEXT_CENTER, cTxt)
    if i >= lastLn - 1 then
      break
    end
    X.LN(w.xl, y + T.lnSpace - 3, w.xl + 140, y + T.lnSpace - 3, X.PEN_DOTTED, D.C.MD_L2)
  end
  X.TX(w.xr - 96, w.yt + 8, "Beep code", X.FONT_S, X.TEXT_LEFT, D.C.MD_L)
  local asID = T.asList[T.lnSelID][4]
  local bLong = math.floor(asID / 5)
  local bShort = asID % 5
  local x = w.xr - 96
  local y = w.yt + 27
  for i = 1, bLong do
    X.RCF(x, y, 9, 3, D.C.OK)
    x = x + 12
  end
  for i = 1, bShort do
    X.RCF(x, y, 3, 3, D.C.OK)
    x = x + 5
  end
  X.TXL(w.xl + 152, w.yt + 46, 224, 86, T.asList[T.lnSelID][2], X.FONT_S, X.TEXT_LEFT, D.C.MD_V, 26, 15)
  X.TXL(w.xl + 152, w.yb - 89, 224, 80, T.asList[T.lnSelID][3], X.FONT_S, X.TEXT_LEFT, D.C.MD_V, 26, 15)
  X.TX(w.xl + 12, w.yb - 20, D.S.mspInfo, X.FONT_S, X.TEXT_LEFT, D.C.MD_V)
  return
end
return

