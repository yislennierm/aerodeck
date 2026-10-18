-- Pure, bounded Betaflight MSP_STATUS_EX arming-disable decoder.
-- No FC/radio writes, transport, sensor reads, or global state.
-- Call once per received packet; retain the result with the packet timestamp.
-- A zero mask reports no disable flags; it never proves armed/ready status.
local M={}
M.sources={
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
local function isByte(v)
 return type(v)=='number' and v>=0 and v<=255 and v%1==0
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
 local names=major==1 and ((minor==46 and count==26 and api146) or (minor==47 and count==29 and api147) or (minor==48 and count==30 and api148)) or nil
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
return M
