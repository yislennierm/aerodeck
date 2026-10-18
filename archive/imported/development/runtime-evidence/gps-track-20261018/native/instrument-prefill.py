from pathlib import Path
import os,json,hashlib,math
H=Path(__file__).resolve().parent;case=os.environ['QA_CASE'];R=H/('runtime-'+case);q=R/'sd/SCRIPTS/TOOLS/QAENV.lua';env=q.read_text();old=" env.loadScript=function(path,mode)return native.loadScript(path,mode or't')end";assert old in env
points=','.join('{lat=%.9f,lon=%.9f}'%(25.99768+0.00045*math.sin(i*math.pi/75),-97.15735+0.00045*math.cos(i*math.pi/75))for i in range(180))
b=""" env.loadScript=function(path,mode)
  local chunk=native.loadScript(path,mode or't')
  if chunk and string.find(path,'AERODECK/session.lua',1,true)then
   return function(...)
    local factory=chunk(...);local new=factory.new
    factory.new=function(opts)
     local api=new(opts);local snapshot=api.snapshot;local fixturePoints={POINTS};local seeded=false;local last=-1
     api.snapshot=function()
      local state=snapshot()
      if not seeded and state.current and (HOME_REQUIREMENT)then state.track=fixturePoints;seeded=true;print('QA_GPS_TRACK_SEEDED|'..native.getTime()..'|180')end
      local count=#state.track
      if count~=last then last=count;print('QA_GPS_TRACK_STATE|'..native.getTime()..'|'..count..'|'..tostring(state.current and state.current.lat)..'|'..tostring(state.current and state.current.lon)..'|'..tostring(state.home~=nil))end
      return state
     end
     return api
    end
    return factory
   end
  end
  return chunk
 end""".replace('POINTS',points).replace('HOME_REQUIREMENT','state.home~=nil'if os.environ.get('QA_AUTO_HOME')=='1'else'true')
env=env.replace(old,b,1);q.write_text(env)
for f in R.rglob('*.luac'):f.unlink()
jp=H/(case+'-inputs.json');j=json.loads(jp.read_text());j['seededTrackFixture']={'points':180,'method':'Development session factory wrapper seeds the real owned session track once after validcurrent/home. Thereafter actual production session rotates/appends points and manual SetHome resets it normally.','mainUnmodified':True,'moduleFilesUnmodified':True,'scope':'Final exact-source seeded maximumhistory stress, supplementary to prior-source naturalgrowth.'};j['driverFiles']['QAENV.lua']=hashlib.sha256(q.read_bytes()).hexdigest();jp.write_text(json.dumps(j,indent=2)+'\n')
