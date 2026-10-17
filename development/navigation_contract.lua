-- Behavioral contract for the actual AERODECK app adapter.
-- This does not implement a second navigation router or a fake app.
-- Usage:
--   local c=assert(loadfile('/.../navigation-contract.lua'))()
--   c.run(makeAdapter, assert(loadfile('/.../events-tx16s-2.12.4.lua'))())
--
-- makeAdapter(E) returns a fresh app/fixture, initially warmed on Flight:
--   send(event,touch) -> actual app.run result (nil event must remain nil)
--   state() -> {page, navFocus=nil|1..6, controlFocus=nil|id,
--               navCaption=string, controlCaption=string}
--   arrange(page) -> test-only page arrangement; clear focus, keep app initialized
--   bitmapLoads() -> cumulative Bitmap.open counter
--   setWarning(enabled) -> set real fixture battery reading; retain frozen values
--   visible(text) -> text visible after final composed LCD frame
-- Optional sourceScans() counts model.getSensor calls to detect hidden refresh.
-- Configuration's own transactional tests should run separately.
local contract={}
function contract.run(makeAdapter,E)
 assert(type(makeAdapter)=='function','provide real-app adapter factory')
 local roots={1,5,7,11,8,6}
 local required={'send','state','arrange','bitmapLoads','setWarning','visible'}
 local count=0
 local function eq(actual,expected,message)
  assert(actual==expected,(message or 'value')..': expected '..tostring(expected)..', got '..tostring(actual))
 end
 local function fresh()
  local a=makeAdapter(E)
  for _,name in ipairs(required)do assert(type(a[name])=='function','adapter missing '..name)end
  eq(a.state().page,1,'fresh app starts on Flight')
  return a
 end
 local function scenario(name,fn)
  local a=fresh();local ok,why=pcall(fn,a)
  assert(ok,name..': '..tostring(why));count=count+1
 end
 local function page(a,id)eq(a.state().page,id,'displayed page')end
 local function noFocus(a)
  eq(a.state().navFocus,nil,'top navigation focus cleared')
 end
 local function normal(a,event,touch)
  eq(a.send(event,touch),0,'app remains open')
 end
 scenario('actual release constants and aliases',function(a)
  eq(E.EVT_SYS_BREAK,525,'SYS release');eq(E.EVT_VIRTUAL_MENU,523,'MDL/menu release')
  eq(E.EVT_VIRTUAL_ENTER,514,'ENTER release');eq(E.EVT_VIRTUAL_EXIT,513,'RTN release')
  eq(E.EVT_VIRTUAL_PREV_PAGE,515,'PAGE previous');eq(E.EVT_VIRTUAL_NEXT_PAGE,516,'PAGE next')
  eq(E.EVT_VIRTUAL_PREV,4099,'rotary previous');eq(E.EVT_VIRTUAL_NEXT,4100,'rotary next')
  eq(E.EVT_VIRTUAL_INC,E.EVT_VIRTUAL_NEXT,'INC aliases NEXT')
  eq(E.EVT_VIRTUAL_DEC,E.EVT_VIRTUAL_PREV,'DEC aliases PREV')
  eq(E.EVT_MENU_BREAK,nil,'TX16S has no physical MENU constant')
  eq(E.EVT_VIRTUAL_NEXT_REPT,nil,'rotary target has no virtual NEXT_REPT export')
 end)
 scenario('unhandled and optional nil events are inert',function(a)
  local before=a.bitmapLoads()
  normal(a,nil);normal(a,0);normal(a,-999);normal(a,0x7FFF)
  for _,event in ipairs({E.EVT_SYS_FIRST,E.EVT_SYS_LONG,E.EVT_SYS_REPT,
     E.EVT_ENTER_FIRST,E.EVT_EXIT_FIRST,E.EVT_PAGEUP_FIRST,E.EVT_PAGEDN_FIRST})do
   normal(a,event);page(a,1);noFocus(a);eq(a.state().controlFocus,nil,'no local focus from unrelated edge')
  end
  eq(a.bitmapLoads(),before,'invalid events do not reset graphic caches')
 end)
 scenario('one SYS press focuses once and release selects nothing',function(a)
  normal(a,E.EVT_SYS_FIRST);noFocus(a)
  normal(a,E.EVT_SYS_BREAK);eq(a.state().navFocus,1,'SYS focuses current section');page(a,1)
  assert(type(a.state().navCaption)=='string' and #a.state().navCaption>0,'focused icon has a readable name')
  normal(a,E.EVT_ENTER_FIRST);eq(a.state().navFocus,1,'ENTER FIRST does not activate')
  normal(a,E.EVT_VIRTUAL_ENTER);noFocus(a);page(a,1)
 end)
 scenario('guarded MDL virtual-menu alias also focuses navigation',function(a)
  normal(a,E.EVT_VIRTUAL_MENU);eq(a.state().navFocus,1,'virtual menu focuses current section')
  normal(a,E.EVT_VIRTUAL_EXIT);noFocus(a);page(a,1)
 end)
 scenario('focused rotary and PAGE only move focus, with wrapping',function(a)
  normal(a,E.EVT_SYS_BREAK)
  normal(a,E.EVT_VIRTUAL_INC);eq(a.state().navFocus,2,'one aliased INC/NEXT event moves once');page(a,1)
  normal(a,E.EVT_VIRTUAL_PREV_PAGE);eq(a.state().navFocus,1,'focused PAGE previous');page(a,1)
  normal(a,E.EVT_VIRTUAL_PREV);eq(a.state().navFocus,6,'backward wrap');page(a,1)
  normal(a,E.EVT_VIRTUAL_NEXT_PAGE);eq(a.state().navFocus,1,'forward wrap');page(a,1)
  local captions={}
  for i=1,6 do
   eq(a.state().navFocus,i,'focused section order')
   local caption=a.state().navCaption
   assert(type(caption)=='string' and #caption>0 and not captions[caption],'six focus captions are readable and distinct')
   captions[caption]=true;normal(a,E.EVT_VIRTUAL_NEXT);page(a,1)
  end
  normal(a,E.EVT_VIRTUAL_EXIT);noFocus(a);page(a,1)
 end)
 scenario('focused ENTER activates a stable root',function(a)
  normal(a,E.EVT_SYS_BREAK);normal(a,E.EVT_VIRTUAL_NEXT);normal(a,E.EVT_VIRTUAL_ENTER)
  page(a,5);noFocus(a)
 end)
 scenario('normal PAGE follows the same six root destinations',function(a)
  for _,id in ipairs({5,7,11,8,6,1})do normal(a,E.EVT_VIRTUAL_NEXT_PAGE);page(a,id);noFocus(a)end
  for _,id in ipairs({6,8,11,7,5,1})do normal(a,E.EVT_VIRTUAL_PREV_PAGE);page(a,id);noFocus(a)end
 end)
 scenario('detail PAGE uses its owner section before cycling',function(a)
  for _,case in ipairs({{10,5,6},{3,7,1},{9,7,1},{2,11,5},{4,1,8},{12,1,8}})do
   a.arrange(case[1]);normal(a,E.EVT_VIRTUAL_NEXT_PAGE);page(a,case[2])
   a.arrange(case[1]);normal(a,E.EVT_VIRTUAL_PREV_PAGE);page(a,case[3])
  end
 end)
 scenario('section touch always opens its root, not a remembered detail',function(a)
  for i,id in ipairs(roots)do
   a.arrange(({10,9,2,11,8,12})[i])
   local left=104+math.floor((i-1)*376/6);local right=104+math.floor(i*376/6)
   normal(a,E.EVT_TOUCH_TAP,{x=left,y=0});page(a,id)
   normal(a,E.EVT_TOUCH_TAP,{x=right-1,y=33});page(a,id)
  end
 end)
 scenario('home icon returns Flight without a twelve-screen drawer',function(a)
  a.arrange(12);normal(a,E.EVT_TOUCH_TAP,{x=20,y=15});page(a,1);noFocus(a)
 end)
 scenario('same-page touch or focus activation keeps bitmap caches',function(a)
  normal(a,0);normal(a,0);local before=a.bitmapLoads()
  normal(a,E.EVT_TOUCH_TAP,{x=130,y=15});page(a,1)
  normal(a,E.EVT_TOUCH_TAP,{x=20,y=15});page(a,1)
  normal(a,E.EVT_SYS_BREAK);normal(a,E.EVT_VIRTUAL_ENTER);page(a,1)
  eq(a.bitmapLoads(),before,'active-page selections open no bitmaps')
 end)
 scenario('normal ENTER reveals the first visible control before action',function(a)
  for _,case in ipairs({{1,10},{5,3},{7,2},{6,4}})do
   a.arrange(case[1]);local scans=a.sourceScans and a.sourceScans()
   normal(a,E.EVT_VIRTUAL_ENTER);page(a,case[1])
   assert(a.state().controlFocus~=nil,'first ENTER shows a visible control focus')
   assert(type(a.state().controlCaption)=='string' and #a.state().controlCaption>0,'focused local control has a caption')
   if scans then eq(a.sourceScans(),scans,'first ENTER does not run hidden telemetry refresh')end
   normal(a,E.EVT_VIRTUAL_ENTER);page(a,case[2])
  end
 end)
 scenario('RTN backs out of a local view and clears its control focus',function(a)
  a.arrange(5);normal(a,E.EVT_VIRTUAL_ENTER)
  normal(a,E.EVT_VIRTUAL_EXIT);page(a,1);eq(a.state().controlFocus,nil,'local focus cleared on back')
 end)
 scenario('RTN from details returns owner root',function(a)
  for _,case in ipairs({{10,1},{3,5},{9,5},{2,7},{4,6},{12,6}})do
   a.arrange(case[1]);normal(a,E.EVT_VIRTUAL_EXIT);page(a,case[2])
  end
 end)
 scenario('RTN from clean section roots returns Flight; Flight exits',function(a)
  for _,id in ipairs({5,7,11,6})do
   a.arrange(id);normal(a,E.EVT_VIRTUAL_EXIT);page(a,1)
  end
  a.arrange(1);eq(a.send(E.EVT_VIRTUAL_EXIT),1,'short RTN on clean Flight exits')
 end)
 scenario('ordinary footer is status, not another navigation surface',function(a)
  a.arrange(1)
  for _,x in ipairs({20,170,280,410})do normal(a,E.EVT_TOUCH_TAP,{x=x,y=257});page(a,1)end
 end)
 scenario('critical warning survives navigation focus and destination changes',function(a)
  a.setWarning(true);normal(a,0);assert(a.visible('BATTERY CRITICAL'),'critical warning visible')
  normal(a,E.EVT_SYS_BREAK);assert(a.visible('BATTERY CRITICAL'),'focus does not cover warning')
  normal(a,E.EVT_VIRTUAL_NEXT);assert(a.visible('BATTERY CRITICAL'),'focus movement keeps warning')
  normal(a,E.EVT_VIRTUAL_ENTER);page(a,5);assert(a.visible('BATTERY CRITICAL'),'destination keeps warning')
  normal(a,E.EVT_VIRTUAL_NEXT_PAGE);page(a,7);assert(a.visible('BATTERY CRITICAL'),'PAGE keeps warning')
 end)
 print('PASS: '..count..' navigation contract scenarios using exact TX16S2.12.4 event aliases')
 return count
end
return contract
