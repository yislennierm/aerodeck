-- Pure, bounded FC arming-disable decoders and offline reference data.
-- No FC/radio writes, transport, sensor reads, or global state.
-- Call once per received packet; retain the result with the packet timestamp.
-- A zero mask reports no disable flags; it never proves armed/ready status.
local M={}
M.sources={
 bits144='https://github.com/betaflight/betaflight/blob/4.3.2/src/main/fc/runtime_config.h#L38-L66',
 codes144='https://github.com/betaflight/betaflight/blob/4.3.2/src/main/fc/runtime_config.c#L36-L63',
 layout144='https://github.com/betaflight/betaflight/blob/4.3.2/src/main/msp/msp.c#L976-L1011',
 api144='https://github.com/betaflight/betaflight/blob/4.3.2/src/main/msp/msp_protocol.h#L61-L62',
 bits145='https://github.com/betaflight/betaflight/blob/4.4.3/src/main/fc/runtime_config.h#L38-L66',
 codes145='https://github.com/betaflight/betaflight/blob/4.4.3/src/main/fc/runtime_config.c#L32-L59',
 api145='https://github.com/betaflight/betaflight/blob/4.4.3/src/main/msp/msp_protocol.h#L61-L62',
 layout='https://github.com/betaflight/betaflight/blob/4.5.2/src/main/msp/msp.c#L995-L1038',
 codes='https://github.com/betaflight/betaflight/blob/4.5.2/src/main/fc/runtime_config.c#L32-L59',
 bits='https://github.com/betaflight/betaflight/blob/4.5.2/src/main/fc/runtime_config.h#L38-L66',
 codes147='https://github.com/betaflight/betaflight/blob/2025.12.4/src/main/fc/runtime_config.c',
 bits147='https://github.com/betaflight/betaflight/blob/2025.12.5/src/main/fc/runtime_config.h#L38-L69',
 api147='https://github.com/betaflight/betaflight/blob/2025.12.5/src/main/msp/msp_protocol.h#L58-L59',
 codes148='https://github.com/betaflight/betaflight/blob/2026.6.2/src/main/fc/runtime_config.c#L38-L70',
 bits148='https://github.com/betaflight/betaflight/blob/2026.6.2/src/main/fc/runtime_config.h#L42-L75',
 api148='https://github.com/betaflight/betaflight/blob/2026.6.2/src/main/msp/msp_protocol.h#L61-L62',
 layout148='https://github.com/betaflight/betaflight/blob/2026.6.2/src/main/msp/msp.c#L1168-L1206',
 conditions148='https://github.com/betaflight/betaflight/blob/2026.6.2/src/main/fc/core.c#L375-L423'
}
-- API 1.46 names and bit order verified against the official 4.5.2 source.
-- Explanations below are concise AERODECK wording, not firmware messages.
local api146={
 {'NOGYRO','Gyro not detected','The flight controller cannot find a gyro.','Check gyro hardware and firmware.'},
 {'FAILSAFE','Failsafe active','The flight controller is in failsafe.','Restore the link and clear failsafe.'},
 {'RXLOSS','Receiver signal lost','No valid receiver signal reaches the FC.','Check receiver power and radio link.'},
 {'NOT_DISARMED','Arm switch still on','The receiver recovered while arm was on.','Move the arm switch to disarmed.'},
 {'BOXFAILSAFE','Failsafe switch active','The configured failsafe mode is active.','Release the failsafe switch.'},
 {'RUNAWAY','Runaway protection','Runaway takeoff protection was triggered.','Disarm and inspect the aircraft.'},
 {'CRASH','Crash detected','Crash recovery is blocking arming.','Disarm and inspect the aircraft.'},
 {'THROTTLE','Throttle too high','Throttle is above the arming threshold.','Lower the throttle fully.'},
 {'ANGLE','Aircraft not level','The aircraft exceeds the allowed tilt.','Place the aircraft level.'},
 {'BOOTGRACE','Startup delay','The initial arming delay is still active.','Wait for startup to finish.'},
 {'NOPREARM','Prearm required','The prearm condition has not been met.','Activate the configured prearm switch.'},
 {'LOAD','FC load too high','The flight controller is overloaded.','Review FC task load and configuration.'},
 {'CALIB','Calibration active','A sensor calibration is still running.','Wait for calibration to complete.'},
 {'CLI','CLI active','The flight controller CLI is open.','Exit the CLI.'},
 {'CMS','OSD menu active','The flight controller menu is open.','Exit the OSD configuration menu.'},
 {'BST','BST blocks arming','A connected BST device requests disarm.','Check the connected BST device.'},
 {'MSP','MSP blocks arming','An MSP client has disabled arming.','Close the connected configurator.'},
 {'PARALYZE','Paralyze active','Paralyze mode has latched the FC off.','Power cycle the flight controller.'},
 {'GPS','GPS requirements unmet','GPS Rescue needs a valid GPS fix and enough satellites.','Wait for a valid fix and the configured minimum satellites.'},
 {'RESCUE_SW','Rescue switch active','GPS Rescue is selected before arming.','Release the GPS Rescue switch.'},
 {'DSHOT_TELEM','ESC telemetry missing','Required DShot telemetry is unavailable.','Check ESC telemetry and DShot setup.'},
 {'REBOOT_REQD','Reboot required','The flight controller requires a reboot.','Reboot the FC while disarmed.'},
 {'DSHOT_BBANG','DShot output unavailable','The DShot bitbang driver cannot start.','Review the motor output configuration.'},
 {'NO_ACC_CAL','Accelerometer not calibrated','The accelerometer needs calibration.','Calibrate the accelerometer.'},
 {'MOTOR_PROTO','Motor protocol missing','No valid motor protocol is configured.','Review the FC motor protocol setting.'},
 {'ARMSWITCH','Arm switch latched','The arm switch must return to disarmed.','Toggle the arm switch off.'}
}
-- APIs 1.44/1.45: pinned official BF 4.3.2/4.4.3 share 26 bit
-- positions; their public codes differ at BADRX and RPMFILTER from 1.46.
local api144={}
for i=1,26 do api144[i]=api146[i] end
api144[4]={'BADRX','Arm switch still on','The receiver recovered while arm was on.','Move the arm switch to disarmed.'}
api144[21]={'RPMFILTER','ESC RPM data missing','Required motor RPM filtering data is unavailable.','Check ESC RPM telemetry and filter setup.'}
local api145=api144
-- API 1.47: official 2025.12.4 names / 2025.12.5 bit positions.
local api147={}
for i=1,25 do api147[i]=api146[i] end
api147[26]={'FLIP_SWITCH','Crash flip selected','Crash flip mode is selected before arming.','Release the crash flip switch.'}
api147[27]={'ALT_HOLD_SW','Altitude hold selected','Altitude hold is selected before arming.','Release the altitude hold switch.'}
api147[28]={'POS_HOLD_SW','Position hold selected','Position hold is selected before arming.','Release the position hold switch.'}
api147[29]={'ARM_SWITCH','Arm switch latched','The arm switch must return to disarmed.','Toggle the arm switch off.'}
-- API 1.48: official stable 2026.6.2 adds AUTOPILOT before the final ARM_SWITCH.
local api148={}
for i=1,28 do api148[i]=api147[i] end
api148[29]={'AUTOPILOT_SW','Autopilot selected','Autopilot mode is selected before arming.','Release the autopilot switch.'}
api148[30]=api147[29]
-- Offline reference data is separate from decode(). A catalogue never reports
-- active flags, armed state or readiness. Cached tables are read-only to callers.
M.sources.inavCodes='https://github.com/iNavFlight/inav/blob/9.1.0/src/main/fc/runtime_config.c#L35-L40'
M.sources.inavFlags='https://github.com/iNavFlight/inav/blob/9.1.0/src/main/fc/runtime_config.h#L21-L61'
M.sources.inavLayout='https://github.com/iNavFlight/inav/blob/9.1.0/src/main/fc/fc_msp.c#L495-L512'
M.sources.inavLayout8='https://github.com/iNavFlight/inav/blob/8.0.1/src/main/fc/fc_msp.c#L459-L476'
M.sources.inavLayout9='https://github.com/iNavFlight/inav/blob/9.0.0/src/main/fc/fc_msp.c#L493-L510'
M.sources.inavLayout800='https://github.com/iNavFlight/inav/blob/8.0.0/src/main/fc/fc_msp.c#L459-L476'
M.sources.inavLayout901='https://github.com/iNavFlight/inav/blob/9.0.1/src/main/fc/fc_msp.c#L493-L510'
M.sources.inavFlags8='https://github.com/iNavFlight/inav/blob/8.0.1/src/main/fc/runtime_config.h#L21-L61'
M.sources.inavFlags9='https://github.com/iNavFlight/inav/blob/9.0.0/src/main/fc/runtime_config.h#L21-L61'
M.sources.inavBoxCount='https://github.com/iNavFlight/inav/blob/9.1.0/src/main/fc/rc_modes.h#L28-L92'
M.sources.inavBitArray='https://github.com/iNavFlight/inav/blob/9.1.0/src/main/common/bitarray.h#L30-L31'
M.sources.referenceBeep='Original ToolBox2.0 UI/480X272/MOD/AST, playAsCode; archive SHA256 9e4b21056c25359d7fcda6a2cd8e997867c2ec400dc7d33cdc18464611a4e766'
local inavReference={
 {7,'GEOZONE','Geozone restriction','An enabled geozone prevents arming.','Check the configured zone and aircraft location.'},
 {8,'FS','Failsafe active','The receiver/failsafe system is not ready.','Restore valid receiver input and clear failsafe.'},
 {9,'ANGLE','Aircraft not level','The aircraft exceeds its allowed arming angle.','Level the aircraft and check small_angle.'},
 {10,'CAL','Calibration active','Prearm sensor calibration has not finished.','Keep the aircraft still until calibration completes.'},
 {11,'OVRLD','FC load too high','The flight controller cannot meet its timing budget.','Inspect task load and loop-time settings.'},
 {12,'NAV','Navigation not ready','Navigation safety checks prevent arming.','Check fix, home, sensors and mission start distance.'},
 {13,'COMPASS','Compass needs calibration','The required compass is not calibrated.','Complete compass calibration for this installation.'},
 {14,'ACC','Accelerometer needs calibration','The required accelerometer is not calibrated.','Complete the supported accelerometer calibration.'},
 {15,'ARMSW','Arm switch latched','The arm switch was active before safe initialization.','Move the arm switch to disarmed.'},
 {16,'HWFAIL','Required hardware unavailable','A required sensor or hardware device is not healthy.','Use FC diagnostics to identify the failed device.'},
 {17,'BOXFS','Failsafe switch selected','The configured failsafe mode is active.','Release the failsafe switch and verify the link.'},
 {18,'KILLSW','Legacy kill-switch blocker','Historical Toolbox reference; INAV 9.1.0 reserves this slot.','Check the exact FC release; do not treat it as a current mapped flag.'},
 {19,'RX','Receiver link unavailable','The flight controller has no usable receiver link.','Check receiver power, protocol and signal.'},
 {20,'THR','Throttle not low','Throttle is outside the allowed arming range.','Lower throttle and inspect receiver endpoints.'},
 {21,'CLI','CLI open','The command-line interface blocks arming.','Exit the FC CLI before attempting to arm.'},
 {22,'CMS','Configuration menu open','The flight-controller CMS menu blocks arming.','Leave the CMS menu.'},
 {23,'OSD','OSD menu open','An OSD menu blocks arming.','Exit the OSD menu.'},
 {24,'ROLL/PITCH','Sticks not centered','Roll or pitch is outside its required center range.','Center the sticks and verify receiver centers.'},
 {25,'AUTOTRIM','Servo autotrim active','Servo autotrim is selected.','Disable autotrim before attempting to arm.'},
 {26,'OOM','FC memory exhausted','The flight controller cannot allocate required memory.','Inspect the FC configuration and memory use.'},
 {27,'SETTINGFAIL','Invalid FC setting','At least one configuration value is invalid.','Inspect the FC reported setting error and correct it.'},
 {28,'PWMOUT','Output initialization failed','Motor or servo outputs could not initialize.','Inspect output resources and selected protocols.'},
 {29,'NOPREARM','Prearm not valid','The required prearm state is absent or expired.','Repeat the configured prearm procedure.'},
 {30,'DSHOTBEEPER','DShot beeper active','The DShot beeper mode is active.','Release the beeper mode before arming.'},
 {31,'LANDED','Landing detected','Landing detection prevents immediate rearming.','Check landing/rearm state for the installed release.'}
}
local patternCache,summaryCache={},{}
local function beepSummary(id)
 local s=summaryCache[id]
 if not s then s={id=id,long=math.floor(id/5),short=id%5};summaryCache[id]=s end
 return s
