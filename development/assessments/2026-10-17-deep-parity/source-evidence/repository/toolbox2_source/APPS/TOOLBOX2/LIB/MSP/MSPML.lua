-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "MSPML.luac" was compiled with Lua 5.3 --

local G = ...
function F.MSPML()
  if D.S.mspReady then
    F.MSPRPT()
  end
  if D.MSP.idle then
    for mCmd, data in pairs(D.MSP.RPT) do
      if data[1] < D.TI.now then
        F.MSPQAD(data[3], mCmd, data[4], data[5])
        data[1] = D.TI.now + data[2]
      end
    end
    if D.MSP.Q[1] then
      D.MSP.OUT.save = D.MSP.Q[1][3]
      D.MSP.OUT.data = D.MSP.Q[1][2]
      D.MSP.OUT.cmd = D.MSP.Q[1][1]
      D.S.mspInfo = "Read " .. G.strHex(D.MSP.OUT.cmd)
      do
        local mspCmdData = D.MSP.CMDS[D.MSP.OUT.cmd]
        if mspCmdData then
          local data = G.split(mspCmdData, "|")
          if data[2] then
            D.S.mspInfo = data[2]
          end
          if data[3] then
            local paramID = tonumber(data[3])
            D.S.mspInfo = D.S.mspInfo .. (" " .. D.MSP.OUT.data[paramID] or "")
          end
        end
        D.S.mspInfo = D.S.mspInfo .. (" #" .. D.MSP.OUT.attNo or "")
        D.MSP.sendRequest = true
      end
    end
  end
  if D.MSP.sendRequest then
    D.MSP.idle = false
    D.MSP.sendRequest = nil
    G.dbgMSP("MSPML", "<--- START REQUEST")
    G.dbgMSP("MSPML", "cmd", G.strHex(D.MSP.OUT.cmd, 2) .. " (" .. D.MSP.OUT.cmd .. ")", "data", G.tblCon(D.MSP.OUT.data, "hex"))
    repeat
      local lastChunk = F.MSPOUT()
    until lastChunk
    do
    end
    D.MSP.respWait = true
    D.MSP.respTimeout = D.TI.now + D.MSP.RESP_WAIT
    G.dbgMSP("MSPML", "Request sent at", D.TI.now)
    G.dbgMSP("MSPML", "<--- END REQUEST")
  end
  if D.MSP.respWait then
    if D.TI.now < D.MSP.respTimeout then
      repeat
        do
          local chunk, chunkStat
          repeat
            chunk = F.MSPWRAP("pop")
            if chunk then
              if D.MSP.badResp then
                G.dbgMSP("MSPML", "drop bad response chunk")
              else
                chunkStat = F.MSPIN(chunk)
              end
            end
            if D.MSP.WRAP ~= "WR/MSPWSP" then
              break
            end
          until chunkStat ~= nil
          if D.MSP.IN.errNo >= D.MSP.IN.errMax then
            G.dbgMSP("MSPML", "!!! ERROR", "Too many errors")
            D.MSP.badResp = true
            break
          end
          if type(chunkStat) ~= "string" then
            break
          end
          G.dbgMSP("MSPML", "!!! ERROR", D.MSP.IN.errNo, chunkStat)
          D.MSP.badResp = true
        until D.MSP.WRAP == "WR/MSPWSP"
        if chunkStat == true then
          G.dbgMSP("MSPML", "MSP packet processed")
          F.MSPRST("cancel")
        end
      end
    else
      G.dbgMSP("MSPML", "!!! TIMEOUT", "now", D.TI.now, "to", D.MSP.respTimeout)
      F.MSPRST("clearBuffer", D.MSP.OUT.cmd)
      D.MSP.OUT.attNo = D.MSP.OUT.attNo + 1
    end
    if D.MSP.OUT.attNo > D.MSP.OUT.attMax then
      F.MSPRST("cancel")
    end
  end
end
return

