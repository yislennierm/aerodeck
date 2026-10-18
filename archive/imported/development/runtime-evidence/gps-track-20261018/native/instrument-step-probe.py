from pathlib import Path
import os,json,hashlib,math
H=Path(__file__).resolve().parent;case=os.environ['QA_CASE'];R=H/('runtime-'+case);f=R/'sd/SCRIPTS/TOOLS/telem.lua';s=f.read_text();assert 'local function navAction(action)'in s
addition="""
do
 local original=inputRuntime.stepNavPlot
 local calls,lastPaint=0,-100
 function inputRuntime.stepNavPlot(now)
  local before=getUsage();local state,geometry,processed=original(now);local after=getUsage();calls=calls+1
  if calls<=32 or calls%10==0 then print('QA_PLOT_STEP|'..now..'|'..#navTrack..'|'..zoom..'|'..before..'|'..after..'|'..tostring(geometry)..'|'..tostring(processed)..'|'..tostring(state.pending)..'|'..tostring(state.completed)..'|'..tostring(state.total)..'|'..tostring(state.frame and state.frame.count)..'|'..tostring(state.frame and state.frame.zoom)..'|'..tostring(state.error))end
  return state,geometry,processed
 end
 function inputRuntime._qaPlotPaint()
  local now=getTime();if now-lastPaint>=100 then lastPaint=now;local state=navPlot.snapshot();print('QA_PLOT_PAINT|'..now..'|'..#navTrack..'|'..zoom..'|'..getUsage()..'|'..tostring(state.pending)..'|'..tostring(state.completed)..'|'..tostring(state.total)..'|'..tostring(state.frame and state.frame.count)..'|'..tostring(state.frame and state.frame.zoom))end
 end
end
"""
s=s.replace('local function navAction(action)',addition+'\nlocal function navAction(action)',1)
s=s.replace('local function navigation(d)\n','local function navigation(d)\n inputRuntime._qaPlotPaint()\n',1);f.write_text(s)
if os.environ.get('QA_PREFILL')=='180':
 q=R/'sd/SCRIPTS/TOOLS/QAENV.lua';env=q.read_text();old=" env.loadScript=function(path,mode)return native.loadScript(path,mode or't')end";assert old in env
 points=','.join('{lat=%.9f,lon=%.9f}'%(25.99768+0.00045*math.sin(i*math.pi/75),-97.15735+0.00045*math.cos(i*math.pi/75))for i in range(180))
 replacement=""" env.loadScript=function(path,mode)
  local chunk=native.loadScript(path,mode or't')
  if chunk and string.find(path,'AERODECK/session.lua',1,true)then
   return function(...)
    local factory=chunk(...);local new=factory.new
    factory.new=function(opts)
     local api=new(opts);local snapshot=api.snapshot;local fixturePoints={POINTS}
     api.snapshot=function()local state=snapshot();state.track=fixturePoints;return state end
     return api
    end
    return factory
   end
  end
  return chunk
 end""".replace('POINTS',points)
 env=env.replace(old,replacement,1);q.write_text(env)
for q in R.rglob('*.luac'):q.unlink()
jp=H/(case+'-inputs.json');j=json.loads(jp.read_text());j['costProbe']={'sourceInstrumented':True,'sourceSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'prefilledTrackPoints':180 if os.environ.get('QA_PREFILL')=='180'else 0,'scope':'Supplementary native cost/progress probe; production frame acceptance requires uninstrumented source. Session wrapper exposes a stable synthetic 180-point snapshot when prefilled, without mutating module source.','logEvery':'First32step calls then every10; paint summary once per100ticks.'};j['productionMainUnmodified']=False;j['driverFiles']['QAENV.lua']=hashlib.sha256((R/'sd/SCRIPTS/TOOLS/QAENV.lua').read_bytes()).hexdigest();jp.write_text(json.dumps(j,indent=2)+'\n')
print('probe prepared',case)
