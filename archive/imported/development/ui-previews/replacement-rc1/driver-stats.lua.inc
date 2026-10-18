
  -- DEVELOPMENT ONLY: post-run bounded counters; production source unchanged.
  if ok then
   local qaNow,qaUsage=getTime(),getUsage();local qaData=w.app.snapshot()
   if not w.qaWindow then w.qaWindow=qaNow;w.qaFrames=0;w.qaChanges=0;w.qaPublications=0;w.qaMaxUsage=0;w.qaMinUsage=100;w.qaUsageSum=0 end
   w.qaFrames=w.qaFrames+1;w.qaUsageSum=w.qaUsageSum+qaUsage;if qaUsage>w.qaMaxUsage then w.qaMaxUsage=qaUsage end;if qaUsage<w.qaMinUsage then w.qaMinUsage=qaUsage end
   if qaData then
    if qaData~=w.qaData then w.qaPublications=w.qaPublications+1;w.qaData=qaData end
    if qaData.pitch~=w.qaPitch or qaData.roll~=w.qaRoll then w.qaChanges=w.qaChanges+1;w.qaPitch=qaData.pitch;w.qaRoll=qaData.roll end
   end
   if qaNow-w.qaWindow>=1000 then
    print('QA_DRAW_STATS|'..w.qaWindow..'|'..qaNow..'|'..w.qaFrames..'|'..w.qaChanges..'|'..w.qaPublications..'|'..w.qaMinUsage..'|'..w.qaMaxUsage..'|'..math.floor(w.qaUsageSum/w.qaFrames*10)/10)
    w.qaWindow=qaNow;w.qaFrames=0;w.qaChanges=0;w.qaPublications=0;w.qaMaxUsage=0;w.qaMinUsage=100;w.qaUsageSum=0
   end
  end