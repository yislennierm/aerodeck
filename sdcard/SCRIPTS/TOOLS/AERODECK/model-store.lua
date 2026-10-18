-- Per-model inert settings storage keyed by EdgeTX model.getInfo().filename.
-- Officialv2.12.4 lua/api_model.cpp:55-73 returns currModelFilename on TX16S;
-- display-name changes do not change identity, duplicate model files do.
-- Legacy display-name files are never automatically owned, imported or changed.
-- Explicit import validates legacy data then verifies a new canonical save.
-- Native io.read/write/close(handle,...) and del/rename FRESULT conventions.
-- No model APIs, executable cache, warm-loop IO or active settings mutation.
local M={}
local domains={settings=8192,battery=256}
local maxHeader=320
local function hex(value)
 return (string.gsub(value,'.',function(c)return string.format('%02x',string.byte(c))end))
end
local function identity(info)
 local f=type(info)=='table' and info.filename
 if type(f)~='string' or #f<1 or #f>96 or f=='.' or f=='..' or string.find(f,'[%c/\\]')then return nil,'MODEL FILENAME UNAVAILABLE'end
 return f,hex(f)
end
local function copy(value,depth)
 if type(value)~='table'then return value end
 if depth>4 then return nil end
 local t={};local count=0
 for k,v in pairs(value)do
  count=count+1;if count>512 then break end
  if type(k)=='string' or type(k)=='number'then t[k]=copy(v,depth+1)end
 end
 return t
end
local function checksum(raw)
 local a,b=0,0
 local i,n=1,#raw;local byte=string.byte
 -- Same persisted Fletcher checksum, evaluated16 bytes per iteration. Exact
 -- legacy equivalence passed3333 binary/boundary/random payloads in LuaJIT
 -- and int32/float32 Lua. Every intermediate is <=38998 (exact in both).
 while i+15<=n do
  local x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16=byte(raw,i,i+15)
  a=a+x1;b=b+a;a=a+x2;b=b+a;a=a+x3;b=b+a;a=a+x4;b=b+a
  a=a+x5;b=b+a;a=a+x6;b=b+a;a=a+x7;b=b+a;a=a+x8;b=b+a
  a=a+x9;b=b+a;a=a+x10;b=b+a;a=a+x11;b=b+a;a=a+x12;b=b+a
  a=a+x13;b=b+a;a=a+x14;b=b+a;a=a+x15;b=b+a;a=a+x16;b=b+a
  a=a%255;b=b%255
  i=i+16
 end
 for j=i,n do a=(a+byte(raw,j))%255;b=(b+a)%255 end
 return string.format('%02X%02X',a,b)
end
local function wrap(domain,key,payload,verifiedSum)
 return 'ADMODEL1\nF|'..key..'\nD|'..domain..'\nN|'..#payload..'\nC|'..(verifiedSum or checksum(payload))..'\n\n'..payload
end
local function decodePayload(decode,payload)
 if type(decode)~='function'then return nil,'DECODER UNAVAILABLE'end
 local ok,data=pcall(decode,payload)
 if not ok then return nil,'DECODE ERROR'end
 if type(data)~='table'then return nil,'INVALID SETTINGS'end
 return data
end
local function unwrap(domain,key,raw,decode)
 local split=string.find(raw,'\n\n',1,true)
 if not split or split>maxHeader then return nil,'INVALID ENVELOPE'end
 local header=string.sub(raw,1,split)
 local owner,kind,n,sum=string.match(header,'^ADMODEL1\nF|([0-9a-f]+)\nD|([a-z]+)\nN|(%d+)\nC|([0-9A-F][0-9A-F][0-9A-F][0-9A-F])\n$')
 if owner~=key or kind~=domain then return nil,'MODEL OWNER MISMATCH'end
 local payload=string.sub(raw,split+2)
 if tonumber(n)~=#payload or #payload<1 or #payload>domains[domain]then return nil,'CORRUPT OR TRUNCATED SETTINGS'end
 local actualSum=checksum(payload)
 if actualSum~=sum or wrap(domain,key,payload,actualSum)~=raw then return nil,'CORRUPT OR TRUNCATED SETTINGS'end
 local data,err=decodePayload(decode,payload)
 return data,err,payload
