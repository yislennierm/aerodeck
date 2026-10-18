-- Read-only fixture evaluation of the current AERODECK configuration schema.
local realio=io
local f=assert(realio.open('/Users/nene/Documents/fpv-1/radiomaster_tx16s_mkII/LUA/sdcard/SCRIPTS/TOOLS/telem.lua'))
local source=f:read('*a');f:close()
local finish=assert(source:find('\nfunction fcLink.update',1,true))
source=source:sub(1,finish-1)
local anchor='return {canOpen=function(id)'
local start=assert(source:find(anchor,1,true))
source=source:sub(1,start-1)..'return {auditSections=sections,auditSchema=schema,auditVisible=visible,canOpen=function(id)'..source:sub(start+#anchor)
source=source..'\nreturn configuration\n'
getTime=function()return 0 end
model={getInfo=function()return {name='AUDIT FIXTURE'}end,getSensor=function(i)return ({ {name='CustomFM',unit=0},{name='Curr',unit=2},{name='RxBt',unit=1} })[i+1]end}
io={open=function()return nil end}
local config=assert(loadstring(source))();config.init()
local defaults={};for key,value in pairs(config.auditSchema)do defaults[key]=value.default end
local result={sections={},defaults=defaults,visibility={}}
for index,section in ipairs(config.auditSections)do
 local out={index=index,name=section.name,rows={}}
 for rowIndex,row in ipairs(section.rows)do
  local copy={index=rowIndex,key=row.key,label=row.label,default=row.default,lo=row.lo,hi=row.hi,step=row.step,choices=row.choices,note=row.note}
  out.rows[#out.rows+1]=copy
 end
 result.sections[#result.sections+1]=out
end
local function clone(t)local c={};for k,v in pairs(t)do c[k]=v end;return c end
result.visibility.factory=config.auditVisible(defaults)
local active=clone(defaults);active.rcProtocol='ELRS / CRSF';active.fcType='Betaflight';active.vtxMode=2
result.visibility.allFeatures=config.auditVisible(active)
local disabled=clone(active);disabled.voltage='None';result.visibility.voltageDisabled=config.auditVisible(disabled)
local gpsOff=clone(active);gpsOff.gps='None';result.visibility.gpsDisabled=config.auditVisible(gpsOff)
local noRc=clone(active);noRc.rcProtocol='None';result.visibility.rcProtocolNone=config.auditVisible(noRc)
config.refreshSensorChoices({'LateFM','Curr','RxBt'})
result.afterRefreshFlightModeChoices={model=config.auditSections[1].rows[14].choices,beta=config.auditSections[7].rows[1].choices}
io=realio
local function json(v)
 local t=type(v)
 if t=='nil'then return 'null'elseif t=='boolean'or t=='number'then return tostring(v)elseif t=='string'then
  return '"'..v:gsub('[%z\1-\31\\"]',function(c)return ({['\\']='\\\\',['"']='\\"',['\n']='\\n',['\r']='\\r',['\t']='\\t'})[c]or string.format('\\u%04x',c:byte())end)..'"'
 elseif t=='table'then
  local array=true;local count=0;for k in pairs(v)do count=count+1;if type(k)~='number'then array=false end end
  if array and count==#v then local a={};for i,item in ipairs(v)do a[i]=json(item)end;return '['..table.concat(a,',')..']'end
  local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys)
  local a={};for _,k in ipairs(keys)do a[#a+1]=json(k)..':'..json(v[k])end;return '{'..table.concat(a,',')..'}'
 end
 error('Unsupported '..t)
end
print(json(result))
