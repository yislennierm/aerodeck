-- DEVELOPMENT ONLY: actual widget callbacks, unchanged native20k hook/API.
-- Actual production modules; only disposable simulator files are modified.
local root='/SCRIPTS/TOOLS/AERODECK'
local modelId=string.rep('M',96)
local uid='112233445566778899AABBCC'
local function create(zone,options)return{zone=zone,stage=1,checks=0,failures=0,usage={},tick=2147000000}end
local function check(w,ok,name)
 w.checks=w.checks+1;if not ok then w.failures=w.failures+1 end
 print('ASYNCIO|'..name..'|'..(ok and'PASS'or'FAIL'))
end
local function finish(w,name,before)
 local after=getUsage();w.usage[name]=after
 print('ASYNCUSAGE|'..name..'|entry='..before..'|after='..after)
end
local function read(path)local f=io.open(path,'r');if not f then return end;local v=io.read(f,4097);io.close(f);return v end
local function advance(w)
 local n=w.stage;local before=getUsage();local name='STAGE '..n
 if n==1 then w.loader=loadScript(root..'/diagnostics-log.lua');check(w,type(w.loader)=='function','LOAD LOG MODULE')
 elseif n==2 then w.factory=w.loader();w.loader=nil;check(w,type(w.factory)=='table','EXECUTE LOG MODULE')
 elseif n==3 then
  w.log=w.factory.new({clock=function()return w.tick end,getDateTime=function()return{year=2026,mon=10,day=17,hour=21,min=22,sec=23}end})
  check(w,w.log.configure(true,modelId),'CONFIGURE LOG')
 elseif n>=4 and n<=11 then
  local i=n-3;check(w,w.log.record(string.rep('K',31)..i,string.rep('Y',191)..i),'RECORD MAX EVENT '..i);w.tick=w.tick+25
 elseif n==12 then name='LOG BEGIN';local ok,why=w.log.beginFlush();check(w,ok and why=='PENDING'and w.log.snapshot().flushPhase==1,'BEGIN COLD MAX REPLACEMENT')
 elseif n==13 then name='LOG ENCODE READ';local ok,why=w.log.stepFlush(modelId);check(w,ok and why=='PENDING'and w.log.snapshot().flushPhase==2,'ENCODE READ STEP')
 elseif n==14 then name='LOG VERIFY COMMIT';local ok,why=w.log.stepFlush(modelId);check(w,ok and why=='SAVED'and not w.log.snapshot().flushing and not w.log.snapshot().pending,'VERIFY COMMIT STEP')
 elseif n==15 then
  local raw,backup=read(root..'/errors.log'),read(root..'/errors.log.bak')
  check(w,type(raw)=='string'and #raw==3404 and string.find(raw,string.rep('Y',32),1,true)~=nil,'MAX LOG READBACK3404')
  check(w,type(backup)=='string'and #backup==3404 and string.find(backup,string.rep('X',32),1,true)~=nil,'VALID OLD LOG BACKUP3404')
 elseif n==16 then w.loader=loadScript(root..'/vtx-cache.lua');check(w,type(w.loader)=='function','LOAD CACHE MODULE')
 elseif n==17 then w.factory=w.loader();w.loader=nil;check(w,type(w.factory)=='table','EXECUTE CACHE MODULE')
 elseif n==18 then w.cache=w.factory.new();check(w,type(w.cache)=='table','CREATE CACHE')
 elseif n==19 then name='CACHE MAX LOAD FRESH';w.tables=w.cache:load(uid,{signature='3:8:8:8'});check(w,w.tables and #w.tables.bands==8 and #w.tables.powers==8,'ACTUAL LOAD FIRST CACHE PRODUCER')
 elseif n==20 then name='CACHE MAX SAVE';w.tables.powers[1].value=11;local ok=w.cache:save(uid,w.tables);check(w,ok,'MAX CACHE CHANGED AFTER LOAD')
 elseif n==21 then
  local raw,backup=read(root..'/vtx-'..uid..'.cache'),read(root..'/vtx-'..uid..'.cache.bak')
  check(w,type(raw)=='string'and #raw==2562 and string.find(raw,'P|1|11|',1,true)~=nil,'MAX CACHE READBACK2562')
  check(w,type(backup)=='string'and #backup==2562 and string.find(backup,'P|1|10|',1,true)~=nil,'CACHE ORIGINAL PRESERVED')
 elseif n==22 then w.mismatch=w.factory.new()
 elseif n==23 then name='CACHE MISMATCH LOAD';local t,err=w.mismatch:load(uid,{signature='3:1:1:1'});check(w,t==nil and err=='METADATA MISMATCH','MISMATCH CACHE NEVER USABLE')
 elseif n==24 then name='CACHE FRESH SAVE AFTER MISMATCH';w.tables.powers[1].value=12;check(w,w.mismatch:save(uid,w.tables),'FRESH MAX TABLES REPLACE MISMATCH')
 elseif n==25 then local raw=read(root..'/vtx-'..uid..'.cache');check(w,raw and #raw==2562 and string.find(raw,'P|1|12|',1,true),'FRESH MAX MISMATCH READBACK')
 elseif n==26 then w.loader=loadScript(root..'/protocols.lua')
 elseif n==27 then w.protocols=w.loader();w.loader=nil
 elseif n==28 then
  w.crsf=w.protocols.profile('ELRS / CRSF','ELRS 3.x','Betaflight');w.frsky=w.protocols.profile('FrSky','ACCST','Betaflight')
  w.cases={
   {'CURRENT HALF AMP','a',.5,'A',.5},
   {'CURRENT500 MILLIAMP','a',500,'mA',.5},
   {'ROLL FRACTIONAL RAD','roll',.05,'rad',.05*180/math.pi},
   {'PITCH RAD NEGATION','pitch',.2,'rad',-.2*180/math.pi},
   {'PITCH NEGATIVE RAD','pitch',-.2,'rad',.2*180/math.pi},
   {'PITCH DEG POSITIVE','pitch',.2,'deg',.2},
   {'RAW UNIT FAILS CLOSED','roll',.05,'RAW',nil,'UNKNOWN UNIT'},
   {'MISSING UNIT FAILS CLOSED','roll',.05,nil,nil,'UNKNOWN UNIT'},
   {'FRACTIONAL RF BYTE REJECTED','rf',1.5,'NUMBER',nil,'OUT OF RANGE'},
   {'FRACTIONAL SAT BYTE REJECTED','sats',.5,'NUMBER',nil,'OUT OF RANGE'},
   {'FRSKY FRACTIONAL ENCODED REJECTED','flight',.5,'NUMBER',nil,'UNIT MISMATCH',true},
   {'FRSKY DECIDEG PITCH','pitch',1,'NUMBER',-.1,nil,true}}
 elseif n>=29 and n<=40 then
  local c=w.cases[n-28];local p=c[7]and w.frsky or w.crsf
  local reader=w.protocols.reader(c[2],c[4],p);local a,ae,ap=reader(c[3]);local b,be,bp=w.protocols.normalize(c[2],c[3],c[4],p)
  local same=(a==nil and b==nil)or(type(a)=='number'and type(b)=='number'and math.abs(a-b)<.0001)
  local expected=c[5]==nil and a==nil or type(a)=='number'and math.abs(a-c[5])<.0001
  check(w,same and expected and ae==c[6]and be==c[6]and ap==bp,c[1])
  if n==40 then print('ASYNCDONE|'..w.checks..'|'..w.failures)end
 end
 finish(w,name,before);w.stage=n+1
end
local function refresh(w)
 if w.stage<=40 then advance(w)end
 lcd.drawFilledRectangle(w.zone.x,w.zone.y,w.zone.w,w.zone.h,BLACK)
 lcd.drawText(w.zone.x+8,w.zone.y+8,'NATIVE ASYNC STORAGE',SMLSIZE+WHITE)
 lcd.drawText(w.zone.x+8,w.zone.y+35,w.checks..' CHECKS / '..w.failures..' ERRORS',SMLSIZE+WHITE)
end
return{name='AERODECK',options={},create=create,refresh=refresh,background=function(w)if w.stage<=40 then advance(w)end end}
