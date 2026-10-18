-- Official OLC vectors + independent direction/ETA and native-number regressions.
-- Pure utility test: no synthetic fixture is installed on the SD card.
local here=string.match(arg[0],'^(.*[/\\])')or'./'
local root=arg[1]or(here..'../')
local M=assert(loadfile(root..'/sdcard/SCRIPTS/TOOLS/AERODECK/navigation-utils.lua'))()
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local numeric32=1/3==0.3333333432674408
local vectorFile=numeric32 and'encoding-float32.csv'or'encoding.csv'
local f=assert(io.open(root..'/tests/data/navigation-utils/'..vectorFile,'r'))
local vectors=0
for line in f:lines()do
 if string.sub(line,1,1)~='#'and line~=''then
  local a,b,_,__,length,expected=string.match(line,'^([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),(.*)$')
  local actual,err=M.encode(tonumber(a),tonumber(b),tonumber(length))
  check(actual==expected,'official vector '..line..' got '..tostring(actual)..' / '..tostring(err));vectors=vectors+1
 end
end
f:close();check(vectors==302,'all302 official encoding vectors covered')
local known='76Q4XRXV+33C'
check(M.encode(25.9976807,-97.1573563)=='76Q4XRXV+33','original screenshot coordinates encode normal full Plus Code')
check(M.encode(25.9976807,-97.1573563,11)==known,'known position extra grid agrees with actual input precision')
check(M.encode(25.9981807,-97.1570563,11)=='76Q4XRXV+75G','nearby current position has its own fractional Plus Code rather than whole-degree collapse')
check(M.encode(0,0)=='6FG22222+22','equator/prime meridian do not mean missing GPS')
check(M.encode(-90,-180)=='22222222+22','southwest pole is bounded')
check(M.encode(90,180)==M.encode(90,-180),'dateline normalization agrees at north pole')
check(M.encode(90,1,15)=='CFX3X2X2+X2RRRRR','north pole maximum grid stays inside legal OLC range')
check(M.encode(0,-0.000000000000001,15)=='6CGX2X2X+2X55555','tiny negative longitude does not lose its sign to the180degree offset')
check(M.encode(-0.000000000000001,0,15)=='6FF2X2X2+X2RRRRR','tiny negative latitude stays below equator')
for _,v in ipairs({false,'1',{},math.huge,-math.huge,0/0})do
 check(M.encode(v,1)==nil and M.encode(1,v)==nil,'invalid coordinates rejected')
 check(M.relativeBearing(v,1)==nil and M.relativeBearing(1,v)==nil,'invalid bearing rejected')
 check(M.formatETA(v,1)==nil and M.formatETA(1,v)==nil,'invalid ETA input rejected')
end
check(M.encode(nil,1)==nil and M.encode(1,nil)==nil,'nil coordinates rejected without substitution')
for _,n in ipairs({0,1,3,5,7,9,-2,10.5,'10',false,{},0/0,math.huge})do check(M.encode(1,1,n)==nil,'invalid code length rejected')end
for _,case in ipairs({{0,0,0},{90,0,90},{0,90,-90},{10,350,20},{350,10,-20},{180,0,-180},{0,180,-180},{720,-720,0},{-450,720,-90},{150,159,-9}})do
 check(M.relativeBearing(case[1],case[2])==case[3],'signed home direction wraps correctly')
end
for a=-720,720,37 do for b=-720,720,41 do local v=M.relativeBearing(a,b);check(v>=-180 and v<180 and (v+b-a)%360==0,'relative direction range and modular identity')end end
check(M.formatETA(0,20)=='00:00','zero distance is valid with positive known speed')
local text,seconds=M.formatETA(1000,36);check(text=='01:40'and seconds==100,'metres and km/h converted once')
check(M.formatETA(15000,10)=='01:30:00','long ETA formats hours without minute overflow')
check(M.formatETA(1000,0)==nil and M.formatETA(-1,10)==nil and M.formatETA(1000,-10)==nil,'stopped/missing/negative motion never fabricates an ETA')
check(M.formatETA(1000000000,0.00001)==nil,'unusable enormous ETA is bounded')
-- EdgeTX lacks the string method metatable; runtime utility uses explicit calls.
if debug and debug.setmetatable then
 local original=debug.getmetatable('');debug.setmetatable('',nil)
 local ok,err=pcall(function()check(M.encode(25.9976807,-97.1573563)=='76Q4XRXV+33','stripped runtime supports encoding');check(M.formatETA(1000,36)=='01:40','stripped runtime supports ETA')end)
 debug.setmetatable('',original);assert(ok,err)
end
print('PASS: '..checks..' navigation checks: '..vectors..' official OLC vectors, known quad coordinate, poles/dateline, validation, signed relative direction and bounded ETA ('..(numeric32 and'native float32' or'double')..')')
