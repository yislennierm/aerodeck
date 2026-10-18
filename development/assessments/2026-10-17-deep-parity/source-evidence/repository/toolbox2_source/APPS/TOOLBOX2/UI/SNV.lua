-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "SNV.luac" was compiled with Lua 5.3 --

local G = ...
function D.UI.SNV(a, bar)
  local drv = {}
  drv.val = ""
  drv.unit = ""
  drv.cv = D.C.MD_V
  drv.cb = D.C.MD_B
  drv.cl = D.C.MD_L
  drv.ci = D.C.MD_B
  if (type(a) ~= "table") or not a.s then
    return drv
  end
  a.data = a.data or D.S.TLM_data
  if not a.data then return drv end
  local txt = D.SEN[a.s .. "n"] or a.n or ""
  a.n = txt
  txt = D.SEN[a.s .. "txt"] or false
  if txt then
    local varName = D.SEN[a.s .. "vs"]
    local t5 = {}
    t5.n = a.n
    do
      t5.val = D.S[varName] or ""
      t5.unit = ""
      t5.cv = D.C.MD_V
      t5.cb = D.C.MD_B
      t5.cl = D.C.MD_L
      t5.ci = D.C.MD_B
      return t5
    end
    local vsn = D.SEN[a.s .. "vs"]
  end
  do
    a.vo = a.vo or D.SEN[a.s .. "vo"] or nil
    if a.vo then
      a.v = a.vo
    else
      a.v = vsn and D.S[vsn] or a.v
    end
    a.v = D.SEN[a.s .. "vf"](a.v) or a.v
    a.vd = D.SEN[a.s .. "vd"] or a.vd
    a.i = D.SEN[a.s .. "i"] or a.i or false
    a.f = a.f or D.SEN[a.s .. "f"] or nil
    a.vM = D.SEN[a.s .. "m"] or a.vM or 0
    a.vX = D.SEN[a.s .. "x"] or a.vX or 100
    a.vL = D.SEN[a.s .. "l"] or a.vL or 20
    a.vC = D.SEN[a.s .. "c"] or a.vC or 10
    a.pd = a.pd or false
    a.pc = a.pc or D.S.TLM_ON and D.S.TLM_data
    a.pr = a.pr or 50
    local unit = a.v or a.vM
    a.v = unit
    unit = a.u or D.SEN[a.s .. "u"] or ""
    local cv, cb, cl, ci, cbar
    if not a.i then
      if a.v <= a.vC then
        cb = a.cbC or D.C.SNB_C
        cv = a.cvC or D.C.SNV_C
        cl = a.clC or D.C.SNL_C
        ci = a.ciC or D.C.WARN
        if not a.cbar then cbar = D.C.BR_C end
      else
        if not a.i then
          if a.v <= a.vL then
            cb = a.cbL or D.C.SNB_L
            cv = a.cvL or D.C.SNV_L
            cl = a.clL or D.C.SNL_L
            ci = a.ciL or D.C.ALERT
            if not a.cbar then cbar = D.C.BR_L end
          else
            cb = a.cbN or D.C.SNB_N
            cv = a.cvN or D.C.SNV_N
            cl = a.clN or D.C.SNL_N
            ci = a.ciN or D.C.OK
            if not a.cbar then cbar = D.C.BR_N end
          end
        end
      end
    end
    local val = a.v or ""
    local t12 = a.v < a.vM and a.vM
    val = a.v
    if (not a.vd or not a.vd) and type(val) ~= "string" and a.f then
      if not string.format(a.f, val) and not a.pd then
        local pcLimit = a.pcv or a.vX or a.vM
        pc = (not a.i) and pcLimit >= a.v or a.i ? nil
        if (not a.i) and pcLimit >= a.v or a.i ? nil then
          local vM = a.pd or (not a.i) and pcLimit >= a.v or a.i ? nil and D.TI["tick" .. a.pr] and "" and ""
        end
      end
    end
    local ret = {n = a.n, val = val, unit = unit, cv = cv, cb = cb, cl = cl, ci = ci}
    if not bar then
      return ret
    end
    local shift = 0 - a.vM
    vM = a.vM + shift
    local vX = a.vX + shift
    local vL = a.vL + shift
    local vC = a.vC + shift
    local v = a.v + shift
    v = vX < v and vX
    v = v or vM > v or vM and vM
    local range = vX - vM
    local pct = G.round(v * 100 / range, 0)
    ret.cbar = cbar
    ret.pct = pct
    return ret
  end
end
return

