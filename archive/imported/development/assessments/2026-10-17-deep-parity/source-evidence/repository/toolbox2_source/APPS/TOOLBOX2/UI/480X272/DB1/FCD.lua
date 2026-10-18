-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "FCD.luac" was compiled with Lua 5.3 --

local G = ...
function T.cS(s)
  if s == 0 or s == false or s == nil then
    return "-"
  end
  if s == 1 then
    return "ACTIVE"
  elseif s == 2 then
    return "UNAVAILABLE"
  elseif s == 3 then
    return "UNHEALTHY"
  else
    return tostring(s)
  end
end
function T.cU(s)
  return string.upper(tostring(s)) or "-"
end
function T.i(w)
  T.data = {}
  local t3 = {}
  T.data[#T.data + 1] = t3
  t3 = {}
  local t4 = "OSV"
  local t5 = "EDGETX"
  local t6
  T.data[#T.data + 1] = t3
  if D.S.MDL_FC_ON and D.S.FC_MSP_ON then
    T.data[#T.data + 1] = {"FW_NAME", "FW NAME"}
    t3 = {"FW_VER", "FW VERSION"}
    T.data[#T.data + 1] = t3
    if G.fm.pgg then
      T.data[#T.data + 1] = {"API_VERSION", "API VERSION"}
      t3 = {"TARGET_NAME", "TARGET NAME"}
      T.data[#T.data + 1] = t3
      if D.S.FC_FW_ID == "BF" then
        t3 = {"MANU_ID", "MANUFACTURER"}
        T.data[#T.data + 1] = t3
      end
      T.data[#T.data + 1] = {"S_GYRO", "GYROSCOPE", T.cS}
      T.data[#T.data + 1] = {"S_ACC", "ACCELEROMETER", T.cS}
      T.data[#T.data + 1] = {"S_MAG", "MAGNETOMETER", T.cS}
      T.data[#T.data + 1] = {"S_BARO", "BAROMETER", T.cS}
      T.data[#T.data + 1] = {"S_GPS", "GPS", T.cS}
      T.data[#T.data + 1] = {"S_RF", "SONAR", T.cS}
      t3 = {"S_PITOT", "PITOT", T.cS}
      T.data[#T.data + 1] = t3
    end
  end
  T.selN = 1
  T.lineN = 8
end
function T.e()
  local maxSel = math.max(1, #T.data - T.lineN)
  if D.evt == D.K.RT then
    T.selN = G.next(T.selN + 1, 1, maxSel)
    return
  elseif D.evt == D.K.LT then
    T.selN = G.next(T.selN - 1, 1, maxSel)
    return
  end
end
function T.d(w)
  local x1, x2 = w.xl + 8, w.xl + 90
  X.TX(w.xc, w.yt + 5, "Firmware / FC", X.FONT_S, X.TEXT_CENTER, D.C.MD_L)
  for i, fData in ipairs(T.data) do
    if i >= T.selN and i <= T.selN + T.lineN then
      X.TX(x1, w.yt + 15 + (i - T.selN + 1) * 12, fData[2], X.FONT_XS, X.TEXT_LEFT, D.C.MD_L)
      local val = "-"
      local src = fData[4] == "RD" and D.RD or D.FC
      if src then
        val = src[fData[1]]
        if val then
          if fData[3] then
            val = fData[3](val)
          else
            val = tostring(val)
          end
        else
          val = "-"
        end
      end
      X.TX(x2, w.yt + 15 + (i - T.selN + 1) * 12, val, X.FONT_XS, X.TEXT_LEFT, D.C.MD_V)
    end
  end
  return
end
return

