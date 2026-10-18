-- Decompiled by cLuaDecompiler (Lua 5.1 to 5.5 Decompiler) --
-- Contact: Coldzer0@protonmail.ch | Discord : Coldzer0 --
-- Copyright (c) 2019 - 2026 --
-- "ASC.luac" was compiled with Lua 5.3 --

local G = ...
local all = {[1] = {"NOGYRO", "A gyro was not detected", "Possibly hardware failure. If a previous firmware version works it may be a firmware issue or you have flashed a wrong target.", 1},
             [2] = {"FAILSAFE", "Failsafe is active", "Rectify the failure condition and try again.", 2},
             [3] = {"RXLOSS", "No valid receiver signal is detected", "Your receiver is either faulty or has no link to the transmitter.", 3},
             [4] = {"BADRX", "Your receiver has just recovered from receiver failsafe but the arm switch is on", "Switch the arm switch off.", 4},
             [5] = {"BOXFAILSAFE", "The FAILSAFE switch was activated", "See FAILSAFE", 5},
             [6] = {"RUNAWAY", "Runway Takeoff Prevention has been triggered", "Disarm to clear this condition.", 6},
             [7] = {"CRASH", "Crash Recovery has been triggered", "Disarm to clear this condition.", 7},
             [8] = {"THROTTLE", "Throttle channel is too high", "Lower throttle below min_check.", 8},
             [9] = {"ANGLE", "Craft is not level (enough)", "Level craft to within small_angle degrees (default 25).", 9},
             [10] = {"BOOTGRACE", "Arming too soon after power on", "Wait until pwr_ON_arm_grace seconds (default 5) have elapsed.", 10},
             [11] = {"NOPREARM", "Prearm switch is not activated or prearm has not been toggled after disarm", "Toggle the prearm switch.", 11},
             [12] = {"LOAD", "System load is too high for safe flight", "Revisit configuration and disable features.", 12},
             [13] = {"CALIB", "Sensor calibration is still ongoing", "Wait for sensor calibration to complete.", 13},
             [14] = {"CLI", "CLI is active", "Exit the CLI.", 14},
             [15] = {"CMS", "CMS (config menu) is Active - over OSD or other display", "Exit the CMS (or OSD menu).", 15},
             [16] = {"BST", "BST device (ex TBS Core Pro) disarmed and is preventing arming", "Refer to the manual for your hardware.", 16},
             [17] = {"MSP", "MSP connection is active, probably via Betaflight Configurator", "Terminate the Betaflight Configurator connection (disconnect).", 17},
             [18] = {"PARALYZE", "Paralyze mode has been activated", "Power cycle/reset FC board.", 18},
             [19] = {"GPS", "GPS rescue mode is configured but required number of satellites has not been fixed", "Wait for GPS fix, enable arming without GPS fix, or disable GPS rescue mode.", 19},
             [20] = {"RESCUE_SW", "GPS Rescue switch is in an unsafe position", "Turn off the GPS Rescue switch to arm.", 20},
             [21] = {"RPMFILTER", "Motor RPM-based filtering is not functioning", "One or more ESC's are not supplying valid RPM telemetry.", 21},
             [22] = {"REBOOT_REQD", "Reboot required", "Reboot the flight controller for settings changes to take effect.", 22},
             [23] = {"DSHOT_BBANG", "DSHOT Bitbang is not working", "", 23},
             [24] = {"NO_ACC_CAL", "Accelerometer calibration required", "Calibrate the accelerometer or disable features that use it", 24},
             [25] = {"MOTOR_PROTO", "ESC/Motor Protocol not configured", "Select the ESC/Motor protocol to use on the Configuration tab.", 25}}
if D.FC.API_VERSION and tonumber(D.FC.API_VERSION) >= 1.47000002861023 then
  all[#all + 1] = {"CRASH_FLIP", "Crash Flip mode is enabled", "Disable Crash Flip mode to arm.", #all + 1}
  all[#all + 1] = {"ALT_HOLD", "Altitude Hold mode is enabled", "Disable Altitude Hold mode to arm.", #all + 1}
  t7 = {"POS_HOLD", "Position Hold mode is enabled", "Disable Position Hold mode to arm.", #all + 1}
  all[#all + 1] = t7
end
all[#all + 1] = {"ARMSWITCH", "Arm switch is in an unsafe position", "Toggle the arm switch to arm.", #all + 1}
local asList = {}
if D.FC.ARMSTOPS then
  for i, v in ipairs(D.FC.ARMSTOPS) do
    local asNo = v[1]
    asList[#asList + 1] = all[asNo]
  end
else
  asList = all
end
return asList

