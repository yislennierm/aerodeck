-- DEVELOPMENT ONLY. Synthetic data confined to an explicit loadScript env.
local M={}
function M.create(native,case)
 -- The native loadScript env argument is broken in pinned2.12.4: it clears
 -- stack arguments before applying env index3. Keep a native API snapshot,
 -- then install fixtures only in this disposable private widget VM instead.
 local nativeGlobal=native;local saved={};for key,value in pairs(native)do saved[key]=value end
 -- Native API/constant rotables can live behind _G's metatable, outside pairs.
 for _,key in ipairs({'model','getSourceIndex','getFieldInfo','getSourceValue','getValue','getSwitchIndex','getSwitchValue','loadScript','crossfireTelemetryPush','crossfireTelemetryPop'})do saved[key]=native[key]or false end
 setmetatable(saved,{__index=nativeGlobal})
 native=saved;native._G=native
 local env=setmetatable({},{__index=native});env._G=env
 env.qaNativeGlobal=nativeGlobal
 local UNIT_RADIANS,UNIT_TEXT,UNIT_KMH,UNIT_METERS,UNIT_DEGREE,UNIT_METERS_PER_SECOND,UNIT_GPS=native.UNIT_RADIANS,native.UNIT_TEXT,native.UNIT_KMH,native.UNIT_METERS,native.UNIT_DEGREE,native.UNIT_METERS_PER_SECOND,native.UNIT_GPS
 local fixtureFields={{name='Ptch',type=0,id=30,unit=UNIT_RADIANS,value=0,prec=2},
{name='Roll',type=0,id=30,unit=UNIT_RADIANS,value=0,prec=2},
{name='FM',type=0,id=33,unit=UNIT_TEXT,value='HORIZON*',prec=2},
{name='RxBt',type=0,id=8,unit=0,value=22.8,prec=2},
{name='Curr',type=0,id=8,unit=0,value=25.0,prec=2},
{name='Capa',type=0,id=8,unit=0,value=2762,prec=2},
{name='Bat%',type=0,id=8,unit=0,value=83,prec=2},
{name='RQly',type=0,id=20,unit=0,value=100,prec=2},
{name='1RSS',type=0,id=20,unit=0,value=-61,prec=2},
{name='2RSS',type=0,id=20,unit=0,value=-65,prec=2},
{name='RSNR',type=0,id=20,unit=0,value=10,prec=2},
{name='TPWR',type=0,id=20,unit=0,value=250,prec=2},
{name='TQly',type=0,id=20,unit=0,value=99,prec=2},
{name='TRSS',type=0,id=20,unit=0,value=-18,prec=2},
{name='TSNR',type=0,id=20,unit=0,value=12,prec=2},
{name='RFMD',type=0,id=20,unit=0,value=3,prec=2},
{name='Sats',type=0,id=2,unit=0,value=13,prec=2},
{name='GSpd',type=0,id=2,unit=UNIT_KMH,value=31,prec=2},
{name='GAlt',type=0,id=2,unit=UNIT_METERS,value=33,prec=2},
{name='Hdg',type=0,id=2,unit=UNIT_DEGREE,value=150,prec=2},
{name='Yaw',type=0,id=30,unit=UNIT_RADIANS,value=0,prec=2},
{name='VSpd',type=0,id=2,unit=UNIT_METERS_PER_SECOND,value=0.6,prec=2},
{name='ASpd',type=0,id=2,unit=UNIT_KMH,value=nil,prec=2},
{name='GPS',type=0,id=2,unit=UNIT_GPS,value={lat=25.9976807,lon=-97.1573563},prec=2}}

 local base=30000;local epoch=native.getTime();local memoryAt=-3000;local gcDone=false;local gpsAt=-20
 local byName,byId,sourceIndices={},{},{}
 for index,s in ipairs(fixtureFields)do
  if s.name=='Ptch'then s.value=0*math.pi/180
  elseif s.name=='Roll'then s.value=0*math.pi/180
  elseif s.name=='RxBt'then s.unit=native.UNIT_VOLTS
  elseif s.name=='Curr'then s.unit=native.UNIT_AMPS end
  s.sourceId=base+index*3;s.current=true
  s.info={id=s.sourceId,name=s.name,unit=s.unit,prec=s.prec}
  byName[s.name]=s;byName[native.CHAR_TELEMETRY..s.name]=s
  sourceIndices[native.CHAR_TELEMETRY..s.name]=s.sourceId
  byId[s.sourceId]=s;byId[s.sourceId+1]=s;byId[s.sourceId+2]=s
 end
 env.model=setmetatable({getInfo=function()return{name='AOS 5',filename='qa-model.yml',bitmap=case=='model-image'and'qa-grid.png'or ''}end,getSensor=function(index)return fixtureFields[index+1]end},{__index=native.model})
 env.getSourceIndex=function(name)
  local id=sourceIndices[name];if id then return id end
  if native.getSourceIndex then return native.getSourceIndex(name)end
 end
 env.getFieldInfo=function(name)
  local s=byId[name]or byName[name];if s then return s.info end
  if native.getFieldInfo then return native.getFieldInfo(name)end
 end
 -- Case-specific changes run once per native widget callback, not per source
 -- read. This keeps synthetic reads constant-time and close to native C APIs.
 env.qaTick=function()
  local elapsed=native.getTime()-epoch
  if case=='animated'and elapsed-memoryAt>=3000 then
   memoryAt=elapsed;print('QA_DEV_MEMORY|'..tostring(epoch)..'|'..tostring(elapsed)..'|'..tostring(collectgarbage('count')))
  end

  if case=='missing'then byName.Ptch.current=false;byName.Roll.current=false end
  if case=='lost-gps'and elapsed>=800 then byName.GPS.current=false end
  if case~='animated'and elapsed>=500 then byName.GPS.value.lat=25.9981807;byName.GPS.value.lon=-97.1570563 end
  if case=='animated'then
   byName.Ptch.value=-math.sin(elapsed/125)*10*math.pi/180
   byName.Roll.value=math.sin(elapsed/200)*35*math.pi/180
   if elapsed<gpsAt or elapsed-gpsAt>=20 then
    gpsAt=elapsed
    byName.GPS.value.lat=25.9976807+math.sin(elapsed/500)*0.00045
    byName.GPS.value.lon=-97.1573563+math.cos(elapsed/500)*0.00045
   end
  elseif case=='subunit'then
   byName.Curr.value=0.5;byName.RxBt.value=24.0;byName.Capa.value=0
  elseif case=='long'then
   byName.GSpd.value=12345;byName.GAlt.value=-99999;byName.Capa.value=99999;byName.Curr.value=999.9;byName.Hdg.value=359
  end
 end
 local qaExtrema={RxBt={21.6,25.2},Curr={0.5,40},Ptch={-20*math.pi/180,30*math.pi/180},Roll={-45*math.pi/180,60*math.pi/180},Capa={0,9999},RQly={75,100},['1RSS']={-105,-40},RSNR={-2,10},GSpd={0,120},GAlt={-5,150},BatPct={0,100}}
 env.getSourceValue=function(index)
  local s=byId[index];if s then local pair=qaExtrema[s.name];local suffix=index-s.sourceId;if pair and(suffix==1 or suffix==2)then return pair[suffix],s.current,true end;return s.value,s.current,true end
  if native.getSourceValue then return native.getSourceValue(index)end
 end
 env.getValue=function(name)
  local s=byId[name]or byName[name];if s then return s.current and s.value or 0 end
  if native.getValue then return native.getValue(name)end
 end
 env.getSwitchIndex=function(name)if name=='Tele'then return 32000 end;if native.getSwitchIndex then return native.getSwitchIndex(name)end end
 env.getSwitchValue=function(index)if index==32000 then return true end;if native.getSwitchValue then return native.getSwitchValue(index)end end
 env.loadScript=function(path,mode)
  local chunk=native.loadScript(path,mode or't')
  if chunk and string.find(path,'native-extrema',1,true)then
   return function(...)
    local factory=chunk(...);local new=factory.new
    factory.new=function(opts)
     local api=new(opts);local step=api.step;local begin=api.begin;local at=0;local publications=0
     api.begin=function(fields,kind)at=native.getTime();return begin(fields,kind)end
     api.step=function(limit)
      local view,done,processed,err=step(limit)
      if done and processed>0 then publications=publications+1;local now=native.getTime();print('QA_HISTORY_PUBLISH|'..publications..'|'..now..'|'..tostring(view.mode)..'|'..(now-at)..'|'..view.count..'|'..tostring(view.records.v and view.records.v.value)..'|'..tostring(view.records.a and view.records.a.value)..'|'..tostring(view.records.pitch and view.records.pitch.value)..'|'..tostring(view.records.roll and view.records.roll.value))end
      return view,done,processed,err
     end
     return api
    end
    return factory
   end
  end
  return chunk
 end
 env.qaTick()
 print('QA_DEV_SYNTHETIC|'..case..'|IDS30000_PLUS_3I|NATIVE_PHYSICAL_FALLTHROUGH|PRIVATE_VM_GLOBALS')
 return env