end
-- Training playback matches Toolbox's radio preview, not an FC command or a
-- promise that a particular firmware's complete beeper preamble sounds the same.
function M.beepPattern(reason)
 if type(reason)~='table'then return nil,'NO VERIFIED BEEP CODE'end
 local id=reason.beepId
 if id==nil and reason.known==true and type(reason.bit)=='number'then id=reason.bit+1 end
 if type(id)~='number'or id%1~=0.0 or id<1 or id>32 then return nil,'NO VERIFIED BEEP CODE'end
 local result=patternCache[id]
 if not result then
  local summary=beepSummary(id);result={id=id,long=summary.long,short=summary.short,tones={},preview=true}
  for i=1,summary.long do result.tones[#result.tones+1]={frequency=2400,duration=350,pause=i==summary.long and 400 or 200}end
  for i=1,summary.short do result.tones[#result.tones+1]={frequency=2400,duration=100,pause=200}end
  patternCache[id]=result
 end
 return result
end
local catalogues={}
local function familyName(family)
 if family=='BF'or family=='BTFL'or family=='Betaflight'then return 'BF'end
 if family=='INAV'or family=='IN'then return 'INAV'end
end
local function bfCatalogue(names,key,minor,mapped)
 if catalogues[key]then return catalogues[key]end
 local list={family='BF',reference=true,mappingKnown=mapped,basis='Betaflight 1.'..minor}
 if mapped then list.apiMajor=1;list.apiMinor=minor;list.flagCount=#names end
 for i,meta in ipairs(names)do
  local item={code=meta[1],title=meta[2],detail=meta[3],help=meta[4],known=true,reference=true,family='BF',referenceId=i,beepId=i,beep=beepSummary(i)}
  if mapped then item.bit=i-1 end
  list[i]=item
 end
 catalogues[key]=list;return list
end
function M.catalogue(family,major,minor,count)
 family=familyName(family)
 if family=='BF'then
  if major==1 and minor==44 and count==26 then return bfCatalogue(api144,'bf144',44,true)end
  if major==1 and minor==45 and count==26 then return bfCatalogue(api145,'bf145',45,true)end
  if major==1 and minor==46 and count==26 then return bfCatalogue(api146,'bf146',46,true)end
  if major==1 and minor==47 and count==29 then return bfCatalogue(api147,'bf147',47,true)end
  if major==1 and minor==48 and count==30 then return bfCatalogue(api148,'bf148',48,true)end
  -- Latest verified codebook, explicitly manual. No guessed version/bit map.
  return bfCatalogue(api148,'bfManual',48,false)
 elseif family=='INAV'then
  if catalogues.inav then return catalogues.inav end
  local list={family='INAV',reference=true,mappingKnown=false,basis='INAV 9.1.0 / historical Toolbox reference'}
  for i,meta in ipairs(inavReference)do
   local id=meta[1]
   list[i]={code=meta[2],title=meta[3],detail=meta[4],help=meta[5],known=true,reference=true,family='INAV',referenceId=id,beepId=id,beep=beepSummary(id),legacy=id==18}
  end
  catalogues.inav=list;return list
 end
 return nil,'UNSUPPORTED FC FAMILY'
end

local function isByte(v)
 return type(v)=='number' and v>=0 and v<=255 and v%1==0.0
end
function M.decode(data,major,minor)
 if type(data)~='table' then return nil,'NO STATUS PACKET' end
 local size=#data
 if size<21 or size>256 then return nil,'INVALID STATUS LENGTH' end
 if not isByte(data[16]) then return nil,'INVALID MODE HEADER' end
 local extra=data[16]%16
 local last=21+extra
 if size<last then return nil,'TRUNCATED STATUS FLAGS' end
 -- Validate all bytes before using any offsets or accepting a clear mask.
 for i=1,last do
  if not isByte(data[i]) then return nil,'INVALID STATUS BYTE' end
 end
 local count=data[17+extra]
 if count<1 or count>32 then return nil,'INVALID FLAG COUNT' end
 local p=18+extra
 -- Test each bit within its byte. EdgeTX uses 32-bit integers and floats;
 -- assembling a U32 would overflow signed integers or round away low bits.
 local function active(bit)
  return math.floor(data[p+math.floor(bit/8)]/2^(bit%8))%2==1
 end
 for bit=count,31 do
  if active(bit) then return nil,'FLAGS EXCEED COUNT' end
 end
 -- Unknown APIs/counts remain useful as numbered flags. Do not borrow the
 -- last ARM_SWITCH bit from an older API: newer versions insert flags before it.
 local names=major==1 and ((minor==44 and count==26 and api144) or (minor==45 and count==26 and api145) or (minor==46 and count==26 and api146) or (minor==47 and count==29 and api147) or (minor==48 and count==30 and api148)) or nil
 local result={count=count,reasons={},mappingKnown=names~=nil,extraModeBytes=extra,
  maskHex=string.format('%02X%02X%02X%02X',data[p+3],data[p+2],data[p+1],data[p]),
  maskBytes={data[p],data[p+1],data[p+2],data[p+3]}}
 for bit=0,count-1 do
  if active(bit) then
   local meta=names and names[bit+1] or nil
   local reason
   if meta then
    reason={bit=bit,code=meta[1],title=meta[2],detail=meta[3],help=meta[4],known=true}
   else
    reason={bit=bit,code='BIT '..bit,title='Unmapped arming flag',
     detail='The FC reports arming-disable bit '..bit..'.',
     help='Use the FC configurator for this API.',known=false}
   end
   result.reasons[#result.reasons+1]=reason
  end
 end
 return result
end
-- MSP2_INAV_STATUS (8192) is a different packet, not BF STATUS_EX.
-- These five exact official releases have a 13-byte prefix, an 8-byte mode
-- bitset (60 mode IDs rounded to two U32s), then one mixer-profile byte.
-- Raw armingFlags are bytes 10..13. Bits 2..5 are state indicators, not
-- arming blockers; 0,1,17,31 are not assigned blockers in these releases.
function M.decodeInav(data,major,minor,patch)
 local supported=(major==8 and minor==0 and(patch==0 or patch==1))
  or (major==9 and minor==0 and(patch==0 or patch==1))
  or (major==9 and minor==1 and patch==0)
 if not supported then return nil,'UNSUPPORTED INAV RELEASE'end
 if type(data)~='table'then return nil,'NO INAV STATUS PACKET'end
 if #data~=22 then return nil,'INVALID INAV STATUS LENGTH'end
 for i=1,22 do if not isByte(data[i])then return nil,'INVALID INAV STATUS BYTE'end end
 local function active(bit)
  return math.floor(data[10+math.floor(bit/8)]/2^(bit%8))%2==1
 end
 local result={family='INAV',statusCommand=8192,count=32,reasons={},mappingKnown=true,
  stateBitCount=0,blockerCount=24,
  maskHex=string.format('%02X%02X%02X%02X',data[13],data[12],data[11],data[10]),
  maskBytes={data[10],data[11],data[12],data[13]}}
 for bit=0,31 do
  if active(bit)then
   if bit>=2 and bit<=5 then
    result.stateBitCount=result.stateBitCount+1
   elseif bit>=6 and bit<=30 and bit~=17 then
    local meta=inavReference[bit-5]
    result.reasons[#result.reasons+1]={bit=bit,code=meta[2],title=meta[3],detail=meta[4],help=meta[5],known=true,family='INAV',beepId=bit+1}
   else
    result.mappingKnown=false
    result.reasons[#result.reasons+1]={bit=bit,code='BIT '..bit,title='Unmapped INAV status flag',
     detail='The FC reports unassigned status bit '..bit..'.',
     help='Check this status with the matching INAV configurator.',known=false,family='INAV'}
   end
  end
 end
 -- A clear blocker list is not a readiness/arming decision. In particular,
 -- neither ignored ARMED/history/simulator state nor zero proves safe to arm.
 return result
end
return M
