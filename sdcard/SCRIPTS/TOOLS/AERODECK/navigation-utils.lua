-- Pure navigation formatting, independently implemented from published OLC rules.
-- Caller owns telemetry freshness/fix and coordinate validity. A code is an area,
-- not a GPS-accuracy claim. No reads, writes, sensor APIs or retained positions.
-- OLC specification: google/open-location-code Documentation/Specification/
-- olc_definition.adoc; official encoding.csv vectors are development fixtures.
-- Original Toolbox GPSINIT main/1 and main/4 confirm relative-bearing and
-- 11-digit Plus Code capabilities; recovered encoder tables/branches are damaged.
local M={}
local alphabet='23456789CFGHJMPQRVWX'
local floor,abs=math.floor,math.abs
local nativeFloat32=1+0.00000001==1
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function letter(index)return string.sub(alphabet,index+1,index+1)end
-- Split degrees BEFORE adding90/180: the reference's4.5e9-unit latitude
-- exceeds native int32, and adding offsets in float32 drops coordinate bits.
-- Pair integers stay <=2,880,000; residual grid integers stay <=3,125.
-- Exact binary float32 fractional product without a large float/int product.
-- A normalized24-bit mantissa times the bounded precision fits three12-bit
-- limbs. Every limb operation stays in signed int32; division occurs only after
-- removing a remainder, when its known integer quotient is <=8,000.
local function nativeParts(value,scale)
 local positive=abs(value);local whole=floor(positive);local fraction=positive-whole
 if fraction==0.0 then return value<0 and-whole*8000 or whole*8000,0 end
 local shifts=0
 while fraction<0.5 do fraction=fraction*2;shifts=shifts+1 end
 local mantissa=floor(fraction*16777216)
 local low=mantissa%4096;local high=floor(mantissa/4096)
 local precision=8000*scale;local pLow=precision%4096
 local pHigh=floor((precision-pLow)/4096)
 local productLow=low*pLow
 local middle=high*pLow+low*pHigh+floor(productLow/4096)
 local productHigh=high*pHigh+floor(middle/4096)
 local remainder=productLow%4096~=0 or middle%4096~=0
 for _=1,shifts do
  local odd=productHigh%2;if odd~=0 then remainder=true end
  productHigh=floor((productHigh-odd)/2)
  if productHigh==0 then break end
 end
 local units=productHigh
 if value<0 and remainder then units=units+1 end
 local grid=units%scale
 local pair=whole*8000+floor((units-grid)/scale+0.5)
 if value<0 then pair=-pair;if grid>0 then pair=pair-1;grid=scale-grid end end
 return pair,grid
end
local function parts(value,scale)
 if nativeFloat32 then return nativeParts(value,scale)end
 local positive=abs(value);local whole=floor(positive)
 local scaled=(positive-whole)*8000
 local pair=floor(scaled+0.00000001)
 local remainder=math.max(0,scaled-pair)
 if remainder<0.00000001 and(whole>0 or pair>0)then remainder=0 end
 local tail=remainder*scale;local nearest=floor(tail+0.5)
 -- Remove only sub-micrometre arithmetic noise near exact decimal boundaries;
 -- do not turn tiny signed coordinates around0 into unsigned zero.
 if abs(tail-nearest)<0.000001 and(nearest>0 or whole>0 or pair>0)then tail=nearest end
 local grid=floor(tail);pair=pair+whole*8000
 if value<0 then
  if tail>grid then grid=grid+1 end
  if grid>=scale then pair=pair+1;grid=0 end
  pair=-pair
  if grid>0 then pair=pair-1;grid=scale-grid end
 elseif grid>=scale then pair=pair+1;grid=0 end
 return pair,grid
end
function M.encode(latitude,longitude,length)
 if not finite(latitude)or not finite(longitude)then return nil,'INVALID COORDINATES'end
 if length==nil then length=10 end
 if not finite(length)or length%1~=0.0 or length<2 or(length<10 and length%2~=0)then return nil,'INVALID CODE LENGTH'end
 length=math.min(length,15)
 -- Standard OLC clipping/normalization; callers must reject invalid GPS first.
 latitude=math.max(-90,math.min(90,latitude))
 if longitude<-180 or longitude>=180 then longitude=longitude%360;if longitude>=180 then longitude=longitude-360 end end
 local lat,latGrid=parts(latitude,3125);local lon,lonGrid=parts(longitude,1024)
 lat=lat+720000;lon=lon+1440000
 -- North pole belongs to the last encodable cell, at every requested precision.
 if lat>=1440000 then lat=1439999;latGrid=3124 end
 local code=''
 for _=1,5 do
  code=letter(lat%20)..letter(lon%20)..code
  lat=floor(lat/20);lon=floor(lon/20)
 end
 local latPlace,lonPlace=625,256
 for _=11,length do
  local row,column=floor(latGrid/latPlace),floor(lonGrid/lonPlace)
  code=code..letter(row*4+column)
  latGrid=latGrid%latPlace;lonGrid=lonGrid%lonPlace
  latPlace=latPlace/5;lonPlace=lonPlace/4
 end
 if length<8 then return string.sub(code,1,length)..string.rep('0',8-length)..'+'end
 return string.sub(code,1,8)..'+'..string.sub(code,9,length)
end
-- Home azimuth and aircraft course use the same clockwise-from-north reference.
--0 is ahead,+90 right,-90 left; exactly opposite is-180. No inferred course.
function M.relativeBearing(homeAzimuth,course)
 if not finite(homeAzimuth)or not finite(course)then return nil,'MISSING OR INVALID BEARING'end
 -- Normalize separately, avoiding overflow if two large signed values differ.
 return ((homeAzimuth%360-course%360)+180)%360-180
end
-- Straight-line duration at the supplied positive ground speed, not a return
-- prediction. Caller supplies current distance/speed in metres and km/h.
function M.formatETA(distanceMetres,speedKmh)
 if not finite(distanceMetres)or distanceMetres<0 or not finite(speedKmh)or speedKmh<=0 then return nil,'MISSING OR INVALID DISTANCE / SPEED'end
 local seconds=distanceMetres/speedKmh*3.6
 if not finite(seconds)or seconds>359999 then return nil,'ETA OUT OF RANGE'end
 seconds=floor(seconds)
 if seconds>=3600 then return string.format('%02d:%02d:%02d',floor(seconds/3600),floor(seconds/60)%60,seconds%60),seconds end
 return string.format('%02d:%02d',floor(seconds/60),seconds%60),seconds
end
return M
