-- Exercise the actual read-only radio module with native physical units.
local M=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/radio-status.lua'))()
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local now,voltage,current=0,7.5,true
local limits={battMin=6,battMax=8.4,battWarn=6.6}
local reads,settingsReads,legacyReads=0,0,0
local r=M.new({getTime=function()return now end,getGeneralSettings=function()settingsReads=settingsReads+1;return limits end,
 getSourceValue=function(name)check(name=='tx-voltage','only fixed native transmitter battery source is read');reads=reads+1;return voltage,current,true end,
 getValue=function()legacyReads=legacyReads+1;return 99 end})
local s=r.sample()
check(s==r.snapshot()and s.state=='CURRENT'and s.voltageState=='CURRENT'and s.limitsState=='CURRENT','stable complete native snapshot')
check(s.voltage==7.5 and s.battMin==6 and s.battMax==8.4 and s.battWarn==6.6,'all values stay native volts rather than being divided a second time')
check(s.percent==63 and s.percentOrigin=='NATIVE RANGE'and s.derived and not s.warning,'rounded native range percentage is explicitly derived, not chemical state of charge')
check(s.sampleAt==0 and s.revision==1 and s.sourceApi=='getSourceValue','first sample records actual native source/time')
for t=1,99 do now=t;check(r.sample()==s and reads==1 and settingsReads==1,'foreground/background warm callbacks never exceed1Hz')end
now=100;voltage=6.6;r.sample()
check(s.percent==25 and s.warning==true and reads==2 and settingsReads==2,'warning includes exact native threshold at next1Hz sample')
now=200;voltage=6.599999904632568;limits.battWarn=6.600000381469727;r.sample()
check(s.voltage==6.6 and s.warning and s.battWarn==6.6,'native float32 voltage and warning quantize consistently to100mV')
now=300;voltage=6.7;r.sample();check(not s.warning,'one native decivolt above threshold is not a warning')
now=400;voltage=5.9;r.sample();check(s.percent==0 and s.warning,'below configured range clamps derived percent only, retains genuine voltage')
now=500;voltage=8.5;r.sample();check(s.percent==100 and not s.warning and s.voltage==8.5,'above range retains actual voltage while clamping range percentage')
now=600;voltage=6;r.sample();check(s.percent==0,'configured minimum is0percent')
now=700;voltage=8.4;r.sample();check(s.percent==100,'configured maximum is100percent')
-- Setting changes are read only at the same bounded cadence, without caching
-- a model-specific pack range or inferring cells/chemistry from voltage.
now=800;limits={battMin=7,battMax=9,battWarn=7.1};voltage=8;r.sample()
check(s.percent==50 and s.battMin==7 and s.battMax==9 and not s.warning,'new general radio limits apply at next bounded sample')
local revision=s.revision;now=10;voltage=7;r.sample()
check(s.revision==revision+1 and s.sampleAt==10 and s.warning,'native clock rollback refreshes once instead of freezing cache')
local at=reads;now=11;r.sample();check(reads==at,'rollback does not trigger repeated warm reads')
check(legacyReads==0,'preferred native API never falls back to getValue')
now=110;current=false;r.sample()
check(s.state=='STALE'and s.voltage==nil and s.percent==nil and s.warning==nil,'stale native data is unavailable, not a stale current-looking battery')
check(legacyReads==0,'stale preferred native result never falls back to unchecked getValue')
now=210;current=nil;r.sample();check(s.state=='UNSUPPORTED'and s.voltage==nil,'missing native current flag fails closed')
now=310;current=true;voltage=nil;r.sample();check(s.state=='UNAVAILABLE'and not s.voltage and not s.percent,'missing value clears old battery rather than inventing zero')
local bad={0,-1,0.01,25.6,math.huge,-math.huge,0/0,'7.5',{},false}
for i,v in ipairs(bad)do now=410+i*100;voltage=v;r.sample();check(s.voltageState=='INVALID'and s.voltage==nil and s.percent==nil and s.warning==nil,'invalid native voltage fails closed')end
local unsupported=M.new({getValue=function(name)check(name=='tx-voltage','legacy reader is limited to native fixed source');return 7.2 end})
local u=unsupported.sample(0)
check(u.voltage==7.2 and u.state=='PARTIAL'and u.limitsState=='UNSUPPORTED'and u.percent==nil and u.warning==nil,'native getValue compatibility can expose actual volts but never invent radio limits')
local legacy=M.new({getGeneralSettings=function()return{battMin=6,battMax=8.4,battWarn=6.6}end,getValue=function()return 7.2 end})
check(legacy.sample(0).percent==50 and legacy.snapshot().sourceApi=='getValue','only absent preferred API allows native fixed-source compatibility read')
local none=M.new();local missing=none.sample(0)
check(missing.state=='UNSUPPORTED'and missing.voltage==nil and missing.percent==nil and missing.warning==nil,'unsupported platform does not fabricate battery data')
local broken=M.new({getGeneralSettings=function()error('native settings failure')end,getSourceValue=function()error('native voltage failure')end})
local b=broken.sample(0)
check(b.state=='UNAVAILABLE'and b.settingsError=='GENERAL SETTINGS READ FAILED'and b.voltageError=='TX VOLTAGE READ FAILED','native exceptions are contained and honestly attributed')
local invalidLimits={{battMin=8,battMax=8,battWarn=7},{battMin=9,battMax=8,battWarn=7},{battMin=6,battMax=8},{battMin=0,battMax=8,battWarn=7},{battMin=6,battMax=math.huge,battWarn=7},false}
for _,v in ipairs(invalidLimits)do
 local q=M.new({getGeneralSettings=function()return v end,getValue=function()return 7.2 end}).sample(0)
 check(q.voltage==7.2 and q.state=='PARTIAL'and q.percent==nil and q.warning==nil,'unsupported/invalid limit tuple leaves real voltage available without fabricated policy')
