from pathlib import Path
import os,json,hashlib
H=Path(__file__).resolve().parent;case=os.environ['QA_CASE'];R=H/('runtime-'+case);p=R/'sd/SCRIPTS/TOOLS/QAENV.lua';s=p.read_text();a=" env.loadScript=function(path,mode)return native.loadScript(path,mode or't')end"
b=""" env.loadScript=function(path,mode)
  local chunk=native.loadScript(path,mode or't')
  if chunk and string.find(path,'AERODECK/session.lua',1,true)then
   return function(...)
    local factory=chunk(...);local new=factory.new
    factory.new=function(opts)
     local api=new(opts);local snapshot=api.snapshot;local last=-1
     api.snapshot=function()
      local state=snapshot();local count=#state.track
      if count~=last then last=count;print('QA_GPS_TRACK_STATE|'..native.getTime()..'|'..count..'|'..tostring(state.current and state.current.lat)..'|'..tostring(state.current and state.current.lon)..'|'..tostring(state.home~=nil))end
      return state
     end
     return api
    end
    return factory
   end
  end
  return chunk
 end"""
assert a in s;s=s.replace(a,b,1);p.write_text(s);f=H/(case+'-inputs.json');j=json.loads(f.read_text());j['sessionSnapshotTimingWrapper']='Returns unmodified stable session snapshot; logs point count changes; no state or module file mutation';j['driverFiles']['QAENV.lua']=hashlib.sha256(p.read_bytes()).hexdigest();f.write_text(json.dumps(j,indent=2)+'\n')
