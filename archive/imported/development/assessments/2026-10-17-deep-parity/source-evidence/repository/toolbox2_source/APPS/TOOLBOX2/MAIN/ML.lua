-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "ML.luac" was compiled with Lua 5.3 --

local G = ...
local ML = {bg = function()
  if D.INIT_do then
    D.INIT_do = G.frun(G.PMAIN .. "INIT")
    if not D.INIT_do then
      G.clear(F, "INIT")
      G.clear(D, "INIT*")
    end
  end
  if D.RINIT then
    if #D.RINIT > 0 then
      local yieldRinit = G.MODE == "WG" and getUsage and RINIT_YIELD_WG
      if yieldRinit and not D.RINIT_total then
        do
          D.RINIT_total = #D.RINIT
          D.RINIT_done = 0
        end
        repeat
          repeat
            local rinitBefore = #D.RINIT
            if yieldRinit then
              local v = table.remove(D.RINIT, 1) or D.RINIT[1]
            end
            if v.cb then
              v.cb()
            else
              if v.fn then
                if v.args then
                  G.loadE(v.fn, table.unpack(v.args))
                else
                  G.loadE(v.fn)
                end
              end
            end
            if not yieldRinit then
              table.remove(D.RINIT, 1)
            end
            if yieldRinit then
              local rinitAdded = #D.RINIT - (rinitBefore - 1)
              if rinitAdded > 0 then
                D.RINIT_total = (D.RINIT_total or rinitBefore) + rinitAdded
              end
              D.RINIT_done = (D.RINIT_done or 0) + 1
            end
            if #D.RINIT ~= 0 and not yieldRinit or yieldRinit > getUsage() then
            end
          until yieldRinit
        until yieldRinit <= getUsage()
        if yieldRinit and #D.RINIT > 0 then
          D.RINIT_busy = true
        else
          G.clear(D, "+RINIT")
          D.RINIT_total = nil
          D.RINIT_done = nil
        end
        return
      end
    end
    D.RINIT_total = nil
    D.RINIT_done = nil
  end
  D.RINIT = {}
  D.RINIT_total = nil
  D.RINIT_done = nil
  D.TI.now = getTime()
  D.TI.tick50 = D.TI.now % 100 > 50 and true or false
  D.TI.tick100 = D.TI.now % 200 > 100 and true or false
  D.TI.tick200 = D.TI.now % 400 > 200 and true or false
  D.TI.tick300 = D.TI.now % 600 > 300 and true or false
  if D.TI.wCrit == nil then
    if D.TI.tick200 then
      D.TI.wCrit = true
    end
  elseif D.TI.wCrit == false then
    if not D.TI.tick200 then D.TI.wCrit = nil end
  end
  if D.TI.wLow == nil then
    if D.TI.tick300 then
      D.TI.wLow = true
    end
  elseif D.TI.wLow == false then
    if not D.TI.tick300 then D.TI.wLow = nil end
  end
  G.mc()
  D.S.TLM_ON = getSwitchValue(D.S.TLM_ON_SRC)
  if G.DEVON then
    G.LOGDEBUG = getValue(G.LOGDEBUGSW) > 50
    D.S.UI_THM_OV = getValue("sb") < 0
    do
      local debugMSP = getValue("sc") >= 0
      if G.DEV.debugMSP ~= debugMSP then
        G.DEV.debugMSP = debugMSP
        if G.mspLogAdd then
          G.mspLogAdd("MSPDBG", "enabled" or "disabled")
        end
      end
    end
    F.RD_BT()
    if D.S.MDL_RCP_ON and D.S.TLM_ON then
    end
    if F.TLM_UPD then
      F.TLM_UPD()
    end
    if G.fm.sxx and D.S.MDL_BTV_ON and (D.S.BT_CELL_WARN_SND > 0) and (D.S.BT_CELL_WARN_TYPE > 0) and not D.UI.mute then
      if (D.S.BT_MD_CELL_VA or 0) > D.S.BT_CELL_NOPWR then
        F.RD_SND()
      end
    end
  end
  F.SN_IND()
  if D.S.TMR_host == 1 and D.TI.tmrUpdate ~= D.S.ARMED then
    F.RD_TMR(D.S.ARMED and "start" or "stop")
    D.TI.tmrUpdate = D.S.ARMED
  end
end,
            run = function()
  if D.INIT_do then
    ML.bg()
  end
  if G.MODE == "WG" and D.RINIT_busy then
    D.RINIT_busy = nil
    X.CLR(D.C.MD_B)
    return
  end
  local mspAllowed = D.S.FC_MSP_ON and D.S.TLM_ON and not D.S.ARMED
  if D.MSP then
    D.MSP.startAt = D.MSP.startAt or D.TI.now + (D.MSP.START_DELAY or 100) or nil
  end
  local mspDelayDone = D.MSP and D.MSP.startAt and D.TI.now >= D.MSP.startAt
  D.S.mspReady = D.S.mspFcReady and mspAllowed and mspDelayDone
  if mspAllowed and mspDelayDone then
    if D.S.mspCheck then
      F.MSPCFC(D.S.mspCheck)
    end
    if D.S.mspFcReady then
      if F.MSPCFC then
        G.clear(F, "MSPCFC")
      end
      F.MSPML()
    end
  end
  ML.bg()
  if F.SN_ATT then
    F.SN_ATT()
  end
  if F.SN_BARO then
    F.SN_BARO()
  end
  if F.SN_AIR then
    F.SN_AIR()
  end
  if F.SN_GPS and D.S.GPS_ON then
    F.SN_GPS()
  end
  if D.S.MDL_VTX_ON and D.S.VTX_CONN_TYPE > 0 and D.VTX.file then
    F.SN_VTX("read")
  end
  G.frun(G.PUI .. "UIML")
  if (D.S.APP_LOG_ERR or G.LOGDEBUG) and #G.LOGQ > G.LOGQP then
    G.frun(G.PLIBFS .. "FSLOG")
  end
end}
return ML

