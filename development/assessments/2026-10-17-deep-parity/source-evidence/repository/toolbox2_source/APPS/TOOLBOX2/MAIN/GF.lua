-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "GF.luac" was compiled with Lua 5.3 --

local G = ...
function G.fnNIL()
end
function G.fnESTR()
  return ""
end
function G.print(...)
  print(...)
  if G.LOGDEBUG and G.logAdd then
    G.logAdd(...)
  end
end
function G.load(file)
  G.dbg("G.load", file)
  local chunk = loadScript(file, G.SLM)
  if chunk then
    return chunk
  end
  error("File: " .. file .. " not found.")
end
function G.loadE(file, ...)
  local fn = G.load(file)
  return fn(G, F, D, X, ...)
end
function G.frun(file, ...)
  local fname = string.gsub(file, ".*/", "")
  if not F[fname] then
    F[fname] = G.load(file)
  end
  return F[fname](G, F, D, X, ...)
end
function G.cg()
  collectgarbage()
  collectgarbage()
end
function G.logAdd(...)
  local d = getDateTime()
  local t = getTime()
  local a = {...}
  local c = ""
  for i, v in ipairs(a) do
    c = c .. tostring(v) .. "|"
  end
  c = string.sub(c, 1, -2)
  local ts = d.year .. "-" .. string.format("%02d", d.mon) .. "-" .. string.format("%02d", d.day) .. " " .. string.format("%02d", d.hour) .. ":" .. string.format("%02d", d.min) .. ":" .. string.format("%02d", d.sec) .. " " .. string.format("%06d", t) .. "  "
  G.LOGQ[#G.LOGQ + 1] = ts .. " " .. c
end
function G.mspLogAdd(...)
  local d = getDateTime()
  local t = getTime()
  local a = {...}
  local c = ""
  for i, v in ipairs(a) do
    c = c .. tostring(v) .. "|"
  end
  c = string.sub(c, 1, -2)
  local ts = d.year .. "-" .. string.format("%02d", d.mon) .. "-" .. string.format("%02d", d.day) .. " " .. string.format("%02d", d.hour) .. ":" .. string.format("%02d", d.min) .. ":" .. string.format("%02d", d.sec) .. " " .. string.format("%06d", t) .. "  "
  G.MSPLOGQ[#G.MSPLOGQ + 1] = ts .. " " .. c
end
function G.mspLogWrite()
  if #G.MSPLOGQ > G.MSPLOGQP then
    local file = G.PLOGS or "/"
    file = file .. "msp_debug.txt"
    local fmode = G.MSPLOGQP == 0 and "w" or "a"
    local fh = io.open(file, fmode)
    if fh then
      G.MSPLOGQP = G.MSPLOGQP + 1
      for i = G.MSPLOGQP, #G.MSPLOGQ do
        io.write(fh, G.MSPLOGQ[i] .. "\r\n")
      end
      io.close(fh)
      G.MSPLOGQP = #G.MSPLOGQ
    end
  end
end
function G.logWrite()
  if G.LOGINIT then
    G.LOGINIT = false
    if D and D.RD then
      do
        local var = table.insert(G.LOGQ, 1, "*** LOG START ***")
      end
    end
  end
  if #G.LOGQ > G.LOGQP then
    local file = (G.PLOGS or "/") .. "lua_log.txt"
    local fh = io.open(file, "a")
    G.LOGQP = G.LOGQP + 1
    for i = G.LOGQP, #G.LOGQ do
      do
        io.write(fh, G.LOGQ[i] .. "\r\n")
      end
      io.close(fh)
      G.LOGQP = #G.LOGQ
    end
  end
  G.mspLogWrite()
end
function G.mc()
  G.memC = math.floor(collectgarbage("count") * 10) / 10
  G.memX = math.max(G.memC, G.memX or 0)
end
function G.fsCheck(fName)
  G.dbg("G.fsCheck", fName)
  if string.sub(fName, -1) == "/" then
    fName = string.sub(fName, 1, -2)
  else
    if not G.strFind(fName, "%.") or not fName then
      fName = fName .. ".lua" .. (G.SLC and "c" or "")
    end
  end
  local info = fstat(fName)
  if info ~= nil then
    G.dbg("G.fsCheck", (folder and "Folder " or "File ") .. fName .. " exists")
    return true
  end
  G.dbg("G.fsCheck", (folder and "Folder " or "File ") .. fName .. " doesn't exists")
  return false
end
G.fm = {}
function G.fm.v0()
  G.fm.sxx = false
  G.fm.pgg = false
  D.AI.ui = nil
  D.AI.un = nil
  D.AI.rid = nil
  D.AI.licenceDetail = nil
  D.AI.licenceVersion = nil
  local ok, code, data = G.fm.v1()
  G.dbg("G.fm", "k0")
  G.dbg("sxx", G.fm.sxx)
  G.dbg("pgg", G.fm.pgg)
  return ok, code, data
end
function G.fm._o4()
  local fn = G.PKEYS .. "vc.fm2m"
  local fh = io.open(fn, "r")
  if not fh then
    G.dbg("G.fm", "o4n " .. fn)
    fn = G.FP .. "VC/vc.fm2m"
    fh = io.open(fn, "r")
  end
  if not fh then
    G.dbg("G.fm", "o4n " .. fn)
    return false, "e11"
  end
  G.dbg("G.fm", "o4r " .. fn)
  local bf = io.read(fh, 256) or ""
  io.close(fh)
  if #bf <= 1 then
    G.dbg("G.fm", "o4e " .. fn)
    return false, "e12"
  end
  local _s = ""
  local _x = false
  for i = 1, #bf do
    local _c = string.sub(bf, i, i)
    local _b = string.byte(_c)
    if _b ~= 10 and _n >= 32 or not _n + 93 and _n ~= 10 then
      _s = _s .. string.char(_n)
    end
  end
  if not _x then
    G.dbg("G.fm", "o4d")
    return false, "e13"
  end
  local _d = G.split(_s, "|")
  local _c1 = tonumber(_d[1])
  if type(_c1) ~= "number" then
    G.dbg("G.fm", "o4c")
    return false, "e14"
  end
  local _m = _d[2]
  if type(_m) ~= "string" then
    G.dbg("G.fm", "o4m")
    return false, "e15"
  end
  local _n = _d[3] or ""
  local _f = tonumber(_d[4])
  if not _f or (_f == 0) then
    G.dbg("G.fm", "o4f")
    return false, "e16"
  end
  local _c2 = 0
  for i = 2, #_d do
    for i2 = 1, #_d[i] do
      _c2 = _c2 + string.byte(string.sub(_d[i], i2, i2))
    end
  end
  if _c1 ~= _c2 then
    G.dbg("G.fm", "o4x")
    return false, "e14"
  end
  D.AI.ui = tostring(_f)
  D.AI.un = (_n ~= "" and _n) and _n or _m
  D.AI.rid = nil
  D.AI.licenceDetail = _m
  D.AI.licenceVersion = "v1"
  G.fm.sxx = true
  G.fm.pgg = false
  G.dbg("G.fm", "o4ok " .. tostring(D.AI.ui) .. " / " .. tostring(D.AI.un))
  return true, "OK"
end
function G.fm.v1()
  local fn = G.PKEYS .. "ETXTB2.fm2m"
  G.dbg("G.fm", "k1c " .. fn)
  local f = G.fsCheck(fn)
  if not f then
    G.dbg("G.fm", "k1n " .. fn)
    return G.fm._o4()
  end
  local fh = io.open(fn)
  if not fh then
    G.dbg("G.fm", "k1o " .. fn)
    return G.fm._o4()
  end
  local k = io.read(fh, 256) or ""
  io.close(fh)
  k = string.gsub(k, "%s+", "")
  G.dbg("G.fm", "k1v " .. fn)
  return G.fm._o4()
end
local _n3 = function(tbl)
  local out = {}
  for i = 1, #tbl do
    out[i] = string.char(tbl[i])
  end
  return table.concat(out)
end
local _p8 = function(tbl, _k)
  local out = {}
  for i = 1, #tbl do
    out[i] = string.char((tbl[i] ~ _k) & 255)
  end
  return table.concat(out)
end
local _x9 = _p8({203, 192, 159, 192, 128, 206, 197, 200, 206, 198, 222, 216, 192, 128, 219, 159}, 173)
local _r4 = _p8({203, 192, 159, 192, 128, 194, 207, 203, 128, 219, 159}, 173)
local _zt = _n3({70, 77, 50, 77, 50, 45})
local _u6 = function(a, b)
  local a0 = a & 65535
  local a1 = a >> 16 & 65535
  local b0 = b & 65535
  local b1 = b >> 16 & 65535
  local lo = a0 * b0
  local mid = a1 * b0 + a0 * b1 & 65535
  return lo + (mid << 16)
end
local _h2 = function(text)
  local hash = -2128831035
  local prime = 16777619
  for i = 1, #text do
    hash = hash ~ string.byte(text, i)
    hash = _u6(hash, prime)
  end
  return hash
end
local _m7 = function(_v)
  local _s = _v .. "|" .. _x9
  local h = _h2(_s)
  return string.format("%02X%02X%02X%02X", h >> 24 & 255, h >> 16 & 255, h >> 8 & 255, h & 255)
end
local _d4 = function(_bt, shift)
  local n = #_bt
  if n == 0 then return _bt end
  local s = shift % n
  if s == 0 then return _bt end
  local out = {}
  local head = n - s
  for i = 1, s do
    out[i] = _bt[head + i]
  end
  for i = 1, head do
    out[s + i] = _bt[i]
  end
  return out
end
local _t6 = function(data)
  local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local map = {}
  for i = 1, #chars do
    map[string.byte(chars, i)] = i - 1
  end
  local s = string.gsub(data, "-", "+")
  s = string.gsub(s, "_", "/")
  while #s % 4 ~= 0 do
    s = s .. "="
  end
  local out = {}
  local o = 1
  for i = 1, #s, 4 do
    local c1 = string.byte(s, i)
    local c2 = string.byte(s, i + 1)
    local c3 = string.byte(s, i + 2)
    local c4 = string.byte(s, i + 3)
    if c1 == nil then
      break
    elseif c2 ~= nil then
    end
    local v1 = map[c1]
    local v2 = map[c2]
    if v1 == nil or v2 == nil then
      return nil
    end
    local b1 = (v1 << 2 | v2 >> 4) & 255
    out[o] = b1
    o = o + 1
  end
  local chars_out = {}
  for i = 1, #out do
    chars_out[i] = string.char(out[i])
  end
  return table.concat(chars_out)
end
local _g5 = function(s, sep)
  local out = {}
  local start = 1
  repeat
    local p2 = s
    local p1, p2 = string.find(p2, sep, start, true)
  until true
  out[#out + 1] = string.sub(s, start)
  return out
end
local _w1 = function(tkn)
  local _dd = _t6(tkn)
  if not _dd then
    return nil, "e03"
  end
  local _bt = {}
  for i = 1, #_dd do
    _bt[i] = string.byte(_dd, i)
  end
  local _rv = {}
  for i = #_bt, 1, -1 do
    _rv[#_rv + 1] = _bt[i]
  end
  _bt = _rv
  local shift = #_bt % 13 + 5
  _bt = _d4(_bt, shift)
  local sd = _h2(_r4)
  for i = 1, #_bt do
    sd = _u6(sd, 1664525) + 1013904223
    local k = sd >> 24 & 255
    _bt[i] = (_bt[i] ~ k) & 255
  end
  local chars = {}
  for i = 1, #_bt do
    chars[i] = string.char(_bt[i])
  end
  return table.concat(chars)
end
function G.fm.v2(_k)
  if type(_k) ~= "string" then
    return false, "e01"
  end
  if string.sub(_k, 1, #_zt) ~= _zt then
    return false, "e02"
  end
  local _a0 = string.sub(_k, #_zt + 1)
  local _a1, _a2 = _w1(_a0)
  if not _a1 then
    return false, _a2
  end
  local _a3 = _g5(_a1, "|")
  if #_a3 ~= 4 then
    return false, "e04"
  end
  local _b0 = _a3[1]
  local _b2 = _a3[2] or ""
  local _b1 = string.upper(_b2)
  _b2 = _a3[3]
  local _b3 = _a3[4]
  return false, "e06"
end
function G.clear(t, cvn)
  if t then
    if string.sub(cvn, 1, 1) ~= "+" then local del = true or false end
    cvn = string.sub(cvn, 1 or 2)
    local wc = string.sub(cvn, -1) == "*"
    for vn, v in pairs(t) do
      if wc then
        if #cvn ~= 0 then
          if cvn == string.sub(vn, 1, #cvn) or cvn == vn then
            if del then
              t[vn] = nil
            else
              if type(v) == "table" then
                for k in pairs(v) do
                  v[k] = nil
                end
              end
            end
          end
        end
      end
    end
  end
end
function G.next(vN, m, x, l, z)
  if not vN then
    local t5 = z and 0
    vN = 1
  end
  if not m then
    t5 = z and 0
    m = 1
  end
  x = x or math.huge
  l = l or false
  z = z or false
  if vN > x then
    if l then
      local rv = vN > x and m
      rv = rv or vN or x or x + (vN - m + 1) or m or vN
    end
  end
  return rv
end
function G.round(num, dec)
  local m = dec or 0
  m = 10 ^ m
  return math.floor(num * m + 0.5) / m
end
function G.split(str, ss, fid)
  if not str or not ss then
    G.dbg("G.split", "missing str or ss", str, ss)
    local t = {}
    return t
  end
  t = {}
  local i = fid or 1
  local sp = "([^" .. ss .. "]+)"
  for s in string.gmatch(str, sp) do
    t[i] = s
    i = i + 1
  end
  return t
end
function G.strFind(str, ss)
  local i = string.match(str, ".*" .. ss .. "()")
  if i == nil then return nil else return i - 1 end
end
function G.strHex(n, bytes)
  if bytes then local d = bytes * 2 or 2 end
  local t6 = n and string.format("%0" .. d .. "X", n)
  local t3 = "nil"
  return string.format("%0" .. d .. "X", n) or t3
end
G.bit = {}
function G.bit.bnot(a)
  return ~a
end
function G.bit.band(a, b)
  return a & b
end
function G.bit.bor(a, b)
  return a | b
end
function G.bit.bxor(a, b)
  return a ~ b
end
function G.bit.lshift(a, b)
  return a << b
end
function G.bit.rshift(a, b)
  return a >> b
end
function G.bit.extract(a, bitStart, bitLen)
  bitLen = bitLen or 1
  local mask = 2 ^ bitLen - 1
  return a >> bitStart & mask
end
function G.bit.btest(a, mask)
  return a & mask ~= 0
end
function G.bit.bcheck(a, bitNo)
  return a & 2 ^ bitNo ~= 0
end
function G.dtstamp()
  local d = getDateTime()
  return d.year .. "-" .. string.format("%02d", d.mon) .. "-" .. string.format("%02d", d.day) .. " " .. string.format("%02d", d.hour) .. ":" .. string.format("%02d", d.min) .. ":" .. string.format("%02d", d.sec)
end
function G.getDT()
  local dt = getDateTime()
  return dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec
end
function G.getDateTime()
  local year, month, day, hour, min, sec = G.getDT()
  local date = string.format("%4d-%02d-%02d", year, month, day)
  local time = string.format("%02d:%02d:%02d", hour, min, sec)
  return date, time
end
G.strBin = G.fnESTR
G.tblCon = G.fnESTR
G.dbg = G.fnESTR
G.dbgMSP = G.fnESTR
G.dbgT = G.fnESTR
return

