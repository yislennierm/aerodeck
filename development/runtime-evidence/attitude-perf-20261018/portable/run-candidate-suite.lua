local candidate=assert(arg[1]);local test=assert(arg[2]);local open=io.open
io.open=function(path,...)
 if path=='sdcard/SCRIPTS/TOOLS/telem.lua'then return open(candidate,...)end
 return open(path,...)
end
loadstring=loadstring or load;unpack=unpack or table.unpack
assert(loadfile(test))()
