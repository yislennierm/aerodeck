-- Actual quick-pack UI; measured native17/12px fonts and metadata only. No SD,
-- telemetry, model, output or fake capacity/battery-state helpers are available.
local M=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/quick-pack.lua'))()
EVT_VIRTUAL_EXIT=1;EVT_VIRTUAL_NEXT=2;EVT_VIRTUAL_PREV=3;EVT_VIRTUAL_ENTER=4;EVT_TOUCH_TAP=5;EVT_VIRTUAL_NEXT_PAGE=6;EVT_VIRTUAL_PREV_PAGE=7
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function rig()
 local r={cfg={pack=3},calls={},draws={},fault=nil,ink=0}
 for i=1,5 do r.cfg['chemistry'..i]=i%2+1;r.cfg['cells'..i]=i+2;r.cfg['capacity'..i]=i*1500 end
 r.cfg.chemistry2=0;r.cfg.capacity4=0;r.cfg.cells5=99;r.cfg.capacity5=100000
 local lcd={}
 function lcd.sizeText(s,font)
  local width=0;for i=1,#s do local c=string.sub(s,i,i);width=width+(c=='W'and 10 or c=='I'and 3 or c==' 'and 4 or string.find(c,'%d')and 8 or 7)end
  return font==128 and width*.75 or width,font==128 and 12 or 17
 end
 function lcd.setColor(_,color)r.ink=color end
 function lcd.drawFilledRectangle(x,y,w,h)r.draws[#r.draws+1]={kind='rect',x=x,y=y,w=w,h=h,color=r.ink}end
 function lcd.drawText(x,y,text,flags)r.draws[#r.draws+1]={kind='text',x=x,y=y,text=text,font=flags%1024,color=r.ink}end
 r.options={lcd=lcd,palette=function()return {black=1,tape=2,white=3,muted=4,cyan=5,green=6,orange=7}end,fonts={small=0,tiny=128},colorFlag=4096,
  configget=function(key)if r.fault=='config'then error('unavailable config')end;return r.cfg[key]end,
  selectPack=function(index)
   r.calls[#r.calls+1]=index
   if r.fault=='throw'then error('native SD error')end
   if r.fault=='nil'then return nil end
   if r.fault=='draft'then return false,'SAVE OR REVERT EXISTING DRAFT'end
   r.cfg.pack=index;return true
  end}
 r.ui=assert(M.new(r.options));r.lcd=lcd
 function r.draw()r.draws={};r.ui.draw();return r.draws end
 function r.has(text)for _,c in ipairs(r.draws)do if c.kind=='text'and string.find(c.text,text,1,true)then return true end end;return false end
 return r
end
local r=rig();local u=r.ui;local s=u.snapshot();local output=s.rows
check(not u.active() and u.input(EVT_VIRTUAL_ENTER)==false,'closed modal ignores input and never applies a pending pack')
check(u.open() and u.active() and u.snapshot()==s and s.rows==output and s.current==3 and s.pending==3 and s.focusName=='packRow3','open snapshots actual current profile and focuses its enabled row')
check(#s.rows==6 and s.rows[1].id==0 and s.rows[6].capacity==100000 and s.rows[6].cells==99,'Auto plus all five actual profiles retain real chemistry/cells/capacity metadata')
check(not u.enabled('packRow2') and not u.enabled('packRow4') and u.enabled('packRow5'),'OFF and malformed profiles are disabled rather than silently repaired')
check(#r.calls==0,'opening and inspecting profiles cannot save or reset battery state')
u.move(1);check(s.focusName=='packRow5','rotary skips OFF/invalid profile rows')
u.move(-1);check(s.focusName=='packRow3','reverse rotary also skips disabled rows')
local handled,status=u.input(EVT_VIRTUAL_ENTER)
check(handled and status=='SELECTED' and s.pending==3 and s.focusName=='packUse' and #r.calls==0,'ENTER selects a pending row then focuses separate USE PACK without saving')
handled,status=u.input(EVT_VIRTUAL_ENTER)
check(handled and status=='APPLIED' and not u.active() and #r.calls==1 and r.calls[1]==3,'only explicit USE activation calls pack persistence and closes after confirmed success')
u.open();u.action('packRow1')
check(s.pending==1 and s.current==3 and r.cfg.pack==3 and #r.calls==1,'a different pending profile does not modify saved active pack')
handled,status=u.input(EVT_VIRTUAL_EXIT)
check(handled and status=='CANCEL' and not u.active() and r.cfg.pack==3 and #r.calls==1,'RTN discards pending choice without save/draft changes')
u.open();check(s.pending==3 and s.focusName=='packRow3','reopen starts from current config instead of a cancelled pending choice')
u.action('packRow5');check(u.action('packEdit')=='EDIT' and not u.active() and #r.calls==1,'EDIT PACKS closes with explicit parent status and never applies a proposal')
u.open();u.action('packRow1');u.stop()
check(not u.active() and #r.calls==1 and r.cfg.pack==3,'lifecycle cancellation performs no writes')
u.open();u.action('packRow1');local before={};for k,v in pairs(r.cfg)do before[k]=v end
check(u.action('packUse')=='APPLIED' and r.cfg.pack==1,'explicit new pack selection applies after positive save result')
for k,v in pairs(before)do if k~='pack'then check(r.cfg[k]==v,'pack proposal never mutates other setting '..k)end end

-- A disabled saved pack is honest: no silent auto-application; focus offers a
-- valid escape while retaining actual saved current metadata until explicit Use.
r.cfg.pack=2;u.open()
check(s.current==2 and s.pending==0 and s.focusName=='packRow0' and s.error~=nil and r.cfg.pack==2,'disabled current pack is explicit and not silently replaced')
local count=#r.calls;check(u.action('packRow2')=='PENDING' and #r.calls==count and s.pending==0,'disabled row action cannot become pending or invoke save')
u.action('packRow0');check(u.action('packUse')=='APPLIED' and r.cfg.pack==0,'Auto/manual selection is an explicit persisted pack0 proposal only')
for _,fault in ipairs({'draft','throw','nil'})do
 r=rig();u=r.ui;s=u.snapshot();r.fault=fault;u.open();u.action('packRow1')
 local result=u.action('packUse')
 check(result=='ERROR' and u.active() and s.status=='ERROR' and s.error and s.current==3 and r.cfg.pack==3,'save rejection/exception stays open with old saved pack: '..fault)
 r.draw();check(r.has('SAVE')or r.has('error')or r.has('REJECTED'),'failed save remains visible in native UI: '..fault)
 r.fault=nil;check(u.action('packUse')=='APPLIED' and r.cfg.pack==1,'explicit retry can apply after save condition clears: '..fault)
end
r=rig();u=r.ui;u.open();u.action('packRow1');r.cfg.chemistry1=0
check(u.action('packUse')=='ERROR' and #r.calls==0 and u.active(),'Use revalidates a profile changed to OFF since modal opened')
r=rig();r.options.selectPack=nil;u=assert(M.new(r.options));u.open();u.action('packRow1')
check(u.action('packUse')=='ERROR' and u.snapshot().error=='PACK SAVE UNAVAILABLE','missing persistence callback cannot claim success')
r=rig();r.fault='config';u=r.ui;u.open();s=u.snapshot()
check(s.current==nil and s.pending==0 and not s.rows[2].enabled and s.rows[2].capacity==nil,'missing config never fabricates a usable pack or capacity')

-- Real touch geometry, all physical controls reachable, outside-modal input
-- consumed without leaking header/PAGE events into the parent application.
r=rig();u=r.ui;u.open();s=u.snapshot()
check(u.hit(8,90)=='packRow0' and u.hit(471,110)=='packRow0' and u.hit(472,90)==nil and u.hit(7,90)==nil,'row touch boundaries are exact/exclusive')
check(u.hit(8,132)==nil and u.hit(20,175)==nil,'OFF/invalid rows never expose active touch targets')
local _,result=u.input(EVT_TOUCH_TAP,{x=200,y=121})
check(result=='SELECTED' and s.pending==1 and s.focusName=='packUse' and #r.calls==0,'touch row selection is pending and focuses Use')
_,result=u.input(EVT_TOUCH_TAP,{x=350,y=232})
check(result=='APPLIED' and #r.calls==1 and r.calls[1]==1,'touch USE performs exactly one explicit pack-only callback')
u.open();local visited={}
for i=1,20 do visited[s.focusName]=true;u.move(1)end
for _,name in ipairs({'packRow0','packRow1','packRow3','packRow5','packCancel','packEdit','packUse'})do check(visited[name],'rotary reaches enabled modal control '..name)end
check(not visited.packRow2 and not visited.packRow4,'rotary never lands on disabled profile')
local pending=s.pending;count=#r.calls
handled,result=u.input(EVT_TOUCH_TAP,{x=20,y=15})
check(handled and result=='PENDING' and s.pending==pending and #r.calls==count and u.active(),'touch outside body is consumed without leaking global navigation or saving')
u.input(nil,nil);check(u.active(),'missing event cannot equal absent key constants and cancel modal')

-- Native font boxes fit exact non-overlapping columns and body/footer extents.
r=rig();u=r.ui;u.open();local commands=r.draw();local spans={}
for _,c in ipairs(commands)do
 if c.kind=='text'then
  local w,h=r.lcd.sizeText(c.text,c.font)
  check(c.x>=8 and c.x+w<=472 and c.y>=64 and c.y+h<=243,'measured native text remains inside modal body/footer')
  spans[#spans+1]={x=c.x,y=c.y,w=w,h=h,text=c.text}
 else check(c.x>=4 and c.x+c.w<=476 and c.y>=62 and c.y+c.h<=244,'modal rectangles remain inside approved body')end
end
for i,a in ipairs(spans)do for j=i+1,#spans do local b=spans[j]
 check(a.x+a.w<=b.x or b.x+b.w<=a.x or a.y+a.h<=b.y or b.y+b.h<=a.y,'measured native labels never overlap their adjacent column/control')
end end
check(r.has('Li-ion')and r.has('99S')and r.has('100000 mAh')and r.has('OFF')and r.has('EDIT PACKS')and r.has('USE PACK'),'native UI displays actual large metadata, disabled chemistry and explicit apply/edit actions')
u.stop();r.draws={};u.draw();check(#r.draws==0,'closed modal draws nothing over parent pages')
local stringMeta=debug.getmetatable('');debug.setmetatable('',nil)
local strippedOK,strippedError=pcall(function()
 local native=rig();native.ui.open();native.ui.draw();native.ui.action('packRow5')
 check(native.ui.action('packUse')=='APPLIED' and native.cfg.pack==5,'stripped EdgeTX string library supports pending-selection/verified-apply UI')
end)
debug.setmetatable('',stringMeta);check(strippedOK,'native string compatibility: '..tostring(strippedError))
check(M.new({lcd={}})==nil,'missing native LCD/config dependency is explicit')
print('quick-pack: '..checks..' checks passed')
