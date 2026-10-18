-- Native TBS wire fixtures from original VTXTBS bytecode, no hardware claims.
local M=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/vtx-native.lua'))()
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function equalBytes(actual,expected,why)
 check(type(actual)=='table' and #actual==#expected,why..' length')
 for i,v in ipairs(expected)do check(actual[i]==v,why..' byte'..i)end
end
local function frame(source,dbm,frequency,pit,flags)
 return {source,dbm,math.floor(frequency/256),frequency%256,flags or (pit and 1 or 0)}
end
local function make(extra)
 local pushes={};local options={hardwareId=1}
 for k,v in pairs(extra or {})do options[k]=v end
 local send=options.push
 options.push=function(kind,bytes)
  local copy={};for i,v in ipairs(bytes)do copy[i]=v end
  pushes[#pushes+1]={kind=kind,data=copy}
  if send then return send(kind,bytes)end
  return true
 end
 options.pop=function()error('native adapter must not own pop')end
 return M.new(options),pushes
end
local function live(client,source,dbm,frequency,pit,tick)
 tick=tick or 0;client:tick(tick,true,true,true)
 check(client:ingest(0x10,frame(source or 0xEC,dbm or 26,frequency or 5800,pit),tick)==true,'a valid native report is accepted')
 return client:snapshot()
end
local function failure(client,wanted,reason)
 local ok,err=client:applyVtx(wanted)
 check(ok==false and err==reason,'apply rejected as '..reason..', got '..tostring(err))
end

-- Exact eight manual maps and nominal labels, never inferred from a report.
local expected={
 {'Sixty9',{0,14,20,26,30},{0,25,100,400,1000}},
 {'Uni Pro32 HV',{0,14,20,26,30},{0,25,100,400,1000}},
 {'Uni Pro32 Nano',{0,14,20,26},{0,25,100,400}},
 {'Uni EVO',{0,14,20,26},{0,25,100,400}},
 {'Uni Pro',{0,14,23,27,29,30},{0,25,200,500,800,1000}},
 {'Uni Pro HV',{0,14,23,27,29},{0,25,200,500,800}},
 {'Uni Pro HV Race',{0,14,23},{0,25,200}},
 {'Uni Pro Nano',{0,14,17},{0,25,50}}
}
local names=M.hardwareList();check(names[0]~=nil and #names==8,'manual selector includes unknown plus exactly8 known hardware maps')
for id,map in ipairs(expected)do
 local c,pushes=make({hardwareId=id});local s=c:snapshot();local v=s.vtx
 check(v.hardwareId==id and v.configuredHardware==map[1] and names[id]==map[1],'manual hardware identity '..id)
 check(#v.powers==#map[2] and v.tablesReady,'manual map size '..id)
 for index,dbm in ipairs(map[2])do
  local p=v.powers[index]
  check(p.index==index and p.dbm==dbm and p.value==dbm and p.mw==map[3][index],'nominal dBm/mW map '..id..'/'..index)
 end
 check(#v.bands==6 and v.bands[6].letter=='L' and v.bands[6].frequencies[1]==5333,'default native presets includeL band')
 check(v.tableSource=='DEFAULT PRESETS / MANUAL HARDWARE','presets/manual hardware are not claimed device-discovered tables')
 for tick=0,200 do c:tick(tick,true,true,true)end
 check(#pushes==0,'configuration, idle ticks and map labels never send commands')
end
names[1]='MUTATED'
check(M.hardwareList()[1]=='Sixty9','a UI caller cannot mutate the module hardware names')
local unknown,unknownPushes=make({hardwareId=0})
local u=live(unknown,0xEC,26,5800,false)
check(u.vtx.hardwareId==0 and u.vtx.reported.power==nil and u.vtx.reported.powerMw==nil,'a native report never auto-detects hardware or invents mapped power')
check(u.vtx.reported.hardwareReported==false and u.vtx.reported.powerDbm==26,'raw reported dBm remains visible with honest hardware provenance')
check(unknown:setHardware(1)==true and u.vtx.reported.power==4 and u.vtx.reported.powerMw==400,'explicit hardware choice interprets existing reported power')
check(#unknownPushes==0,'choosing a manual power map does not transmit')
check(unknown:setHardware(9)==false and unknown:setHardware(-1)==false,'invalid manual hardware indices are rejected')
check(unknown:setHardware(0)==true and u.vtx.reported.power==nil,'removing manual map removes its derived power label')

-- Selected direct-VTX source EC supersedes receiver CE and remains sticky.
local preferred,preferencePushes=make()
local ps=live(preferred,0xCE,26,5800,false)
check(ps.vtx.reported.source==0xCE and ps.vtx.reported.sourceName=='RECEIVER','receiver-only native reports are useful')
preferred:tick(1,true,true,true)
check(preferred:ingest(0x10,frame(0xEC,20,5825,true,5),1)==true,'direct VTX report can replace receiver source')
check(ps.vtx.reported.source==0xEC and ps.vtx.reported.frequency==5825 and ps.vtx.reported.pit==true and ps.vtx.reported.flags==5,'big-endian MHz and only PIT bit0 are decoded')
local selected=ps.vtx.reported
local ignored,ignoredWhy=preferred:ingest(0x10,frame(0xCE,30,5905,false),1)
check(ignored==false and ignoredWhy=='LOWER PRIORITY SOURCE' and ps.vtx.reported==selected,'receiver report never overwrites direct VTX state')
preferred:tick(802,true,true,true)
check(not ps.ready and ps.vtx.status=='STATUS OLD','old preferred status is explicitly stale')
preferred:ingest(0x10,frame(0xCE,30,5905,false),802)
check(ps.vtx.reported==selected and ps.vtx.reportedAt==1,'lower-priority traffic cannot refresh stale selected-source age')
preferred:tick(803,true,false,true)
check(ps.vtx.reported==nil and ps.vtx.source==nil,'disconnect clears source ownership and live report')
live(preferred,0xCE,14,5658,false,804)
check(ps.vtx.reported.source==0xCE,'a new connection can use the receiver after prior VTX preference is cleared')
check(#preferencePushes==0,'passive native source selection never sends packets')

-- Malformed frames cannot replace current state or trigger implicit commands.
local invalid,invalidPushes=make();local inv=live(invalid)
local original=inv.vtx.reported;local reports=inv.responses
for _,f in ipairs({{}, {0xEC,26,22,168}, {0xEC,26,22,168,0,0}, {0xEC,'26',22,168,0}, {0xEC,26.5,22,168,0}, {0xEC,26,256,168,0}, {0xEC,26,22,168,-1},frame(0xEC,26,5299,false),frame(0xEC,26,5951,false)})do
 check(invalid:ingest(0x10,f,0)==false,'invalid/short/long/non-byte/out-of-range native report is rejected')
 check(inv.vtx.reported==original and inv.responses==reports,'malformed report leaves current truth intact')
end
check(invalid:ingest(0x7B,{1,2},0)==false and invalid:ingest(0x10,frame(0xEA,26,5800,false),0)==false,'unrelated kind/address never become VTX state')
check(invalid:ingest(0x10,frame(0xEC,26,5800,false),-1)==false,'old-clock frame is rejected')
check(#invalidPushes==0,'ingest never owns a telemetry request or write')
invalid:ingest(0x10,frame(0xEC,19,5800,false),0)
check(inv.vtx.reported.powerDbm==19 and inv.vtx.reported.power==nil and inv.vtx.reported.powerMw==nil,'unknown hardware power code remains raw19dBm, not fabricated0mW')

-- Explicit frequency-only command uses exact original native bytes and readback.
local frequency,frequencyPushes=make({hardwareId=0});local fs=live(frequency)
failure(frequency,{},'NO CHANGES')
check(frequency:applyVtx({frequency=5825})==true and #frequencyPushes==0,'an explicit valid apply queues, it does not write during UI dispatch')
frequency:tick(0,true,true,true)
check(#frequencyPushes==1 and frequencyPushes[1].kind==0x32,'one native command is pushed on scheduler tick')
equalBytes(frequencyPushes[1].data,{0xCE,0xEA,0x08,0x02,22,193},'frequency native wire')
check(fs.vtx.operation.state=='VERIFYING' and fs.vtx.reported.frequency==5800,'push acceptance is not an acknowledgement or optimistic state update')
frequency:tick(1,true,true,true)
frequency:ingest(0x10,frame(0xEC,26,5800,false),1)
check(fs.vtx.operation.state=='VERIFYING' and fs.vtx.operation.readbackMismatch,'wrong actual report cannot declare success')
frequency:tick(2,true,true,true)
frequency:ingest(0x10,frame(0xEC,26,5825,false),2)
check(fs.vtx.operation.state=='SUCCEEDED' and fs.vtx.operation.confirmation=='OBSERVED REPORT','a subsequent matching selected-source report confirms observed frequency')
check(fs.vtx.reported.frequency==5825 and #frequencyPushes==1,'reported truth changes only on actual report; no accepted-write retransmit')
for tick=3,200 do frequency:tick(tick,true,true,true)end
check(#frequencyPushes==1,'completed transaction never autonomously replays')

-- Two-field write is bounded to two packets and only final later reports confirm.
local combined,combinedPushes=make();local cs=live(combined)
check(combined:applyVtx({frequency=5810,power=3,pit=false})==true,'frequency+power transaction can be staged together')
combined:tick(0,true,true,true)
equalBytes(combinedPushes[1].data,{0xCE,0xEA,8,2,22,178},'combined frequency wire')
combined:tick(10,true,true,true);combined:ingest(0x10,frame(0xEC,20,5810,false),10)
check(cs.vtx.operation.state=='WRITING','a matching report before the final write cannot finish transaction')
combined:tick(24,true,true,true);check(#combinedPushes==1,'multiple packets obey configured minimum spacing')
combined:tick(25,true,true,true)
equalBytes(combinedPushes[2].data,{0xCE,0xEA,8,8,20},'combined power wire')
check(cs.vtx.operation.state=='VERIFYING','last write still requires a later report')
combined:tick(26,true,true,true);combined:ingest(0x10,frame(0xEC,20,5810,false),26)
check(cs.vtx.operation.state=='SUCCEEDED' and cs.vtx.reported.powerMw==100 and #combinedPushes==2,'full observed frequency/power/PIT result is verified')

-- Every manual map sends its actual dBm bytes, not a power index or mW value.
for id,map in ipairs(expected)do
 for index=2,#map[2]do
  local c,p=make({hardwareId=id});local s=live(c,0xEC,0,5800,true)
  check(c:applyVtx({power=index,pit=false})==true,'explicit power selection exits PIT for every hardware map')
  c:tick(0,true,true,true)
  equalBytes(p[1].data,{0xCE,0xEA,8,8,map[2][index]},'hardware power bytes '..id..'/'..index)
  check(s.vtx.operation.state=='VERIFYING','no fake power acknowledgement '..id..'/'..index)
  c:tick(1,true,true,true);c:ingest(0x10,frame(0xEC,map[2][index],5800,false),1)
  check(s.vtx.operation.state=='SUCCEEDED' and s.vtx.reported.power==index,'reported dBm confirms manual map selection '..id..'/'..index)
 end
end

-- PIT on and off work independently even when desired normal power is unchanged.
local pit,pitPushes=make();local pits=live(pit)
check(pit:applyVtx({pit=true})==true,'PIT on is an explicit action')
pit:tick(0,true,true,true)
equalBytes(pitPushes[1].data,{0xCE,0xEA,8,8,0},'PIT on native zero command')
pit:tick(1,true,true,true);pit:ingest(0x10,frame(0xEC,0,5800,true),1)
check(pits.vtx.operation.state=='SUCCEEDED' and pits.vtx.reported.pit,'PIT flag is confirmed by a subsequent actual report')
failure(pit,{pit=true,power=4},'NO CHANGES')
failure(pit,{pit=true,power=3},'EXIT PIT TO CHANGE POWER')
check(pit:applyVtx({pit=false})==true,'PIT off restores remembered valid pre-PIT power')
pit:tick(1,true,true,true)
equalBytes(pitPushes[2].data,{0xCE,0xEA,8,8,26},'PIT off resends unchanged selected normal power')
pit:tick(2,true,true,true);pit:ingest(0x10,frame(0xEC,0,5800,true),2)
check(pits.vtx.operation.state=='VERIFYING','PIT still active cannot masquerade as an applied off action')
pit:tick(3,true,true,true);pit:ingest(0x10,frame(0xEC,26,5800,false),3)
check(pits.vtx.operation.state=='SUCCEEDED' and not pits.vtx.reported.pit and pits.vtx.reported.power==4,'PIT off is confirmed with restored exact nonzero power')
local retained,retainedPushes=make();local rs=live(retained)
retained:applyVtx({pit=true});retained:tick(0,true,true,true);retained:tick(1,true,true,true)
retained:ingest(0x10,frame(0xEC,26,5800,true),1)
check(rs.vtx.operation.state=='SUCCEEDED','PIT flag is authoritative even if firmware retains its normal dBm field')
local selection,selectionPushes=make();live(selection)
selection:applyVtx({pit=true,power=4});selection:tick(0,true,true,true)
selection:tick(1,true,true,true);selection:ingest(0x10,frame(0xEC,30,5800,false),1)
selection:tick(2,true,true,true);selection:ingest(0x10,frame(0xEC,0,5800,true),2)
check(selection:applyVtx({pit=false})==true,'a pending PIT operation retains its selected restoration power')
selection:tick(2,true,true,true)
equalBytes(selectionPushes[2].data,{0xCE,0xEA,8,8,26},'intermediate non-PIT report does not replace explicit restoration selection')
local noRestore,noRestorePushes=make({hardwareId=0});live(noRestore,0xEC,0,5800,true)
failure(noRestore,{pit=false},'SELECT RESTORE POWER')
check(#noRestorePushes==0,'unknown manual hardware has no guessed PIT-off power')

-- Busy/error/timeout paths are bounded and never retransmit accepted writes.
local busy,busyPushes=make({push=function()return false end});local bs=live(busy)
busy:applyVtx({frequency=5825})
for tick=0,1000 do busy:tick(tick,true,true,true)end
check(#busyPushes==12 and bs.busy==12 and bs.requests==0,'busy pushes retry at25ticks only during300tick send deadline')
check(bs.vtx.operation.state=='FAILED' and bs.vtx.operation.error=='SEND TIMEOUT' and not bs.vtx.operation.uncertain,'unsent bounded timeout does not claim physical uncertainty')
local timeout,timeoutPushes=make({reportTimeout=100});local ts=live(timeout)
timeout:applyVtx({frequency=5825});timeout:tick(0,true,true,true)
for tick=1,500 do timeout:tick(tick,true,true,true)end
check(#timeoutPushes==1 and ts.vtx.operation.state=='FAILED' and ts.vtx.operation.error=='READBACK TIMEOUT','accepted command is not retried when reports never arrive')
check(ts.vtx.operation.uncertain and ts.vtx.reportedAt==nil,'failed sent transaction explicitly invalidates current control confidence')
local mismatch=make({reportTimeout=100});local ms=live(mismatch)
mismatch:applyVtx({frequency=5825});mismatch:tick(0,true,true,true)
mismatch:tick(1,true,true,true);mismatch:ingest(0x10,frame(0xEC,26,5800,false),1);mismatch:tick(100,true,true,true)
check(ms.vtx.operation.state=='FAILED' and ms.vtx.operation.error=='READBACK MISMATCH','wrong readback has a distinct final failure')
local late,latePushes=make({reportTimeout=100});local ls=live(late)
late:applyVtx({frequency=5825});late:tick(0,true,true,true)
late:ingest(0x10,frame(0xEC,26,5825,false),100)
check(ls.vtx.operation.state=='FAILED' and ls.vtx.operation.error=='READBACK TIMEOUT','a late matching report delivered before tick cannot revive an expired transaction')
check(ls.vtx.reported.frequency==5825 and #latePushes==1,'late actual state is still visible without pretending the transaction met its deadline')
local throwing,throwingPushes=make({push=function()error('transport failed')end});local th=live(throwing)
throwing:applyVtx({frequency=5825});throwing:tick(0,true,true,true)
check(th.vtx.operation.state=='FAILED' and th.vtx.operation.error:match('PUSH ERROR:') and #throwingPushes==1,'push exception is contained with no uncontrolled retry')

-- Arming/unknown/disconnect/stop cancel in-flight changes, retain no queued replay.
local guarded,guardPushes=make();local gs=live(guarded)
guarded:tick(1,true,true,false)
check(guarded:ingest(0x10,frame(0xEC,26,5800,false),1)==true and gs.ready,'passive status stays readable while armed')
failure(guarded,{frequency=5825},'ARMED / UNKNOWN')
guarded:tick(2,true,true,nil);failure(guarded,{frequency=5825},'ARMED / UNKNOWN')
guarded:tick(3,true,true,true);guarded:applyVtx({frequency=5825})
guarded:tick(4,true,true,false)
check(gs.vtx.operation.state=='CANCELLED' and not gs.vtx.operation.uncertain and #guardPushes==0,'arming before first write cancels without transmitting')
guarded:tick(5,true,true,true)
for tick=6,100 do guarded:tick(tick,true,true,true)end
check(#guardPushes==0,'returning disarmed never resumes a cancelled action')
local sent,sentPushes=make({reportTimeout=100});local ss=live(sent)
sent:applyVtx({frequency=5825});sent:tick(0,true,true,true);sent:tick(1,true,true,false)
check(ss.vtx.operation.state=='CANCELLED' and ss.vtx.operation.uncertain,'arming after accepted write keeps outcome explicitly uncertain')
sent:tick(2,true,true,true);sent:ingest(0x10,frame(0xEC,26,5825,false),2)
failure(sent,{frequency=5800},'WAIT FOR LINK TO SETTLE')
sent:tick(102,true,true,true);check(sent:applyVtx({frequency=5800})==true,'new explicit transaction is allowed only after bounded settle and fresh report')
check(sent:cancelVtx()==true and ss.vtx.operation.state=='CANCELLED','user cancellation removes a queued action')
sent:stop();check(not ss.active and ss.vtx.reported==nil and #sentPushes==1,'stop clears ownership and never sends a teardown setting change')
failure(sent,{frequency=5825},'NO CURRENT LINK')

-- Source promotion cancels target ownership instead of validating another source.
local promote,promotePushes=make();local pro=live(promote,0xCE)
promote:applyVtx({frequency=5825});promote:tick(0,true,true,true)
promote:tick(1,true,true,true);promote:ingest(0x10,frame(0xEC,26,5825,false),1)
check(pro.vtx.operation.state=='CANCELLED' and pro.vtx.operation.error=='VTX SOURCE CHANGED' and pro.vtx.operation.uncertain,'preferred-source change cannot acknowledge a different observed endpoint')
check(pro.vtx.reported.source==0xEC and #promotePushes==1,'preferred new report is visible without automatic resend')

-- Validation gates are checked before queueing any packet.
local validation,validationPushes=make();live(validation)
for _,case in ipairs({
 {false,'INVALID REQUEST'},{ {unsupported=1},'UNSUPPORTED FIELD'},{{frequency=false},'INVALID FREQUENCY'},{{frequency=5299},'INVALID FREQUENCY'},
 {{frequency=5951},'INVALID FREQUENCY'},{{frequency=5800.5},'INVALID FREQUENCY'},{{power=99},'POWER NOT AVAILABLE'},
 {{power=1,pit=false},'NONZERO POWER REQUIRED'},{{pit=1},'INVALID PIT'},{{band=1},'INVALID CHANNEL'},
 {{band=1,channel=9},'INVALID CHANNEL'},{{band=1,channel=1,frequency=5800},'CHANNEL FREQUENCY MISMATCH'}
})do failure(validation,case[1],case[2])end
check(#validationPushes==0,'bad settings/requests never enqueue or send')
check(validation:applyVtx({band=6,channel=1})==true,'explicitL-band preset resolves to its known frequency')
validation:tick(0,true,true,true)
equalBytes(validationPushes[1].data,{0xCE,0xEA,8,2,20,213},'L1 frequency5333 native wire')
failure(validation,{frequency=5800},'TRANSACTION ACTIVE')
check(validation:setHardware(2)==false,'manual hardware cannot change halfway through a transaction')
local stale=make();live(stale);stale:tick(801,true,true,true)
failure(stale,{frequency=5825},'VTX STATUS OLD')
local readonly=M.new({hardwareId=1});live(readonly)
failure(readonly,{frequency=5825},'TRANSPORT UNAVAILABLE')
local clock=make({reportTimeout=100});local clocks=live(clock,0xEC,26,5800,false,1000)
clock:applyVtx({frequency=5825});clock:tick(1000,true,true,true);clock:tick(0,true,true,true)
check(clocks.vtx.operation.state=='CANCELLED' and clocks.vtx.reported==nil,'clock rollback cancels writes and invalidates old status')
check(clock:ingest(0x10,frame(0xCE,14,5800,false),0)==true,'new-clock report can establish fresh status after reset')
failure(clock,{frequency=5825},'WAIT FOR LINK TO SETTLE')

print('vtx-native: '..checks..' checks passed')
