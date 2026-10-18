-- One owner of each EdgeTX telemetry queue. UI supplies current/disarmed guards.
-- MSP and native TBS video share a four-pop/one-push budget per callback.
local M={}
local function busy(op)return op and(op.state=='QUEUED'or op.state=='WRITING'or op.state=='SAVING'or op.state=='VERIFYING')end
function M.new(opts)
 opts=opts or {};local load=opts.load
 local c={state={status='NOT LOADED'},nativeState={status='OFF'},backend='FC MSP'}
 local family,transport,revision,adapter,client,native,now,budget,pushed,inbox
 local cacheFactory,cache,cacheEnabled,cacheActive,cacheUid,cacheHardware,cacheBandCount,cacheChannelCount,cachePowerCount
 local cacheRecord,cacheDisplay,cacheBands,cachePowers,cacheBypass,cacheInfoAt,infoEnabled,infoAt,cacheJob
 local function clearCacheJob()cacheJob=nil;c.cacheJob=nil end
 local function resetCache()
  clearCacheJob()
  cacheUid=nil;cacheHardware=nil;cacheBandCount=nil;cacheChannelCount=nil;cachePowerCount=nil
  cacheRecord=nil;cacheDisplay=nil;cacheBands=nil;cachePowers=nil;cacheInfoAt=nil
 end
 local function fresh(stamp)return type(stamp)=='number'and now>=stamp and now-stamp<=800 end
 local function matches(state,r)
  return state.uid==cacheUid and r.hardware==cacheHardware and r.bandCount==cacheBandCount and r.channelCount==cacheChannelCount and r.powerCount==cachePowerCount
 end
 local function queueCache(kind,state,r,v)
  cacheJob={kind=kind,client=client,uid=state.uid,metadata={hardware=r.hardware,bandCount=r.bandCount,channelCount=r.channelCount,powerCount=r.powerCount,tableAvailable=true}}
  if kind=='SAVE'then
   cacheJob.bands=v.bands;cacheJob.powers=v.powers
   cacheJob.tables={uid=state.uid,hardware=r.hardware,bandCount=r.bandCount,channelCount=r.channelCount,powerCount=r.powerCount,bands=v.bands,powers=v.powers}
  end
  c.cacheJob=kind
 end
 local function syncCache()
  if cacheJob or not cacheEnabled or not cacheActive or family~='BF'or not client then return end
  local state=client:snapshot();local v=state.vtx;local r=v and v.reported
  if not state.active or not state.uid or not r or not r.tableAvailable or not fresh(v.reportedAt)then return end
  local needsLoad=not matches(state,r)
  local needsSave=v.tablesReady and v.tablesFresh==true and(v.bands~=cacheBands or v.powers~=cachePowers)
  if not needsLoad and not needsSave then return end
  if not fresh(state.uidAt)then
   -- A slow link can finish88 after the optional UID has aged. Refresh once per
   -- identity window, rather than accepting old identity or retrying SD each frame.
   c.cacheStatus='WAITING FOR FRESH IDENTITY'
   if not cacheInfoAt or now<cacheInfoAt or now-cacheInfoAt>=800 then client:requestInfo(true);cacheInfoAt=now end
   return
  end
  if needsLoad then
   resetCache();cacheUid=state.uid;cacheHardware=r.hardware;cacheBandCount=r.bandCount;cacheChannelCount=r.channelCount;cachePowerCount=r.powerCount
   if not cacheBypass then
    queueCache('LOAD',state,r,v);return
   end
  end
  -- Imported or RAM tables remain unverified as a whole. Never rewrite them as
  -- live discovery merely because the backend permits a guarded selected write.
  if v.tablesReady and v.tablesFresh==true and(v.bands~=cacheBands or v.powers~=cachePowers)then
   cacheBands=v.bands;cachePowers=v.powers;cacheDisplay=nil
   queueCache('SAVE',state,r,v)
  end
 end
 local function runCacheJob(enabled,current,disarmed,videoEnabled)
  local job=cacheJob;if not job then return false end
  local state=client and client:snapshot();local v=state and state.vtx;local r=v and v.reported;local md=job.metadata
  if not enabled or not current or not disarmed or videoEnabled~=true or not cacheEnabled or not cacheActive or family~='BF'or c.backend~='FC MSP'
   or client~=job.client or not state or not state.active or state.uid~=job.uid or not r or not r.tableAvailable
   or r.hardware~=md.hardware or r.bandCount~=md.bandCount or r.channelCount~=md.channelCount or r.powerCount~=md.powerCount
   or not fresh(state.uidAt)or not fresh(v.reportedAt)then resetCache();return false end
  if job.kind=='SAVE'and(not v.tablesReady or v.tablesFresh~=true or v.bands~=job.bands or v.powers~=job.powers)then clearCacheJob();return false end
  -- Preparing the module's bounded lookup maps gets a separate cold callback;
  -- a maximum decode must never share its budget with module initialization.
  if not cache then
   local chunk=load and load('/SCRIPTS/TOOLS/AERODECK/vtx-cache.lua');cacheFactory=chunk and chunk()
   cache=cacheFactory and cacheFactory.new({io=opts.cacheIO,root=opts.cacheRoot,remove=opts.cacheRemove or del,rename=opts.cacheRename or rename})
   if not cache then c.cacheStatus='MODULE UNAVAILABLE';cacheEnabled=false;clearCacheJob()end
   return true
  end
  clearCacheJob()
  if job.kind=='LOAD'then
   cacheRecord,c.cacheStatus=cache:load(job.uid,md)
   if cacheRecord and not v.tablesReady then queueCache('IMPORT',state,r,v);cacheJob.record=cacheRecord end
  elseif job.kind=='IMPORT'then
   if not v.tablesReady then
    local ok,why;if client.useCachedTables then ok,why=client:useCachedTables(job.record)end
    if ok then c.cacheStatus='SD CACHE / VERIFIED ON APPLY'
    else
     cacheDisplay=setmetatable({bands=job.record.bands,powers=job.record.powers,cached=true,tablesReady=false,tablesFresh=false,tableSource='SD CACHE / DISPLAY ONLY'},{__index=v})
     c.cacheStatus=why or'CACHE DISPLAY ONLY / LIVE DISCOVERY'
    end
   end
  else
   local ok,why=cache:save(job.uid,job.tables);c.cacheStatus=ok and'LIVE TABLES SAVED'or why
   if ok then cacheBypass=false end
  end
  c.state=client:snapshot();return true
 end
 local function module(name)local chunk=load and load('/SCRIPTS/TOOLS/AERODECK/'..name..'.lua');return chunk and chunk()end
 local function push(kind,data)
  if pushed then return false end
  if type(opts.crsfPush)~='function'then return false end
  local ok=opts.crsfPush(kind,data);if ok==true then pushed=true end;return ok
 end
 local function rawPop()
  if budget<=0 or type(opts.crsfPop)~='function'then return nil end
  budget=budget-1;return opts.crsfPop()
 end
 local function dispatch(kind,data)
  if native then native:ingest(kind,data,now)end
 end
 local function pop()
  if #inbox>0 then local frame=table.remove(inbox,1);return frame[1],frame[2]end
  return rawPop()
 end
 function c:configure(profile,settings)
  if cacheJob then resetCache()end
  local nextFamily=profile and profile.fcType=='INAV'and'INAV'or'BF'
  local nextTransport=profile and profile.family=='FRSKY'and'S.PORT'or'CRSF'
  self.backend=settings.vtxBackend or 'FC MSP'
  cacheEnabled=settings.vtxCache==1
  cacheActive=cacheEnabled and settings.video==true and settings.vtxMode and settings.vtxMode>0 and self.backend=='FC MSP'
  infoEnabled=settings.info==true
  if not client or family~=nextFamily or transport~=nextTransport then
   self:stop();family=nextFamily;transport=nextTransport;inbox={}
   local af,mf=module('msp-adapters'),module('crsf-msp')
   if af and mf then
    local io
    if transport=='CRSF'then io={push=push,pop=pop,onFrame=dispatch}
    else io={push=opts.sportPush,pop=opts.sportPop}end
    adapter=af.new(transport,io)
    client=adapter and mf.new(adapter,{family=family})or nil
   end
   self.client=client;self.state=client and client:snapshot()or{status='TRANSPORT / MODULE UNAVAILABLE'}
  end
  if not native and transport=='CRSF'then local f=module('vtx-native');native=f and f.new({push=push})or nil end
  if native then native:setHardware(settings.vtxHardware or 0);self.nativeState=native:snapshot()end
  self.nativeClient=native
  if client then
   if client.setIntervals then client:setIntervals(settings.statusInterval or 3,settings.vtxPolling or 5)end
   if client.setVtxEnabled then client:setVtxEnabled(settings.vtxMode and settings.vtxMode>0 and settings.video and self.backend=='FC MSP')end
   if client.setGpsEnabled then client:setGpsEnabled(settings.gps)end
   if(infoEnabled or cacheActive)and client.requestInfo then client:requestInfo();infoAt=now end
  end
 end
 function c:tick(t,enabled,current,disarmed,videoEnabled,nativeGuard)
  now=t;budget=4;pushed=false;inbox=inbox or{}
  local nativeEnabled=transport=='CRSF'and self.backend=='TBS native'and videoEnabled==true
  -- Native video reports do not require a flight controller/FM sensor. The
  -- optional guard separates current RF reception from explicit arm knowledge;
  -- an omitted guard preserves the original five-argument call contract.
  local nativeCurrent,nativeDisarmed=current,disarmed
  if type(nativeGuard)=='table'then nativeCurrent=nativeGuard.current==true;nativeDisarmed=nativeGuard.disarmed==true end
  if runCacheJob(enabled,current,disarmed,videoEnabled)then return self.state end
  if native then self.nativeState=native:tick(now,nativeEnabled,nativeCurrent,nativeDisarmed)end
  if client then
   if enabled and current and disarmed and infoEnabled and client.requestInfo and(not infoAt or now<infoAt or now-infoAt>=300)then client:requestInfo();infoAt=now end
   self.state=client:tick(now,enabled,current,disarmed)
   if not self.state.active then resetCache();cacheBypass=false end
  end
  -- The MSP client forwards non-MSP frames while reading. When it is paused,
  -- collect native video without stealing an active MSP reply from next tick.
  if nativeEnabled then
   while budget>0 do
    local kind,data=rawPop();if kind==nil then break end
    if kind==0x7B then
     if self.state.active and #inbox<16 then inbox[#inbox+1]={kind,data}end
    else dispatch(kind,data)end
   end
  end
  if enabled and current and disarmed then syncCache()end
  return self.state
 end
 function c:videoClient()return self.backend=='TBS native'and native or client end
 function c:videoState()
  if self.backend=='TBS native'then return self.nativeState and self.nativeState.vtx or{}end
  local v=self.state and self.state.vtx
  if cacheActive and cacheDisplay and self.state.active and v and v.reported and matches(self.state,v.reported)and fresh(self.state.uidAt)and fresh(v.reportedAt)and not v.tablesReady then return cacheDisplay end
  return v or{}
 end
 function c:refreshVideo()
  if self.backend=='TBS native'then if native then native:stop();return true end;return false,'NATIVE CLIENT UNAVAILABLE'end
  if cacheEnabled and cache and self.state.uid then local ok,why=cache:remove(self.state.uid);if not ok then self.cacheStatus=why end end
  resetCache();cacheBypass=true
  if client and client.refreshVtx then return client:refreshVtx()end
  return false,'MSP CLIENT UNAVAILABLE'
 end
 function c:stop()
  if client then client:stop()end;if native then native:stop()end
  if adapter and adapter.reset then adapter.reset()end;inbox={};resetCache();cacheBypass=false;infoAt=nil
 end
 return c
end
return M
