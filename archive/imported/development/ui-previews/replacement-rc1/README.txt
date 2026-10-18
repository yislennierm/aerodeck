AERODECK REPLACEMENT RC1 - native simulator acceptance

Source: 03ef8187ead264617a85f98a2c4980fb7e0c934b9175f2ac6016b5a48b16034a
Runtime: 64 active production Lua/icon files, matching both 48-suite reports.
Capture provenance: original 137-file maps retained separately; 73 historical,
unused PNGs are not production runtime requirements or included artwork.

19 cases / 133 manually inspected 480x272 screenshots:
- Unmodified production widget: clean compact, background, all 13 views,
  fullscreen navigation and return to compact.
- Development-only current-data driver: production main/modules byte-identical;
  all 13 populated views, attitude poses, missing/stale/long/fractional values,
  physical input extremes, optional model image and picker.
- Actual UI Settings Save, Quick Pack 5, and unchanged 1389-byte full-settings
  reopen. Max matching/mismatching VTX caches load/import/discover/save through
  the actual app. Module-only max log/reader, physical inventory and timer lease
  checks are supplementary evidence, not physical-radio proof.

Current-data warm: 220.584 seconds native process; approximately 203.584 seconds
in fullscreen current-widget execution. The monitored warm interval is exactly
170.365 seconds / 4500 frame samples (37 ms), with 0 blank frames, 0 ordinary
Updating frames and 0 CPU-limit errors. Moving attitude, GPS at nominal 5 Hz and
alternating status cycle-time bytes were active. No forced garbage collection.

Pure-PFD 10-second windows: about 17.01-17.10 draws and distinct attitude updates
per second; 4.09-4.20 published telemetry snapshots per second; 80-92% of the
native 20,000-instruction callback allowance used before measurement counters.
Maximum across the initial tour was 96%. Final Runtime screen: 17.2 fps / 17.2
value Hz. Final About screen: 1348.9 KB current / 1387.0 KB observed peak Lua heap.
These are native simulator observations, not transmitter performance estimates.

The consumer continuously copies dirty LCD buffers to owned memory then
acknowledges the flush, matching the official consumer contract. The native
instruction hook was not modified. Capture scripts never substitute framebuffer
retention for missing app painting.

LIMITS: EdgeTX 3.0 TX16S WASM, target physical firmware 2.12.4. RF cadence,
connected-quad sensors, flight-controller writes, other display hardware and
unlimited-duration stability are not verified here. Synthetic fixtures and the
development driver are not SD-card application content.
