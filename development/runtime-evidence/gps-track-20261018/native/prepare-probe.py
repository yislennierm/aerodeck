from pathlib import Path
import shutil,hashlib,json
H=Path(__file__).resolve().parent;R=H/'runtime-probe'
if not R.exists():shutil.copytree(H/'runtime-baseline',R)
f=R/'sd/SCRIPTS/TOOLS/telem.lua';base=(H/'baseline-main.lua').read_text();s='local __navProbe={last=-1,n=0}\n'+base
s=s.replace("local function navigation(d)\n", "local function navigation(d)\n local __q0=getUsage();local __q1,__q2;__navProbe.n=__navProbe.n+1;if __navProbe.last~=#navTrack then __navProbe.last=#navTrack;print('QA_TRACK_COUNT|'..getTime()..'|'..#navTrack..'|'..zoom..'|'..__q0)end\n",1)
s=s.replace(" if origin then\n  local px,py", " __q1=getUsage()\n if origin then\n  local px,py",1)
s=s.replace(" local function row(y,label,value,col)\n", " __q2=getUsage()\n local function row(y,label,value,col)\n",1)
s=s.replace(" vlabel(341,222,21,'NORTH UP',p.muted)\nend", " vlabel(341,222,21,'NORTH UP',p.muted)\n if __navProbe.n%20==0 then print('QA_TRACK_COST|'..getTime()..'|'..#navTrack..'|'..zoom..'|'..__q0..'|'..__q1..'|'..__q2..'|'..getUsage())end\nend",1)
f.write_text(s)
for f in R.rglob('*.luac'):f.unlink()
# Keep probe short: count and last successful frame are the useful evidence.
s=(H/'capture-baseline.js').read_text().replace("'baseline-'","'probe-'").replace('i<12','i<6').replace('i===3||i===7','i===1||i===3');(H/'capture-probe.js').write_text(s)
(H/'probe-inputs.json').write_text(json.dumps({'baseMainSHA256':hashlib.sha256(base.encode()).hexdigest(),'instrumentedSHA256':hashlib.sha256(s.encode()).hexdigest(),'scope':'private timing/count probe only','hook':20000,'hookChanged':False},indent=2)+'\n')
