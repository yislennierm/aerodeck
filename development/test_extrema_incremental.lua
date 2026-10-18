local path=arg[1]or'sdcard/SCRIPTS/TOOLS/AERODECK/native-extrema.lua'
local M=assert(loadfile(path))()
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function near(a,b,why)check(type(a)=='number'and math.abs(a-b)<.0001,why)end
local values,received,reads,normalizations={},{},0,0
local function read(id)reads=reads+1;local v=values[id];if v then return v[1],v[2],v[3]end end
local function normalize(field,raw,unit)normalizations=normalizations+1;return unit=='NEG'and-raw or raw*.1,nil,'NORMALIZED '..tostring(unit)end
local n=M.new({getSourceValue=read,normalize=normalize,received=function(id)return received[id]end})
local fields={}
for i=1,27 do local id=100+i*3;fields[i]={key='field'..i,id=id,name='S'..i,unit=i==1 and'NEG'or'A',invertExtrema=i==1};values[id+1]={i,true,true};values[id+2]={i+100,true,false}end
local s=n.sample(fields,'MIN');local record=s.records.field1;local records,order=s.records,s.order
near(record.value,-101,'inverted physical MIN uses source MAX')
local old={};for key,r in pairs(records)do old[key]=r.value end
local originalCount=reads;n.begin(fields,'MAX')
check(reads==originalCount and s.pending and s.mode=='MIN'and s.targetMode=='MAX','begin captures descriptors without native reads or claiming a completed mode')
-- Caller-owned descriptors are captured, not retained as mutable aliases.
fields[1].id=999;fields[1].unit='CHANGED'
local completed=0
while s.pending do
 local before,beforeNorm=reads,normalizations
 local same,done,processed=n.step(4);completed=completed+1
 check(same==s and reads-before<=4 and normalizations-beforeNorm<=4 and processed<=4,'every step has at most four read/normalize operations')
 if not done then
  check(s.mode=='MIN'and s.records==records and s.order==order,'published identities/mode remain atomic while work is incomplete')
  for key,value in pairs(old)do check(s.records[key].value==value,'no partial new extrema leak before commit')end
 end
end
check(completed==7 and reads-originalCount==27,'all27fields complete over seven bounded callbacks')
check(s.mode=='MAX'and not s.pending and s.targetMode==nil and s.records==records and s.order==order and s.records.field1==record,'completion atomically preserves published snapshot/order/record identities')
check(record.id==103 and record.unit=='NEG'and record.nativeId==104 and record.nativeMode=='MIN','mid-cycle descriptor mutation cannot alter captured source/normalization ownership')
near(record.value,-1,'inverted MAX preserves exact captured normalization')
-- A new cycle sees changed identity and denies inherited receipt for old data.
values[1000]={0,false,false};n.begin(fields,'MIN');while n.snapshot().pending do n.step()end
check(record.id==999 and record.state=='NOT RECEIVED'and record.value==nil,'changed descriptor cannot inherit receipt or fabricated zero')
-- Cancelled private receipt cannot mutate published records or survive reset.
local last=s.records.field2.value;n.begin(fields,'MAX');n.step(4)
check(s.records.field2.value==last,'private work does not mutate a held published record')
n.cancel();local before=reads;local same,done,processed=n.step()
check(same==s and done and processed==0 and reads==before and s.records.field2.value==last,'cancel stops all native reads without replacing the last completed mode')
n.begin(fields,'MAX');n.step(4);n.resetBindings();before=reads;n.step()
check(not s.pending and reads==before and record.state=='NOT RECEIVED'and record.value==nil,'binding reset cancels pending work and clears receipt in stable records')
-- Known receipt permits honestly historical zero; fresh alone does not.
local zero={{key='zero',id=500,unit='A'}};values[501]={0,false,true}
n.begin(zero,'MIN');n.step();check(s.records.zero.state=='NOT RECEIVED'and s.records.zero.value==nil,'third native flag is not receipt')
received[500]=true;n.begin(zero,'MIN');n.step()
check(s.records.zero.value==0 and s.records.zero.state=='HISTORICAL'and not s.records.zero.current and not s.records.zero.fresh,'known receipt allows historical numeric zero without live claims')
values[501]={0,true,true};n.begin(zero,'MIN');n.step();check(s.records.zero.value==0 and s.records.zero.state=='CURRENT'and s.records.zero.fresh,'real current zero remains current')
-- Invalid limits cannot drain or advance a pending transaction.
n.begin(zero,'MAX');before=reads
for _,limit in ipairs({0,-1,.5,math.huge,0/0,'4'})do local _,ready,count,err=n.step(limit);check(not ready and count==0 and err=='INVALID STEP LIMIT'and reads==before and s.completed==0,'invalid limit performs zero reads')end
n.step(1000);check(not s.pending,'large requested work limit remains bounded64')
-- Removed fields and invalid input commit cleanly; old bindings do not grow.
local many={};for i=1,70 do many[i]={key=i,id=1000+i*3,unit='A'};values[1001+i*3]={i,true,true}end
n.begin(many,'MIN');local steps=0;before=reads
while s.pending do local oldReads=reads;local _,_,count=n.step(4);check(reads-oldReads<=4 and count<=4,'max64batch stays bounded at each step');steps=steps+1 end
check(steps==16 and s.count==64 and #s.order==64 and s.error=='TOO MANY FIELDS'and reads-before==64,'native64sensor bound preserves supported values and explicit overflow error')
check(s.records.zero==nil and s.records.field1==nil,'removed published records do not accumulate')
n.begin(nil,'MIN');before=reads;n.step();check(reads==before and s.count==0 and next(s.records)==nil and s.error=='INVALID FIELDS','invalid fields clear atomically without reads')
-- Stable records across warm incremental samples and mode changes.
n.sample(zero,'MIN');local held=s.records.zero
for i=1,100 do n.begin(zero,i%2==0 and'MIN'or'MAX');n.step(1);check(s.records.zero==held and s.records==records and s.order==order,'warm incremental outputs retain identity')end
local meta=debug.getmetatable('');debug.setmetatable('',nil)
local ok,err=pcall(function()n.begin(zero,'MIN');n.step(4)end);debug.setmetatable('',meta)
check(ok,'stripped native string library: '..tostring(err))
print('PASS: '..checks..' incremental native-extrema bounded work, atomic publication, receipt, inverse provenance, cancellation and stable identities')
