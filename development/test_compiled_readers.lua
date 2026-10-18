-- Compiled closures versus the unchanged branch-based normalize() oracle.
-- Synthetic semantic/instruction checks; no radio CPU or physical FPS claim.
local path=arg[1]or'sdcard/SCRIPTS/TOOLS/AERODECK/protocols.lua'
local module=assert(loadfile(path))()
local checks,cases,readers=0,0,0
local function check(value,why)checks=checks+1;if not value then error(why or('check '..checks),2)end end
local function same(reader,field,raw,unit,profile)
 local expected,err,provenance=module.normalize(field,raw,unit,profile)
 local actual,actualError,actualProvenance=reader(raw)
 cases=cases+1
 check(actual==expected,'value differs for '..field..' / '..tostring(unit)..' / '..tostring(raw))
 check(actualError==err,'error differs for '..field..' / '..tostring(unit)..': '..tostring(actualError)..' / '..tostring(err))
 check(actualProvenance==provenance,'provenance differs for '..field)
 if type(actual)=='number'then
  if math.type then check(math.type(actual)==math.type(expected),'numeric representation differs')end
  if actual==0.0 then check(1/actual==1/expected,'zero sign differs')end
 end
end
local aliases={'voltage','current','consumed','percent','txPower','rfMode','groundSpeed','gpsAltitude','baroAltitude','verticalSpeed','airSpeed','receiverVoltage','flightMode'}
local unitCases={false,'V','A','mA','mAh','Ah','mW','W','%','dBm','dB','deg','rad','km/h','mph','kt','m/s','ft/s','m','ft','NUMBER','ENCODED','GPS','TEXT','g','volts','AMPS','KNOTS','FEET','DEGREES','NONE','unknown-unit',0,17,99,201,202,203,{},true}
local values={false,true,'','1','ACRO*','ABC\n',string.rep('A',32),string.rep('A',33),{},
 {lat=25.9976807,lon=-97.1573563},{lat=90,lon=180},{lat=-90,lon=-180},
 {lat=90.1,lon=0},{lat=0,lon=180.1},{lat=0/0,lon=0},
 -math.huge,math.huge,0/0,-200001,-9999,-360,-180,-1,-.2,-0.0,0,.2,.5,1,179.999,180,255,360,9999,200000,200001,16777217,1e30}
local profileSpecs={{'ELRS / CRSF','ELRS 2.x'},{'ELRS / CRSF','ELRS 3.x'},{'ELRS / CRSF','ELRS Gemini'},
 {'TBS Crossfire','Auto'},{'TBS Tracer','Auto'},{'FrSky','ACCST'},{'FrSky','R9'},
 {'Other','Auto'},{'FrSky','ELRS 3.x'}}
