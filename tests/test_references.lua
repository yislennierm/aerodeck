-- Pure reference/decoder contract tests; no radio, FC or playback side effects.
-- Optional argv[1] is a project root containing sdcard/.
local root=arg[1] or '.'
local base=root..'/sdcard/SCRIPTS/TOOLS/AERODECK/'
local checks=0
local function check(value,message)
 checks=checks+1;assert(value,message or ('check '..checks))
end
local function pureModule(path)
 local chunk=assert(loadfile(path))
 -- Only pure Lua dependencies are available. An accidental output/read is an
 -- error rather than a mock silently accepting an unintended command.
 local env={type=type,ipairs=ipairs,pairs=pairs,math=math,string=string,table=table}
 setmetatable(env,{__index=function(_,name)error('Forbidden module global: '..name)end})
 if setfenv then setfenv(chunk,env)end
 return chunk()
end
local arm=pureModule(base..'arm-status.lua')
local reference=pureModule(base..'reference.lua')
local bf=assert(reference.guide('BF'))
local inav=assert(reference.guide('INAV'))
check(#bf==20 and #inav==28,'Full original 20/28 guide coverage')
check(reference.reference and reference.sendsCommands==false)
check(reference.guide('BTFL')==bf and reference.guide('Betaflight')==bf,'BF aliases cache one guide')
check(reference.guide('IN')==inav and reference.guide('INAV')==inav,'INAV aliases cache one guide')
check(reference.guide('ARDU')==nil,'Unsupported family is not silently BF')
for _,list in ipairs({bf,inav})do
 check(list.reference and list.sendsCommands==false and type(list.basis)=='string')
 for i,item in ipairs(list)do
  check(item.id==i and item.reference==true and type(item[1])=='string' and #item[1]>0)
  check(item.label==item[1] and type(item.context)=='string' and #item.context>0)
  for axis=2,5 do check(item[axis]==-1 or item[axis]==0 or item[axis]==1,'Valid normalized guide axis')end
  check(item.t==item[2] and item.y==item[3] and item.p==item[4] and item.r==item[5],'Named/positional tuple agrees')
  check(item.run==nil and item.apply==nil and item.command==nil,'Guides contain no callable controls')
 end
end
local function tuple(item,t,y,p,r)
 check(item[2]==t and item[3]==y and item[4]==p and item[5]==r,item[1]..' tuple')
end
-- Regression for actual mistakes in the reference package. Official INAV
-- Controls.md and rc_controls.c distinguish Save from Unload and center yaw.
tuple(inav[15],-1,0,1,1);tuple(inav[16],-1,0,1,-1)
tuple(inav[17],-1,0,-1,1);tuple(inav[18],-1,0,0,1);tuple(inav[19],-1,0,0,-1)
check(inav[16].p~=inav[17].p and inav[16].r~=inav[17].r,'Save/Unload are distinct')
check(inav[20].note:find('ALLOW_BYPASS',1,true) and inav[20].note:find('arm switch',1,true),'Bypass conditions visible')
for i=9,12 do
 check(bf[i].note:find('ANGLE/HORIZON',1,true) and bf[i].note:find('ACRO',1,true),'BF trim/rate modes distinguished')
end
for _,item in ipairs({bf[14],inav[22]})do
 check(item.note:find('not an immediate exit',1,true),'Yaw high opens choices, not a claimed immediate save/exit')
end
check(bf[13].context=='CMS closed' and bf[14].context=='CMS open')
check(inav[21].context=='CMS closed' and inav[22].context=='CMS open')
local expected146={'NOGYRO','FAILSAFE','RXLOSS','NOT_DISARMED','BOXFAILSAFE','RUNAWAY','CRASH','THROTTLE','ANGLE','BOOTGRACE','NOPREARM','LOAD','CALIB','CLI','CMS','BST','MSP','PARALYZE','GPS','RESCUE_SW','DSHOT_TELEM','REBOOT_REQD','DSHOT_BBANG','NO_ACC_CAL','MOTOR_PROTO','ARMSWITCH'}
local expected147={};for i=1,25 do expected147[i]=expected146[i]end
expected147[26]='FLIP_SWITCH';expected147[27]='ALT_HOLD_SW';expected147[28]='POS_HOLD_SW';expected147[29]='ARM_SWITCH'
local expected148={};for i=1,28 do expected148[i]=expected147[i]end
expected148[29]='AUTOPILOT_SW';expected148[30]='ARM_SWITCH'
for _,v in ipairs({{46,26,expected146},{47,29,expected147},{48,30,expected148}})do
 local list=arm.catalogue('BF',1,v[1],v[2])
 check(#list==v[2] and list.mappingKnown and list.reference)
 check(list.apiMajor==1 and list.apiMinor==v[1] and list.flagCount==v[2])
 check(arm.catalogue('BTFL',1,v[1],v[2])==list,'Alias returns cached codebook')
 for i,item in ipairs(list)do
  check(item.code==v[3][i] and item.bit==i-1 and item.known and item.reference)
  for _,field in ipairs({'title','detail','help'})do check(type(item[field])=='string' and #item[field]>0,'Complete reason guidance')end
  check(item.beepId==i and item.beep.id==i and item.beep.long==math.floor(i/5) and item.beep.short==i%5)
 end
end
local manual=arm.catalogue('BF')
check(#manual==30 and manual.reference and not manual.mappingKnown and manual.flagCount==nil,'Unknown BF version is manual only')
for _,v in ipairs({{1,49,30},{1,48,29},{2,48,30}})do check(arm.catalogue('BF',v[1],v[2],v[3])==manual)end
for _,item in ipairs(manual)do check(item.bit==nil,'Manual BF reference must not supply guessed bits')end
local nav=arm.catalogue('INAV')
check(#nav==25 and nav.reference and not nav.mappingKnown,'INAV full manual catalogue')
check(arm.catalogue('IN')==nav and arm.catalogue('INAV',1,48,30)==nav)
local navCodes={'GEOZONE','FS','ANGLE','CAL','OVRLD','NAV','COMPASS','ACC','ARMSW','HWFAIL','BOXFS','KILLSW','RX','THR','CLI','CMS','OSD','ROLL/PITCH','AUTOTRIM','OOM','SETTINGFAIL','PWMOUT','NOPREARM','DSHOTBEEPER','LANDED'}
for i,item in ipairs(nav)do
 check(item.referenceId==i+6 and item.beepId==i+6 and item.code==navCodes[i])
 check(item.bit==nil and item.reference and item.known,'Manual INAV catalogue must not imply a live bit map')
 for _,field in ipairs({'title','detail','help'})do check(type(item[field])=='string' and #item[field]>0)end
 check(item.legacy==(item.code=='KILLSW'),'Reserved/legacy slot explicitly tagged')
end
check(nav[12].detail:find('reserves this slot',1,true),'KILLSW is not portrayed as a current 9.1 blocker')
check(nav[15].detail:find('command-line',1,true),'CLI explanation is not the old BST copy/paste error')
check(arm.catalogue('ARDU')==nil and arm.catalogue(nil)==nil)
-- Pattern data reproduces the original Toolbox radio training preview. No
-- module calls playTone: the caller explicitly decides whether to preview it.
for id=1,32 do
 local pattern=assert(arm.beepPattern({beepId=id}))
 local long,short=math.floor(id/5),id%5
 check(pattern.id==id and pattern.long==long and pattern.short==short and pattern.preview)
 check(#pattern.tones==long+short and arm.beepPattern({beepId=id})==pattern,'Bounded cached training pattern')
 for i,tone in ipairs(pattern.tones)do
  check(tone.frequency==2400 and tone.duration==(i<=long and 350 or 100))
  check(tone.pause==((i==long and long>0) and 400 or 200),'Original long/short cadence')
 end
end
check(arm.beepPattern({known=true,bit=18}).id==19,'Known live BF reason uses original one-based beep ID')
for _,bad in ipairs({{}, {known=false,bit=18}, {beepId=0}, {beepId=33}, {beepId=1.5}, {beepId='19'}, {beepId=0/0}})do
 local pattern,errorText=arm.beepPattern(bad);check(pattern==nil and errorText=='NO VERIFIED BEEP CODE')
end
check(arm.beepPattern(nil)==nil and arm.beepPattern(19)==nil)
-- New offline features must preserve strict live BF unknown-version semantics.
local packet={};for i=1,21 do packet[i]=0 end
packet[17]=30;packet[20]=4
local known=assert(arm.decode(packet,1,48))
check(known.reasons[1].code=='GPS' and known.reasons[1].known)
check(arm.beepPattern(known.reasons[1]).id==19)
local unknown=assert(arm.decode(packet,1,49))
check(unknown.reasons[1].code=='BIT 18' and not unknown.reasons[1].known)
check(arm.beepPattern(unknown.reasons[1])==nil,'Manual catalogue does not promote unknown live flags')
-- Independent INAV8192 fixture:13Bprefix +8Bmode bitset +mixer byte.
-- No BF STATUS_EX offsets/count fields occur in this packet.
local function inavPacket(bits)
 local data={};for i=1,22 do data[i]=0 end
 data[1]=0xE8;data[2]=0x03;data[5]=0x3F;data[7]=27;data[9]=0x21
 for _,bit in ipairs(bits or {})do
  local pos=10+math.floor(bit/8);data[pos]=data[pos]+2^(bit%8)
 end
 data[14]=0x80;data[21]=0x08;data[22]=2
 return data
end
local versions={{8,0,0},{8,0,1},{9,0,0},{9,0,1},{9,1,0}}
for _,version in ipairs(versions)do
 for bit=0,31 do
  local packet=inavPacket({bit});local before=table.concat(packet,',')
  local result,errorText=arm.decodeInav(packet,version[1],version[2],version[3])
  check(result~=nil,errorText)
  check(table.concat(packet,',')==before,'INAV decode is not an in-place mask')
  check(result.family=='INAV' and result.statusCommand==8192 and result.count==32 and result.blockerCount==24)
  check(result.armed==nil and result.ready==nil,'INAV state flags do not become a readiness claim')
  if bit>=2 and bit<=5 then
   check(#result.reasons==0 and result.stateBitCount==1 and result.mappingKnown,'Armed/history/simulator bits are not blockers')
  elseif bit>=6 and bit<=30 and bit~=17 then
   local reason=result.reasons[1]
   check(#result.reasons==1 and result.mappingKnown and reason.known and reason.bit==bit)
   check(reason.code==navCodes[bit-5] and reason.beepId==bit+1,'INAV exact named blocker and original beep ID')
   check(arm.beepPattern(reason).id==bit+1,'Known INAV live reason can be previewed')
  else
   check(#result.reasons==1 and not result.mappingKnown and not result.reasons[1].known,'Reserved bits stay unknown, including old KILLSW')
   check(result.reasons[1].code=='BIT '..bit and arm.beepPattern(result.reasons[1])==nil)
  end
 end
 local mixed=inavPacket({2,6,17,19,30,31})
 local result=assert(arm.decodeInav(mixed,version[1],version[2],version[3]))
 check(result.maskHex=='C00A0044' and result.stateBitCount==1 and #result.reasons==5 and not result.mappingKnown,'INAV bytewise low/high and reserved flags survive together')
 check(result.reasons[1].code=='GEOZONE' and result.reasons[2].code=='BIT 17' and result.reasons[3].code=='THR' and result.reasons[4].code=='LANDED' and result.reasons[5].code=='BIT 31')
 local clear=assert(arm.decodeInav(inavPacket(),version[1],version[2],version[3]))
 check(#clear.reasons==0 and clear.maskHex=='00000000' and clear.armed==nil and clear.ready==nil)
end
for _,version in ipairs({{8,0,2},{8,1,0},{9,0,2},{9,1,1},{9,2,0},{10,0,0},{1,48,0},{9,1},{}})do
 local result,errorText=arm.decodeInav(inavPacket(),version[1],version[2],version[3])
 check(result==nil and errorText=='UNSUPPORTED INAV RELEASE','Unknown releases never borrow INAV offsets/clear flags')
end
for size=0,23 do
 if size~=22 then
  local bad={};for i=1,size do bad[i]=0 end
  local result,errorText=arm.decodeInav(bad,9,1,0)
  check(result==nil and errorText=='INVALID INAV STATUS LENGTH','Full exact22Bpacket is required')
 end
end
for position=1,22 do
 for _,badByte in ipairs({-1,256,0.5,'0',false,0/0})do
  local bad=inavPacket();bad[position]=badByte
  check(arm.decodeInav(bad,9,1,0)==nil,'Every INAV byte is validated, not only the flag field')
 end
 local bad=inavPacket();bad[position]=nil;check(arm.decodeInav(bad,9,1,0)==nil,'Sparse INAV packet rejected')
end
check(arm.decodeInav(nil,9,1,0)==nil and arm.decodeInav('status',9,1,0)==nil)
print('Reference catalogue and stick guides: '..checks..' checks PASS')
