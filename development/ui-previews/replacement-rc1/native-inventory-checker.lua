-- Development-only: reads actual simulator physical APIs, without telemetry mocks.
local provider,done,steps,maxWork,sourceProbes,switchProbes
local function init()
 local factory=assert(loadScript('/SCRIPTS/TOOLS/AERODECK/input-indicators.lua'))()
 sourceProbes,switchProbes=0,0
 local function actualSources()
  local next,state,previous=sources()
  return function(...)sourceProbes=sourceProbes+1;return next(...)end,state,previous
 end
 local function actualSwitches()
  local next,state,previous=switches()
  return function(...)switchProbes=switchProbes+1;return next(...)end,state,previous
 end
 provider=factory.new({sources=actualSources,switches=actualSwitches,getFieldInfo=getFieldInfo,getSourceName=getSourceName,getSourceIndex=getSourceIndex,getSwitchInfo=getSwitchInfo,getSwitchIndex=getSwitchIndex,getSwitchName=getSwitchName,getSwitchValue=getSwitchValue,getLogicalSwitchValue=getLogicalSwitchValue,getSourceValue=getSourceValue,getValue=getValue,getUsage=getUsage},{deferRefresh=true})
 steps,maxWork=0,0
end
local function run()
 if not done then
  local ready,state=provider.refreshStep(8);steps=steps+1;maxWork=math.max(maxWork,state.work)
  if ready then
   local inv=provider.inventory()
   print('INVENTORY|READY|'..#inv.sources..'|'..#inv.switches..'|'..#inv.analogs..'|'..#inv.predicates..'|'..#inv.logical..'|'..tostring(inv.partial)..'|'..steps..'|'..maxWork..'|'..sourceProbes..'|'..switchProbes)
   for _,source in ipairs(inv.sources)do
    if source.field=='sa'or source.field=='thr'or source.field=='s1'then
     local raw,current=getSourceValue(source.index);local info=getSwitchInfo(source.index)
     print('PHYSICAL|'..source.field..'|'..source.index..'|'..source.label..'|'..source.kind..'|'..tostring(raw)..'|'..tostring(current)..'|'..tostring(info and info.type))
    end
   end
   local ids={};for _,id in ipairs(provider.choices('arm'))do ids[id]=true end
   print('LOGICAL64|'..tostring(ids['LS:L64'])..'|'..tostring(ids['LS:!L64']))
   provider.bind('arm','LS:L64');provider.sample();print('LOGICAL64_VALUE|'..tostring(provider.snapshot().roles.arm.value)..'|'..provider.snapshot().roles.arm.state)
   provider.bind('arm','LS:!L64');provider.bind('cut','PRED:sa:LOW');provider.bind('throttle','SRC:thr');provider.bind('limiter','SRC:s1');provider.sample()
   for _,role in ipairs({'arm','cut','throttle','limiter'})do local value=provider.snapshot().roles[role];print('PHYSICAL_ROLE|'..role..'|'..value.identity..'|'..value.state..'|'..tostring(value.value))end
   done=true;print('INVENTORY_DONE|PASS')
  end
 end
 lcd.clear();lcd.drawText(10,30,'NATIVE PHYSICAL INVENTORY',SMLSIZE)
 lcd.drawText(10,60,done and'READY / actual simulator input APIs'or'DISCOVERING / bounded8 work per callback',SMLSIZE)
 return 0
end
return{init=init,run=run}
