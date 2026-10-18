-- Read-only proposal picker. Choosing an input never binds, saves or writes it.
-- The caller owns the modal event route and explicit application settings Save.
local M={}
local floor,min,max=math.floor,math.min,math.max
local controls={
 {'pickerGroupPrevious',8,64,40,22,'PREVIOUS GROUP'},
 {'pickerGroupNext',432,64,40,22,'NEXT GROUP'},
 {'pickerRow1',8,88,464,18,'INPUT 1'},
 {'pickerRow2',8,106,464,18,'INPUT 2'},
 {'pickerRow3',8,124,464,18,'INPUT 3'},
 {'pickerRow4',8,142,464,18,'INPUT 4'},
 {'pickerRow5',8,160,464,18,'INPUT 5'},
 {'pickerRow6',8,178,464,18,'INPUT 6'},
 {'pickerPrevious',8,222,60,21,'PREV'},
 {'pickerNext',73,222,60,21,'NEXT'},
 {'pickerLearn',138,222,100,21,'LEARN'},
 {'pickerUse',243,222,109,21,'USE INPUT'},
 {'pickerCancel',357,222,115,21,'CANCEL'}
}
local groupNames={'OFF / NATIVE','SWITCH POSITIONS','SWITCHES / INVERTED','LOGICAL SWITCHES','LOGICAL / INVERTED','ANALOG CONTROLS','ANALOG / REVERSED','RAW SWITCH PREDICATES','SAVED / UNAVAILABLE'}
local roleNames={arm='ARM',cut='THROTTLE CUT',acro='ACRO',angle='ANGLE',horizon='HORIZON',air='AIR MODE',turtle='TURTLE',rth='RETURN TO HOME',wrth='WAYPOINT RTH',throttle='THROTTLE',limiter='LIMITER'}
local percentRoles={throttle=true,limiter=true}
local learnText={
 BASELINING={'KEEP ALL CONTROLS STILL','Capturing the starting positions.','Then move one intended input.'},
 LEARNING={'MOVE ONE INPUT','Move the desired switch or control.','Keep all other controls still.'},
 RESOLVING={'READING POSITION','Keep the chosen input in position.','Resolving its native switch name.'},
 AMBIGUOUS={'MORE THAN ONE INPUT MOVED','Keep other controls still.','Press LEARN to try again.'},
 TIMEOUT={'NO INPUT LEARNED','No clear movement before timeout.','Press LEARN to try again.'},
 UNAVAILABLE={'INPUT CANNOT BE LEARNED','No current input or position data.','Select a different group or retry.'},
 CANCELLED={'LEARNING CANCELLED','The saved binding is unchanged.','Browse inputs or press LEARN.'},
 FOUND={'INPUT FOUND','Review the name and current state.','USE INPUT returns this proposal.'}
}
local failureText={AMBIGUOUS='SEVERAL INPUTS MOVED / retry LEARN',TIMEOUT='TIMED OUT / retry LEARN',UNAVAILABLE='LEARNING UNAVAILABLE / select or retry',CANCELLED='LEARNING CANCELLED / binding unchanged'}
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function call(fn,...)
 if type(fn)~='function'then return nil end
 local ok,a,b=pcall(fn,...);if ok then return a,b end
end
local function identityLabel(identity)
 if identity=='OFF'then return'Off'end
 if identity=='NATIVE'then return'Native FC data'end
 if type(identity)~='string'then return'Unknown saved input'end
 local name=string.match(identity,'^SW:(.+)$')or string.match(identity,'^LS:(.+)$')
 if name then return name end
 name=string.match(identity,'^SRC!:(.+)$');if name then return name..' reversed'end
 name=string.match(identity,'^SRC:(.+)$');if name then return name end
 local field,predicate=string.match(identity,'^PRED:([^:]+):(.+)$')
 if field then return string.upper(field)..' '..string.gsub(predicate,'_',' ')end
 return'Saved input unavailable'
end
local function category(identity)
 if identity=='OFF'or identity=='NATIVE'then return 1 end
 if string.sub(identity,1,4)=='SW:!'then return 3 end
 if string.sub(identity,1,3)=='SW:'then return 2 end
 if string.sub(identity,1,4)=='LS:!'then return 5 end
 if string.sub(identity,1,3)=='LS:'then return 4 end
 if string.sub(identity,1,5)=='SRC!:'then return 7 end
 if string.sub(identity,1,4)=='SRC:'then return 6 end
 if string.sub(identity,1,5)=='PRED:'then return 8 end
 return 9
