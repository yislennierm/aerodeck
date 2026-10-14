local f=assert(io.open('sdcard/SCRIPTS/TOOLS/telem.lua'));local app=f:read('*a');f:close()
local a=assert(string.find(app,'local configuration=(function()',1,true));local b=assert(string.find(app,'local telemetry=(function()',a,true));local source=string.sub(app,a,b-1)..'\nreturn configuration'
local disk={};local fail=false
io={open=function(p,m)if m=='r' and not disk[p] then return nil end;if m=='w' and fail then return nil end;return {p=p}end,read=function(f)return disk[f.p]end,write=function(f,s)disk[f.p]=s end,close=function()end}
model={getInfo=function()return {name='Test A'}end,getSensor=function(i)if i==0 then return {name='CustomV'}end end}
getFieldInfo=function(n)if n=='CustomV' then return {id=1}end end
getSourceValue=function()return 16.2,true end
EVT_VIRTUAL_ENTER=2;EVT_TOUCH_TAP=1;EVT_VIRTUAL_NEXT=3;EVT_VIRTUAL_PREV=4
local c=assert(loadstring(source))();c.init()
local function tap(x,y)c.input(1,{x=x,y=y})end
local function list()return table.concat(c.visible(),',')end
assert(list()=='1,6,11,12')
tap(120,231);assert(list()=='1,2,3,4,6,10,11,12')
tap(200,90);tap(120,231);assert(list()=='1,2,3,4,5,6,7,10,11,12')
tap(200,110);tap(120,231);tap(120,231);assert(#c.visible()==12)
assert(c.save());c.init();assert(#c.visible()==12)
-- Explicitly disabling voltage hides both battery sections.
tap(200,130);tap(120,231);assert(list()=='1,2,5,6,7,8,9,10,11,12')
-- Disabling GPS hides GPS configuration.
tap(200,210);tap(200,70);tap(120,231);assert(list()=='1,2,5,6,7,8,9,11,12')
-- Revert restores all saved feature selections.
tap(380,231);assert(#c.visible()==12)
-- Protocol None collapses to the four base lists; hidden settings survive save/reopen.
tap(200,210);tap(200,210);tap(200,70);tap(35,231)
assert(list()=='1,6,11,12');assert(c.save());c.init();assert(c.get('fcType')=='Betaflight' and c.get('vtxMode')==2)
tap(120,231);assert(#c.visible()==12)
print('PASS: 4/8/10/12 visibility, voltage/GPS dependency, revert, persistent hidden values, re-enable')
