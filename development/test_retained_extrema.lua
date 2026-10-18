-- Real retained app, native-extrema module, protocol readers and UI routes.
-- Host clocks/telemetry are synthetic; native callback budget is separate QA.
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function near(v,w,why)check(type(v)=='number'and math.abs(v-w)<.0001,why..': '..tostring(v))end
loadstring=loadstring or load;unpack=unpack or table.unpack
local modulePath='sdcard/SCRIPTS/TOOLS/AERODECK/native-extrema.lua'
local realLoad=loadfile;local factory=assert(realLoad(modulePath))()
local trace={reads=0,begins=0,steps=0,cancels=0,commits=0,samples=0,records=nil,order=nil}
local function frozen(view)
 local r={mode=view.mode,count=view.count,records={}}
 for key,row in pairs(view.records)do r.records[key]={value=row.value,raw=row.rawValue,state=row.state,mode=row.mode,nativeId=row.nativeId}end
 return r
end
local function equalPublished(view,old)
 check(view.mode==old.mode and view.count==old.count,'incomplete extrema work leaves published mode/count atomic')
 for key,row in pairs(old.records)do local now=view.records[key]
  check(now and now.value==row.value and now.rawValue==row.raw and now.state==row.state and now.mode==row.mode and now.nativeId==row.nativeId,'incomplete work cannot mutate published record '..tostring(key))
 end
 for key in pairs(view.records)do check(old.records[key]~=nil,'incomplete work cannot add a published binding')end
end
local wrapped={new=function(opts)
 local read=opts.getSourceValue
 opts.getSourceValue=function(id)trace.reads=trace.reads+1;return read(id)end
 local n=factory.new(opts);trace.reader=n
 local begin,step,cancel,sample=n.begin,n.step,n.cancel,n.sample
 n.begin=function(fields,mode)trace.begins=trace.begins+1;return begin(fields,mode)end
 n.cancel=function()trace.cancels=trace.cancels+1;return cancel()end
 n.sample=function(...)trace.samples=trace.samples+1;return sample(...)end
 n.step=function(limit)
  trace.steps=trace.steps+1;local before=trace.reads;local old=frozen(n.snapshot());local wasPending=n.snapshot().pending
  local view,done,count,err=step(limit)
  check(trace.reads-before<=4 and count<=4,'actual retained service reads at most four native extrema per callback')
  if not done then equalPublished(view,old)elseif wasPending then trace.commits=trace.commits+1 end
  if trace.records then check(view.records==trace.records and view.order==trace.order,'published container identities remain stable')else trace.records=view.records;trace.order=view.order end
  return view,done,count,err
 end
 return n
end}
loadfile=function(path,...)if path==modulePath then return function()return wrapped end end;return realLoad(path,...)end
local hostOpen=io.open
if arg[1]then io.open=function(path,...)return hostOpen(path=='sdcard/SCRIPTS/TOOLS/telem.lua'and arg[1]or path,...)end end
local adapter=assert(realLoad('development/test_ui_navigation.lua'))('adapter');loadfile=realLoad;io.open=hostOpen
local E=adapter.events
local extrema={RxBt={min=20.4,max=25.2},Curr={min=.5,max=42},Capa={min=0,max=1234},RQly={min=65,max=100},
 ['1RSS']={min=-100,max=-45},RSNR={min=-2,max=10},Sats={min=8,max=17},GSpd={min=0,max=67},GAlt={min=-4,max=130},
 Hdg={min=15,max=350},Ptch={min=-.3,max=.2},Roll={min=-.25,max=.75}}
