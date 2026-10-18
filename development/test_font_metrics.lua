-- Actual app font fitting: bounded native-metric reuse without stale font state.
local realLoadstring=loadstring
local main
loadstring=function(source,name,...)
 if name=='@telem-under-test'then
  local count;source,count=string.gsub(source,' runtimeServices=runtimeServices,',' width=textWidth,runtimeServices=runtimeServices,',1);assert(count==1)
  local chunk,err=realLoadstring(source,name,...)
  if not chunk then return nil,err end
  return function(...)main=chunk(...);return main end
 end
 return realLoadstring(source,name,...)
end
local adapter=assert(loadfile('development/test_ui_navigation.lua'))('adapter')
local a=adapter.make();loadstring=realLoadstring
local checkCount=0
local function check(v,why)checkCount=checkCount+1;assert(v,why)end
local calls=0
lcd.sizeText=function(text,font)calls=calls+1;return #text*7+font/128,17 end
for i=1,128 do check(main.width('tick '..i,SMLSIZE)==#('tick '..i)*7,'first native width is preserved')end
check(calls==128,'each distinct caption is measured once')
for i=1,128 do main.width('tick '..i,SMLSIZE)end
check(calls==128,'all128 recent captions reuse their exact native metric')
main.width('tick 129',SMLSIZE);main.width('tick 1',SMLSIZE)
check(calls==130,'inserting beyond128 evicts old captions rather than accumulating an unbounded history')
check(main.width('tick 1',MIDSIZE)==#'tick 1'*7+MIDSIZE/128,'font is part of the metric identity')
for i=1,2000 do
 local value=string.format('%+.1f',i/10)
 for _,font in ipairs({TINSIZE,SMLSIZE,MIDSIZE,DBLSIZE})do
  check(main.width(value,font)==#value*7+font/128,'moving text and every native font retain exact widths')
 end
end
local before=calls
check(main.width('metric change',SMLSIZE)==#'metric change'*7,'old metric is established')
lcd.sizeText=function(text,font)calls=calls+1;return #text*9+font/256,19 end
check(main.width('metric change',SMLSIZE)==#'metric change'*9,'replacement LCD/font API invalidates prior metrics immediately')
check(calls==before+2,'LCD replacement really invokes the new native metric function')
lcd.sizeText=nil
check(main.width('123',MIDSIZE)==48 and main.width('123',SMLSIZE)==24,'missing native metrics retain the established conservative fallback')
lcd.sizeText=function()return nil end
check(main.width('123',MIDSIZE)==48,'an unavailable measured width also uses the established fallback')
print('PASS: '..checkCount..' native font-metric checks; bounded128-caption reuse, font/API invalidation, moving values, fallback')
