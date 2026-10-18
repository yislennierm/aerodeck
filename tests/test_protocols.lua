-- Native protocol fixtures from original Toolbox bytecode, not live-radio proof.
-- Original evidence: LIB-TLM-TLMRLD; TBS/RL(main/0); FRS/GYRO_{BF,IN}(main/0);
-- FRS/FC_{BF,IN}(main/0); FRS/GPS_{BF,IN}(main/0), under the deep parity audit.
local M=assert(loadfile('sdcard/SCRIPTS/TOOLS/AERODECK/protocols.lua'))()
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function near(actual,expected,why)check(type(actual)=='number' and math.abs(actual-expected)<0.00001,why)end
local function value(field,raw,unit,p)
 local actual,err,source=M.normalize(field,raw,unit,p)
 check(err==nil and type(source)=='string','valid normalization returns provenance, no error: '..field)
 return actual
end
local function rejected(field,raw,unit,p,expected)
 local actual,err=M.normalize(field,raw,unit,p)
 check(actual==nil and err==expected,'reject '..field..' as '..expected..', got '..tostring(err))
end
local el=M.profile('ELRS / CRSF','ELRS 3.x','Betaflight')
local el2=M.profile('ELRS / CRSF','ELRS 2.x','Betaflight')
local gemini=M.profile('ELRS / CRSF','ELRS Gemini','Betaflight')
local xf=M.profile('TBS Crossfire','Crossfire','Betaflight')
local tracer=M.profile('TBS Crossfire','Tracer','Betaflight')
local fr=M.profile('FrSky','ACCST','Betaflight')
local r9=M.profile('FrSky','R9','INAV')
local inav=M.profile('ELRS / CRSF','EL3','INAV')