end
function M.seedSettings(store,env)
 return store.save('settings',env.model.getInfo(),"ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nvtxMode=2\npack=1\ncells1=6\ncapacity1=6000\nautoHome=1\ncutBinding=PRED:sa:LOW\nlimiterBinding=SRC:s1\nerrorLog=1\ntimerHost=RADIO\ntimerIndex=0\n",function(raw)if string.sub(raw,1,7)=='ADCFG1\n' then return{}end end)
end
function M.seedBattery(store,env)
 return store.save('battery',env.model.getInfo(),'ADBAT1 6,27,30,34,36,42,0,0\n',function(raw)if string.sub(raw,1,7)=='ADBAT1 'then return{}end end)
end
function M.installMSP(env,factory)
 local fc=factory.new({external=true,clock=env.getTime});local body=fc.body
 function fc:body(command,index)
  if command==1 then return{0,1,48}end
  if command==3 then return{4,6,0}end
  if command==150 then return{125,0,0,0,43,0,0,0,0,0,0,35,0,3,0,0,30,0,0,4,0}end
  return body(self,command,index)
 end
 -- Build protocol-valid read replies once in this separate cold callback.
 -- Actual native C push/pop does not decode/construct synthetic FC packets in
 -- the caller's Lua budget, so warm fixture wrappers must not do that either.
 local replies={};local frames,cursor=nil,1
 local function remember(command,index)
  fc.queue={};fc:reply(command,fc:body(command,index),0)
  if index then replies[command]=replies[command]or{};replies[command][index]=fc.queue else replies[command]=fc.queue end
 end
 for _,command in ipairs({2,1,3,150,160,4,88,164})do remember(command)end
 for index=1,#fc.bands do remember(137,index)end
 for index=1,#fc.powers do remember(138,index)end
 env.crossfireTelemetryPush=function(kind,data)
  -- This development transport is READ ONLY. It never acknowledges or
  -- pretends to apply VTX/EEPROM/native writes in the budget experiment.
  if kind~=0x7A or type(data)~='table'or #data<8 or data[1]~=0xC8 or data[2]~=0xEA or frames then return false end
  local command=data[5]+data[6]*256;local nextFrames=replies[command]
  if command==137 or command==138 then nextFrames=nextFrames and nextFrames[data[9]]end
  if not nextFrames then return false end
  frames=nextFrames;cursor=1;return true
 end
 env.crossfireTelemetryPop=function()
  if not frames then return end
  local frame=frames[cursor];cursor=cursor+1;if cursor>#frames then frames=nil end
  return frame.kind,frame.data
 end
 for _,key in ipairs({'model','getSourceIndex','getFieldInfo','getSourceValue','getValue','getSwitchIndex','getSwitchValue','loadScript','crossfireTelemetryPush','crossfireTelemetryPop'})do env.qaNativeGlobal[key]=env[key]end
 return true
end
return M