end
function M.new(options)
 options=options or{}
 local provider,lcd=options.provider,options.lcd
 if type(provider)~='table'or type(provider.choices)~='function'or type(lcd)~='table'or type(lcd.setColor)~='function'or type(lcd.drawText)~='function'or type(lcd.drawFilledRectangle)~='function'or type(lcd.sizeText)~='function'then return nil,'PICKER DEPENDENCY UNAVAILABLE'end
 local fonts=options.fonts or{};local small,tiny=fonts.small or 0x300,fonts.tiny or 0x200
 local flag=options.colorFlag or 0
 local state={active=false,status='CLOSED',learning=false,learnStatus='IDLE',focus=0,preview={state='UNAVAILABLE'},previewReady=false}
 local choices,groups,extras={}, {},{}
 local fallbackItems={}
 local selectedGroup,selectedRow,clock=1,1,nil
 local resultIdentity,resultStatus=nil,'CLOSED'
 local picker={controls=controls}
 local fitted={}
 local function palette()
  return type(options.palette)=='function'and options.palette()or options.palette or{}
 end
 local function fit(text,width,font)
  text=tostring(text or'');local key=text..'|'..width..'|'..font
  if fitted[key]then return fitted[key]end
  local measured=type(lcd.sizeText)=='function'and lcd.sizeText or nil
  if not measured then return string.sub(text,1,max(0,floor(width/9)))end
  if (measured(text,font)or 0)<=width then fitted[key]=text;return text end
  local value=text
  while #value>0 do
   local last=#value
   while last>1 and string.byte(value,last)>=128 and string.byte(value,last)<192 do last=last-1 end
   value=string.sub(value,1,last-1)
   if (measured(value..'...',font)or 0)<=width then value=value..'...';fitted[key]=value;return value end
  end
  fitted[key]='';return''
 end
 local function item(index)
  if type(index)=='number'and index<=0 then return extras[1-index]end
  local descriptor=choices.items and choices.items[index]
  if descriptor then return descriptor end
  local identity=choices[index];if not identity then return nil end
  if not fallbackItems[index]then fallbackItems[index]={identity=identity,label=choices.labels and choices.labels[index]or identityLabel(identity)}end
  return fallbackItems[index]
 end
 local function current()
  local group=groups[selectedGroup];return group and item(group.items[selectedRow])or nil
 end
 local function sync()
  local group=groups[selectedGroup];local selected=current()
  state.group=selectedGroup;state.groupCount=#groups;state.groupName=group and group.name or'NO INPUTS'
  state.selected=selectedRow;state.count=group and #group.items or 0
  state.offset=floor((selectedRow-1)/6)*6;state.page=floor((selectedRow-1)/6)+1;state.pages=max(1,math.ceil(state.count/6))
  state.identity=selected and selected.identity or nil;state.label=selected and selected.label or'No inputs'
  state.focusName=controls[state.focus]and controls[state.focus][1]or nil
 end
 local function invalidate()
  state.previewReady=false;state.preview.state='UNAVAILABLE';state.preview.value=nil;state.preview.error=nil
 end
 local function select(groupIndex,rowIndex)
  selectedGroup=max(1,min(#groups,groupIndex));local group=groups[selectedGroup]
  selectedRow=group and max(1,min(#group.items,rowIndex))or 1
  invalidate();sync()
 end
 local function find(identity)
  for groupIndex,group in ipairs(groups)do for row,index in ipairs(group.items)do
   if item(index).identity==identity then return groupIndex,row end
  end end
 end
 local function stopLearn()
  if state.learning then call(provider.cancelLearn)end
  state.learning=false
 end
 local function setFocus(index)state.focus=index;sync()end
 local function close(status,identity)
  stopLearn();state.active=false;state.status=status;resultStatus=status;resultIdentity=identity;state.focus=0;sync()
 end
 function picker.open(role,currentIdentity)
  stopLearn();choices=call(provider.choices,role)or{};groups={};fitted={};extras={};fallbackItems={}
  local buckets={};for i=1,#groupNames do buckets[i]={name=groupNames[i],kind=i,items={}}end
  for i,identity in ipairs(choices)do
   if type(identity)=='string'then local group=buckets[category(identity)];group.items[#group.items+1]=i end
  end
  local positionOrder={}
  local inv=call(provider.inventory)
  for _,position in ipairs(type(inv)=='table'and inv.predicates or{})do positionOrder[position.identity]=math.abs(position.index or 0)end
  for _,number in ipairs({2,3})do table.sort(buckets[number].items,function(a,b)
   local ai,bi=choices[a],choices[b];local ak,bk=positionOrder[ai],positionOrder[bi]
   if ak and bk and ak~=bk then return ak<bk end
   return ai<bi
  end)end
  for _,group in ipairs(buckets)do if #group.items>0 then groups[#groups+1]=group end end
  state.role=role;state.currentIdentity=currentIdentity;state.roleName=roleNames[role]or'INPUT'
  state.active=true;state.status='OPEN';state.learnStatus='IDLE';state.learning=false;resultIdentity=nil;resultStatus='OPEN';clock=nil
  local group,row=find(currentIdentity)
  if not group and type(currentIdentity)=='string'then
   extras[1]={identity=currentIdentity,label=identityLabel(currentIdentity),available=false}
   groups[#groups+1]={name=groupNames[9],kind=9,items={0}};group=#groups;row=1
  end
  if #groups==0 then close('UNAVAILABLE');return false,'NO INPUT CHOICES'end
  select(group or 1,row or 1);setFocus(3+(selectedRow-1)%6)
  return true
 end
 function picker.enabled(name)
  if not state.active then return false end
  if name=='pickerCancel'then return true end
  if name=='pickerLearn'then return type(provider.beginLearn)=='function'and type(provider.learn)=='function'end
  if state.learning then return false end
  if name=='pickerGroupPrevious'or name=='pickerGroupNext'then return #groups>1 end
  if name=='pickerPrevious'then return state.page>1 end
  if name=='pickerNext'then return state.page<state.pages end
  if name=='pickerUse'then return current()~=nil and state.previewReady and state.preview.error==nil end
  local row=string.match(name or'','^pickerRow([1-6])$')
  return row~=nil and state.offset+tonumber(row)<=state.count
 end
 function picker.move(delta)
  if not state.active or not finite(delta)or delta==0 then return false end
  local direction=delta>0 and 1 or -1;local index=state.focus
  for _=1,#controls do
   index=(index-1+direction)%#controls+1
   local name=controls[index][1]
   if picker.enabled(name)then
    local row=string.match(name,'^pickerRow([1-6])$')
    if row then select(selectedGroup,state.offset+tonumber(row));state.learnStatus='IDLE'end
    setFocus(index);return true
   end
  end
  return false
 end
 function picker.action(name,value)
  if name=='move'then return picker.move(value)end
  if name=='activate'then return picker.action(state.focusName)end
  if not picker.enabled(name)then return false end
  if name=='pickerCancel'then close('CANCELLED');return true
  elseif name=='pickerUse'then close('CHOSEN',state.identity);return true
  elseif name=='pickerGroupPrevious'or name=='pickerGroupNext'then
   local delta=name=='pickerGroupNext'and 1 or -1;select((selectedGroup-1+delta)%#groups+1,1);state.learnStatus='IDLE';setFocus(name=='pickerGroupNext'and 2 or 1)
  elseif name=='pickerPrevious'or name=='pickerNext'then
   local delta=name=='pickerNext'and 6 or -6;select(selectedGroup,state.offset+1+delta);state.learnStatus='IDLE';setFocus(name=='pickerNext'and 10 or 9)
  elseif name=='pickerLearn'then
   if state.learning then stopLearn();state.learnStatus='CANCELLED';invalidate();setFocus(11)
   else
    local now=finite(value)and value or clock
    if not finite(now)then state.learnStatus='UNAVAILABLE';return false,'LEARN CLOCK UNAVAILABLE'end
    local kind=groups[selectedGroup].kind
    local learnKind=(kind==4 or kind==5)and'logical'or(kind==6 or kind==7 or percentRoles[state.role])and'analog'or'switch'
    local ok=call(provider.beginLearn,learnKind,now)
    state.learning=ok==true;state.learnStatus=ok==true and'BASELINING'or'UNAVAILABLE';invalidate();setFocus(11)
   end
  else
   local row=tonumber(string.match(name,'^pickerRow([1-6])$'))
   select(selectedGroup,state.offset+row);state.learnStatus='IDLE';setFocus(12)
  end
  return true
 end
 function picker.activate()return picker.action(state.focusName)end
 function picker.hit(x,y)
  if not finite(x)or not finite(y)then return nil end
  for _,control in ipairs(controls)do
   if x>=control[2]and x<control[2]+control[4]and y>=control[3]and y<control[3]+control[5]and picker.enabled(control[1])then return control[1]end
  end
 end
 function picker.tick(now,native)
  if not state.active then return end
  if not finite(now)or clock and now<clock then
   stopLearn();state.learnStatus='CANCELLED';invalidate();clock=finite(now)and now or nil;return
  end
  clock=now
  if state.learning then
   local candidate,status=call(provider.learn,now)
   state.learnStatus=type(status)=='string'and status or'UNAVAILABLE'
   state.learning=status=='BASELINING'or status=='LEARNING'or status=='RESOLVING'
   if status=='FOUND'and type(candidate)=='table'and type(candidate.identity)=='string'then
    local group,row=find(candidate.identity)
    if not group then
     extras[#extras+1]={identity=candidate.identity,label=candidate.label or identityLabel(candidate.identity)}
     groups[#groups+1]={name='LEARNED INPUT',kind=9,items={1-#extras}};group=#groups;row=1
    end
    select(group,row);setFocus(12)
   end
   -- Baseline/motion/position callbacks consume the learning budget alone.
   return
  end
  local selected=current();local preview=selected and call(provider.preview,state.role,selected.identity,native)
  local out=state.preview
  out.state=type(preview)=='table'and preview.state or'UNAVAILABLE';out.value=type(preview)=='table'and preview.value or nil
  -- Preserve boolean false without Lua's and/or nil idiom.
  if type(preview)=='table'then out.value=preview.value;out.error=preview.error else out.error='PREVIEW UNAVAILABLE'end
  state.previewReady=true
 end
 function picker.result()return resultIdentity,resultStatus end
 function picker.snapshot()return state end
 local function rect(x,y,w,h,color)
  lcd.setColor(flag,color);lcd.drawFilledRectangle(x,y,w,h,flag)
 end
 local function text(x,y,h,value,color,font,width)
  font=font or small;value=fit(value,width or 460,font)
  local _,height=lcd.sizeText(value,font);height=height or(font==tiny and 12 or 17)
  lcd.setColor(flag,color);lcd.drawText(x,y+floor((h-height)/2),value,flag+font)
 end
 function picker.draw(focusName)
  if not state.active then return end
  local p=palette();local bg=p.black or p.bg or 0;local panel=p.tape or p.panel or bg;local fg=p.white or 0;local muted=p.muted or fg;local green=p.green or fg;local cyan=p.cyan or green;local orange=p.orange or fg
  focusName=focusName or state.focusName
  rect(5,62,470,182,bg);rect(8,64,464,22,panel)
  text(56,64,22,state.groupName,fg,small,316)
  text(378,64,22,state.page..'/'..state.pages,muted,tiny,48)
  for index=1,2 do
   local control=controls[index];local focused=focusName==control[1];rect(control[2],control[3],control[4],control[5],focused and cyan or panel)
   text(control[2]+15,control[3],control[5],index==1 and'<'or'>',focused and bg or picker.enabled(control[1])and fg or muted,small,24)
  end
  local message=learnText[state.learnStatus]
  if state.learning then
   for i,line in ipairs(message or learnText.UNAVAILABLE)do text(16,96+(i-1)*25,22,line,i==1 and orange or fg,small,448)end
  else
   for row=1,6 do
    local selectedIndex=state.offset+row;local group=groups[selectedGroup];local entry=group and item(group.items[selectedIndex])
    if entry then
     local y=88+(row-1)*18;local name='pickerRow'..row;local focused=focusName==name;local selected=selectedIndex==selectedRow
     rect(8,y,464,18,focused and green or panel)
     if selected and not focused then rect(8,y,3,18,green)end
     local col=focused and bg or fg;local saved=entry.identity==state.currentIdentity
     text(16,y,18,entry.label,col,small,saved and 370 or 448)
     if saved then text(416,y,18,'SAVED',focused and bg or muted,tiny,48)end
    end
   end
  end
  local preview=state.preview;local value
  if state.learning then value=state.learnStatus=='BASELINING'and'Keep still / building baseline'or'Learning / move only one input'
  elseif failureText[state.learnStatus]then value=failureText[state.learnStatus]
  elseif not state.previewReady then value=state.learnStatus=='FOUND'and'INPUT FOUND / review, then USE'or'Waiting for current preview'
  elseif preview.error then value=preview.error
  elseif preview.state=='OFF'then value='OFF / NOT CONFIGURED'
  elseif preview.state~='LIVE'then value='UNAVAILABLE / no current value'
  elseif type(preview.value)=='boolean'then value='LIVE / '..(preview.value and'ACTIVE'or'INACTIVE')
  elseif finite(preview.value)then value=string.format('LIVE / %.0f%%',preview.value)
  else value='UNAVAILABLE / no current value'end
  text(12,199,20,value,preview.state=='LIVE'and cyan or muted,small,456)
  for index=9,13 do
   local control=controls[index];local enabled=picker.enabled(control[1]);local focused=enabled and focusName==control[1]
   rect(control[2],control[3],control[4],control[5],focused and cyan or panel)
   local caption=index==11 and state.learning and'STOP LEARN'or control[6]
   text(control[2]+6,control[3],control[5],caption,focused and bg or enabled and fg or muted,small,control[4]-12)
  end
 end
 return picker
end
return M
