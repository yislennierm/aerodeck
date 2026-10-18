-- DEVELOPMENT ONLY: protocol-valid synthetic FC; no native hook changes.
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function equal(a,b,why)
 check(#a==#b,(why or'')..' length')
 for i=1,#a do check(a[i]==b[i],(why or'')..' byte '..i)end
end
local function append(a,b)for _,v in ipairs(b)do a[#a+1]=v end;return a end
local function str(s)local t={#s};for i=1,#s do t[#t+1]=string.byte(s,i)end;return t end
local function u16(v)return {v%256,math.floor(v/256)}end
local status={125,0,0,0,43,0,0,0,0,0,0,35,0,3,0,0,26,0,0,0,0}
local function harness(options)
 options=options or{}
 local h={now=0,queue={},sent={},pops=0,pushOk=true,dropped={},rejected={},wrongReadback=false,forwarded=0}
 h.external=options.external==true
 h.uid={1,2,3,4,5,6,7,8,9,10,11,12}
 h.board=append({73,70,82,67,12,0,2,5},str('TARGET'));append(h.board,str('BOARD'));append(h.board,str('ACME'))
 h.report={hardware=3,band=1,channel=2,power=2,pit=true,frequency=5800,ready=true,lowPower=2}
 h.bands={{name='RACE',letter='R',factory=1,frequencies={5658,5800,5917}},{name='CUSTOM',letter='C',factory=0,frequencies={5700,5800,5900}}}
 h.powers={{value=25,label='25 '},{value=400,label='MAX'}}
 local transport={push=function(kind,data)
  if options.clock then h.now=options.clock()end
  check(#data<=58 and data[1]==0xC8 and data[2]==0xEA,'bounded addressed CRSF body')
  check(data[3]>=0x50 and data[3]<=0x5F and data[4]==0,'MSPv2 START/sequence flags')
  local cmd=data[5]+data[6]*256;local len=data[7]+data[8]*256
  check(len==#data-8,'MSP declared payload length')
  if cmd==89 then check(kind==0x7C and(len==4 or len==5),'VTX write frame/payload')
  elseif cmd==250 then check(kind==0x7C and len==0,'EEPROM write frame/payload')
  else check(kind==0x7A,'all read commands use read frame')end
  if not h.pushOk then return h.pushOk end
  local payload={};for i=9,#data do payload[#payload+1]=data[i]end
  h.sent[#h.sent+1]={kind=kind,data=data,cmd=cmd,payload=payload,at=h.now};return true
 end,pop=function()
  h.pops=h.pops+1
  if #h.queue==0 then return nil end
  local f=table.remove(h.queue,1);return f.kind,f.data
 end,onFrame=function()h.forwarded=h.forwarded+1 end}
 h.transport=transport
 if not h.external then h.c=factory.new(transport)end
 function h:tick(t,enabled,link,disarmed)
  self.now=t;local before=#self.sent;local pops=self.pops
  if enabled==nil then enabled=true end;if link==nil then link=true end;if disarmed==nil then disarmed=true end
  local s=self.c:tick(t,enabled,link,disarmed)
  check(#self.sent-before<=1,'at most one push per callback')
  check(self.pops-pops<=4,'at most four pops per callback')
  return s
 end
 function h:reply(cmd,data,t,reject)
  local first={0xEA,0xC8,reject and 0xD7 or 0x57,0,cmd%256,math.floor(cmd/256),#data%256,math.floor(#data/256)}
  local p=1
  while p<=#data and #first<58 do first[#first+1]=data[p];p=p+1 end
  self.queue[#self.queue+1]={kind=0x7B,data=first}
  local seq=8
  while p<=#data do
   local chunk={0xEA,0xC8,0x40+seq}
   while p<=#data and #chunk<58 do chunk[#chunk+1]=data[p];p=p+1 end
   self.queue[#self.queue+1]={kind=0x7B,data=chunk};seq=(seq+1)%16
  end
  if self.external then self.now=t;return end
  return self:tick(t)
 end
 function h:body(cmd,index)
  if cmd==2 then return {66,84,70,76}
  elseif cmd==1 then return {0,1,46}
  elseif cmd==3 then return {4,5,2}
  elseif cmd==150 then return status
  elseif cmd==160 then return self.uid
  elseif cmd==4 then return self.board
  elseif cmd==88 then
   local r=self.report
   return {r.hardware,r.band,r.channel,r.power,r.pit and 1 or 0,r.frequency%256,math.floor(r.frequency/256),r.ready and 1 or 0,r.lowPower,0,0,1,#self.bands,#self.bands[1].frequencies,#self.powers}
  elseif cmd==137 then
   local b=self.bands[index];local body=append({index},str(b.name));body[#body+1]=string.byte(b.letter);body[#body+1]=b.factory;body[#body+1]=#b.frequencies
   for _,f in ipairs(b.frequencies)do append(body,u16(f))end;return body
  elseif cmd==138 then return append(append({index},u16(self.powers[index].value)),str(self.powers[index].label))
  elseif cmd==164 then return {1,0,12,5,35} -- Synthetic protocol-valid legacy SV entry.
  elseif cmd==89 or cmd==250 then return {}end
  error('unexpected command '..cmd)
 end
 function h:answer(q)
  if self.dropped[q.cmd]then return end
  if q.cmd==89 and not self.rejected[89]and not self.wrongReadback then
   local value=q.payload[1]+q.payload[2]*256;local r=self.report
   if value<=63 then r.band=math.floor(value/8)+1;r.channel=value%8+1;r.frequency=self.bands[r.band].frequencies[r.channel]
   else r.band=0;r.channel=0;r.frequency=value end
   r.power=q.payload[3];r.pit=q.payload[4]==1;if q.payload[5]~=nil then r.lowPower=q.payload[5]end
  end
  local body=self:body(q.cmd,q.payload[1]);self:reply(q.cmd,body,self.now+1,self.rejected[q.cmd])
 end
 function h:pump(untilFn,limit)
  local start=self.now
  while not untilFn(self.c:snapshot())and self.now-start<(limit or 5000)do
   self:tick(self.now+25)
   local q=self.sent[#self.sent]
   if q and not q.answered then q.answered=true;self:answer(q)end
  end
  check(untilFn(self.c:snapshot()),'scenario completed before bounded deadline')
  return self.c:snapshot()
 end
 function h:service(t)
  self.now=t or(options.clock and options.clock())or self.now
  local last=#self.sent
  for i=(self.serviced or 0)+1,last do
   local q=self.sent[i];if not q.answered then q.answered=true;self:answer(q)end
  end
  self.serviced=last
 end
 function h:count(cmd)local n=0;for _,q in ipairs(self.sent)do if q.cmd==cmd then n=n+1 end end;return n end
 function h:last(cmd)for i=#self.sent,1,-1 do if self.sent[i].cmd==cmd then return self.sent[i]end end end
 return h
end

return{new=harness}
