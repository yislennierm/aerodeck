local modulePath=arg[1] or 'sdcard/SCRIPTS/TOOLS/AERODECK/arm-status.lua'
local decoder=assert(loadfile(modulePath))()
local function fixture(bytes,count,extra,header)
 extra=extra or 0;count=count or 26
 local d={};for i=1,16+extra do d[i]=0 end
 d[16]=header or extra;d[17+extra]=count
 for i=1,4 do d[17+extra+i]=bytes[i] end
 return d
end
local function reason(bytes,count,major,minor,extra,header)
 local d=fixture(bytes,count,extra,header)
 local r,e=decoder.decode(d,major or 1,minor or 46)
 assert(r,e);return r,d
end
local function bitBytes(bit)
 local b={0,0,0,0};b[math.floor(bit/8)+1]=2^(bit%8);return b
end
local expected146={'NOGYRO','FAILSAFE','RXLOSS','NOT_DISARMED','BOXFAILSAFE','RUNAWAY','CRASH','THROTTLE','ANGLE','BOOTGRACE','NOPREARM','LOAD','CALIB','CLI','CMS','BST','MSP','PARALYZE','GPS','RESCUE_SW','DSHOT_TELEM','REBOOT_REQD','DSHOT_BBANG','NO_ACC_CAL','MOTOR_PROTO','ARMSWITCH'}
local expected147={};for i=1,25 do expected147[i]=expected146[i]end
expected147[26]='FLIP_SWITCH';expected147[27]='ALT_HOLD_SW';expected147[28]='POS_HOLD_SW';expected147[29]='ARM_SWITCH'
local expected148={};for i=1,28 do expected148[i]=expected147[i]end
expected148[29]='AUTOPILOT_SW';expected148[30]='ARM_SWITCH'
for _,version in ipairs({{46,26,expected146},{47,29,expected147},{48,30,expected148}})do
 for bit=0,version[2]-1 do
  local bytes=bitBytes(bit)
  local r=reason(bytes,version[2],1,version[1])
  assert(r.count==version[2] and r.mappingKnown)
  assert(#r.reasons==1 and r.reasons[1].bit==bit and r.reasons[1].code==version[3][bit+1])
  assert(r.reasons[1].known and #r.reasons[1].title>0 and #r.reasons[1].detail>0 and #r.reasons[1].help>0)
  assert(r.maskHex==string.format('%02X%02X%02X%02X',bytes[4],bytes[3],bytes[2],bytes[1]))
 end
end
-- Literal bytes preserve bit0 alongside high bit25 without ever building U32.
local multi,d=reason({129,0,128,2},26,1,46,3,0xA3)
assert(multi.extraModeBytes==3 and #multi.reasons==4 and multi.maskHex=='02800081')
assert(multi.reasons[1].bit==0 and multi.reasons[2].code=='THROTTLE' and multi.reasons[3].bit==23 and multi.reasons[4].code=='ARMSWITCH')
local snapshot=table.concat(d,',');decoder.decode(d,1,46);assert(table.concat(d,',')==snapshot,'decoder mutates input')
local empty=reason({0,0,0,0});assert(empty.maskHex=='00000000' and #empty.reasons==0 and empty.armed==nil and empty.ready==nil)
for _,api in ipairs({{1,48},{1,49},{2,46},{0,0}})do
 local r=reason({129,0,128,128},32,api[1],api[2])
 assert(not r.mappingKnown and #r.reasons==4 and r.maskHex=='80800081')
 assert(r.reasons[1].bit==0 and r.reasons[2].bit==7 and r.reasons[3].bit==23 and r.reasons[4].bit==31)
 for _,v in ipairs(r.reasons)do assert(v.code=='BIT '..v.bit and not v.known)end
end
-- A known API with an unexpected count must not label a possibly moved bit.
local changed=reason({0,0,0,2},29,1,46);assert(not changed.mappingKnown and changed.reasons[1].code=='BIT 25')
local all=reason({255,255,255,255},32,1,49);assert(#all.reasons==32 and all.maskHex=='FFFFFFFF')
local noVersion=assert(decoder.decode(fixture({0,0,0,2}),nil,nil));assert(not noVersion.mappingKnown and noVersion.reasons[1].code=='BIT 25')
local api147=reason({1,0,0,30},29,1,47)
assert(#api147.reasons==5 and api147.reasons[1].code=='NOGYRO' and api147.reasons[2].code=='FLIP_SWITCH' and api147.reasons[5].code=='ARM_SWITCH')
-- The reported zero-based BIT18 now has its exact GPS meaning on stable API1.48.
for _,version in ipairs({{46,26},{47,29},{48,30}})do
 local gps=reason({0,0,4,0},version[2],1,version[1]).reasons[1]
 assert(gps.bit==18 and gps.code=='GPS'and gps.known,'GPS bit18 must not shift between the supported releases')
 assert(string.find(gps.detail,'valid GPS fix',1,true)and string.find(gps.help,'configured minimum satellites',1,true),'GPS guidance must describe both required fix and configured satellite threshold')
end
local autopilot=reason({0,0,0,16},30,1,48).reasons[1]
assert(autopilot.bit==28 and autopilot.code=='AUTOPILOT_SW'and autopilot.title=='Autopilot selected')
local armSwitch=reason({0,0,0,32},30,1,48).reasons[1]
assert(armSwitch.bit==29 and armSwitch.code=='ARM_SWITCH','API1.48 arm switch is bit29, not the former bit28')
local newest,latestPacket=reason({129,0,4,48},30,1,48,15,0xAF)
assert(newest.mappingKnown and newest.extraModeBytes==15 and newest.maskHex=='30040081'and #newest.reasons==5)
for i,code in ipairs({'NOGYRO','THROTTLE','GPS','AUTOPILOT_SW','ARM_SWITCH'})do assert(newest.reasons[i].code==code,'Mixed API1.48 low/high bits retain their exact names')end
local latestSnapshot=table.concat(latestPacket,',');decoder.decode(latestPacket,1,48)
assert(table.concat(latestPacket,',')==latestSnapshot,'API1.48 decoding must not mutate its packet')
local clear148=reason({0,0,0,0},30,1,48)
assert(clear148.mappingKnown and #clear148.reasons==0 and clear148.armed==nil and clear148.ready==nil,'A known empty mask never proves armed or ready')
-- The new mapping is exact-version/count only; never infer a future flag table.
for _,version in ipairs({{1,48,29},{1,48,31},{1,48,32},{1,47,30},{1,46,30},{1,49,30},{2,48,30}})do
 local r=reason({0,0,4,16},version[3],version[1],version[2])
 assert(not r.mappingKnown and #r.reasons==2)
 assert(r.reasons[1].code=='BIT 18'and r.reasons[2].code=='BIT 28'and not r.reasons[1].known and not r.reasons[2].known,'Unsupported API/count must keep numbered GPS/autopilot bits instead of guessing')
end
local function invalid(packet,label)
 local r,e=decoder.decode(packet,1,46);assert(r==nil and type(e)=='string',label)
end
invalid(nil,'missing');invalid('status','wrong type');invalid({},'empty')
local truncated=fixture({0,0,0,2},26,4);truncated[#truncated]=nil;invalid(truncated,'variable flags truncated')
for _,count in ipairs({0,33,255})do local p=fixture({0,0,0,0});p[17]=count;invalid(p,'invalid count '..count)end
for _,value in ipairs({-1,256,0.5,'0',false})do local p=fixture({0,0,0,0});p[18]=value;invalid(p,'invalid flag byte')end
local bad=fixture({0,0,0,0});bad[16]=256;invalid(bad,'invalid header')
local nan=fixture({0,0,0,0});nan[19]=0/0;invalid(nan,'NaN')
local hole=fixture({0,0,0,0});hole[7]=nil;invalid(hole,'missing stable-prefix byte')
local beyond=fixture({0,0,0,4},26);invalid(beyond,'mask beyond count')
local beyond148,error148=decoder.decode(fixture({0,0,0,64},30),1,48)
assert(beyond148==nil and error148=='FLAGS EXCEED COUNT','API1.48 must reject a mask set beyond its advertised30 flags')
local truncated148=fixture({0,0,4,0},30,3);truncated148[#truncated148]=nil
assert(decoder.decode(truncated148,1,48)==nil,'Truncated API1.48 variable flags must be rejected')
local oversized=fixture({0,0,0,0});for i=#oversized+1,257 do oversized[i]=0 end;invalid(oversized,'oversize')
local extension=fixture({128,0,0,0},26,15);for i=#extension+1,256 do extension[i]=255 end
assert(decoder.decode(extension,1,46).reasons[1].code=='THROTTLE','bounded future trailing payload')
print('PASS: STATUS_EX offsets, every API1.46/1.47/1.48 flag, GPS18, autopilot28, arm-switch29, bytewise low/high bits, strict unknown APIs/counts, malformed rejection, no input mutation')
