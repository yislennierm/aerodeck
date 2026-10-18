-- Normalized EdgeTX MSP telemetry transports. No parallel reader or drain loop.
-- S.Port: original MSPWSP uses sensor0x0D/frame0x30 requests, sensor0/0x1B
-- frame0x32 responses; six MSP bytes packed LE into dataId(U16)+value(U32).
-- EdgeTX2.12.4 api_general.cpp pushes/checks integers for S.Port values.
-- Use signed integer arithmetic to preserve all32 bits on Lua int32/float32.
local M={}
local function integer(v,lo,hi)return type(v)=='number'and v>=lo and v<=hi and v%1==0.0 end
local function byte(v)return integer(v,0,255)end
local function validBody(kind,data)
 if kind~=0x7A and kind~=0x7C then return false end
 if type(data)~='table'or #data<8 or #data>264 then return false end
 for i=1,#data do if not byte(data[i])then return false end end
 return data[1]==0xC8 and data[2]==0xEA and data[3]>=0x50 and data[3]<=0x5F and data[4]==0 and data[7]+data[8]*256==#data-8
end
local function pack(chunk)
 local id=math.floor(chunk[1])+math.floor(chunk[2])*256
 local lo=math.floor(chunk[3])+math.floor(chunk[4])*256
 local hi=math.floor(chunk[5])+math.floor(chunk[6])*256
 -- No positive intermediate exceeds INT32_MAX; the negative branch never
 -- drops low bytes by assembling an unsigned word as a float32.
 local value=(hi>=32768 and hi-65536 or hi)*65536+lo
 return id,value
end
local function unpack(id,value)
 local data={id%256,math.floor(id/256)}
 for i=3,6 do
  local low=value%256;data[i]=low
  value=math.floor((value-low)/256)
 end
 return data
end
function M.new(kind,io)
 if kind~='CRSF'and kind~='S.PORT'then return nil,'UNSUPPORTED TRANSPORT'end
 if not io or type(io.push)~='function'or type(io.pop)~='function'then return nil,'TRANSPORT UNAVAILABLE'end
 local stats={queued=0,fragments=0,received=0,dropped=0,invalid=0,busy=0}
 local t={name=kind,responseWait=kind=='S.PORT'and 800 or 500,stats=stats,onFrame=io.onFrame}
 if kind=='CRSF'then
  function t.push(frame,data)
   if not validBody(frame,data)then stats.invalid=stats.invalid+1;return false end
   local ok=io.push(frame,data);if ok==true then stats.queued=stats.queued+1 else stats.busy=stats.busy+1 end
   return ok
  end
  function t.pop()local frame,data=io.pop();if frame~=nil then stats.received=stats.received+1 end;return frame,data end
  function t.reset()end
  return t
 end
 local tx,sequence=nil,0
 local maxWord=2147483647
 -- LuaJIT/double fixtures and Lua64 hosts can also represent unsigned U32.
 -- On radio Lua32, sportTelemetryPop already returns the signed bit pattern.
 if not math.maxinteger or math.maxinteger>2147483647 then maxWord=4294967295 end
 function t.push(frame,data)
  if tx or not validBody(frame,data)then if tx then stats.busy=stats.busy+1 else stats.invalid=stats.invalid+1 end;return false end
  local copy={};for i=1,#data do copy[i]=math.floor(data[i])end
  tx={data=copy,ptr=9,first=true};stats.queued=stats.queued+1;return true
 end
 function t.tick()
  if not tx then return end
  local data,ptr=tx.data,tx.ptr
  local chunk
  if tx.first then chunk={0x50+sequence,data[4],data[5],data[6],data[7],data[8]}
  else chunk={0x40+sequence};while #chunk<6 and ptr<=#data do chunk[#chunk+1]=data[ptr];ptr=ptr+1 end end
  while #chunk<6 do chunk[#chunk+1]=0 end
  local id,value=pack(chunk)
  if io.push(0x0D,0x30,id,value)==true then
   stats.fragments=stats.fragments+1;sequence=(sequence+1)%16
   tx.ptr=ptr;tx.first=false;if ptr>#data then tx=nil end
  else stats.busy=stats.busy+1 end
 end
 function t.pop()
  local sensor,frame,id,value=io.pop()
  if sensor==nil then return nil end
  if(sensor~=0 and sensor~=0x1B)or frame~=0x32 then stats.dropped=stats.dropped+1;return 0,nil end
  if not integer(id,0,65535)or not integer(value,-2147483648,maxWord)then stats.invalid=stats.invalid+1;return 0,nil end
  local chunk=unpack(math.floor(id),math.floor(value));local data={0xEA,0xC8}
  for i=1,6 do data[#data+1]=chunk[i]end
  stats.received=stats.received+1;return 0x7B,data
 end
 function t.sending()return tx~=nil end
 function t.reset()tx=nil end -- never transmit a cancelled partial request
 return t
end
return M
