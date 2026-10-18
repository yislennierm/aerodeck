-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "GPS.luac" was compiled with Lua 5.3 --

local G = ...
function T.i(w)
  local tasks = {{f = nil, w = {xl = w.xl, yt = w.yt, w = 110, h = 40}},
                 {f = nil, w = {xl = w.xl + 110, yt = w.yt, w = 168, h = 40}},
                 {f = nil, w = {xl = w.xl + 278, yt = w.yt, w = 110, h = 40}},
                 {f = nil, w = {xl = w.xl, yt = w.yt + 40, w = 140, h = 168}},
                 {f = nil, w = {xl = w.xl, yt = w.yb - 27, w = 140, h = 28}},
                 {f = nil, w = {xl = w.xl + 140, yt = w.yt + 40, w = 248, h = 196}}}
  G.loadE(G.PUI .. "UITSKSET", tasks)
  T.errorsRead = false
  T.satsInfo = false
  T.satsAll = 0
  T.readNextTS = 0
  T.readWait = 100
  local t2 = {}
  T.SATS = t2
  T.SAT_TYPE = {"SBAS", "Galileo", "BeiDou", "IMES", "QZSS", "Glonass", [0] = "GPS"}
  T.SAT_STAT = {"Searching", "Acquired", "Unusable", "Lock", "Full Lock", "Full Lock", "Full Lock", [0] = "No Signal"}
  T.SAT_STATC = {"MD_V", "MD_V", "MD_V", "ALERT", "OK", "OK", "OK", [0] = "MD_V"}
  T.SAT_HEAL = {"Healthy", "Unhealthy", "Unknown", [0] = "Unknown"}
  T.lnMax = 10
  T.lnSpace = 16
  T.lnID = 1
end
function T.e()
  if D.evt == D.K.EX then
    D.UI.MODS.nextID = "DBD"
    D.evt = 0
  elseif D.evt == D.K.RT then
    T.lnID = T.lnID + 1
    if T.satsAll >= T.lnMax then
      T.lnID = math.min(T.lnID, T.satsAll - T.lnMax + 1)
    else
      T.lnID = 1
    end
  elseif D.evt == D.K.LT then
    T.lnID = T.lnID - 1
    T.lnID = math.max(T.lnID, 1)
  end
end
function T.d(w)
  T.satsAll = 0
  if G.fm.pgg and D.S.MDL_GPS_ON and D.GPS and D.GPS.SATS then
    T.satsAll = #D.GPS.SATS
    if T.satsAll > 0 then
      local lastLn = math.min(T.lnID + T.lnMax, T.satsAll + 1)
      for i = T.lnID, lastLn do
        local y = w.yt + 43 + (i - T.lnID) * T.lnSpace
        local satStatName = T.SAT_STAT[D.GPS.SATS[i][1]] or ""
        local satTypeName = T.SAT_TYPE[D.GPS.SATS[i][2]] or D.GPS.SATS[i][2]
        local satTypeID = D.GPS.SATS[i][3] or ""
        do
          local satUsed = D.GPS.SATS[i][4] == 1
          local satSignal = D.GPS.SATS[i][5] or 0
          if satUsed then
            local cid = T.SAT_STATC[D.GPS.SATS[i][1]] or "MD_L" or "MD_L"
          end
          local ct = D.C[cid] or D.C.MD_L
          X.TX(w.xl + 12, y + 4, satTypeName .. "." .. satTypeID, X.FONT_XS, X.TEXT_LEFT, ct)
          X.GA(w.xl + 68, y + 7, 15, 6, satSignal, 99, nil, ct)
          X.TX(w.xl + 86, y + 4, satStatName, X.FONT_XS, X.TEXT_LEFT, ct)
          if i >= lastLn - 1 then
            break
          end
        end
      end
    end
  end
  do
    local color = D.C.MD_L
    if G.fm.pgg then
      local var = D.S.GPS_SATS or "-"
      X.TX(w.xl + 10, w.yt + 15, "SATS", X.FONT_S, X.TEXT_LEFT, D.C.MD_L)
      X.TX(w.xl + 68, w.yt + 12, var, X.FONT_STD_BOLD, X.TEXT_RIGHT, D.C.MD_V)
      X.TX(w.xl + 73, w.yt + 12, "/", X.FONT_STD_BOLD, X.TEXT_LEFT, D.C.MD_L)
      X.TX(w.xl + 100, w.yt + 12, T.satsAll > 0 and T.satsAll or "", X.FONT_STD_BOLD, X.TEXT_RIGHT, D.C.MD_L)
    end
    local color = D.S.POS_FIX and D.C.INB_ON or D.C.INB_WR
    X.RCF(w.xr - 110, w.yt, 110, 40, color)
    color = D.C.INV_WR
    X.TX(w.xr - 54, w.yt + 12, "3D FIX", X.FONT_STD_BOLD, X.TEXT_CENTER, color)
    local cL = w.xl + 150
    local cD = w.xl + 350
    local cU = w.xl + 355
    local y = w.yt + 46
    local var
    local c = D.S.TLM_ON and D.C.MD_L or D.C.MD_L2
    local degs = D.UI.CHDEG
    local items = {{l = "Aircraft LAT", sID = "POS_LAT", f = "%3.7f", u = "DDEG", d = "-"},
                     {l = "Aircraft LON", sID = "POS_LON", f = "%3.7f", u = "DDEG", d = "-"},
                     {l = "Ground speed", sID = "SPD_GND", f = "%d", u = "KM/H", d = "-"},
                     {l = "Altitude (ASL)", sID = "ALT_GPS", f = "%d", u = "M", d = "-"},
                     {l = "Aircraft heading", sID = "DIR_GC", f = "%d", u = degs, d = "-"}}
    if G.fm.pgg then
      items[#items + 1] = {l = "Home LAT", sID = "POS_LATH", f = "%3.7f", u = "DDEG", d = "-"}
      items[#items + 1] = {l = "Home LON", sID = "POS_LONH", f = "%3.7f", u = "DDEG", d = "-"}
      items[#items + 1] = {l = "Home Distance", sID = "POS_DISTH", f = "%d", u = "m", d = "-"}
      items[#items + 1] = {l = "Home heading", sID = "DIR_GCH", f = "%d", u = degs, d = "-"}
    end
    local lnSpace = D.S.TLM_ON and D.C.MD_V
    c = D.C.MD_L
    lnSpace = 20
    for i, item in ipairs(items) do
      X.TX(cL, y + (i - 1) * lnSpace + 3, item.l, X.FONT_S, X.TEXT_LEFT, c)
      local value = D.S[item.sID]
      if (item.f ~= "%d" or not value or not math.floor(value)) and value then
        local var = string.format(item.f, value) or item.d
      end
      X.TX(cD, y + (i - 1) * lnSpace - 1, var, X.FONT_STD_BOLD, X.TEXT_RIGHT, c)
      local ys = item.u == degs and 0 or 6
      local unit = item.u or ""
      X.TX(cU, y + (i - 1) * lnSpace + ys, unit, X.FONT_XS, X.TEXT_LEFT, c)
    end
    X.TX(w.xl + 12, w.yb - 20, D.S.mspInfo, X.FONT_S, X.TEXT_LEFT, D.C.MD_V)
    return
  end
end
return

