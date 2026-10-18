AERODECK ROLL-DISPLAY-20261018 - scoped native validation

Source f3ec289ca9655833d04285dbd46900ba64afeac058fcc2e9d1916c9d1418b60a.
Only telem.lua differs from the frozen RC1 active64 runtime. Both49-suite reports
pass. The previous RC1 native bundle was independently checked unchanged.

34 manually reviewed native screenshots across8 cases cover level, raw rolls
+/-30 degrees with normalized pitch+/-10 degrees, Normal0/Reversed1 contrast,
all3 HUDs, raw Telemetry, and an actual UserInterface selector Save.
The saved owned model file contains rollDisplay=1. Reversed changes the display
readouts, field, ladder and sky pointer consistently; raw Telemetry stays+/-30.
Fifteen actual-PNG sky/ground colour checks also compare all3 HUD directions.

Reversed1 moving-attitude/GPS/status-jitter warm:57.584 seconds monitored,
1500 frame samples, zero blank frames, zero ordinary Updating frames, zero
instruction errors, no forced collection. Final Runtime:18.3 fps/valueHz.
The native20,000-instruction callback hook was unchanged; LCD consumption used
continuous dirty-frame copy to owned memory followed by flush acknowledgment.

This is EdgeTX3.0 TX16S WASM with synthetic telemetry and a development-only
widget driver; production app/modules remain unchanged from staged files.
It does not verify the physical quad sign or physical EdgeTX2.12.4 performance.
Normal0 remains default. Reversed1 is an explicitly saved per-model option.
No physical radio files were changed or deployed by this validation.
