-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "RL.luac" was compiled with Lua 5.3 --

local G = ...
D.S.RX_QLY_CH1 = nil
D.S.RX_RSI_CH1 = nil
D.S.RX_RSI_CH2 = nil
D.S.RX_SNR_CH1 = nil
D.S.TX_QLY_CH1 = nil
D.S.TX_RSI_CH1 = nil
D.S.TX_SNR_CH1 = nil
D.S.TX_PWR_CH1 = nil
D.S.TX_RFM_CH1 = nil
local sensors = {}
if add then
  D.SEN.SN11n = "RQLY"
  D.SEN.SN11m = 0
  D.SEN.SN11x = 100
  D.SEN.SN11l = D.S.RL_RQL_L or 20
  D.SEN.SN11c = D.S.RL_RQL_C or 10
  D.SEN.SN11u = "%"
  D.SEN.SN11v = nil
  D.SEN.SN11vs = "RX_QLY_CH1"
  D.SEN.SN11vf = math.floor
  D.SEN.SN12n = "RSSI"
  D.SEN.SN12m = -130
  D.SEN.SN12x = 0
  D.SEN.SN12l = D.S.RL_RSI_L or -90
  D.SEN.SN12c = D.S.RL_RSI_C or -100
  D.SEN.SN12u = "dBm"
  D.SEN.SN12v = nil
  D.SEN.SN12vs = "RX_RSI_CH1"
  D.SEN.SN12vf = math.floor
  D.SEN.SN13n = "RSNR"
  D.SEN.SN13m = -6
  D.SEN.SN13x = 50
  D.SEN.SN13l = D.S.SNnL or 4
  D.SEN.SN13c = D.S.SNnC or 0
  D.SEN.SN13u = "dB"
  D.SEN.SN13v = nil
  D.SEN.SN13vs = "RX_SNR_CH1"
  D.SEN.SN13vf = math.floor
  D.SEN.SN17n = "TX POWER"
  D.SEN.SN17m = 0
  D.SEN.SN17x = math.huge
  D.SEN.SN17l = math.huge
  D.SEN.SN17c = 1000
  D.SEN.SN17u = "mW"
  D.SEN.SN17i = true
  D.SEN.SN17v = nil
  D.SEN.SN17vs = "TX_PWR_CH1"
  D.SEN.SN17vf = math.floor
  D.SEN.SN18n = "RF MODE"
  D.SEN.SN18m = 0
  D.SEN.SN18x = math.huge
  D.SEN.SN18l = math.huge
  D.SEN.SN18c = math.huge
  D.SEN.SN18i = true
  D.SEN.SN18vs = "TX_RFM_CH1"
  D.SEN.SN18vf = math.floor
  D.SEN.SN19n = "TQLY"
  D.SEN.SN19m = nil
  D.SEN.SN19x = nil
  D.SEN.SN19l = 30
  D.SEN.SN19c = 10
  D.SEN.SN19u = "%"
  D.SEN.SN19v = nil
  D.SEN.SN19vs = "TX_QLY_CH1"
  D.SEN.SN19vf = math.floor
  local getRFModeTable = function()
    if D.S.RCP_pverID == "XF" then
      return {"50", "150", [0] = "4"}
    elseif D.S.RCP_pverID == "TRS" then
      return {"250", [0] = "-"}
    elseif D.S.RCP_pverID == "EL2" then
      return {"25", "50", "100", "150", "200", "250", "500", [0] = "-"}
    elseif D.S.RCP_pverID == "EL3" then
      return {"25", "50", "100", "100F", "150", "200", "250", "333F", "500", "D250", "D500", "F500", "F1k", [0] = "-"}
    end
    return {}
  end
  local rfModeTable = getRFModeTable()
  local TX_RSI_CH1_fn = function()
    if D.S.RX_RSI_CH2 and D.S.RX_RSI_CH2 < 0 then
    end
    D.SEN.SN12vo = math.max(D.S.RX_RSI_CH1, D.S.RX_RSI_CH2) or D.S.RX_RSI_CH1 or nil
  end
  local TX_RFM_CH1_fn = function()
    D.SEN.SN18vd = rfModeTable[D.S.TX_RFM_CH1] or D.S.TX_RFM_CH1 or nil
  end
  table.insert(sensors, {sName = "TX_RFM_CH1", pName = "RFMD", sLabel = "RF Mode", dUnit = "NONE", sMin = 0, sMax = 20, uFN = TX_RFM_CH1_fn})
  table.insert(sensors, {sName = "TX_RSI_CH1", pName = "TRSS", sLabel = "Tx RSSI", dUnit = "DBM", sMin = -130, sMax = 0, uFN = TX_RSI_CH1_fn})
  table.insert(sensors, {sName = "TX_QLY_CH1", pName = "TQly", sLabel = "Tx Quality", dUnit = "PERCENT", sMin = 0, sMax = 100})
  table.insert(sensors, {sName = "TX_SNR_CH1", pName = "TSNR", sLabel = "Tx SNR", dUnit = "DB", sMin = -50, sMax = 50})
  table.insert(sensors, {sName = "TX_PWR_CH1", pName = "TPWR", sLabel = "Tx Power", dUnit = "MILLIWATT", sMin = 0, sMax = 5000})
  table.insert(sensors, {sName = "RX_RSI_CH1", pName = "1RSS", sLabel = "Rx RSSI1", dUnit = "DBM", sMin = -130, sMax = 0})
  table.insert(sensors, {sName = "RX_RSI_CH2", pName = "2RSS", sLabel = "Rx RSSI2", dUnit = "DBM", sMin = -130, sMax = 0})
  table.insert(sensors, {sName = "RX_QLY_CH1", pName = "RQly", sLabel = "Rx Quality", dUnit = "PERCENT", sMin = 0, sMax = 100})
  t12 = {sName = "RX_SNR_CH1", pName = "RSNR", sLabel = "Rx SNR", dUnit = "DB", sMin = -50, sMax = 50}
  table.insert(sensors, t12)
end
return sensors