-- Exact original protocol defaults, with LQ and RSSI units kept separate.
for _,p in ipairs({el,el2,gemini,xf,tracer,fr,r9,inav})do
 check(p.supported and p.fcSupported,'recognized protocol/subtype/family is supported')
 check(#p.assumptions==0,'an explicit subtype is not presented as auto-discovered firmware')
 check(p.capabilities.acceleration=='CONDITIONAL / REFERENCE DISABLED','disabled acceleration module is not claimed as a working feed')
 check(p.capabilities.individualCells=='UNVERIFIED PRODUCER','module capability cannot invent individual-cell data')
end
for _,p in ipairs({el,el2,gemini,inav})do
 check(p.thresholds.lqLow==20 and p.thresholds.lqCrit==10,'ELRS defaults are20/10, not Crossfire80/70')
 check(p.thresholds.rssiLow==-94 and p.thresholds.rssiCrit==-102 and p.rssiUnit=='dBm','ELRS RSSI defaults and units match original')
end
for _,p in ipairs({xf,tracer})do check(p.thresholds.lqLow==80 and p.thresholds.lqCrit==70,'Crossfire/Tracer original LQ defaults')end
for _,p in ipairs({fr,r9})do
 check(p.thresholds.rssiLow==40 and p.thresholds.rssiCrit==30 and p.rssiUnit=='%','FrSky defaults are percentage RSSI40/30')
 check(p.thresholds.lqLow==nil and p.thresholds.lqCrit==nil and p.fields.lq==nil,'FrSky percentage RSSI is not fabricated into LQ')
end
local auto=M.profile('ELRS / CRSF','Auto','Betaflight')
check(auto.subtype=='EL3' and auto.assumptions[1]=='SUBTYPE DEFAULT EL3','Auto is explicitly an assumption, not firmware detection')
check(M.profile('TBS Tracer',nil,'BF').subtype=='TRS' and M.profile('FrSky R9',nil,'INAV').subtype=='R9','protocol-specific default subtype routing')
for _,args in ipairs({{'Other','EL3','BF'},{'ELRS / CRSF','ELRS 4.x','BF'},{'FrSky','EL3','BF'},{'None',nil,'BF'}})do
 local p=M.profile(args[1],args[2],args[3])
 check(not p.supported and next(p.fields)==nil and p.error~=nil,'unknown/cross-family profile cannot inherit misleading source conventions')
end
check(M.profile('FrSky','ACCST','Unknown').fields.pitch==nil,'unknown FC cannot borrow a numeric attitude/FC encoding')

-- Native battery aliases preserve pack/receiver/auxiliary/consumption provenance.
check(el.aliases.v[1]=='RxBt' and el.aliases.mah[1]=='Capa' and el.aliases.pct[1]=='Bat%','CRSF pack and consumption aliases match the native backend')
check(fr.aliases.v[1]=='VFAS' and fr.aliases.rxV[1]=='RxBt' and fr.aliases.mah[1]=='Fuel','FrSky distinguishes FC pack from receiver voltage and Fuel')
check(fr.aliases.v[2]==nil and el.aliases.v[2]==nil,'Auto pack aliases do not silently mix different protocol voltage meanings')
for i=1,4 do check(fr.aliases['a'..i][1]=='A'..i,'FrSky auxiliary/direct-cell alias remains independent')end
check(fr.fields.a4.convention=='DIRECT CELL SENSOR' and not fr.fields.pct,'A4 is directly reported voltage, no fake battery percent')
check(not fr.fields.tx and r9.aliases.tx[1]=='R9PW' and el.aliases.tx[1]=='TPWR','R9PW only exists onR9, CRSF usesTPWR')
near(value('v',0,'VOLT',el),0,'real zero pack voltage is valid')
near(value('a',0,'AMPERE',el),0,'real zero current is valid')
near(value('mah',0,'MILLIAMPERE_HOUR',el),0,'real zero consumed capacity is valid')
near(value('pct',0,'PERCENT',el),0,'reported zero percentage is valid')
near(value('receiverVoltage',5,'V',fr),5,'receiver voltage has its own field')
near(value('a4',3.9,'V',fr),3.9,'direct cell sensor is not divided by configured cell count')
rejected('pct',70,'%',fr,'UNSUPPORTED FIELD')
rejected('rxV',5,'V',el,'UNSUPPORTED FIELD')
local d,err=M.info('voltage',fr)
check(d==fr.fields.v and err==nil,'descriptor lookup uses canonical alias without a false error')
local unsupported,unsupportedError=M.info('fabricated',el)
check(unsupported==nil and unsupportedError=='UNSUPPORTED FIELD','unknown field capability is explicit')
local other=M.profile('ELRS / CRSF','EL3','BF');other.aliases.v[1]='CUSTOM'
check(el.aliases.v[1]=='RxBt','one profile caller cannot mutate another instance source aliases')

-- All supported numeric conversions preserve valid zero, bounds and raw inputs.
for _,case in ipairs({
 {'speed',10,'KNOT',18.52},{'speed',10,'MPH',16.09344},{'speed',10,'METER_PER_SECOND',36},{'speed',10,'FEET_PER_SECOND',10.9728},
 {'speed',10,'KMH',10},{'alt',100,'FEET',30.48},{'baro',-20,'METERS',-20},{'vspeed',-10,'FEET_PER_SECOND',-3.048},
 {'a',1250,'MILLIAMPERE',1.25},{'mah',1.5,'AMPERE_HOUR',1500},{'tx',0.25,'WATT',250},{'hdg',math.pi,'RADIAN',180},
 {'aspd',10,nil,18.52}
})do near(value(case[1],case[2],case[3],el),case[4],'correct physical conversion for '..case[1]..'/'..tostring(case[3]))end
for _,field in ipairs({'v','a','mah','pct','lq','rssi','snr','tx','rf','txlq','sats','speed','alt','baro','vspeed','hdg'})do
 local fieldInfo=el.fields[field]
 near(value(field,0,fieldInfo.unit,el),0,'genuine zero survives '..field)
 rejected(field,nil,fieldInfo.unit,el,'MISSING')
 rejected(field,0/0,fieldInfo.unit,el,'INVALID')
 rejected(field,math.huge,fieldInfo.unit,el,'INVALID')
 rejected(field,'0',fieldInfo.unit,el,'INVALID')
end
rejected('v',-1,'VOLT',el,'OUT OF RANGE')
rejected('pct',101,'PERCENT',el,'OUT OF RANGE')
rejected('rssi',40,'PERCENT',el,'UNIT MISMATCH')
rejected('rssi',-90,'DBM',fr,'UNIT MISMATCH')
rejected('sats',13.5,'NONE',el,'OUT OF RANGE')
rejected('rf',7.5,'NONE',el,'OUT OF RANGE')
rejected('speed',20,'unrecognized unit',el,'UNKNOWN UNIT')
rejected('speed',20,9876,el,'UNKNOWN UNIT')
-- Unit IDs here are deliberately synthetic; caller injects actual EdgeTX constants.
el.unitNames[777]='UNIT_NOT_MAPPED';el.unitNames[778]='RADIAN';el.unitNames[779]='DEGREE';el.unitNames[780]='NONE'
rejected('pitch',1,777,el,'UNKNOWN UNIT')
near(value('pitch',math.pi/6,778,el),-30,'caller-provided numeric radian unit is resolved without guessed native enum')
near(value('roll',30,779,el),30,'caller-provided numeric degree unit preserves roll')
near(value('sats',0,780,el),0,'known native RAW/NONE metadata is valid for counts')

-- Verified TBS pitch convention: radians invert only pitch, degrees already normalized.
for _,angle in ipairs({-math.pi,-math.pi/6,0,math.pi/6,math.pi})do
 near(value('pitch',angle,'RADIAN',el),-angle*180/math.pi,'CRSF pitch radians match original signed transform')
 near(value('roll',angle,'RADIAN',el),angle*180/math.pi,'CRSF roll radians retain sign')
 near(value('yaw',angle,'RADIAN',el),angle*180/math.pi,'CRSF yaw radians retain sign')
end
near(value('pitch',20,'DEGREE',el),20,'CRSF degree producer input is already normalized, not inverted twice')
rejected('pitch',0,nil,el,'UNKNOWN UNIT')
rejected('pitch',0,'NONE',el,'UNIT MISMATCH')
check(fr.aliases.pitch[1]=='5230' and fr.aliases.roll[1]=='5240' and r9.aliases.pitch[1]=='0430' and r9.aliases.roll[1]=='0440','BF/INAV numeric attitude source aliases are distinct')
near(value('pitch',200,nil,fr),-20,'BF unknown-metadata native numeric pitch uses deci-degree convention')
near(value('roll',-200,'NONE',fr),-20,'BF raw numeric roll divides by10 with original sign')
near(value('pitch',20,'DEGREE',fr),-20,'BF declared degree bypasses /10 but still inverts pitch')
near(value('pitch',200,'DEGREE',r9),-20,'INAV original numeric pitch always divides by10, even with degree label')
near(value('roll',-200,nil,r9),-20,'INAV numeric roll retains sign after /10')
rejected('pitch',1,'RADIAN',r9,'UNIT MISMATCH')

-- Genuine FrSky encoded GPS status is different from count-only CRSF data.
check(fr.aliases.gpsStatus[1]=='Tmp2' and r9.aliases.gpsStatus[1]=='0480','family-specific GPS status aliases')
local bfGps=M.decodeGPS(1713,fr)
check(bfGps.fix==true and bfGps.sats==13 and bfGps.qualityIndex==7 and bfGps.homeFix==nil,'BF Tmp2 A bit0 / B quality / CD satellites')
local inGps=M.decodeGPS(3812,r9)
check(inGps.fix==true and inGps.homeFix==true and inGps.sats==12 and inGps.qualityIndex==8,'INAV0480 additionally exposes home fix bit1')
check(inGps.qualityKind=='REPORTED ENCODED INDEX' and inGps.hdop==nil and inGps.fixType==nil,'encoded quality/fix boolean are not mislabeled physical HDOP or3D type')
local noFix=M.decodeGPS(0,r9)
check(noFix.fix==false and noFix.homeFix==false and noFix.sats==0 and noFix.qualityIndex==0,'zero status is explicitly decoded, not treated as missing')
for _,raw in ipairs({-1,10000,3.2,'1713',0/0,math.huge})do local v,e=M.decodeGPS(raw,fr);check(v==nil and e=='INVALID GPS STATUS','invalid numeric GPS status is rejected')end
local missingGps,missingGpsError=M.decodeGPS(nil,fr)
check(missingGps==nil and missingGpsError=='MISSING','absent GPS status never becomes an invented no-fix/sats0 record')
local crsfGps,crsfGpsError=M.decodeGPS(13,el)
check(crsfGps==nil and crsfGpsError=='UNSUPPORTED GPS STATUS','CRSF satellite count is never interpreted as encoded fix/HDOP')
check(el.capabilities.fix=='UNSUPPORTED' and el.capabilities.hdop=='UNSUPPORTED','unsupported CRSF fix/HDOP capability remains explicit')
for _,point in ipairs({{lat=0,lon=0},{lat=90,lon=180},{lat=-90,lon=-180}})do check(value('gps',point,nil,el)==point,'current coordinate table including valid bounds/zero is accepted without data invention')end
for _,point in ipairs({{lat=91,lon=0},{lat=0,lon=181},{lat=0/0,lon=0},{lat=0,lon=math.huge}})do rejected('gps',point,nil,el,'INVALID')end

-- FC native arming/mode conventions, not MSP disabling-mask/readiness claims.
for _,case in ipairs({
 {'ACRO',true,false,'ACRO'},{'ACRO*',false,false,'ACRO'},{'ACRO?',false,false,'ACRO'},{'ACRO!',false,true,'ACRO'},
 {'HORIZON',true,false,'HORIZON'},{'FS',true,false,'FS'}
})do local fc=M.decodeFC(case[1],el);check(fc.armed==case[2] and fc.armBlocked==case[3] and fc.mode==case[4],'BF CRSF native FM convention '..case[1])end
for _,case in ipairs({{'OK',false,false},{'WAIT',false,false},{'0',false,false},{'ACRO',true,false},{'ANGLE!',false,true},{'RTH',true,false}})do
 local fc=M.decodeFC(case[1],inav);check(fc.armed==case[2] and fc.armBlocked==case[3],'INAV CRSF own disarm convention '..case[1])
end
for _,case in ipairs({{0,false,false,'ACRO'},{4,true,false,'ACRO'},{14,true,false,'ANGL'},{24,true,false,'HOR'},{44,true,false,'PASS'},{2,false,true,'ERR'},{16,true,true,'ERR'}})do
 local fc=M.decodeFC(case[1],fr);check(fc.armed==case[2] and fc.armBlocked==case[3] and fc.mode==case[4],'BF Tmp1 native numeric flags/mode '..case[1])
 check(fc.ready==nil,'numeric arm status never claims FC readiness')
end
local inavModes={{4,'ACRO'},{40004,'FS'},{44,'MANU'},{1000004,'WRTH'},{2000004,'ANGH'},{200004,'TURT'},{100004,'LAND'},{400004,'GEO'},{800004,'LOTR'},{1004,'RTH'},{2004,'WP'},{4004,'HEAD'},{8004,'CRSH'},{404,'HOLD'},{304,'CRUZ'},{204,'ALT'},{14,'ANGL'},{24,'HOR'},{0,'OK'},{2,'ERR'}}
for _,case in ipairs(inavModes)do local fc=M.decodeFC(case[1],r9);check(fc.mode==case[2],'INAV0470 original priority catalogue '..case[1]..'→'..case[2])end
check(M.decodeFC(1040044,r9).mode=='FS','INAV failsafe wins over manual/RTH/other lower-priority modes')
check(M.decodeFC(1001044,r9).mode=='MANU','INAV manual wins over WRTH/RTH')
check(M.decodeFC(1001004,r9).mode=='WRTH','INAV WRTH wins overRTH')
for _,raw in ipairs({'',string.rep('A',33),'ACRO\n',42,false,'!'})do local fc,e=M.decodeFC(raw,el);check(fc==nil and e=='INVALID FC STATUS','malformed CRSF flight status is not interpreted')end
for _,raw in ipairs({-1,100000,1.2,'14',math.huge})do local fc,e=M.decodeFC(raw,fr);check(fc==nil and e=='INVALID FC STATUS','malformed BF numeric status is rejected')end
local fcNil,fcError=M.decodeFC(nil,fr);check(fcNil==nil and fcError=='MISSING','no FC packet means unknown armed state, not false')

-- Exact RF mode lookup by version; unknown codes remain numerically observable.
local el3Names={[0]='-','25','50','100','100F','150','200','250','333F','500','D250','D500','F500','F1k'}
for code=0,13 do local caption,e=M.rfCaption(code,el);check(caption==el3Names[code] and e==nil,'ELRS3 original RF enum '..code)end
local el2Names={[0]='-','25','50','100','150','200','250','500'}
for code=0,7 do check(M.rfCaption(code,el2)==el2Names[code],'ELRS2 original RF enum '..code)end
for code,name in pairs({[0]='4','50','150'})do check(M.rfCaption(code,xf)==name,'Crossfire original RF enum '..code)end
check(M.rfCaption(1,tracer)=='250','Tracer packet-rate caption is250')
for _,p in ipairs({gemini,el,el2,xf,tracer})do local caption,e=M.rfCaption(250,p);check(caption=='250' and e=='UNKNOWN RF MODE','unknown RF index retained without guessed caption')end
local geminiCaption,geminiError=M.rfCaption(7,gemini)
check(geminiCaption=='7' and geminiError=='UNKNOWN RF MODE','Gemini never borrows an unproven ELRS3 RF enum')
near(value('rf',250,'NONE',el),250,'future raw RF index is retained for honest unknown presentation')
near(M.bestRssi(-100,-85,el),-85,'CRSF uses the stronger valid negative antenna reading')
near(M.bestRssi(-100,0,el),-100,'unpopulated second antenna0 does not mask real negative RSSI')
near(M.bestRssi(nil,-85,el),-85,'valid second antenna remains useful when the first is missing')
near(M.bestRssi(40,90,fr),40,'FrSky percentage RSSI never applies CRSF diversity combining')
local best,bestError=M.bestRssi(nil,nil,el);check(best==nil and bestError~=nil,'both missing antennas never become a numeric zero')

print('protocols: '..checks..' checks passed')
