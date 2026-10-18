-- Development-only shared host/native Lua checks. Not a radio runtime module.
-- Each step exercises actual modules with injected data and performs no real
-- model, telemetry, output, audio or SD writes. Native loader owns module reads.
local M={}
function M.new(load,report)
 local protocols=assert(load('protocols'))
 local extrema=assert(load('native-extrema'))
 local power=assert(load('power-policy'))
 local timer=assert(load('timer-owner'))
 local session=assert(load('session'))
 local display=assert(load('display'))
 local nativeVtx=assert(load('vtx-native'))
 local adapters=assert(load('msp-adapters'))
 local radio=assert(load('radio-status'))
 local pack=assert(load('quick-pack'))
 local profile=protocols.profile('ELRS','EL3','BF')
 local cases={}
 local function add(name,fn)cases[#cases+1]={name,fn}end
 local function near(v,expected)return type(v)=='number'and math.abs(v-expected)<0.0001 end
 local function settings(extra)
  local c={cells=6,profile=0,thresholds={noPower=2.7,min=3,critical=3.4,low=3.6,max=4.2},alertType=0,audible=0}
  for k,v in pairs(extra or{})do c[k]=v end;return c
 end
 add('HALF AMP PRESERVED',function()return near(protocols.normalize('a',0.5,'A',profile),0.5)end)
 add('SUBUNIT VOLT PRESERVED',function()return near(protocols.normalize('v',0.2,'V',profile),0.2)end)
 add('RADIAN PITCH PRESERVED',function()return near(protocols.normalize('pitch',0.2,'rad',profile),-0.2*180/math.pi)end)
 add('REAL NUMERIC ZERO',function()local v=protocols.normalize('a',0.0,'A',profile);return type(v)=='number'and v==0.0 end)
 add('FRACTIONAL SATS REJECTED',function()return protocols.normalize('sats',0.5,'NUMBER',profile)==nil end)
 add('FRACTIONAL RF ENUM REJECTED',function()return protocols.rfCaption(1.5,profile)==nil end)
 add('FRACTIONAL GPS STATUS REJECTED',function()return protocols.decodeGPS(1001.5,protocols.profile('FrSky','ACCST','BF'))==nil end)
 add('SUBUNIT NATIVE MIN PRESERVED',function()
  local e=extrema.new({getSourceValue=function()return 0.2,true,true end,normalize=function(_,raw)return raw end})
  local r=e.sample({{key='v',id=100,unit='V'}},'MIN').records.v
  return r.current and near(r.value,0.2)
 end)
 add('FRACTIONAL PRIMARY ID REJECTED',function()
  local reads=0;local e=extrema.new({getSourceValue=function()reads=reads+1;return 0.2,true,true end,normalize=function(_,raw)return raw end})
  local r=e.sample({{key='v',id=100.5}},'MIN').records.v
  return reads==0 and r.value==nil and r.state=='UNAVAILABLE'
 end)
 add('FRACTIONAL CELLS REJECTED',function()return power.new().update(0,{v=22.8},settings({cells=6.5})).condition=='INVALID CONFIG'end)
 add('FRACTIONAL PROFILE ENUM REJECTED',function()return power.new().update(0,{v=22.8},settings({profile=0.5})).condition=='INVALID CONFIG'end)
 add('FRACTIONAL CHEMISTRY REJECTED',function()
  local c=settings({profile=1,profiles={{chemistry=1.5,cells=6,capacity=1500}}})
  return power.new().update(0,{v=22.8},c).condition=='INVALID PROFILE'and #power.favourites(c.profiles)==0
 end)
 add('FRACTIONAL CAPACITY REJECTED',function()
  return power.new().update(0,{v=22.8},settings({profile=1,profiles={{chemistry=1,cells=6,capacity=1500.5}}})).condition=='INVALID PROFILE'
 end)
 add('VOLTAGE RANGE DISTINCT FROM CHARGE',function()
  local s=power.new().update(0,{v=22.8,mah=350,reportedPct=91},settings({profile=1,profiles={{chemistry=1,cells=6,capacity=1500}}}))
  return near(s.voltagePct,100*0.8/1.2)and near(s.displayPct,1150/1500*100)and s.reportedPct==91 and s.voltagePctOrigin=='CELL VOLTAGE RANGE'
 end)
 add('FRACTIONAL TIMER INDEX REJECTED',function()
  local reads,writes=0,0
  local t=timer.new({getTimer=function()reads=reads+1;return{}end,setTimer=function()writes=writes+1 end,getModelId=function()return'model1.yml'end})
  local ok=t.configure({host='AERODECK',timerIndex=1.5})
  return ok==false and reads==0 and writes==0
 end)
 add('SESSION FRACTIONAL TIMER DISABLED',function()
  local reads=0;local s=session.new({getTimer=function()reads=reads+1;return{}end})
  s.update(0,{}, {timerIndex=1.5})
  return reads==0 and s.snapshot().modelTimer==nil
 end)
 add('SESSION ZERO FRACTIONAL MOTION',function()
  local s=session.new();local cfg={autoHome=1,homeSats=8}
  s.update(0,{gps={lat=0,lon=0},sats=10},cfg)
  s.update(100,{gps={lat=0.1,lon=0.1},sats=10},cfg)
  local moved=s.snapshot().homeDistance
  s.update(200,{gps={lat=0,lon=0},sats=10},cfg)
  return moved>10000 and #s.snapshot().track==3 and near(s.snapshot().homeDistance,0.0)and s.snapshot().homeBearing==nil
 end)
 add('KNOWN NO FIX NOT CURRENT',function()
  local s=session.new();local cfg={autoHome=1,homeSats=8}
  s.update(0,{gps={lat=0,lon=0},sats=10,fix=true},cfg)
  local home=s.snapshot().home
  s.update(100,{gps={lat=0.1,lon=0.1},sats=10,fix=false},cfg)
  local ok,why=s.setHome();local state=s.snapshot()
  return state.current==nil and state.lastKnown.lat==0.0 and state.lastKnown.lon==0.0 and #state.track==1
   and state.home==home and state.homeDistance==nil and state.homeBearing==nil and ok==false and why=='NO REPORTED GNSS FIX'
 end)
 add('SCALED TOUCH NOT NATIVE FASTPATH',function()
  local d=display.new({sizeText=function()return 12,12 end},800,480)
  local raw={x=240,y=100};local mapped=d.touch(raw)
  return mapped~=raw and mapped.x==144 and mapped.y==60 and d.scale>1.6 and d.scale<1.7
 end)
 add('FRACTIONAL NATIVE VTX FREQUENCY REJECTED',function()
  local pushed=0;local v=nativeVtx.new({hardwareId=1,push=function()pushed=pushed+1;return true end})
  v:tick(0,true,true,true);v:ingest(0x10,{0xEC,14,22,168,0},0)
  local ok,why=v:applyVtx({frequency=5800.5})
  return ok==false and why=='INVALID FREQUENCY'and pushed==0
 end)
 add('FRACTIONAL VTX HARDWARE REJECTED',function()return nativeVtx.new():setHardware(1.5)==false end)
 add('FRACTIONAL WIRE BYTE REJECTED',function()
  local pushed=0;local a=adapters.new('CRSF',{push=function()pushed=pushed+1;return true end,pop=function()end})
  local ok=a.push(0x7A,{0xC8,0xEA,0x50,0,1,0,1,0,0.5})
  return ok==false and pushed==0
 end)
 add('RADIO SUBUNIT VOLTAGE PRESERVED',function()
  local r=radio.new({getGeneralSettings=function()return{battMin=6,battMax=8.4,battWarn=6.6}end,getSourceValue=function()return 0.2,true,true end})
  local s=r.sample(0);return near(s.voltage,0.2)and s.percent==0 and s.warning==true
 end)
 add('QUICK PACK FRACTIONAL CHEMISTRY DISABLED',function()
  local p=pack.new({lcd={sizeText=function()return 8,12 end,setColor=function()end,drawText=function()end,drawFilledRectangle=function()end},configget=function(k)
   if k=='pack'then return 0 elseif k=='chemistry1'then return 1.5 elseif k=='cells1'then return 6 elseif k=='capacity1'then return 1500 end
  end})
  p.open();return p.snapshot().rows[2].enabled==false and p.snapshot().rows[2].chemistryLabel=='INVALID'
 end)
 local out={checks=0,failed=0,total=#cases};local index=1;local api={}
 function api.snapshot()return out end
 function api.step()
  local c=cases[index];if not c then return true end
  local ok,value=pcall(c[2]);local pass=ok and value==true
  out.checks=out.checks+1;if not pass then out.failed=out.failed+1 end
  if report then report(c[1],pass,not ok and tostring(value)or'')end
  index=index+1;return index>#cases
 end
 return api
end
return M
