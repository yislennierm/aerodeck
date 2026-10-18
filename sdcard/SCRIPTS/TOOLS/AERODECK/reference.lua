-- Manual stick guides. This module never sends controls, changes settings,
-- calibrates sensors or arms a model. Tuple order: label,throttle,yaw,pitch,roll;
-- each axis is -1 low, 0 center, +1 high. The UI maps axes to radio modes 1..4.
-- Cached tables are read-only to callers. Firmware features/settings still apply.
local M={sources={
 bfControls='https://github.com/betaflight/betaflight/blob/2026.6.2/src/main/fc/rc_controls.c#L256-L378',
 bfCms='https://github.com/betaflight/betaflight/blob/2026.6.2/src/main/cms/cms.c#L1390-L1419',
 inavControls='https://github.com/iNavFlight/inav/blob/9.1.0/docs/Controls.md#stick-positions',
 inavRc='https://github.com/iNavFlight/inav/blob/9.1.0/src/main/fc/rc_controls.c#L260-L373',
 inavCms='https://github.com/iNavFlight/inav/blob/9.1.0/src/main/cms/cms.c#L1254-L1269'
},reference=true,sendsCommands=false}
local bf={
 {'Save FC settings',-1,-1,-1,1},
 {'PID profile 1',-1,-1,0,-1},
 {'PID profile 2',-1,-1,1,0},
 {'PID profile 3',-1,-1,0,1},
 {'In-flight calibration*',-1,-1,1,1,note='Requires the in-flight accelerometer calibration feature; this starts its FC-managed procedure.'},
 {'Calibrate compass',1,1,-1,0,note='Requires compass support.'},
 {'Calibrate gyro',-1,-1,-1,0,note='While disarmed. This may also reset GPS home/barometer ground level when those features exist.'},
 {'Calibrate accelerometer',1,-1,-1,0},
 {'Accel trim left / rate 4*',1,0,0,-1,note='ANGLE/HORIZON: accelerometer trim. ACRO: rate profile 4. Release throttle after trims to save.'},
 {'Accel trim right / rate 3*',1,0,0,1,note='ANGLE/HORIZON: accelerometer trim. ACRO: rate profile 3. Release throttle after trims to save.'},
 {'Accel trim forward / rate 1*',1,0,1,0,note='ANGLE/HORIZON: accelerometer trim. ACRO: rate profile 1. Release throttle after trims to save.'},
 {'Accel trim back / rate 2*',1,0,-1,0,note='ANGLE/HORIZON: accelerometer trim. ACRO: rate profile 2. Release throttle after trims to save.'},
 {'OSD menu open',0,-1,1,0,context='CMS closed'},
 {'OSD save / exit menu',0,1,0,0,context='CMS open',note='Opens save/exit choices; this is not an immediate exit.'},
 {'OSD enter submenu',0,0,0,1,context='CMS submenu row'},
 {'OSD back',0,-1,0,0,context='CMS open'},
 {'OSD previous option',0,0,1,0,context='CMS open'},
 {'OSD next option',0,0,-1,0,context='CMS open'},
 {'OSD decrease value',0,0,0,-1,context='CMS value row'},
 {'OSD increase value',0,0,0,1,context='CMS value row'}
}
local inav={
 {'Save FC settings',-1,-1,-1,1},
 {'Control profile 1',-1,-1,0,-1,note='Requires TX profile selection enabled.'},
 {'Control profile 2',-1,-1,1,0,note='Requires TX profile selection enabled.'},
 {'Control profile 3',-1,-1,0,1,note='Requires TX profile selection enabled.'},
 {'Battery profile 1',1,-1,0,-1,note='Requires TX profile selection enabled; changes the FC battery profile.'},
 {'Battery profile 2',1,-1,1,0,note='Requires TX profile selection enabled; changes the FC battery profile.'},
 {'Battery profile 3',1,-1,0,1,note='Requires TX profile selection enabled; changes the FC battery profile.'},
 {'Compass calibrate / yaw zero',1,1,-1,0,note='With a compass: calibrate. Without one: may zero/trust heading; consult the installed INAV release.'},
 {'Calibrate gyro',-1,-1,-1,0},
 {'Calibrate accelerometer',1,-1,-1,0},
 {'Accel trim left',1,0,0,-1,note='Changes and saves FC board alignment while disarmed.'},
 {'Accel trim right',1,0,0,1,note='Changes and saves FC board alignment while disarmed.'},
 {'Accel trim forward',1,0,1,0,note='Changes and saves FC board alignment while disarmed.'},
 {'Accel trim back',1,0,-1,0,note='Changes and saves FC board alignment while disarmed.'},
 {'Load waypoint mission',-1,0,1,1,note='Requires nonvolatile waypoint storage.'},
 -- Toolbox duplicated Save/Unload. Official 9.1.0 docs and rc_controls.c agree:
 {'Save waypoint mission',-1,0,1,-1,note='Requires nonvolatile waypoint storage; writes the current mission.'},
 {'Unload waypoint mission',-1,0,-1,1,note='Clears the active waypoint list; requires the supported FC feature.'},
 {'Increase mission index',-1,0,0,1,note='Requires multi-mission support. Throttle LOW and yaw CENTER, unlike the old Toolbox tuple.'},
 {'Decrease mission index',-1,0,0,-1,note='Requires multi-mission support. Throttle LOW and yaw CENTER, unlike the old Toolbox tuple.'},
 {'Bypass nav arming checks*',-1,1,0,0,note='Requires nav_extra_arming_safety=ALLOW_BYPASS and use of the arm switch. Bypasses navigation safety checks; this guide sends nothing.'},
 {'OSD menu open',0,-1,1,0,context='CMS closed'},
 {'OSD save / exit menu',0,1,0,0,context='CMS open',note='Opens save/exit choices; this is not an immediate exit.'},
 {'OSD enter submenu',0,0,0,1,context='CMS submenu row'},
 {'OSD back',0,-1,0,0,context='CMS open'},
 {'OSD previous option',0,0,1,0,context='CMS open'},
 {'OSD next option',0,0,-1,0,context='CMS open'},
 {'OSD decrease value',0,0,0,-1,context='CMS value row'},
 {'OSD increase value',0,0,0,1,context='CMS value row'}
}
local function prepare(list,family,basis)
 list.family=family;list.basis=basis;list.reference=true;list.sendsCommands=false
 for i,item in ipairs(list)do
  item.id=i;item.reference=true;item.label=item[1]
  item.t=item[2];item.y=item[3];item.p=item[4];item.r=item[5]
  item.context=item.context or 'Disarmed'
 end
 return list
end
prepare(bf,'BF','Betaflight 2026.6.2');prepare(inav,'INAV','INAV 9.1.0')
function M.guide(family)
 if family=='BF'or family=='BTFL'or family=='Betaflight'then return bf end
 if family=='INAV'or family=='IN'then return inav end
 return nil,'UNSUPPORTED FC FAMILY'
end
return M
