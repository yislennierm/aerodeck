# AERODECK

AERODECK puts flight instruments, power, GPS, radio-link information and flight-controller diagnostics on an EdgeTX radio. Open it as a tool or use it as a full-screen App mode widget.

**Current version: 2026.10.0-alpha.** The primary development target is the RadioMaster TX16S MkII with its 480 × 272 display. This is a development prerelease. Wider radio and protocol support is implemented in parts and still needs target-specific verification.

![AERODECK flight screen with sample telemetry](docs/images/flight.png)

*Native TX16S simulator capture with sample telemetry. Actual values depend on your aircraft and sensor configuration.*

## Install and start

1. Back up your radio’s SD card. Download an AERODECK installation ZIP from [Releases](https://github.com/yislennierm/aerodeck/releases) when one is available. A GitHub source ZIP is not an installation package.
2. Extract the installation ZIP. Merge its `SCRIPTS`, `WIDGETS` and `LICENSES` folders into the SD-card root. Keep existing folders and your per-model settings files.
3. Safely eject the SD card, disconnect USB and restart the radio.
4. Open **SYS → Tools → AERODECK**, or select **App mode** in a screen’s layout and choose the **AERODECK** widget.
5. With your aircraft connected, discover its telemetry sensors in the EdgeTX model Telemetry page. Open AERODECK Setup to check source mappings, battery profile and control indicators.

For the full-screen widget, long-press the display and select the native full-screen/focus action when shown to give AERODECK input focus. Long-press **RTN** to release it. A small ordinary widget zone shows compact telemetry instead of the full application.

Read the [user manual](docs/USER-MANUAL.md) for setup, controls, every screen, settings, updates and troubleshooting. For first aircraft setup, work with propellers removed.

## What you can use

- Flight attitude, compass, link and power instruments.
- Unified GPS track view, home reference and position inspector.
- Live telemetry, native extrema and discovered sensors.
- Battery profiles, thresholds, consumption and session information.
- VTX channel/power controls with explicit Apply and readback.
- Arming explanations, manual stick-command guides and diagnostics.
- Per-model preferences and App mode/compact widget support.

AERODECK shows received data; missing values remain unavailable. It does not create missing sensors or replace flight-controller setup. Stick-command guides are references, not buttons that send commands. No activation key is required.

## Project links

- [User manual](docs/USER-MANUAL.md)
- [Current status and known limits](docs/PROJECT-STATUS.md)
- [Development and packaging](CONTRIBUTING.md)
- [AI handover prompt](docs/AI-HANDOVER.md)
- [Version policy](VERSIONING.txt)
- [Third-party notices](THIRD-PARTY-NOTICES.md)

AERODECK is maintained independently. The private `fpv` equipment repository includes a pinned AERODECK submodule; aircraft settings and personal deployment history belong there.