end
function M.new(opts)
 opts=opts or {}
 local fs=opts.io or io
 local removeFile,renameFile=opts.remove or del,opts.rename or rename
 local statFile=opts.stat or fstat
 local root=opts.root or '/SCRIPTS/TOOLS/AERODECK'
 local validRoot=type(root)=='string' and #root<=128 and string.sub(root,1,1)=='/' and not string.find(root,'[%c\\]')
 if validRoot then
  for part in string.gmatch(root,'[^/]+')do if part=='.' or part=='..'then validRoot=false end end
  root=string.gsub(root,'/+$','');validRoot=validRoot and #root>0
 end
 local api={}
 -- At most one verified canonical envelope per domain. Fresh reads must still
 -- be byte-identical, and the caller's current decoder always runs again.
 local verified={settings={},battery={}}
 local function remember(p,raw)
  local record=verified[p.domain];record.path=p.canonical;record.raw=raw
  record.payloadStart=string.find(raw,'\n\n',1,true)+2
 end
 function api.paths(domain,info)
  if not domains[domain]then return nil,'INVALID DOMAIN'end
  if not validRoot then return nil,'INVALID STORE ROOT'end
  local filename,key=identity(info);if not filename then return nil,key end
  local p={filename=filename,key=key,domain=domain,canonical=root..'/'..domain..'-model-'..key..'.cfg'}
  local name=info.name
  if type(name)=='string' and #name>0 and #name<=64 then p.legacy=root..'/'..domain..'-'..hex(name)..'.cfg'end
  return p
 end
 local function ioReady(write)
  return type(fs)=='table' and type(fs.open)=='function' and type(fs.read)=='function' and type(fs.close)=='function'
   and (not write or (type(fs.write)=='function' and type(removeFile)=='function' and type(renameFile)=='function'))
 end
 local function readFile(path,limit)
  local ok,f=pcall(fs.open,path,'r');if not ok then return nil,'OPEN ERROR',false end
  if not f then return nil,'NOT FOUND',false end
  local good,raw=pcall(fs.read,f,limit+1);local closed,result=pcall(fs.close,f)
  if not good or not closed or result==false or type(raw)~='string'then return nil,'READ ERROR',true end
  if #raw>limit then return nil,'OVERSIZE FILE',true end
  return raw,nil,true
 end
 local function canonical(p,decode)
  local raw,err,exists=readFile(p.canonical,domains[p.domain]+maxHeader)
  local data,decodeError,payload
  if raw then data,decodeError,payload=unwrap(p.domain,p.key,raw,decode)end
  if data then remember(p,raw);return data,{state='SAVED',source='PRIMARY',path=p.canonical,filename=p.filename},payload end
  local primaryError=err or decodeError
  local backup,backupError=readFile(p.canonical..'.bak',domains[p.domain]+maxHeader)
  if backup then data,decodeError,payload=unwrap(p.domain,p.key,backup,decode)end
  if data then return data,{state='RECOVERED',source='BACKUP',path=p.canonical..'.bak',filename=p.filename,primaryError=primaryError},payload end
  return nil,{error=decodeError or primaryError or backupError,primaryError=primaryError,primaryExists=exists,filename=p.filename,path=p.canonical}
 end
 local function legacy(p,decode)
  if not p.legacy then return nil,{error='LEGACY NAME UNAVAILABLE'}end
  local raw,err=readFile(p.legacy,domains[p.domain])
  local data,decodeError
  if raw then data,decodeError=decodePayload(decode,raw)end
  if data then return data,{source='LEGACY',legacyPath=p.legacy},raw end
  local backup,backupError=readFile(p.legacy..'.bak',domains[p.domain])
  if backup then data,decodeError=decodePayload(decode,backup)end
  if data then return data,{source='LEGACY BACKUP',legacyPath=p.legacy..'.bak'},backup end
  return nil,{error=decodeError or err or backupError}
 end
 function api.read(domain,info,decode,defaults)
  local fallback=copy(type(defaults)=='table' and defaults or {},0)
  local p,err=api.paths(domain,info)
  if not p then return fallback,{state='DEFAULTS',error=err,identityUnavailable=err=='MODEL FILENAME UNAVAILABLE'}end
  if not ioReady(false)then return fallback,{state='DEFAULTS',error='IO UNAVAILABLE',filename=p.filename}end
  local data,meta=canonical(p,decode)
  if data then return data,meta end
  local _,oldMeta,oldRaw=legacy(p,decode)
  if oldRaw then
   meta.state='IMPORT AVAILABLE';meta.legacyAvailable=true;meta.legacyPath=oldMeta.legacyPath;meta.legacySource=oldMeta.source
  else meta.state='DEFAULTS';meta.legacyAvailable=false;meta.legacyError=oldMeta.error end
  return fallback,meta
 end
 local function remove(path)
  -- Official simulator FatFS returns FR_INVALID_NAME(6) for an absent file;
  -- real FatFS uses FR_NO_FILE(4). Do not accept6 as a successful delete.
  -- Native fstat permits avoiding that unnecessary call for a missing backup.
  if type(statFile)=='function'then
   local ok,info=pcall(statFile,path)
   if not ok or(info~=nil and type(info)~='table')then return false end
   if info==nil then return true end
  end
  local ok,v=pcall(removeFile,path);return ok and (v==0 or v==true or v==4 or v==5)
 end
 local function move(from,to)
  local ok,v=pcall(renameFile,from,to);return ok and (v==0 or v==true)
 end
 local function writeFile(path,raw,limit)
  local ok,f=pcall(fs.open,path,'w');if not ok or not f then return false,'OPEN WRITE FAILED'end
  local good,v=pcall(fs.write,f,raw);local closed,result=pcall(fs.close,f)
  if not good or v==false or not closed or result==false then return false,'WRITE ERROR'end
  local actual=readFile(path,limit)
  if actual~=raw then return false,'READBACK MISMATCH'end
  return true
 end
 function api.save(domain,info,payload,decode)
  local p,err=api.paths(domain,info);if not p then return false,err end
  if type(payload)~='string' or #payload<1 or #payload>domains[domain]then return false,'INVALID PAYLOAD LENGTH'end
  local data;data,err=decodePayload(decode,payload);if not data then return false,err end
  if not ioReady(true)then return false,'ATOMIC IO UNAVAILABLE'end
  local limit=domains[domain]+maxHeader
  local raw=wrap(domain,p.key,payload)
  local old,oldError,exists=readFile(p.canonical,limit)
  if oldError=='OPEN ERROR' or oldError=='READ ERROR'then return false,'PRIMARY READ ERROR'end
  -- The new payload was decoded above and encoded canonically. Exact equality
  -- therefore proves the existing file valid without repeating its checksum.
  if old==raw then remember(p,raw);return true,'UNCHANGED'end
  local oldValid
  if old then
   local record=verified[domain]
   if record.path==p.canonical and record.raw==old then
    oldValid=decodePayload(decode,string.sub(old,record.payloadStart))
   else oldValid=unwrap(domain,p.key,old,decode)end
  end
  local ok;ok,err=writeFile(p.canonical..'.tmp',raw,limit);if not ok then return false,err end
  if oldValid then
   if not remove(p.canonical..'.bak')then return false,'BACKUP DELETE FAILED'end
   if not move(p.canonical,p.canonical..'.bak')then return false,'BACKUP RENAME FAILED'end
  elseif exists then
   if not remove(p.canonical)then return false,'CORRUPT PRIMARY DELETE FAILED'end
  end
  if not move(p.canonical..'.tmp',p.canonical)then return false,'PROMOTION FAILED'end
  local actual=readFile(p.canonical,limit)
  -- The payload already passed its decoder; raw is its canonical envelope.
  -- Both temporary readback and promoted readback must equal those exact bytes,
  -- including owner, domain, length, checksum and payload. No validation is lost
  -- by avoiding a second decode/checksum of byte-identical known-valid data.
  if actual~=raw then return false,'FINAL VERIFY FAILED'end
  remember(p,raw)
  return true,'SAVED'
 end
 function api.importLegacy(domain,info,decode)
  local p,err=api.paths(domain,info);if not p then return nil,{state='IMPORT FAILED',error=err}end
  if not ioReady(true)then return nil,{state='IMPORT FAILED',error='ATOMIC IO UNAVAILABLE'}end
  local existing,meta=canonical(p,decode)
  if existing then return nil,{state='IMPORT FAILED',error='MODEL SETTINGS ALREADY EXIST',path=meta.path}end
  local data,oldMeta,raw=legacy(p,decode)
  if not data then return nil,{state='IMPORT FAILED',error=oldMeta.error or 'NO VALID LEGACY SETTINGS'}end
  local ok;ok,err=api.save(domain,info,raw,decode)
  if not ok then return nil,{state='IMPORT FAILED',error=err,legacyPath=oldMeta.legacyPath}end
  -- Return imported values only after the new owner-bound canonical file passes
  -- verified promotion/readback. Original display-name data remains untouched.
  return data,{state='IMPORTED',source=oldMeta.source,path=p.canonical,legacyPath=oldMeta.legacyPath,filename=p.filename}
 end
 return api
end
return M
