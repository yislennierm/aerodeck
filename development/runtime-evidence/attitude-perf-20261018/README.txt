AERODECK performance investigation — frozen intermediate evidence

The native comparison contains exact-source snapshots f3ec (ROLL-DISPLAY),
816d (initial font/cell cache), and a7f (staged icons). Those records retain
their original hashes and limitations; they are not assertions that a later
main or backend was measured. The native comparison found much lower Lua VM
allowance use in the original smaller/different free Toolbox scene. No file
here establishes complete Toolbox or physical-radio speed superiority.

Portable renderer comparison uses the captured baseline and candidate main
sources and runs with LuaJIT or Lua5.3 int32/float32. From the project root:
luajit development/runtime-evidence/attitude-perf-20261018/portable/test-render-candidate.lua development/runtime-evidence/attitude-perf-20261018/portable sdcard/SCRIPTS/TOOLS/telem.lua

Native measurements require the existing EdgeTX3.0 TX16S WASM development
runtime, isolated sample providers, unchanged20k callback budget, and a
continuous owned-LCD-copy then ACK consumer. The original entire free Toolbox
app was run without activation changes; paid AHR full-app speed is unmeasured.
See final build-specific acceptance records alongside these snapshots.
