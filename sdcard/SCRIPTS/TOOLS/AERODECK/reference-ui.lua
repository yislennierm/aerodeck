-- Body-only arming reference / manual stick guide UI. No transport, sensor,
-- model or channel access. Parent owns freshness, navigation and native events.
local M={}
local floor,min,max=math.floor,math.min,math.max
local function family(value)
 if value=='BF'or value=='BTFL'or value=='Betaflight'then return 'BF'end
 if value=='INAV'or value=='IN'then return 'INAV'end
end
local lineGap=1
local axes={{3,4,5,2},{3,2,5,4},{5,4,3,2},{5,2,3,4}}
local function integer(value)return type(value)=='number'and value==value and value%1==0.0 end
local function control(id,x,y,w,h,caption)return{id,x,y,w,h,caption}end
local armControls={
 control('armFilter',8,64,132,21,'LIVE / REFERENCE'),
 control('armFamily',148,64,112,21,'REFERENCE FAMILY'),
 control('armPreview',268,64,112,21,'BEEP PREVIEW'),
 control('armPrev',388,64,38,21,'PREVIOUS REASONS'),control('armNext',434,64,38,21,'NEXT REASONS'),
 control('armDetailUp',148,222,45,21,'SCROLL DETAILS UP'),control('armDetailDown',198,222,55,21,'SCROLL DETAILS DOWN')
}
local guideControls={
 control('guideFamily',8,64,140,21,'GUIDE FAMILY'),control('guideMode',156,64,106,21,'STICK MODE'),
 control('guidePrev',270,64,45,21,'PREVIOUS GUIDES'),control('guideNext',323,64,45,21,'NEXT GUIDES'),
 control('guideNoteUp',376,64,44,21,'SCROLL NOTE UP'),control('guideNoteDown',428,64,44,21,'SCROLL NOTE DOWN')
}
for row=1,6 do armControls[#armControls+1]=control('armRow'..row,8,88+(row-1)*22,132,22,'SELECT REASON '..row)end
for row=1,5 do guideControls[#guideControls+1]=control('guideRow'..row,8,89+(row-1)*24,300,24,'SELECT GUIDE '..row)end
function M.new(options)
 options=options or{}
 local decoder,reference,lcd=options.arm,options.reference,options.lcd
 if type(decoder)~='table'or type(decoder.catalogue)~='function'or type(decoder.beepPattern)~='function'
  or type(reference)~='table'or type(reference.guide)~='function'then return nil,'REFERENCE MODULES UNAVAILABLE'end
 if type(lcd)~='table'or type(lcd.sizeText)~='function'or type(lcd.drawText)~='function'
  or type(lcd.drawFilledRectangle)~='function'or type(lcd.setColor)~='function'then return nil,'REFERENCE LCD UNAVAILABLE'end
 local fonts=options.fonts or{}
 local tiny,small=fonts.tiny or 0x200,fonts.small or 0x300
 local colorFlag=options.colorFlag or 0
 local paint=options.palette
 if type(paint)~='function'then local fixed=paint or{};paint=function()return fixed end end
 local tone=options.tone
 local armMode,refFamily,guideFamily='LIVE','BF','BF'
 local manualArmFamily,manualGuideFamily=false,false
 local contextFamily,major,minor,count
 local liveDecoded,liveAvailable,liveStatus,liveError=nil,false,'MISSING',nil
 local selectedArm,selectedGuide,stickMode=1,1,options.mode or 2
 if stickMode<1 or stickMode>4 or stickMode%1~=0.0 then stickMode=2 end
 local armList,guideList={},{}
 local armLines,guideLines={},{}
 local armScroll,guideScroll=1,1
 local preview,previewIndex,due,lastTick,beepError=nil,1,nil,nil,nil
 local state={reference=false,view='LIVE',liveAvailable=false,status='MISSING',mode=stickMode}
 local api={armControls=armControls,guideControls=guideControls}
 local armLabels={'LIVE FLAGS','FC --','PLAY BEEP','<','>','UP','DOWN'}
 local guideLabels={'BF GUIDES','MODE '..stickMode,'<','>','UP','DN'}
 local function stop()
  preview=nil;previewIndex=1;due=nil
 end
 api.stop=stop
 local function width(text,size)local w=lcd.sizeText(text,size);return w end
 local function height(size)local _,h=lcd.sizeText('Ag',size);return h end
 local tinyHeight,smallHeight=height(tiny),height(small)
 if type(tinyHeight)~='number'or tinyHeight<=0 or type(smallHeight)~='number'or smallHeight<=0 then return nil,'REFERENCE FONT METRICS UNAVAILABLE'end
 local function utf8Next(text,index)
  local b=string.byte(text,index)or 0
  return index+(b>=240 and 4 or b>=224 and 3 or b>=192 and 2 or 1)
 end
 local function fit(text,available,size)
  text=tostring(text or'')
  if width(text,size)<=available then return text end
  local result,index='',1
  while index<=#text do
   local nextIndex=utf8Next(text,index);local nextText=result..string.sub(text,index,nextIndex-1)
   if width(nextText..'...',size)>available then break end
   result=nextText;index=nextIndex
  end
  return result..'...'
 end
 local function appendWrapped(rows,text,available,size,role)
  text=tostring(text or'')
  if #text>4096 then text=string.sub(text,1,4096)..' [REFERENCE TEXT TRUNCATED]'end
  local line=''
  local function add(s)rows[#rows+1]={text=s,size=size,height=size==tiny and tinyHeight or smallHeight,role=role}end
  for word in string.gmatch(text,'%S+')do
   local combined=line==''and word or line..' '..word
   if width(combined,size)<=available then line=combined
   else
    if line~=''then add(line);line=''end
    if width(word,size)<=available then line=word
    else
     local index=1
     while index<=#word do
      local nextIndex=utf8Next(word,index);local character=string.sub(word,index,nextIndex-1)
      if line~=''and width(line..character,size)>available then add(line);line=''end
      line=line..character;index=nextIndex
     end
    end
   end
  end
  if line~=''then add(line)end
 end
 local function selectedReason()return armList[selectedArm]end
 local function makeArmLines()
  armLines={};armScroll=1
  local item=selectedReason()
  if item then
   if armMode=='REFERENCE'and armList.basis then appendWrapped(armLines,armList.basis,304,tiny,'orange')end
   appendWrapped(armLines,item.title,304,small,'white')
   appendWrapped(armLines,item.detail,304,small,'white')
   appendWrapped(armLines,'CHECK',304,tiny,'cyan')
   appendWrapped(armLines,item.help,304,small,'muted')
  else
   appendWrapped(armLines,liveAvailable and'No disable flags reported'or'Live status unavailable',304,small,liveAvailable and'white'or'orange')
   appendWrapped(armLines,liveAvailable and'This does not prove armed state or readiness.'or(liveError or'No current decoded FC status is available.'),304,small,'muted')
   appendWrapped(armLines,'Select REFERENCE for the offline codebook.',304,small,'muted')
  end
 end
 local function makeGuideLines()
  guideLines={};guideScroll=1
  local item=guideList[selectedGuide]
  if not item then appendWrapped(guideLines,'Guide unavailable',140,small,'orange');return end
  appendWrapped(guideLines,item.label or item[1],140,small,'white')
  appendWrapped(guideLines,item.context or'Disarmed',140,tiny,'orange')
  if guideList.basis then appendWrapped(guideLines,guideList.basis,140,tiny,'muted')end
  appendWrapped(guideLines,item.note or'Follow the installed FC release and feature requirements. This is a manual stick reference.',140,small,'muted')
 end
 local function refreshArm(previous)
  if armMode=='REFERENCE'then
   local same=refFamily==contextFamily
   armList=decoder.catalogue(refFamily,same and major or nil,same and minor or nil,same and count or nil)or{}
  else armList=liveAvailable and liveDecoded.reasons or{}end
  selectedArm=min(max(1,selectedArm),max(1,#armList))
  if previous then for index,item in ipairs(armList)do if item.code==previous.code and item.bit==previous.bit then selectedArm=index;break end end end
  makeArmLines()
 end
 local function refreshGuide()
  guideList=reference.guide(guideFamily)or{}
  selectedGuide=min(max(1,selectedGuide),max(1,#guideList));makeGuideLines()
 end
 function api.setContext(fcFamily,apiMajor,apiMinor,flagCount)
  local newFamily=family(fcFamily)
  if contextFamily==newFamily and major==apiMajor and minor==apiMinor and count==flagCount then return end
  contextFamily=newFamily;major=apiMajor;minor=apiMinor;count=flagCount
  if newFamily and not manualArmFamily then refFamily=newFamily end
  if newFamily and not manualGuideFamily and guideFamily~=newFamily then guideFamily=newFamily;selectedGuide=1;refreshGuide()end
  if armMode=='REFERENCE'then stop();refreshArm()end
 end
 function api.setLive(decoded,fresh,status,errorText)
  local available=fresh==true and type(decoded)=='table'and type(decoded.reasons)=='table'
  local safeStatus=available and'LIVE'or(errorText and'ERROR'or(status=='OLD'or status=='STATUS OLD')and'OLD'or'MISSING')
  local normalized=available and decoded or nil
  if normalized==liveDecoded and available==liveAvailable and safeStatus==liveStatus and errorText==liveError then return end
  local previous=selectedReason()
  liveDecoded=available and decoded or nil;liveAvailable=available;liveStatus=safeStatus;liveError=errorText
  if armMode=='LIVE'then
   refreshArm(previous)
   local current=selectedReason()
   if not available or not current or not previous or current.code~=previous.code or current.bit~=previous.bit then stop()end
  end
 end
 local function scrollLimit(rows,viewHeight)
  if #rows==0 then return 1 end
  local total=0;local first=#rows
  for index=#rows,1,-1 do
   local nextHeight=rows[index].height+lineGap
   if total+nextHeight>viewHeight then break end
   total=total+nextHeight;first=index
  end
  return max(1,first)
 end
 local function selectedArmPage()return floor((selectedArm-1)/6)end
 local function selectedGuidePage()return floor((selectedGuide-1)/5)end
 function api.enabled(area,id)
  if area=='arm'then
   if id=='armFilter'then return true end
   if id=='armFamily'then return armMode=='REFERENCE'end
   if id=='armPreview'then return preview~=nil or type(tone)=='function'and decoder.beepPattern(selectedReason())~=nil end
   if id=='armPrev'then return selectedArmPage()>0 end
   if id=='armNext'then return(selectedArmPage()+1)*6<#armList end
   if id=='armDetailUp'then return armScroll>1 end
   if id=='armDetailDown'then return armScroll<scrollLimit(armLines,105)end
   local row=tonumber(id and string.match(id,'^armRow(%d+)$'))
   return row and row>=1 and row<=6 and armList[selectedArmPage()*6+row]~=nil or false
  end
  if area=='guide'then
   if id=='guideFamily'or id=='guideMode'then return true end
   if id=='guidePrev'then return selectedGuidePage()>0 end
   if id=='guideNext'then return(selectedGuidePage()+1)*5<#guideList end
   if id=='guideNoteUp'then return guideScroll>1 end
   if id=='guideNoteDown'then return guideScroll<scrollLimit(guideLines,105)end
   local row=tonumber(id and string.match(id,'^guideRow(%d+)$'))
   return row and row>=1 and row<=5 and guideList[selectedGuidePage()*5+row]~=nil or false
  end
  return false
 end
 function api.armAction(action,value)
  if action=='move'or action=='armSelect'then
   if action=='move'and not integer(value==nil and 1 or value)then return false end
   local n=action=='move'and selectedArm+(value==nil and 1 or value)or value
   if type(n)~='number'or n%1~=0.0 or #armList==0 then return false end
   n=min(max(1,n),#armList)
   if n~=selectedArm then selectedArm=n;stop();makeArmLines()end
   return true
  end
  if not api.enabled('arm',action)then return false end
  if action=='armFilter'then armMode=armMode=='LIVE'and'REFERENCE'or'LIVE';selectedArm=1;stop();refreshArm()
  elseif action=='armFamily'then refFamily=refFamily=='BF'and'INAV'or'BF';manualArmFamily=true;selectedArm=1;stop();refreshArm()
  elseif action=='armPrev'or action=='armNext'then
   selectedArm=min(max(1,(selectedArmPage()+(action=='armNext'and 1 or-1))*6+1),#armList);stop();makeArmLines()
  elseif action=='armDetailUp'or action=='armDetailDown'then armScroll=min(max(1,armScroll+(action=='armDetailDown'and 1 or-1)),scrollLimit(armLines,105))
  elseif action=='armPreview'then
   if preview then stop()else preview=decoder.beepPattern(selectedReason());previewIndex=1;due=nil;beepError=nil end
  else
   local row=tonumber(string.match(action,'^armRow(%d+)$'))
   if row then return api.armAction('armSelect',selectedArmPage()*6+row)end
  end
  return true
 end
 function api.guideAction(action,value)
  if action=='move'or action=='guideSelect'then
   if action=='move'and not integer(value==nil and 1 or value)then return false end
   local n=action=='move'and selectedGuide+(value==nil and 1 or value)or value
   if type(n)~='number'or n%1~=0.0 or #guideList==0 then return false end
   n=min(max(1,n),#guideList)
   if n~=selectedGuide then selectedGuide=n;makeGuideLines()end
   return true
  end
  if not api.enabled('guide',action)then return false end
  if action=='guideFamily'then guideFamily=guideFamily=='BF'and'INAV'or'BF';manualGuideFamily=true;selectedGuide=1;refreshGuide()
  elseif action=='guideMode'then if not integer(value==nil and 1 or value)then return false end;stickMode=(stickMode+(value==nil and 1 or value)-1)%4+1;guideLabels[2]='MODE '..stickMode
  elseif action=='guidePrev'or action=='guideNext'then selectedGuide=min(max(1,(selectedGuidePage()+(action=='guideNext'and 1 or-1))*5+1),#guideList);makeGuideLines()
  elseif action=='guideNoteUp'or action=='guideNoteDown'then guideScroll=min(max(1,guideScroll+(action=='guideNoteDown'and 1 or-1)),scrollLimit(guideLines,105))
  else
   local row=tonumber(string.match(action,'^guideRow(%d+)$'))
   if row then return api.guideAction('guideSelect',selectedGuidePage()*5+row)end
  end
  return true
 end
 function api.tick(now)
  if type(now)~='number'or now~=now or now==math.huge or now==-math.huge or now<0 then return false end
  if lastTick and now<lastTick then stop()end
  lastTick=now
  if not preview or due and now<due then return false end
  local nextTone=preview.tones[previewIndex]
  if not nextTone then stop();return false end
  -- playTone returns no result in EdgeTX2.12.4. One normal-priority tone/call,
  -- no immediate-priority flag, loops, sleeps, radio writes or queue draining.
  local ok,errorText=pcall(tone,nextTone.frequency,nextTone.duration,nextTone.pause)
  if not ok then beepError=tostring(errorText);stop();return false end
  due=now+math.ceil((nextTone.duration+nextTone.pause)/10)
  previewIndex=previewIndex+1
  return true
 end
 function api.snapshot()
  state.reference=armMode=='REFERENCE';state.view=armMode;state.liveAvailable=liveAvailable;state.status=liveStatus
  state.contextFamily=contextFamily;state.referenceFamily=refFamily;state.guideFamily=guideFamily
  state.referenceBasis=armMode=='REFERENCE'and armList.basis or nil;state.guideBasis=guideList.basis
  state.armCount=#armList;state.armSelected=selectedArm;state.armPage=selectedArmPage()+1;state.armPages=max(1,math.ceil(#armList/6))
  state.guideCount=#guideList;state.guideSelected=selectedGuide;state.guidePage=selectedGuidePage()+1;state.guidePages=max(1,math.ceil(#guideList/5))
  state.mode=stickMode;state.playing=preview~=nil;state.previewIndex=previewIndex;state.beepError=beepError
  state.armScroll=armScroll;state.armScrollMax=scrollLimit(armLines,105);state.armLineCount=#armLines
  state.guideScroll=guideScroll;state.guideScrollMax=scrollLimit(guideLines,105);state.guideLineCount=#guideLines
  return state
 end
 function api.hit(area,x,y)
  local controls=area=='arm'and armControls or area=='guide'and guideControls
  if not controls or type(x)~='number'or type(y)~='number'then return end
  for _,item in ipairs(controls)do if x>=item[2]and x<item[2]+item[4]and y>=item[3]and y<item[3]+item[5]and api.enabled(area,item[1])then return item[1]end end
 end
 local function ink(color)lcd.setColor(colorFlag,color)end
 local function rect(x,y,w,h,color)ink(color);lcd.drawFilledRectangle(x,y,w,h,colorFlag)end
 local function text(x,y,h,value,color,size)
  ink(color);local measured=size==tiny and tinyHeight or smallHeight
  lcd.drawText(x,y+floor((h-measured)/2),value,colorFlag+size)
 end
 local function button(item,caption,enabled,p,focus)
  rect(item[2],item[3],item[4],item[5],p.tape)
  if focus==item[1]then rect(item[2],item[3],item[4],1,p.cyan);rect(item[2],item[3]+item[5]-1,item[4],1,p.cyan)end
  local shown=fit(caption,item[4]-12,small)
  text(item[2]+6,item[3],item[5],shown,enabled and p.cyan or p.muted,small)
 end
 local function drawLines(rows,first,x,y,w,h,p)
  local at=y;local last=first-1
  for index=first,#rows do
   local row=rows[index]
   if at+row.height>y+h then break end
   text(x,at,row.height,row.text,p[row.role]or p.white,row.size)
   at=at+row.height+lineGap;last=index
  end
  return last
 end
 function api.drawArm(focus)
  local p=paint();rect(4,62,472,182,p.black)
  armLabels[1]=armMode=='LIVE'and'LIVE FLAGS'or'REFERENCE'
  local shownFamily=armMode=='LIVE'and contextFamily or refFamily
  armLabels[2]=shownFamily=='BF'and'BETAFLIGHT'or shownFamily=='INAV'and'INAV'or'FC --'
  armLabels[3]=preview and'STOP BEEP'or'PLAY BEEP'
  for i=1,7 do local item=armControls[i];button(item,armLabels[i],api.enabled('arm',item[1]),p,focus)end
  rect(8,88,132,132,p.tape);rect(148,88,324,132,p.tape)
  local offset=selectedArmPage()*6
  for row=1,6 do
   local item=armList[offset+row]
   if item then
    local y=88+(row-1)*22;local selected=offset+row==selectedArm
    rect(8,y,132,21,selected and p.cyan or(row%2==0 and p.black or p.tape))
    text(15,y,21,fit(item.code,118,small),selected and p.black or p.white,small)
   end
  end
  local item=selectedReason()
  local heading=armMode=='REFERENCE'and'OFFLINE REFERENCE'or(liveAvailable and(item and'LIVE BIT '..tostring(item.bit)or'NO FLAGS')or'STATUS '..liveStatus)
  text(156,91,18,fit(heading,304,tiny),armMode=='REFERENCE'and p.orange or p.muted,tiny)
  drawLines(armLines,armScroll,156,113,304,105,p)
  if scrollLimit(armLines,105)>1 then text(416,91,18,armScroll..'/'..#armLines,p.muted,tiny)end
  rect(8,222,132,21,p.tape)
  local range=#armList>0 and(offset+1)..'-'..min(offset+6,#armList)..' / '..#armList or(liveAvailable and'0 FLAGS'or'NO LIVE DATA')
  text(15,222,21,range,p.muted,tiny)
  local pattern=item and decoder.beepPattern(item)
  if pattern then
   text(261,222,21,'CODE '..pattern.id,p.muted,tiny)
   local x=324
   for i,t in ipairs(pattern.tones)do
    local w=t.duration>=350 and 12 or 4
    rect(x,228,w,9,preview and i==previewIndex-1 and p.cyan or p.muted);x=x+w+3
   end
  else text(261,222,21,beepError and'BEEP UNAVAILABLE'or'NO VERIFIED BEEP CODE',p.muted,tiny)end
 end
 local function diagram(x,y,horizontal,vertical,p)
  rect(x,y,18,18,p.border);rect(x+1,y+1,16,16,p.black)
  rect(x+8,y+2,1,14,p.dim);rect(x+2,y+8,14,1,p.dim)
  rect(x+6+horizontal*5,y+6-vertical*5,5,5,p.green)
 end
 function api.drawGuide(focus)
  local p=paint();rect(4,62,472,182,p.black)
  guideLabels[1]=guideFamily=='BF'and'BF GUIDES'or'INAV GUIDES'
  for i=1,6 do local item=guideControls[i];button(item,guideLabels[i],api.enabled('guide',item[1]),p,focus)end
  local offset=selectedGuidePage()*5;local map=axes[stickMode]
  for row=1,5 do
   local item=guideList[offset+row]
   if item then
    local y=89+(row-1)*24;local selected=offset+row==selectedGuide
    rect(8,y,300,23,selected and p.tape or p.black)
    if selected then rect(8,y,2,23,p.cyan)end
    diagram(14,y+2,item[map[1]],item[map[2]],p);diagram(38,y+2,item[map[3]],item[map[4]],p)
    text(64,y,23,fit(item.label or item[1],236,small),p.white,small)
   end
  end
  rect(316,89,156,131,p.tape)
  text(324,92,18,'MANUAL GUIDE',p.orange,tiny)
  local last=drawLines(guideLines,guideScroll,324,113,140,105,p)
  rect(8,222,300,21,p.tape);text(16,222,21,'MANUAL ONLY / NO COMMANDS',p.orange,tiny)
  rect(316,222,156,21,p.tape)
  text(324,222,21,guideScroll..'-'..last..' / '..#guideLines,p.muted,tiny)
 end
 refreshArm();refreshGuide()
 return api
end
return M
