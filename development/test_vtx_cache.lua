-- Exercise the actual cache with EdgeTX-style io/del/rename in RAM only.
-- No SD file or host filesystem write is performed by this test.
local M=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/vtx-cache.lua'))()
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local UID='0123456789ABCDEF01234567';local UID2='FEDCBA9876543210FEDCBA98'
local FILE='/CACHE/vtx-'..UID..'.cache'
local function clone(t)
 if type(t)~='table'then return t end
 local c={};for k,v in pairs(t)do c[k]=clone(v)end;return c
end
local function fixture()
 return {uid=UID,signature='3:2:3:2',bands={
  {index=1,name='Race | Custom',letter='R',factory=false,frequencies={5658,0,5917}},
  {index=2,name='FATSHARK',letter='F',factory=true,frequencies={5740,5800,5880}}
 },powers={{index=1,value=14,label='25 mW'},{index=2,value=26,label='400 mW'}}}
end
local function fresh(extra)
 local t={hardware=3,bandCount=2,channelCount=3,powerCount=2,tableAvailable=true}
 for k,v in pairs(extra or {})do t[k]=v end;return t
end
local function memory()
 local store,events,handles={},{},{}
 local faults={};local stats={reads=0,writes=0,maxRead=0,maxWrite=0,closes=0}
 local fs={}
 function fs.open(path,mode)
  events[#events+1]={'open',path,mode}
  if faults.directoryMissing then return nil end
  if faults.openThrow==path then error('open failed')end
  if faults.openFail==path then return nil end
  if mode=='r' and store[path]==nil then return nil end
  if mode=='w' then store[path]=''end
  local f={path=path,mode=mode};handles[f]=true;return f
 end
 function fs.read(f,n)
  check(handles[f] and f.mode=='r','io.read receives the explicit native file handle')
  stats.reads=stats.reads+1;stats.maxRead=math.max(stats.maxRead,n)
  if faults.readThrow==f.path then error('read failed')end
  if faults.readWrongType==f.path then return {}end
  return string.sub(store[f.path]or'',1,n)
 end
 function fs.write(f,raw)
  check(handles[f] and f.mode=='w','io.write receives the explicit native file handle')
  stats.writes=stats.writes+1;stats.maxWrite=math.max(stats.maxWrite,#raw)
  if faults.writeThrow==f.path then error('write failed')end
  if faults.writeFalse==f.path then return false end
  store[f.path]=faults.truncate==f.path and string.sub(raw,1,math.floor(#raw/2)) or raw
  return nil -- Native EdgeTX write has no required boolean success result.
 end
 function fs.close(f)
  check(handles[f],'all native close calls receive an open handle')
  handles[f]=nil;stats.closes=stats.closes+1
  if faults.closeThrow==f.path then error('close failed')end
  if faults.closeFalse==f.path then return false end
 end
 local function remove(path)
  events[#events+1]={'remove',path}
  if faults.removeFail==path then return 7 end
  if store[path]==nil then return 4 end
  store[path]=nil;return 0 -- FRESULT0 is success, not a boolean.
 end
 local function rename(from,to)
  events[#events+1]={'rename',from,to}
  if faults.renameFailFrom==from or faults.renameFailTo==to then return 7 end
  if store[from]==nil then return 4 end
  if store[to]~=nil then return 8 end
  store[to]=store[from];store[from]=nil
  if faults.corruptPromote==to then store[to]='corrupted after rename'end
  return 0
 end
 local cache=M.new({io=fs,root='/CACHE',remove=remove,rename=rename})
 return {store=store,events=events,handles=handles,faults=faults,stats=stats,fs=fs,remove=remove,rename=rename,cache=cache}
end
local function noHandles(m)check(next(m.handles)==nil,'no file handle remains open after operation')end
local function denied(t,reason)
 local m=memory();local ok,err=m.cache:save(UID,t)
 check(ok==false and (not reason or err==reason),'invalid table is rejected before IO: '..tostring(err))
 check(#m.events==0,'invalid table cannot touch an SD path');noHandles(m)
end

-- Round-trip exact inert data, native API signatures and metadata-only matching.
local m=memory();local tables=fixture()
local ok,why=m.cache:save(string.lower(UID),tables)
check(ok and why=='SAVED','save normalizes a valid lowercase UID and verifies promotion')
local raw=m.store[FILE]
check(type(raw)=='string' and raw:sub(1,6)=='ADVT1\n' and not raw:find('return ',1,true),'cache is a versioned data record, not executable Lua')
check(not raw:find('Race | Custom',1,true),'text delimiters are hex encoded without ambiguous records')
local loaded,err,meta=m.cache:load(UID,fresh())
check(loaded and err==nil and meta.source=='PRIMARY','valid primary cache loads against matching reported metadata')
check(loaded.uid==UID and loaded.signature=='3:2:3:2','UID/signature survive the inert file')
check(loaded.bands[1].name==tables.bands[1].name and loaded.bands[1].factory==false and loaded.bands[2].factory==true,'band names and factory booleans survive exactly')
check(loaded.bands[1].frequencies[2]==0 and loaded.bands[2].frequencies[3]==5880,'all frequencies including disabled0 survive')
check(loaded.powers[2].value==26 and loaded.powers[2].label=='400 mW','power values and labels survive exactly')
check(loaded.cached and loaded.ready==nil and loaded.fresh==nil and loaded.writeAllowed==nil,'cache is explicitly inert and cannot claim readiness/freshness/write authority')
check(M.matches(loaded,UID,fresh())==true,'exact UID+hardware/dimension signature can match')
for _,fields in ipairs({{hardware=4},{bandCount=1},{channelCount=8},{powerCount=1},{tableAvailable=false}})do
 check(M.matches(loaded,UID,fresh(fields))==false,'new hardware/dimensions/unavailable table invalidates cached metadata')
end
check(M.matches(loaded,UID2,fresh())==false,'another FC UID cannot reuse the cached tables')
check(M.matches(loaded,UID,nil)==false,'missing fresh metadata cannot validate a cache for use')
-- Only decode-owned records use the internal fast metadata path. The public
-- API still validates untrusted tables; both primary and backup loads must
-- preserve exactly the public decision/error for every fresh metadata case.
for _,change in ipairs({'frequency','factory','count','uid'})do
 local untrusted=clone(loaded)
 if change=='frequency'then untrusted.bands[1].frequencies[1]=5800.5
 elseif change=='factory'then untrusted.bands[1].factory=1
 elseif change=='count'then untrusted.powers[3]=clone(untrusted.powers[1])
 else untrusted.uid=UID2 end
 check(M.matches(untrusted,UID,fresh())==false,'public metadata API rejects untrusted mutated record: '..change)
end
for _,reported in ipairs({fresh(),fresh({hardware=4}),fresh({bandCount=1}),fresh({tableAvailable=false}),
 fresh({powerCount=9}),{signature='03:2:3:2'},{reported=fresh()},'invalid metadata'})do
 local expected,expectedError=M.matches(loaded,UID,reported)
 for _,source in ipairs({'PRIMARY','BACKUP'})do
  local isolated=memory();isolated.store[source=='PRIMARY'and FILE or FILE..'.bak']=raw
  local result,resultError,resultMeta=isolated.cache:load(UID,reported)
  check((result~=nil)==expected and resultError==expectedError,'internal validated metadata decision/errors match public API: '..source)
  if result then check(resultMeta.source==source and result.cached and result.ready==nil and result.writeAllowed==nil,'fast metadata comparison preserves inert source/provenance: '..source)end
  noHandles(isolated)
 end
end
check(m.cache:load(UID,fresh({hardware=4}))==nil,'load with explicit mismatched fresh metadata does not return a usable table')
local writes=m.stats.writes
check(m.cache:load(UID)~=nil and m.stats.writes==writes,'load without metadata returns only inert data and never repairs/writes')
check(m.cache:save(UID,fixture())==true and m.stats.writes==writes,'unchanged canonical data avoids extra SD writes')
check(m.stats.maxRead<=4097 and m.stats.maxWrite<=4096,'native IO is strictly byte bounded')
noHandles(m)

-- Official native simulator deletion returns6 for missing paths. Avoid that
-- unnecessary call using fstat, while6 on an existing object remains failure.
local sim=memory();local simDeletes,simStats=0,0;local statFault,deleteFault
local simCache=M.new({io=sim.fs,root='/CACHE',rename=sim.rename,
 stat=function(path)
  simStats=simStats+1
  if statFault=='throw'then error('stat failure')end
  if statFault=='shape'then return false end
  if sim.store[path]~=nil then return{size=#sim.store[path]}end
 end,
 remove=function(path)
  simDeletes=simDeletes+1
  if deleteFault or sim.store[path]==nil then return 6 end
  return sim.remove(path)
 end})
local simTable=fixture();check(simCache:save(UID,simTable)==true,'native-style cache first save succeeds')
simTable.powers[2].label='CHANGED'
check(simCache:save(UID,simTable)==true and simDeletes==0 and simStats==1,'changed cache save skips missing backup rather than accepting delete6')
check(simCache:load(UID).powers[2].label=='CHANGED','changed cache payload passes actual decode/readback')
simTable.powers[2].label='THIRD';check(simCache:save(UID,simTable)==true and simDeletes==1,'existing cache backup is actually deleted before rotation')
local simPrimary,simBackup=sim.store[FILE],sim.store[FILE..'.bak'];deleteFault=true;simTable.powers[2].label='FAILED'
check(simCache:save(UID,simTable)==false and sim.store[FILE]==simPrimary and sim.store[FILE..'.bak']==simBackup,'delete6 on existing backup preserves old cache primary/backup')
check(simCache:remove(UID)==false and sim.store[FILE]==simPrimary,'explicit cache prune cannot pretend existing failure6 succeeded')
deleteFault=nil
for _,fault in ipairs({'throw','shape'})do
 statFault=fault
 check(simCache:remove(UID)==false and sim.store[FILE]==simPrimary and sim.store[FILE..'.bak']==simBackup,'invalid/failed stat prevents cache pruning: '..fault)
end
statFault=nil;check(simCache:remove(UID)==true and sim.store[FILE]==nil and sim.store[FILE..'.bak']==nil and sim.store[FILE..'.tmp']==nil,'explicit prune removes actual backup/temp/primary in safe order')
local beforeDeletes=simDeletes
check(simCache:remove(UID)==true and simDeletes==beforeDeletes,'pruning already absent cache never calls simulator delete on missing files')
noHandles(sim)

local memo=memory();local memoTables=fixture()
check(memo.cache:save(UID,memoTables),'verified cache memo fixture saves')
memo.store[FILE]=string.gsub(memo.store[FILE],'ADVT1','ADVT2')
memoTables.powers[1].label='NEW'
check(memo.cache:save(UID,memoTables)and memo.cache:load(UID).powers[1].label=='NEW'and memo.store[FILE..'.bak']==nil,'externally changed cache bytes invalidate memo and corrupt primary is never rotated as valid backup')
local metadataMemo=memory();local beforeTables=fixture()
check(metadataMemo.cache:save(UID,beforeTables),'metadata mismatch memo fixture saves')
local oldEnvelope=metadataMemo.store[FILE]
local reopened=M.new({io=metadataMemo.fs,root='/CACHE',remove=metadataMemo.remove,rename=metadataMemo.rename})
check(reopened:load(UID,fresh({hardware=4}))==nil,'fresh mismatch still exposes no usable cached table')
beforeTables.signature='4:2:3:2'
check(reopened:save(UID,beforeTables)and metadataMemo.store[FILE..'.bak']==oldEnvelope,'valid inert old envelope can be retained as backup even after freshness mismatch')
local accepted=reopened:load(UID,fresh({hardware=4}))
check(accepted and accepted.hardware==4 and accepted.ready==nil and accepted.writeAllowed==nil,'changed metadata produces only inert newly matched cache, no write authority')
noHandles(memo);noHandles(metadataMemo)

-- Cache files are owned copies; injected executable-looking strings stay strings.
loaded.bands[1].frequencies[1]=1;loaded.powers[1].label='mutated'
local again=m.cache:load(UID)
check(again.bands[1].frequencies[1]==5658 and again.powers[1].label=='25 mW','caller mutation cannot alter persisted/other loaded tables')
local executable=fixture();executable.bands[1].name="os.remove('/MODELS')";executable.powers[1].label='return function() end'
check(m.cache:save(UID,executable)==true,'printable source-looking names remain legal inert labels')
local strings=m.cache:load(UID)
check(strings.bands[1].name==executable.bands[1].name and strings.powers[1].label==executable.powers[1].label,'source-looking labels round-trip as data without execution')
check(m.store[FILE..'.bak']==raw,'a validated previous primary becomes the backup')

-- UID paths are canonical and cannot escape the existing cache directory.
for _,bad in ipairs({'../MODELS',UID..'/x','/SCRIPTS/TOOLS/elrs.lua','',string.rep('0',24),string.rep('A',23),string.rep('A',25),string.rep('G',24),UID..'\n'})do
 local before=#m.events
 check(m.cache:save(bad,fixture())==false and m.cache:load(bad)==nil and m.cache:remove(bad)==false,'malformed/nonunique UID is rejected')
 check(#m.events==before,'invalid UID causes no open/rename/delete')
end
for _,root in ipairs({'relative','/CACHE/../MODELS','/CACHE/.','/','/CACHE\n','/CACHE\\other'})do
 local bad=M.new({io=m.fs,root=root,remove=m.remove,rename=m.rename});local before=#m.events
 check(bad:save(UID,fixture())==false and bad:remove(UID)==false and #m.events==before,'invalid cache root cannot direct file operations')
end

-- Strict dimensions/counts/indices/printable lengths and U16 ranges.
for _,sig in ipairs({'3:9:3:2','3:2:0:2','3:2:3:9','0:2:3:2','255:2:3:2','03:2:3:2','3:2:3:2 extra'})do local t=fixture();t.signature=sig;denied(t)end
local t=fixture();t.hardware=4;denied(t,'METADATA MISMATCH')
t=fixture();t.reported=fresh({hardware=4});denied(t,'METADATA MISMATCH')
t=fixture();t.uid=UID2;denied(t,'UID MISMATCH')
t=fixture();t.bands[1]=nil;denied(t,'TABLE COUNT MISMATCH')
t=fixture();t.bands[3]=clone(t.bands[2]);denied(t,'TABLE COUNT MISMATCH')
t=fixture();t.bands.extra={};denied(t,'TABLE COUNT MISMATCH')
t=fixture();t.bands[2].index=1;denied(t,'INVALID BAND')
t=fixture();t.bands[1].name=string.rep('A',65);denied(t,'INVALID BAND')
t=fixture();t.bands[1].name='A\nB';denied(t,'INVALID BAND')
t=fixture();t.bands[1].letter='AB';denied(t,'INVALID BAND')
t=fixture();t.bands[1].factory=0;denied(t,'INVALID BAND')
t=fixture();t.bands[1].frequencies[4]=5800;denied(t,'INVALID BAND')
for _,bad in ipairs({-1,65536,5800.5,0/0,math.huge,'5800'})do t=fixture();t.bands[1].frequencies[1]=bad;denied(t,'INVALID FREQUENCY')end
for _,bad in ipairs({-1,65536,1.2,0/0,math.huge,'26'})do t=fixture();t.powers[1].value=bad;denied(t,'INVALID POWER')end
t=fixture();t.powers[1].label=string.rep('A',65);denied(t,'INVALID POWER')
t=fixture();t.powers[1].label='bad\0';denied(t,'INVALID POWER')
t=fixture();t.powers[1].index=2;denied(t,'INVALID POWER')
t=fixture();t.powers[1].label=function()error('never execute a label')end;denied(t,'INVALID POWER')

-- Maximum legal table stays within one bounded native read/write record.
local maximum={reported={hardware=5,bandCount=8,channelCount=8,powerCount=8,tableAvailable=true},bands={},powers={},ready=true}
for i=1,8 do
 local frequencies={};for j=1,8 do frequencies[j]=(j==1 and 0 or 65535)end
 maximum.bands[i]={index=i,name=string.rep('N',64),letter='Z',factory=i%2==0,frequencies=frequencies}
 maximum.powers[i]={index=i,value=65535,label=string.rep('P',64)}
end
local big=memory();check(big.cache:save(UID,maximum)==true,'maximum legal8×8×8/64byte table saves')
local biggest=big.cache:load(UID)
check(#biggest.bands==8 and #biggest.bands[8].frequencies==8 and #biggest.powers==8,'maximum dimensions round-trip')
check(#biggest.bands[8].name==64 and #biggest.powers[8].label==64 and biggest.ready==nil,'maximum text is preserved while foreign readiness is dropped')
check(#big.store[FILE]<=4096 and big.stats.maxRead==4097 and big.stats.maxWrite<=4096,'worst case remains bounded')
noHandles(big)

-- Corrupt/truncated/oversize/executable files are rejected without evaluating.
for _,rawFile in ipairs({'return os.remove("/MODELS")',raw:sub(1,-2),raw:gsub('5658','5659',1),raw..'extra',string.rep('X',10000)})do
 local corrupt=memory();corrupt.store[FILE]=rawFile
 check(corrupt.cache:load(UID)==nil and corrupt.stats.writes==0,'untrusted/truncated/oversize file is not data or code')
 check(corrupt.stats.maxRead<=4097,'even an oversized file has bounded read work');noHandles(corrupt)
end
-- Independently recompute fixture checksum after semantic tampering to exercise
-- parser validation, rather than letting checksum rejection hide parser bugs.
local function reseal(body)
 local a,b=0,0
 for i=1,#body do a=(a+body:byte(i))%255;b=(b+(#body-i+1)*body:byte(i))%255 end
 return body..string.format('C|%02X%02X\n',a,b)
end
local body=raw:match('^(.*)C|[0-9A-F]+\n$')
for _,changed in ipairs({(body:gsub('5658','65536',1)),(body:gsub('B|1|0|','B|2|0|',1)),(body:gsub('S|3:2:3:2','S|3:8:3:2',1)),(body:gsub('U|'..UID,'U|'..UID2,1)),(body:gsub('5658,0,5917','5658,,5917',1))})do
 local parser=memory();parser.store[FILE]=reseal(changed)
 check(parser.cache:load(UID)==nil,'semantically malformed file is rejected even with a valid checksum')
 noHandles(parser)
end

-- Recovery is read-only and preserves old good data on every failed save phase.
local recovery=memory();recovery.cache:save(UID,fixture())
local updated=fixture();updated.powers[1].label='NEW POWER'
recovery.cache:save(UID,updated);recovery.store[FILE]='broken'
local beforeWrites=recovery.stats.writes
local recovered,recoverError,recoverMeta=recovery.cache:load(UID)
check(recovered and recovered.powers[1].label=='25 mW' and recoverError==nil and recoverMeta.recovered and recoverMeta.primaryError~=nil,'corrupt primary recovers the validated same-UID backup with truthful metadata')
check(recovery.stats.writes==beforeWrites and recovery.store[FILE]=='broken','load recovery never rewrites SD on a read path')
recovery.store[FILE..'.bak']=recovery.store[FILE..'.bak']:gsub(UID,UID2,1)
check(recovery.cache:load(UID)==nil,'another UID or invalid backup is not accepted as recovery')
for _,fault in ipairs({'truncate','writeThrow','writeFalse','closeThrow','closeFalse'})do
 local failed=memory();failed.cache:save(UID,fixture());local good=failed.store[FILE]
 failed.faults[fault]=FILE..'.tmp'
 check(failed.cache:save(UID,updated)==false and failed.store[FILE]==good,'failed verified-temp phase preserves current primary: '..fault)
 check(failed.cache:load(UID).powers[1].label=='25 mW','old good primary remains usable after '..fault);noHandles(failed)
end
for _,fault in ipairs({'readThrow','readWrongType','closeThrow','closeFalse','openThrow'})do
 local failed=memory();failed.cache:save(UID,fixture());local good=failed.store[FILE];local writesBefore=failed.stats.writes
 failed.faults[fault]=FILE
 check(failed.cache:save(UID,updated)==false and failed.store[FILE]==good and failed.stats.writes==writesBefore,'transient primary read failure aborts before replacing good data: '..fault)
 noHandles(failed)
end
local failedRename=memory();failedRename.cache:save(UID,fixture());failedRename.faults.renameFailFrom=FILE..'.tmp'
check(failedRename.cache:save(UID,updated)==false and failedRename.store[FILE]==nil,'failed promotion is reported after atomic old-primary backup rotation')
check(failedRename.cache:load(UID).powers[1].label=='25 mW','old validated backup survives failed promotion')
local postCorrupt=memory();postCorrupt.cache:save(UID,fixture());postCorrupt.faults.corruptPromote=FILE
check(postCorrupt.cache:save(UID,updated)==false,'post-promotion corruption fails final readback')
check(postCorrupt.cache:load(UID).powers[1].label=='25 mW','final readback failure still leaves validated prior backup')

-- Removing cached tables never deletes another FC/tool, and cannot resurrect bak.
local removal=memory();removal.cache:save(UID,fixture());removal.cache:save(UID,updated)
removal.store[FILE..'.tmp']='partial';removal.store['/CACHE/unrelated.lua']='DO NOT TOUCH'
removal.store['/CACHE/vtx-'..UID2..'.cache']='OTHER FC'
check(removal.cache:remove(UID)==true and not removal.store[FILE] and not removal.store[FILE..'.bak'] and not removal.store[FILE..'.tmp'],'explicit remove clears primary,backup and temporary cache')
check(removal.cache:load(UID)==nil,'removed cache cannot return through stale backup')
check(removal.store['/CACHE/unrelated.lua']=='DO NOT TOUCH' and removal.store['/CACHE/vtx-'..UID2..'.cache']=='OTHER FC','remove is strictly scoped to one validated UID prefix')
check(removal.cache:remove(UID)==true,'removing an already absent cache handles native FRESULT4 correctly')
local partial=memory();partial.cache:save(UID,fixture());partial.cache:save(UID,updated);local good=partial.store[FILE]
partial.faults.removeFail=FILE..'.bak'
check(partial.cache:remove(UID)==false and partial.store[FILE]==good,'backup deletion failure aborts before deleting primary')
local absent=memory();absent.faults.directoryMissing=true
check(absent.cache:save(UID,fixture())==false and absent.cache:load(UID)==nil,'missing cache directory is a nonfatal cache miss/save failure')
for _,event in ipairs(absent.events)do check(event[1]~='mkdir','no directory creation occurs on cache operations')end
local readonly=M.new({io=m.fs,root='/CACHE'})
local readonlyOK,readonlyError=readonly:save(UID,fixture())
check(readonlyOK==false and readonlyError=='ATOMIC FILE API UNAVAILABLE','missing native atomic APIs never cause unsafe direct overwrite fallback')

-- EdgeTX's stripped string library does not install a method metatable. Exercise
-- actual validation, serialization, parsing, recovery, matching and removal.
local stringMeta=debug.getmetatable('')
debug.setmetatable('',nil)
local strippedOK,strippedError=pcall(function()
 local native=memory();local nativeCache=M.new({io=native.fs,remove=native.remove,rename=native.rename,root='/CACHE/'})
 check(nativeCache:save(UID,fixture())==true,'cache saves without string method metatable')
 local record=nativeCache:load(UID,fresh())
 check(record and record.bands[1].name=='Race | Custom' and record.powers[2].label=='400 mW','cache parses names/powers without string method metatable')
 check(M.matches(record,UID,fresh())==true,'metadata/UID validation work without string method metatable')
 local changed=fixture();changed.powers[1].label='UPDATED'
 check(nativeCache:save(UID,changed)==true,'cache rotates validated backup without string method metatable')
 native.store[FILE]='corrupted'
 local backup,_,meta=nativeCache:load(UID)
 check(backup and meta.source=='BACKUP','cache validates backup recovery without string method metatable')
 check(nativeCache:remove(UID)==true and nativeCache:load(UID)==nil,'cache removes all same-UID files without string method metatable')
 noHandles(native)
end)
debug.setmetatable('',stringMeta)
check(strippedOK,'stripped native string compatibility: '..tostring(strippedError))

print('vtx-cache: '..checks..' checks passed')