end
-- No implicit global IO, timers, outputs or playback, including reset.
local oldIO=io;local unexpected=0
io=setmetatable({},{__index=function()unexpected=unexpected+1;error('unexpected IO')end})
local beforeRevision=s.revision;r.reset();check(s.voltage==nil and s.percent==nil and s.warning==nil and s.sampleAt==nil,'explicit reset clears previous radio view')
voltage=7.5;current=true;now=3000;r.sample();check(s.revision==beforeRevision+1 and s.voltage==7.5,'reset allows immediate next actual sample')
collectgarbage('collect');local coldReads=reads
for i=1,1000 do check(r.sample(now)==s and reads==coldReads,'stable warm samples and GC cannot reload or resample native data')end
io=oldIO;check(unexpected==0,'radio status never touches SD IO')
local nativeStringMeta=debug.getmetatable('');debug.setmetatable('',nil)
local okay,why=pcall(function()now=3100;check(r.sample().voltage==7.5,'works with native stripped string metatable')end)
debug.setmetatable('',nativeStringMeta);check(okay,'stripped-string compatibility '..tostring(why))
local noClock=M.new({getGeneralSettings=function()error('must not read')end,getValue=function()error('must not read')end})
check(noClock.sample().error=='CLOCK UNAVAILABLE','missing clock cannot cause unbounded native reads')
local previous=reads;now=-1;check(r.sample().voltage==nil and r.snapshot().error=='CLOCK UNAVAILABLE'and reads==previous,'invalid clock clears current claim without native reads')
check(s.health==nil and s.rawVoltage==nil and s.battMin==nil and s.sampleAt==nil and s.limitsState=='UNAVAILABLE','invalid clock clears all native/derived battery claims')
local invalidRevision=s.revision;r.sample();check(s.revision==invalidRevision,'repeated invalid clock does not allocate new snapshot revisions')
now=3200;r.sample();check(s.voltage==7.5 and s.state=='CURRENT','valid clock recovery samples immediately')
limits={battMin=6,battMax=9,battWarn=6.2}
for _,case in ipairs({{7,'LOW',false},{7.1,'NORMAL',false},{6.7,'LOW',false},{6.6,'CRITICAL',false},{6.2,'CRITICAL',true}})do
 now=now+100;voltage=case[1];r.sample()
 check(s.health==case[2]and s.warning==case[3],'inclusive lower-third/lower-fifth bands stay separate from native alarm: '..case[1])
end
limits.battWarn=8;now=now+100;voltage=8;r.sample()
check(s.health=='CRITICAL'and s.warning and s.percent==67,'configured native warning overrides visual range bands')
now=now+100;current=false;r.sample();check(s.health==nil and s.warning==nil,'stale source clears visual health and native warning')
-- A range minimum is not a floor for the measured voltage. Toolbox's SNV
-- formatter clamps its displayed value; preserve the actual native reading.
local belowRange=M.new({getGeneralSettings=function()return{battMin=6.2,battMax=8.2,battWarn=6.6}end,
 getSourceValue=function()return 4.2,true,true end,getValue=function()return 4.2 end}).sample(0)
check(belowRange.voltage==4.2 and belowRange.percent==0 and belowRange.warning and belowRange.health=='CRITICAL','4.2V stays4.2V below a6.2V native gauge minimum')
check(belowRange.displayVoltage==6.2 and belowRange.displayBoundary=='LOWER','separate presentation voltage uses configured minimum with explicit lower-bound marker')
local displayNow,displayRaw,displayCurrent=0,8.5,true
local display=M.new({getGeneralSettings=function()return{battMin=6.2,battMax=8.2,battWarn=6.6}end,getSourceValue=function()return displayRaw,displayCurrent,true end})
local ds=display.sample(displayNow)
check(ds.voltage==8.5 and ds.displayVoltage==8.2 and ds.displayBoundary=='UPPER'and not ds.warning,'display maximum is separate from measured voltage and alarm')
for _,v in ipairs({6.2,7.4,8.2})do
 displayNow=displayNow+100;displayRaw=v;display.sample(displayNow)
 check(ds.voltage==v and ds.displayVoltage==v and ds.displayBoundary==nil,'exact limits and in-range voltage have no comparison marker')
end
displayNow=displayNow+100;displayCurrent=false;display.sample(displayNow)
check(ds.displayVoltage==nil and ds.displayBoundary==nil,'source loss clears old display limits as well as measured voltage')
display.reset();check(ds.displayVoltage==nil and ds.displayBoundary==nil,'reset clears bounded display metadata')
displayRaw=4.2;displayCurrent=true;display.sample(displayNow)
check(ds.displayBoundary=='LOWER','fresh source recovers display metadata after reset')
display.sample(-1);check(ds.displayVoltage==nil and ds.displayBoundary==nil,'invalid clock cannot leave a misleading clamped header value')
print('radio-status: '..checks..' checks passed')
