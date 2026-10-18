# Radio battery refresh investigation

## Report and reproduction

The transmitter battery beside Home appeared to update only after leaving AERODECK for an EdgeTX page and returning. This concerns the native radio battery, not the aircraft's voltage/current sensors or ExpressLRS script.

The retained full-screen loop can defer slow quad-data phases when its prefix usage exceeds10percent. Radio sampling was inside the second acquisition phase. Repeated deferral therefore left the header's radio snapshot unchanged even though the display and attitude continued to run. Hidden/compact widget service calls `background()`, which performs the slow service outside that foreground gate; this explains the page-switch symptom.

`tests/test_widget_budget.lua` reproduces the dependency using the actual application, a controlled native source and a steady12percent prefix. It changes native radio voltage, runs16 foreground callbacks spanning3.2seconds, and never calls background service, switches pages or reinitializes. Before the refresh fix, the assertion fails with the old8.1V instead of7.0V. This is a scheduling regression fixture, not a physical CPU/FPS measurement.

## Source comparison

| Element | Toolbox reference | AERODECK after correction |
|---|---|---|
| Voltage source | Dedicated `LIB/RD/BAT.lua` reader uses `getValue("tx-voltage")` | Dedicated `pollRadio` path uses the native `getSourceValue` API; `getValue` compatibility only when that API is absent |
| Settings | Native general radio battery limits | Native general radio battery limits, validated in volts |
| Gauge fill | Linear position within configured min/max | Rounded, clamped range percentage; explicitly not chemical SOC |
| Health colours | Lower third/ lower fifth bands in sensor policy | Same inclusive range bands, with native battery warning also forcing critical |
| Warning | Visual sensor thresholds | Native configured warning remains a separate boolean; no new audio/haptic policy |
| Refresh ownership | Separate radio battery reader | Native sampling independent of the quad acquisition gate; reads at most1Hz |
| Painting | Bitmap/frame and dynamic gauge primitives | Existing compact dynamic rectangles, with muted silhouette and health-coloured fill |

The inspected reference paths are `LIB/RD/BAT.lua`, `UI/SNV.lua`, `UI/480X272/DB1/RDB.lua` and `MOD/BAT.lua`. This comparison does not introduce Toolbox source or licence mechanisms into the product.

EdgeTX2.12.4's [Lua implementation](https://github.com/EdgeTX/edgetx/blob/v2.12.4/radio/src/lua/api_general.cpp) exposes radio limits in volts. Both voltage APIs read the same native TX source; switching API names alone would not fix this scheduling dependency. The native [battery gauge/warning definitions](https://github.com/EdgeTX/edgetx/blob/v2.12.4/radio/src/edgetx.h) use configured voltage limits. The firmware's [battery acquisition](https://github.com/EdgeTX/edgetx/blob/v2.12.4/radio/src/main.cpp) has its own cadence, averaging and100mV quantization; a1Hz application poll does not imply1Hz voltage changes.

## Correction and verification

`radio-status.lua` still owns the bounded native source/settings reads and stable revisioned snapshot. `telemetry.pollRadio` copies that small snapshot into the displayed frame independently of the slower quad pipeline. Completed and working quad buffers do not alias the module's borrowed table. Regular Tool/background acquisition continues to use the same cache. Attitude polling, model-data deferral, RF operations and the20000-instruction native callback budget are preserved.

The regression checks foreground voltage changes, low/critical/normal gauge fill and colour, bounded native reads, unchanged deferred quad acquisition, source loss and recovery. The radio module checks inclusive visual thresholds, separation from the actual native warning, invalid clock clearing and recovery, missing/stale sources and float32 voltage rounding. Current source-bound reports come from the two complete acceptance commands in CONTRIBUTING.md; archived release reports remain historical.

Verification for this correction: all60 suites pass in LuaJIT and Lua5.3 int32/float32, and the source-bound installation package builds successfully. The native480×272 WASM preview was inspected with the corrected gauge and unchanged20000-instruction callback budget; this is sample-data rendering evidence, not hardware throughput. The checked main SHA256 is `c27cbf10b1bf4ad6f5e114c06bf03f20d09d49847c7d3c9184b75a06dd2ca2a4`, and the radio module SHA256 is `cbee472ded40b344e896e261adbd457d6bfde63a106f631d67f20925f59f44b7`. Local generated reports/captures remain under ignored `.build/`.

## Physical acceptance still required

Install the checked runtime deliberately, then keep the full-screen App open with real telemetry long enough for the radio's native voltage to change. Compare against EdgeTX's radio battery display, allowing for its measurement granularity. Confirm refresh without changing pages, normal attitude responsiveness and the Tool/compact/hidden lifecycle paths. Record exact runtime hashes and observed results in the equipment records. This repository change has not itself installed or physically validated a radio.