getUsage=nil
local a=adapter.make({settings='ADCFG1\nrcProtocol=ELRS / CRSF\nfcType=Betaflight\nmspMode=0\nvtxMode=0\n',extrema=extrema})
local now=getTime();getTime=function()return now end
a.setRetained(true);a.reinit()
local function background(ticks)now=now+(ticks or 4);a.background(1)end
local startup=0;while a.inputs.startup do background();startup=startup+1;check(startup<250,'retained startup progresses')end
background()
local function view()return trace.reader and trace.reader.snapshot()end
local function step(event,touch,ticks)
 now=now+(ticks or 4);local before=trace.reads;local ret=a.send(event or 0,touch)
 check(ret==0,'real app remains active');check(trace.reads-before<=4,'complete retained callback performs at most four extrema reads')
 check(#a.commands()>0,'every retained callback paints a real frame')
 return ret
end
local function tapMode()step(E.EVT_TOUCH_TAP,{x=70,y=45})end
local function waitCommit(minimum)
 local start=trace.commits
 for i=1,40 do step();if trace.commits>=start+(minimum or 1)then return end end
 error('ongoing extrema failed to publish within forty25Hz callbacks')
end
local writes=a.writes();a.arrange(5)
check(a.visible('TELEM / LIVE'),'real Data route starts on current values')
tapMode();check(a.visible('PREPARING NATIVE MIN'),'first native request prepares bindings separately')
waitCommit()
check(view().mode=='MIN'and a.visible('NATIVE MIN')and view().records.a,'real mode control displays a completed native minimum view')
check(trace.samples==0,'retained drawing never calls synchronous all-field sampling')
local pitch=view().records.pitch;local roll=view().records.roll;local current=view().records.a
near(pitch.rawValue,.2,'physical pitch MIN uses actual native raw MAX')
near(pitch.value,-.2*180/math.pi,'native physical pitch minimum retains verified source sign normalization')
near(roll.rawValue,-.25,'native raw Roll remains unflipped')
near(roll.value,-.25*180/math.pi,'native Roll minimum is physically normalized without display inversion')
near(current.value,.5,'fractional current minimum is not fabricated zero')
check(current.state=='CURRENT'and current.origin=='NATIVE','native currentness and historical origin are explicit')
local heldCurrent=current;local oldCommits=trace.commits;extrema.Curr.min=1.25
waitCommit();near(view().records.a.value,1.25,'next bounded cycle publishes changed native minima')
check(view().records.a==heldCurrent and trace.commits>oldCommits,'repeated minima keep identity and remain live rather than frozen')
-- Switch modes during incomplete work. Old MIN cannot be presented as MAX.
while not view().pending do step()end
local begins=trace.begins;tapMode();check(trace.begins>begins,'mode change starts a new private cycle')
check(not a.visible('NATIVE MAX'),'unfinished MAX never relabels completed MIN values')
waitCommit();check(view().mode=='MAX'and a.visible('NATIVE MAX'),'complete MAX atomically replaces MIN')
near(view().records.pitch.rawValue,-.3,'physical pitch MAX uses actual native raw MIN')
near(view().records.pitch.value,.3*180/math.pi,'physical MAX retains pitch convention')
near(view().records.roll.rawValue,.75,'raw Roll MAX is not inverted')
near(view().records.a.value,42,'real current maximum reaches actual UI data')
-- A visible LIVE mode cancels a pending native job immediately.
while not view().pending do step()end
local cancels=trace.cancels;tapMode();check(a.visible('TELEM / LIVE')and not view().pending and trace.cancels>cancels,'LIVE cancels pending historical acquisition')
local idleReads=trace.reads;for i=1,12 do step()end
check(trace.reads==idleReads,'current-data rendering does not drain native extrema')
-- Leaving a historical page cannot resume an old partial acquisition later.
tapMode();while not view().pending do step()end
cancels=trace.cancels;a.arrange(1);check(not view().pending and trace.cancels>cancels,'leaving Data cancels a pending batch')
idleReads=trace.reads;for i=1,20 do step()end;check(trace.reads==idleReads,'other pages perform no extrema acquisition')
now=now+250;a.arrange(5);begins=trace.begins;waitCommit();check(trace.begins>=begins,'reentering historical view reacquires a complete bounded cycle')
-- Over-age pending work is restarted, never completed with pre-pause values.
while not view().pending do step()end
local old=view().records.a.value;extrema.Curr.min=2.5;begins=trace.begins
step(0,nil,201);check(trace.begins>begins,'older than two seconds pending work restarts before continuing')
waitCommit();near(view().records.a.value,2.5,'only replacement age-bounded native data publish')
while not view().pending do step()end
begins=trace.begins;now=now-100;step()
check(trace.begins>begins,'clock rollback restarts pending native work instead of completing an old time window')
waitCommit()
-- Explicit refresh changes source bindings without any persistence writes.
while not view().pending do step()end
a.arrange(3);a.setSensor('Curr',nil,false,false);a.addSensor('Curr',.7,0,true)
step(E.EVT_TOUCH_TAP,{x=230,y=232});check(a.visible('SENSOR BINDINGS REFRESHED'),'real refresh action rebuilds bindings')
begins=trace.begins;a.arrange(5);waitCommit()
check(trace.begins>begins and view().records.a.id==1045,'new qualified source ID cannot reuse the removed sensor binding')
check(a.writes()==writes,'native histories, mode changes, page changes and explicit refresh never write SD')
-- Native measured budgets reserve more margin for begin/final commits while
-- ordinary middle batches may use their smaller measured allowance.
local usage=15;getUsage=function()return usage end
begins=trace.begins;local budgetReads=trace.reads;tapMode()
check(trace.begins==begins and trace.reads==budgetReads,'new-mode begin is blocked at15 allowance points')
usage=18;step();check(trace.begins==begins and trace.reads==budgetReads,'new-mode begin remains blocked at18 points')
usage=10;step();check(trace.begins==begins+1 and view().pending and view().completed==4,'begin is allowed at its exact10point boundary')
check(view().completed+4<view().total,'fixture has a genuine ordinary middle batch')
usage=19;local completed=view().completed;step();check(view().completed==completed,'middle batch is blocked above18points')
usage=15;step();check(view().completed==completed+4,'middle batch advances at15points with at most four native reads')
usage=0;while view().pending do step()end
-- A second independently started cycle verifies the exact18point middle bound.
usage=0;step(0,nil,20);check(view().pending and view().completed==4,'next native cycle starts with its first bounded batch')
usage=18;completed=view().completed;step();check(view().completed==completed+4,'ordinary middle batch advances at the exact18point boundary')
usage=0;while view().pending and view().completed+4<view().total do step()end
check(view().pending,'fixture reaches an actual final commit batch')
for _,budget in ipairs({11,15,18})do
 usage=budget;completed=view().completed;budgetReads=trace.reads;step()
 check(view().pending and view().completed==completed and trace.reads==budgetReads,'final commit is blocked above10points at'..budget)
end
usage=10;oldCommits=trace.commits;step();check(not view().pending and trace.commits==oldCommits+1,'final batch and atomic commit are allowed at exactly10points')
usage=0;step(0,nil,20);check(view().pending,'age-budget fixture starts a real pending cycle')
usage=15;begins=trace.begins;completed=view().completed;budgetReads=trace.reads;step(0,nil,201)
check(trace.begins==begins and view().completed==completed and trace.reads==budgetReads,'over-age restart uses the stricter10point begin margin')
usage=10;step();check(trace.begins==begins+1 and view().completed==4,'over-age job restarts at exactly10points')
usage=18;begins=trace.begins;completed=view().completed;now=now-100;step()
check(trace.begins==begins and view().completed==completed,'clock-rollback restart also keeps the stricter begin margin')
usage=10;step();check(trace.begins==begins+1 and view().completed==4,'clock rollback can restart safely at10points')
usage=0;while view().pending do step()end
getUsage=nil
-- Return through the real control to MIN for the configuration test below.
tapMode();tapMode();waitCommit()
-- An intentional settings save is separate from history reads. Revision changes
-- must clear receipt/normalizers and remove disabled native fields thereafter.
while not view().pending do step()end
check(a.config.openSection(1,'current'),'actual current source setting is reachable')
a.config.input(E.EVT_VIRTUAL_ENTER);a.config.input(E.EVT_VIRTUAL_NEXT);a.config.input(E.EVT_VIRTUAL_ENTER)
check(a.config.save()and a.config.get('current')=='None','explicit source disable uses the actual transactional setting save')
local userWrites=a.writes();check(userWrites>writes,'only explicit user save owns these persistence writes')
begins=trace.begins;waitCommit();check(trace.begins>begins and view().records.a==nil,'configuration revision removes disabled native current and old receipt')
for i=1,60 do step()end
check(a.writes()==userWrites and trace.samples==0,'ongoing refreshed extrema never save or switch to synchronous acquisition')
print('PASS: '..checks..' actual retained extrema scheduling, atomic views, currentness, pitch/roll provenance, cancellation, age/revision/source changes and no background writes')
