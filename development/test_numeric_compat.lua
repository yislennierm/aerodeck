local root=arg[1]or'.'
local module=assert(loadfile(root..'/development/numeric_compat_checks.lua'))()
local function load(name)return assert(loadfile(root..'/sdcard/SCRIPTS/TOOLS/AERODECK/'..name..'.lua'))()end
local failures={};local test=module.new(load,function(name,pass,why)if not pass then failures[#failures+1]=name..' '..why end end)
while not test.step()do end
local result=test.snapshot()
assert(result.failed==0,table.concat(failures,'\n'))
print('Numeric compatibility: '..result.checks..' actual-module checks PASS (host; native checker runs same cases)')