local seed=19
local function random()seed=(seed*109+1021)%65521;return seed/65521 end
for _,spec in ipairs(profileSpecs)do
 for _,fc in ipairs({'Betaflight','INAV','Other'})do
  local p=module.profile(spec[1],spec[2],fc)
  p.unitNames={[0]='NUMBER',[17]='A',[99]='UNSUPPORTED',[201]='V',[202]='rad',[203]='km/h'}
  local fields={};for field in pairs(p.fields)do fields[#fields+1]=field end
  table.sort(fields);for _,field in ipairs(aliases)do fields[#fields+1]=field end
  fields[#fields+1]='unsupported-field'
  for _,field in ipairs(fields)do
   for _,unitCase in ipairs(unitCases)do
    local unit=unitCase;if unitCase==false then unit=nil end
    local reader=module.reader(field,unit,p);readers=readers+1
    check(type(reader)=='function','compile always returns a callable reader')
    same(reader,field,nil,unit,p)
    for _,raw in ipairs(values)do same(reader,field,raw,unit,p)end
    local d=module.info(field,p)
    if d and d.min then
     for _,raw in ipairs({d.min-1,d.min-.001,d.min,d.min+.001,d.max-.001,d.max,d.max+.001,d.max+1})do same(reader,field,raw,unit,p)end
    end
    for i=1,8 do same(reader,field,(random()-.5)*500000,unit,p)end
   end
  end
 end
end
-- Error precedence and the native/current caller contract stay explicit.
local crsf=module.profile('ELRS / CRSF','ELRS 3.x','Betaflight')
local frsky=module.profile('FrSky','ACCST','Betaflight')
local missingUnit=module.reader('pitch',nil,crsf)
local value,err=missingUnit(nil);check(value==nil and err=='MISSING','missing input precedes missing units')
value,err=missingUnit(false);check(value==nil and err=='INVALID','invalid numeric type precedes unit error')
value,err=missingUnit(.2);check(value==nil and err=='UNKNOWN UNIT','CRSF angles still require an explicit compatible unit')
value,err=module.reader('rf','NUMBER',crsf)(.2);check(value==nil and err=='OUT OF RANGE','fractional RF enum remains rejected')
value,err=module.reader('flight','NUMBER',frsky)(.2);check(value==nil and err=='UNIT MISMATCH','fractional encoded status keeps the distinct unit error')
local gps={lat=25.9976807,lon=-97.1573563};check(module.reader('gps','bad-unit',crsf)(gps)==gps,'GPS identity is preserved and ignores scalar unit policy like the oracle')
check(module.reader('flight','bad-unit',crsf)('ACRO*')=='ACRO*','TEXT validates content independently of scalar units')
-- Snapshot compilation must not re-read mutable profile/unit/descriptor tables.
crsf.unitNames[201]='A'
local cached=module.reader('current',201,crsf)
crsf.unitNames[201]='V';crsf.fields.a.min=2
check(cached(.5)==.5,'compiled unit/range snapshot is independent from later profile edits')
value,err=module.reader('current',201,crsf)(.5);check(value==nil and err=='UNIT MISMATCH','caller recompilation observes new unit metadata')
crsf.fields=setmetatable({},{__index=function()error('Hot reader accessed profile descriptors')end})
crsf.unitNames=setmetatable({},{__index=function()error('Hot reader accessed unit names')end})
check(cached(.5)==.5,'hot closure never looks up profile fields or native unit maps')
value,err=cached(-1);check(value==nil and err=='OUT OF RANGE','captured lower bound remains effective')
value,err=module.reader('v','V',nil)(1);check(value==nil and err=='UNSUPPORTED FIELD','unsupported profiles have a stable callable result')
-- Conversion boundaries retain operation order under float32; no combined scale.
for _,point in ipairs({{'a','mA',400000},{'mah','Ah',200},{'tx','W',5},{'pitch','rad',math.pi},{'roll','rad',-math.pi},{'hdg','rad',2*math.pi},{'speed','m/s',277.5},{'alt','ft',20000/.3048}})do
 local p=module.profile('ELRS / CRSF','ELRS 3.x','Betaflight');local read=module.reader(point[1],point[2],p)
 for _,offset in ipairs({-.0001,0,.0001})do same(read,point[1],point[3]+offset,point[2],p)end
end
-- Portable VM instruction evidence measures steady readers, excluding compilation.
-- It is not a native callback budget/performance acceptance result.
local normalInstructions,readerInstructions
if debug and debug.sethook then
 if jit then jit.off()end
 local p=module.profile('ELRS / CRSF','ELRS 3.x','Betaflight')
 local selected={{'v','V',24},{'a','mA',500},{'mah','Ah',.4},{'rssi','dBm',-70},{'sats','NUMBER',12},{'pitch','rad',-.2},{'roll','rad',.3},{'speed','m/s',15}}
 for _,entry in ipairs(selected)do entry.reader=module.reader(entry[1],entry[2],p)end
 local function count(compiled)
  local n=0;debug.sethook(function()n=n+1 end,'',1)
  for _=1,25 do for _,entry in ipairs(selected)do
   if compiled then entry.reader(entry[3])else module.normalize(entry[1],entry[3],entry[2],p)end
  end end
  debug.sethook();return n
 end
 normalInstructions=count(false);readerInstructions=count(true)
 check(readerInstructions<normalInstructions,'compiled hot readers must execute fewer VM instructions than normalize')
end
print(string.format('PASS: %d checks / %d oracle comparisons / %d compiled readers; portable VM instructions normalize=%s reader=%s (no hardware claim)',checks,cases,readers,tostring(normalInstructions),tostring(readerInstructions)))
