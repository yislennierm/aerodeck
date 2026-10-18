-- Real model-store code with native EdgeTX io/del/rename signatures in RAM.
-- No radio/host SD/model/preference file is read or written by this test.
local M=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/model-store.lua'))()
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
-- Compare the real optimized checksum with the original byte-at-a-time file
-- algorithm, including binary/high-byte data and every block/tail boundary.
do
 local implementations={}
 for _,name in ipairs({'model-store','diagnostics-log','vtx-cache'})do
  local f=assert(io.open('sdcard/SCRIPTS/TOOLS/AERODECK/'..name..'.lua'));local source=f:read('*a');f:close()
  local first=assert(string.find(source,'local function checksum(raw)',1,true));local last=assert(string.find(source,'\nlocal function ',first+1,true))
  implementations[name]=assert((loadstring or load)(string.sub(source,first,last-1)..'\nreturn checksum'))()
 end
 local function legacy(raw)local a,b=0,0;for i=1,#raw do a=(a+string.byte(raw,i))%255;b=(b+a)%255 end;return string.format('%02X%02X',a,b)end
 local function same(raw)
  local expected=legacy(raw)
  for name,current in pairs(implementations)do check(current(raw)==expected,name..' persisted checksum stays byte-identical at length '..#raw)end
 end
 same('');same('ADCFG1\n');same('ADBAT1 6,27,30,34,36,42,0,0\n')
 for byte=0,255 do for _,n in ipairs({1,7,8,15,16,17,31,32,33,255,256,257})do same(string.rep(string.char(byte),n))end end
 local seed=1
 for n=0,129 do local t={};for i=1,n do seed=(seed*109+89)%65521;t[i]=string.char(seed%256)end;same(table.concat(t))end
 for _,n in ipairs({511,512,513,1023,1024,1025,1373,2047,2048,2049,4095,4096,4097,8191,8192,8193})do
  for sample=1,8 do local t={};for i=1,n do seed=(seed*109+89)%65521;t[i]=string.char(seed%256)end;same(table.concat(t))end
 end
end
local A={filename='model1.yml',name='AOS 5'}
local B={filename='model2.yml',name='AOS 5'}
local defaults={value=7,nested={value='default'}}
local function decode(raw)
 local n=string.match(raw,'^ADCFG1\nvalue=(%d+)\n$')
 if n and tonumber(n)<=100 then return {value=tonumber(n)}end
end
local function encode(n)return 'ADCFG1\nvalue='..n..'\n'end
local function battery(raw)
 local n=string.match(raw,'^ADBAT1 (%d+)\n$')
 if n and tonumber(n)<=12 then return {tonumber(n)}end
end
local function memory()
 local files,events,handles,faults={},{},{},{}
 local stats={opens=0,reads=0,writes=0,closes=0,maxRead=0,maxWrite=0}
 local fs={}
 function fs.open(path,mode)
  stats.opens=stats.opens+1;events[#events+1]={'open',path,mode}
  if faults.openThrow==path then error('open failure')end
  if faults.openFail==path or faults.noDirectory then return nil end
  if mode=='r' and files[path]==nil then return nil end
  if mode=='w'then files[path]=''end
  local f={path=path,mode=mode};handles[f]=true;return f
 end
 function fs.read(f,count)
  check(handles[f] and f.mode=='r','io.read uses explicit native open handle')
  stats.reads=stats.reads+1;stats.maxRead=math.max(stats.maxRead,count)
  if faults.readThrow==f.path then error('read failure')end
  if faults.readWrongType==f.path then return {}end
  return string.sub(files[f.path],1,count)
 end
 function fs.write(f,raw)
  check(handles[f] and f.mode=='w','io.write uses explicit native open handle')
  stats.writes=stats.writes+1;stats.maxWrite=math.max(stats.maxWrite,#raw)
  if faults.writeThrow==f.path then error('write failure')end
  if faults.writeFalse==f.path then return false end
  files[f.path]=faults.truncate==f.path and string.sub(raw,1,math.floor(#raw/2)) or raw
  return nil
 end
 function fs.close(f)
  check(handles[f]~=nil,'every opened native handle is closed exactly once')
  stats.closes=stats.closes+1;handles[f]=nil
  if faults.closeThrow==f.path then error('close failure')end
  if faults.closeFalse==f.path then return false end
  return nil
 end
 local function remove(path)
  events[#events+1]={'delete',path}
  if faults.removeFail==path then return 7 end
  if files[path]==nil then return 4 end
  files[path]=nil;return 0
 end
 local function rename(from,to)
  events[#events+1]={'rename',from,to}
  if faults.renameFailFrom==from or faults.renameFailTo==to then return 7 end
  if files[from]==nil then return 4 end
  files[to]=files[from];files[from]=nil
  if faults.corruptPromote==to then files[to]='truncated'end
  return 0
 end
 local api=M.new({io=fs,remove=remove,rename=rename,root='/STORE/'})
 return {api=api,fs=fs,files=files,events=events,handles=handles,faults=faults,stats=stats,remove=remove,rename=rename}
end
local function noHandles(m)check(next(m.handles)==nil,'no native IO handle leaks')end
local m=memory();local p=m.api.paths('settings',A);local pB=m.api.paths('settings',B)
check(p.canonical=='/STORE/settings-model-6d6f64656c312e796d6c.cfg' and p.legacy=='/STORE/settings-414f532035.cfg','canonical filename identity and exact old lowercase namehex paths')
check(p.canonical~=pB.canonical and p.legacy==pB.legacy,'same display name has separate canonical files and one ambiguous legacy file')
local data,meta=m.api.read('settings',A,decode,defaults)
check(data.value==7 and meta.state=='DEFAULTS' and m.stats.writes==0,'new model uses defaults without creating/claiming any file')
data.nested.value='changed';check(defaults.nested.value=='default','defaults are cloned rather than sharing active settings tables')
m.files[p.legacy]=encode(11);m.files[p.legacy..'.bak']=encode(10)
data,meta=m.api.read('settings',A,decode,defaults)
check(data.value==7 and meta.state=='IMPORT AVAILABLE' and meta.legacyAvailable and meta.legacyPath==p.legacy,'legacy name data is offered for explicit import, never silently applied')
check(m.stats.writes==0 and m.files[p.canonical]==nil,'legacy discovery is strictly read-only with no ownership claim')
data,meta=m.api.read('settings',B,decode,defaults)
check(data.value==7 and meta.state=='IMPORT AVAILABLE','same-name duplicate does not inherit ambiguous legacy settings')
data,meta=m.api.importLegacy('settings',A,decode)
check(data and data.value==11 and meta.state=='IMPORTED' and meta.path==p.canonical,'explicit import returns data only after verified new owner-bound save')
check(m.files[p.legacy]==encode(11) and m.files[p.legacy..'.bak']==encode(10),'legacy original and backup remain byte-for-byte unchanged on import')
check(string.sub(m.files[p.canonical],1,9)=='ADMODEL1\n' and not string.find(m.files[p.canonical],'return ',1,true),'canonical settings are inert owner-bound data')
local writes=m.stats.writes
data,meta=m.api.read('settings',A,decode,defaults)
check(data.value==11 and meta.source=='PRIMARY' and meta.state=='SAVED' and m.stats.writes==writes,'normal read loads only canonical state and never writes')
local renamed={filename=A.filename,name='RACE QUAD'}
check(m.api.paths('settings',renamed).canonical==p.canonical,'renaming display name preserves canonical identity')
check(m.api.read('settings',renamed,decode,defaults).value==11,'renamed model retains its own settings')
check(m.api.read('settings',B,decode,defaults).value==7,'same-name duplicate still has defaults after other model imports')
check(m.api.save('settings',B,encode(22),decode)==true,'duplicate saves its own independent preferences')
check(m.api.read('settings',A,decode,defaults).value==11 and m.api.read('settings',B,decode,defaults).value==22,'switching between same-name files restores only each owner')
local imported,failedMeta=m.api.importLegacy('settings',A,decode)
check(imported==nil and failedMeta.error=='MODEL SETTINGS ALREADY EXIST','legacy import cannot silently overwrite an existing valid canonical or backup')
check(m.api.save('settings',A,encode(13),decode)==true,'new preference save succeeds with verified backup rotation')
local raw13=m.files[p.canonical]
m.files[p.canonical]='TRUNCATED'
data,meta=m.api.read('settings',A,decode,defaults)
check(data.value==11 and meta.source=='BACKUP' and meta.state=='RECOVERED' and meta.primaryError~=nil,'corrupt primary recovers previously validated same-owner backup')
check(m.files[p.canonical]=='TRUNCATED','read-only recovery does not rewrite a corrupt primary')
check(m.api.save('settings',A,encode(14),decode)==true and m.files[p.canonical..'.bak']~=nil,'explicit save can replace a corrupt primary without discarding its valid backup')
check(m.api.read('settings',A,decode,defaults).value==14,'repaired primary is verified and readable')
local before=m.stats.writes;check(m.api.save('settings',A,encode(14),decode)==true and m.stats.writes==before,'saving unchanged valid canonical data avoids SD write work')
noHandles(m)

-- Real EdgeTX simulator f_unlink returns6 for missing paths. An optional native
-- fstat avoids deleting an absent backup, without treating6 on existing files
-- as success or weakening primary preservation after actual filesystem errors.
local simulator=memory();local deleteCalls,statCalls=0,0;local statFault,deleteFault
local sim=M.new({io=simulator.fs,root='/STORE/',rename=simulator.rename,
 stat=function(path)
  statCalls=statCalls+1
  if statFault=='throw'then error('stat fault')end
  if statFault=='shape'then return false end
  if simulator.files[path]~=nil then return{size=#simulator.files[path]}end
 end,
 remove=function(path)
  deleteCalls=deleteCalls+1
  if deleteFault or simulator.files[path]==nil then return 6 end
  return simulator.remove(path)
 end})
check(sim.save('settings',A,encode(31),decode)==true,'native-style first save succeeds')
local simPath=sim.paths('settings',A).canonical
check(simulator.files[simPath..'.bak']==nil,'first save has no old backup')
check(sim.save('settings',A,encode(32),decode)==true and deleteCalls==0 and statCalls==1,'changed save skips absent backup rather than interpreting simulator result6 as success')
check(sim.read('settings',A,decode,defaults).value==32 and sim.read('settings',A,decode,defaults).value~=31,'changed native-style save verifies current payload')
check(sim.save('settings',A,encode(33),decode)==true and deleteCalls==1,'existing backup is actually deleted before rotation')
local simPrimary,simBackup=simulator.files[simPath],simulator.files[simPath..'.bak']
deleteFault=true
check(sim.save('settings',A,encode(34),decode)==false and simulator.files[simPath]==simPrimary and simulator.files[simPath..'.bak']==simBackup,'result6 on an existing backup fails closed and preserves primary/backup')
deleteFault=nil
for _,fault in ipairs({'throw','shape'})do
 statFault=fault
 check(sim.save('settings',A,encode(34),decode)==false and simulator.files[simPath]==simPrimary and simulator.files[simPath..'.bak']==simBackup,'failed/invalid stat cannot authorize delete or replace active settings: '..fault)
end
statFault=nil;local beforeStats=statCalls
check(sim.read('settings',A,decode,defaults).value==33 and statCalls==beforeStats,'ordinary settings reads do not add stat/delete IO')
noHandles(simulator)

-- A verified-envelope memo must never trust changed file bytes, another owner,
-- or a decoder whose validation policy changes while its function is retained.
local memo=memory();local memoPath=memo.api.paths('settings',A).canonical
check(memo.api.save('settings',A,encode(31),decode),'memo fixture first save')
check(memo.api.read('settings',A,decode,defaults).value==31,'actual canonical read can establish a verified envelope')
memo.files[memoPath]=string.gsub(memo.files[memoPath],'value=31','value=99')
check(memo.api.save('settings',A,encode(32),decode)and memo.api.read('settings',A,decode,defaults).value==32 and memo.files[memoPath..'.bak']==nil,'externally changed bytes invalidate memo and corrupt primary never becomes a trusted backup')
local policy=memory();local minimum,decoderCalls=0,0
local function changingDecoder(raw)decoderCalls=decoderCalls+1;local t=decode(raw);if t and t.value>=minimum then return t end end
check(policy.api.save('settings',A,encode(31),changingDecoder),'current decoder memo fixture first save')
minimum=50;local beforeDecode=decoderCalls
check(policy.api.save('settings',A,encode(60),changingDecoder)and decoderCalls>=beforeDecode+2,'current decoder reruns for new and memoized old payload even when function identity is unchanged')
check(policy.files[policy.api.paths('settings',A).canonical..'.bak']==nil and policy.api.read('settings',A,changingDecoder,defaults).value==60,'memoized envelope cannot authorize backup of a payload rejected by current decoder')
check(policy.api.save('settings',B,encode(70),changingDecoder)and policy.api.read('settings',A,changingDecoder,defaults).value==60,'same-domain model change cannot reuse another owner envelope')
noHandles(memo);noHandles(policy)

-- Domain separation keeps application settings and battery policies distinct.
local bp=m.api.paths('battery',A)
check(m.api.save('battery',A,'ADBAT1 6\n',battery)==true and m.api.read('battery',A,battery,{0})[1]==6,'battery domain retains raw ADBAT1 payload under filename identity')
check(m.api.read('settings',A,decode,defaults).value==14,'battery save cannot alter application settings')
local domainSwap=memory();domainSwap.files[domainSwap.api.paths('settings',A).canonical]=m.files[bp.canonical]
data,meta=domainSwap.api.read('settings',A,decode,defaults)
check(data.value==7 and meta.error=='MODEL OWNER MISMATCH','cross-domain envelope cannot be accepted by a permissive decoder')
local ownerSwap=memory();ownerSwap.files[ownerSwap.api.paths('settings',B).canonical]=raw13
data,meta=ownerSwap.api.read('settings',B,decode,defaults)
check(data.value==7 and meta.error=='MODEL OWNER MISMATCH','copied envelope for another filename cannot transfer preference ownership')

-- Missing filename never falls back to a display name or touches legacy files.
for _,info in ipairs({{}, {name=A.name}, {filename='',name=A.name}, {filename='..',name=A.name}, {filename='../model.yml'}, {filename='a/b.yml'}, {filename='a\\b.yml'}, {filename='x\0.yml'}, {filename=string.rep('a',97)}})do
 local x=memory();x.files[p.legacy]=encode(11)
 local old=data;local result,state=x.api.read('settings',info,decode,defaults)
 check(result.value==7 and state.identityUnavailable and x.stats.opens==0,'unknown/invalid native filename cannot inherit a same-name file')
 check(x.api.save('settings',info,encode(2),decode)==false and x.stats.writes==0,'unknown native filename cannot save to a colliding name path')
 local imported,importMeta=x.api.importLegacy('settings',info,decode)
 check(imported==nil and importMeta.state=='IMPORT FAILED' and data==old,'unknown native filename cannot import or mutate active values')
end
for _,domain in ipairs({'../settings','SETTINGS','vtx',''})do
 check(m.api.paths(domain,A)==nil and m.api.save(domain,A,encode(1),decode)==false,'domain must be one of the two fixed preference scopes')
end
for _,root in ipairs({'relative','/x/../y','/x/./y','/x\\y','/x\0y','/'})do
 local x=memory();local store=M.new({io=x.fs,remove=x.remove,rename=x.rename,root=root})
 check(store.paths('settings',A)==nil and x.stats.opens==0,'invalid store root cannot become an arbitrary filesystem path')
end
local utf={filename='quad å.yml',name='模型'}
check(m.api.paths('settings',utf)~=nil,'valid non-ASCII/spaced native basenames remain safely hex encoded')

-- Legacy backup is offered/imported only after its payload validates, still
-- without claiming automatic ownership of ambiguous name-based preferences.
local old=memory();local lp=old.api.paths('settings',A)
old.files[lp.legacy]='BROKEN';old.files[lp.legacy..'.bak']=encode(19)
data,meta=old.api.read('settings',A,decode,defaults)
check(data.value==7 and meta.state=='IMPORT AVAILABLE' and meta.legacySource=='LEGACY BACKUP','valid legacy backup is available without applying it')
data,meta=old.api.importLegacy('settings',A,decode)
check(data and data.value==19 and meta.source=='LEGACY BACKUP' and old.files[lp.legacy]=='BROKEN','explicit verified import can promote original backup without modifying either legacy file')
local missing=memory();imported,meta=missing.api.importLegacy('settings',A,decode)
check(imported==nil and meta.state=='IMPORT FAILED' and missing.stats.writes==0,'missing legacy data does not create defaults under an import claim')
local failedImport=memory();local ip=failedImport.api.paths('settings',A)
failedImport.files[ip.legacy]=encode(20);failedImport.faults.truncate=ip.canonical..'.tmp'
imported,meta=failedImport.api.importLegacy('settings',A,decode)
check(imported==nil and meta.error=='READBACK MISMATCH' and failedImport.files[ip.canonical]==nil and failedImport.files[ip.legacy]==encode(20),'failed verified import returns no imported active values and preserves original')
noHandles(failedImport)

-- Never evaluate untrusted settings as code. Fully validate the payload before
-- write, and envelope ownership/length/checksum before the schema decoder.
for _,raw in ipairs({'return os.remove("/MODELS")','ADCFG1\nvalue=999\n','ADCFG1\nvalue=1\nextra',string.rep('X',9000),'ADCFG1\nvalue=2'})do
 local x=memory();local xp=x.api.paths('settings',A);x.files[xp.legacy]=raw
 check(x.api.read('settings',A,decode,defaults).value==7 and x.stats.writes==0,'invalid/executable/oversize/truncated legacy payload is never applied')
 check(x.api.save('settings',A,raw,decode)==false and x.stats.writes==0,'invalid payload cannot be promoted through save')
end
for _,raw in ipairs({string.sub(raw13,1,-2),raw13..'EXTRA',string.gsub(raw13,'ADMODEL1','ADMODEL2',1),string.gsub(raw13,'value=13','value=14',1),string.rep('X',10000)})do
 local x=memory();local xp=x.api.paths('settings',A);x.files[xp.canonical]=raw
 local calls=0;local result=x.api.read('settings',A,function(s)calls=calls+1;return decode(s)end,defaults)
 check(result.value==7 and calls==0 and x.stats.writes==0,'bad envelope/length/checksum is rejected before schema decoder')
 check(x.stats.maxRead<=8513,'even oversized canonical file has bounded read work');noHandles(x)
end
local x=memory();local xp=x.api.paths('settings',A)
local active={value=66};local exactActive=active
for _,fault in ipairs({'truncate','writeThrow','writeFalse','closeThrow','closeFalse','openThrow','openFail'})do
 x=memory();xp=x.api.paths('settings',A);x.api.save('settings',A,encode(11),decode)
 local good=x.files[xp.canonical];x.faults[fault]=xp.canonical..'.tmp'
 local ok=x.api.save('settings',A,encode(33),decode);if ok then active={value=33}end
 check(not ok and active==exactActive and active.value==66 and x.files[xp.canonical]==good,'failed temp write never changes previous valid primary/active preferences: '..fault)
 check(x.api.read('settings',A,decode,defaults).value==11,'failed write keeps old settings readable: '..fault);noHandles(x)
end
for _,fault in ipairs({'readThrow','readWrongType','closeThrow','closeFalse','openThrow'})do
 x=memory();xp=x.api.paths('settings',A);x.api.save('settings',A,encode(11),decode)
 local good=x.files[xp.canonical];local beforeWrites=x.stats.writes;x.faults[fault]=xp.canonical
 check(x.api.save('settings',A,encode(33),decode)==false and x.files[xp.canonical]==good and x.stats.writes==beforeWrites,'transient primary read failure aborts before replacing good data: '..fault);noHandles(x)
end
for _,fault in ipairs({'backupDelete','backupRename','promotion','finalCorrupt'})do
 x=memory();xp=x.api.paths('settings',A);x.api.save('settings',A,encode(11),decode)
 if fault=='backupDelete'then x.faults.removeFail=xp.canonical..'.bak'
 elseif fault=='backupRename'then x.faults.renameFailFrom=xp.canonical
 elseif fault=='promotion'then x.faults.renameFailFrom=xp.canonical..'.tmp'
 else x.faults.corruptPromote=xp.canonical end
 check(x.api.save('settings',A,encode(33),decode)==false,'atomic promotion failure is reported: '..fault)
 check(x.api.read('settings',A,decode,defaults).value==11,'old validated primary or backup survives failed promotion: '..fault);noHandles(x)
end

-- Missing native functions and absent directories fail safely, not via unsafe
-- direct overwrite. Decoder exceptions cannot change active or original data.
x=memory();local store=M.new({io=x.fs,root='/STORE'})
check(store.save('settings',A,encode(1),decode)==false and x.stats.writes==0,'absent native atomic file APIs cannot cause direct overwrite')
store=M.new({io={},root='/STORE'});data,meta=store.read('settings',A,decode,defaults)
check(data.value==7 and meta.error=='IO UNAVAILABLE' and store.save('settings',A,encode(1),decode)==false,'missing native IO produces defaults plus explicit failure')
x=memory();x.faults.noDirectory=true
check(x.api.save('settings',A,encode(1),decode)==false and x.api.read('settings',A,decode,defaults).value==7,'missing directory is nonfatal and is never created during storage operations')
check(m.api.save('settings',A,encode(1),function()error('bad schema')end)==false and m.api.save('settings',A,encode(1),nil)==false,'missing/throwing decoder cannot authorize writes')
for _,event in ipairs(m.events)do check(event[2]~='/MODELS' and event[1]~='mkdir','store writes are scoped to its own inert preference records')end

-- EdgeTX string method metatable is absent. Test actual read/import/backup/
-- filename keying with that compatibility constraint, not host-only behavior.
local stringMeta=debug.getmetatable('');debug.setmetatable('',nil)
local strippedOK,strippedError=pcall(function()
 local native=memory();local np=native.api.paths('settings',A)
 native.files[np.legacy]=encode(9)
 local values,state=native.api.read('settings',A,decode,defaults)
 check(values.value==7 and state.state=='IMPORT AVAILABLE','stripped string library supports legacy detection')
 values,state=native.api.importLegacy('settings',A,decode)
 check(values.value==9 and state.state=='IMPORTED','stripped string library supports verified inert import')
 check(native.api.save('settings',A,encode(10),decode)==true,'stripped string library supports atomic preference save')
 native.files[np.canonical]='corrupt'
 check(native.api.read('settings',A,decode,defaults).value==9,'stripped string library supports validated backup recovery')
 noHandles(native)
end)
debug.setmetatable('',stringMeta);check(strippedOK,'native stripped string compatibility: '..tostring(strippedError))
print('model-store: '..checks..' checks passed')
