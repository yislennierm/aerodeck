# Radio battery refresh investigation

## Report and reproduction

The transmitter battery beside Home appeared to update only after leaving AERODECK for an EdgeTX page and returning. This concerns the native radio battery, not the aircraft's voltage/current sensors or ExpressLRS script.

The retained full-screen loop can defer slow quad-data phases when its prefix usage exceeds10percent. Radio sampling was inside the second acquisition phase. Repeated deferral therefore left the header's radio snapshot unchanged even though the display and attitude continued to run. Hidden/compact widget service calls `background()`, which performs the slow service outside that foreground gate; this explains the page-switch symptom.

`tests/test_widget_budget.lua` reproduces the dependency using the actual application, a controlled native source and a steady12percent prefix. It changes native radio voltage, runs16 foreground callbacks spanning3.2seconds, and never calls background service, switches pages or reinitializes. Before the refresh fix, the assertion fails with the old8.1V instead of7.0V. This is a scheduling regression fixture, not a physical CPU/FPS measurement.

## Source comparison

| Element | Toolbox reference | AERODECK after correction |
|---|---|---|
| Voltage source | Dedicated `LIB/RD/BAT.lua` reader uses `getValue("tx-voltage")` | Dedicated `pollRadio` path uses the native `getSourceValue` API; `getValue` compatibility only when that API is absent |
| Displayed voltage outside range | `UI/SNV.lua` clamps the displayed numeric value to the configured min/max before formatting | Same numeric floor/ceiling in the header, marked with `<`/`>`; measured value retained for diagnostics and alarms |
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

Refresh-fix baseline verification: all60 suites passed in LuaJIT and Lua5.3 int32/float32, and the source-bound installation package built successfully. The native480×272 WASM preview was inspected with the corrected gauge and unchanged20000-instruction callback budget; this is sample-data rendering evidence, not hardware throughput. That baseline main SHA256 is `c27cbf10b1bf4ad6f5e114c06bf03f20d09d49847c7d3c9184b75a06dd2ca2a4`, and its radio module SHA256 is `cbee472ded40b344e896e261adbd457d6bfde63a106f631d67f20925f59f44b7`. Local generated reports/captures remain under ignored `.build/`.

## Physical acceptance still required

### Follow-up:4.2V versus6.2V

After installation, a user reported4.2V beside Home while Toolbox displayed6.2V. The charging indication in EdgeTX was full, so it did not provide a numeric tie-breaker. Inspection of Toolbox's actual `UI/SNV.luac` confirms that its numeric formatter clamps the displayed value as well as its percentage. With a configured6.2–8.2V range, its formatter produces the following results:

| Supplied raw voltage | Toolbox displayed voltage | AERODECK displayed voltage |
|---|---|---|
|4.2V |6.2V |<6.2V |
|6.2V |6.2V |6.2V |
|6.4V |6.4V |6.4V |
|8.5V |8.2V |>8.2V |

The Toolbox results were reproduced with its actual compiled formatter, a controlled radio source and the int32/float32 Lua interpreter. Only the copied chunk's size_t header was adapted to the host loader; instructions and constants were unchanged. No Toolbox code/binary is added to this repository. These are formatter comparisons, not measurements of a physical battery.

The matching clamp explains how this exact display discrepancy can occur; it does not independently establish the real battery voltage or prove a fault in either EdgeTX voltage API. Both native API implementations use the same underlying TX source in the inspected firmware. The user subsequently reported about4.02V on EdgeTX's Hardware screen and a shutdown, consistent with the application's approximately4V reading. The physical pack voltage has not been independently measured.

At the user's request, the header now follows Toolbox's configured numeric floor/ceiling. It adds a comparison marker so the limit is visibly distinct from an in-range measurement. `radio-status.lua` provides separate `displayVoltage` and `displayBoundary` fields, sampled at the existing1Hz cadence. Native `voltage`, `rawVoltage`, alarm comparisons, `d.radioVoltage` and the measured-voltage diagnostic remain unclamped. Missing limits leave the actual voltage available; missing voltage clears the display. The module/header checks cover both out-of-range directions, exact boundaries, in-range values, loss, reset and clock failure. This display change does not alter radio calibration, battery charging or cell-count configuration, and it does not establish the pack's physical condition.

Display-limit verification: all60 suites pass in both interpreters, and the source-bound package builds. The native480×272 preview with an explicit development-only4.2V sample and6.2–8.2V meter range shows `<6.2 V` fitting beside Home, an empty gauge, the critical battery footer, and4.2V in the measured-voltage diagnostic. The firmware callback budget remains20000. The checked main SHA256 is `2a26c0343cc8b4268278c75f59e00b93a11d8e882f9aa013a50e3fe00b87d7b8`; the radio module SHA256 is `1052267ee164dc44f0208fdee6cc09dba2a279fe0d6fe0bc094ff472473b5c2f`. The source-bound reports are generated as `.build/checks-display-*.json`; local screenshots/metadata are under `.build/radio-display/`. These simulation results do not claim a physical install or hardware acceptance of the display-limit change.

The battery-refresh build was subsequently installed and file-hash verified on the primary radio; the private equipment deployment record is the installation authority. Physical acceptance remains separate: keep the full-screen App open with real telemetry long enough for the radio's native voltage to change. Compare against EdgeTX's numeric radio battery reading, allowing for its measurement granularity. Confirm refresh without changing pages, normal attitude responsiveness and the Tool/compact/hidden lifecycle paths. Record exact runtime hashes and observed results in the equipment records. A verified copy does not validate the physical voltage or application performance.
