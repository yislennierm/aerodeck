# AERODECK user manual

This manual covers AERODECK 2026.10.0-alpha on the RadioMaster TX16S MkII. It explains installing, opening and using the application with your own telemetry. Firmware menu wording can differ between EdgeTX versions.

## Before you start

You need a compatible colour-screen EdgeTX radio, a working SD card and an aircraft/receiver telemetry connection. The primary development configuration is TX16S MkII, EdgeTX 2.12.4, Betaflight and ExpressLRS. It is a development baseline, not a promise of compatibility with every newer firmware or receiver.

Connect and configure the aircraft using its normal flight-controller tools first. For bench setup, remove propellers. A radio screen is an aid to understanding the aircraft; it does not establish that the aircraft is safe to arm.

AERODECK has two data paths: EdgeTX’s discovered telemetry sensors and a supported flight-controller connection for additional status and video information. Having a working RC link does not mean every extra field is available.

## Install or update

1. Connect the radio using **USB Storage** mode and locate its SD-card volume. Do not select the firmware/bootloader volume.
2. Back up the card, particularly the radio model files and existing AERODECK preferences.
3. Extract a built AERODECK installation package on the computer. Copy the contents into the SD root, merging directories. The resulting paths must include:

   ```text
   SCRIPTS/TOOLS/telem.lua
   SCRIPTS/TOOLS/AERODECK/...
   WIDGETS/AERODECK/main.lua
   LICENSES/...
   ```

4. Keep AERODECK’s saved per-model configuration files. Do not replace `MODELS`, `RADIO`, ExpressLRS or other applications as part of this update.
5. Eject the card safely, disconnect USB and restart the radio. Restarting also ensures a widget is not retaining an old Lua module in memory.
6. Check the product version in AERODECK’s startup screen or System information.

When updating from a much older version, remove only stale AERODECK compiled `.luac` counterparts for changed Lua files, after backing them up. Do not delete unrelated caches or settings. A source ZIP from GitHub contains development files and should not be copied wholesale to the card.

To roll back, restore the previous AERODECK files and their matching settings backup, then restart. Keep the newer settings backup separately in case an older build cannot interpret it.

## Open AERODECK

### As a tool

Open **SYS → Tools → AERODECK**. The installation filename is `telem.lua`; its registered tool name is AERODECK.

### As a full-screen App mode widget

Open EdgeTX’s screen configuration, select **App mode** as the layout, then use **Setup widgets** to select **AERODECK**. In an actual full-display zone the complete dashboard renders even while it does not own input focus.

Use the native long-press menu/full-screen action to give it focus. Long-press **RTN** releases focus back to EdgeTX. An EdgeTX badge while unfocused belongs to the firmware. AERODECK does not intercept touches it does not own.

### As an ordinary widget

Select AERODECK in a smaller widget zone for compact telemetry. This deliberately uses a different presentation from the complete application. Hidden widgets service the retained session without painting the full dashboard. Reopening the same widget session keeps its application state; restarting or changing models can reset it.

## Controls and navigation

| Control | Purpose |
|---|---|
| Home icon | Return to the Flight screen |
| Top toolbar icons | Open Data, Navigation, Video, Setup, Tools or Arm information |
| Tabs below the toolbar | Choose the available view inside that section |
| PAGE keys | Cycle sections when no editor or modal owns the input |
| SYS/MDL in the application | Focus the navigation bar |
| Rotary control | Move through available controls or adjust the selected value |
| ENTER | Activate the focused item or accept an edit |
| RTN | Cancel the current edit, leave a panel or return toward the parent screen |
| Long RTN in widget full screen | Release native input focus |

Dialogs and editors take priority over page navigation. Cancelling an individual edit is different from saving an entire settings draft. Follow the on-screen Save/Revert choices before leaving Setup.

## Connect live telemetry

1. Select the correct radio model and establish the receiver link.
2. Power the aircraft as required for its sensors. Some equipment powered over USB does not provide battery voltage/current.
3. In the model’s EdgeTX Telemetry page, use **Discover new sensors**. Finish discovery after the sources appear.
4. In AERODECK **Setup → Model setup**, check the protocol, flight-controller choice, enabled providers and source mappings. Start with Auto; select a specific discovered source when needed.
5. Compare a few readings with EdgeTX’s own telemetry page. Tilt the aircraft and check pitch/roll directions before relying on the horizon.

Typical sensor names include `RxBt`/`VFAS` for voltage, `Curr` for current, `Capa` for consumed capacity, `GPS`, `GSpd`, `GAlt`, `Ptch`, `Roll`, `RQly`, `1RSS` and `RSNR`. Actual names and availability depend on the receiver and firmware. Use the discovered sensor’s meaning and units rather than assigning by name alone.

`--` means no usable value for that field. It is not zero. AERODECK’s runtime does not fill gaps with demo data. Browser development previews use explicitly labelled sample telemetry.

## Flight screen

The Flight screen combines the RC-link panel, central instruments and aircraft-energy panel. The home icon returns here; there is no separate duplicate Flight toolbar button.

The centre can show attitude, video information or navigation. Use its selector or **Setup → User interface → Default Flight centre panel**. The attitude view contains the horizon and angle markings, with a compass above it. The home direction belongs in the heading presentation rather than as a second moving aircraft symbol.

The energy panel shows available pack voltage, cell/profile information, consumption, current and average cell voltage. A reported remaining percentage and a voltage-derived estimate have different meanings. Check your battery profile and capacity before interpreting reserve information. No current sensor means current and consumed-capacity readings may remain unavailable.

The arm-information shield opens arming diagnostics. Its colour summarizes status; it is not an arming control. Open it for the actual reason, connection state and interpretation.

## Data and sensors

The Data section provides telemetry views, power/link detail and discovered-sensor information. Where a view offers LIVE/MIN/MAX, historical values come from the supported native extrema sources; a missing minimum or maximum stays unavailable.

Use the sensor inventory to confirm what the model exposes. Check source mappings if an EdgeTX value exists but the application field is empty. Changing mappings or providers does not create a sensor on the aircraft.

## Navigation and GPS

The GPS dashboard puts the track in the centre with return/navigation figures on the left and motion figures on the right. The aircraft is a position marker, not a claim that body heading is available. GPS ground course describes travel direction and can become unreliable at very low speed; body yaw is a different source.

The grid/ring scale changes with the plotted extent and selected zoom. Read the displayed scale rather than assuming a fixed number of metres per ring. The plot is a local track display, not a downloaded terrain or street map.

The GPS inspector brings together coordinates, last-known position, Plus Codes, home information and any additional satellite information actually received. A satellite count alone does not establish a 3D fix, constellation or HDOP. Fields requiring unavailable information remain unavailable.

AERODECK’s **local home** is an application/session reference. **Set local home** and automatic capture do not change the flight controller’s rescue/RTH configuration. Automatic capture can be Off, First valid position, or On arm with valid GPS; its satellite threshold is configurable. Confirm the home point for the current flight. Last-known positions after telemetry loss are identified as history, not a live position.

ETA uses ground speed and distance. It is an indication, not a wind-aware return guarantee.

## Video and VTX

Choose a backend that matches your equipment: flight-controller MSP or supported TBS native hardware. Enable the video application in Model setup; favourites appear when Video + favourites is selected.

Read the current connection/table status first. Select channel/frequency, power or PIT changes, review the pending settings, then use **Apply**. Wait for readback/status to verify the result. A favourite is a selection shortcut; selecting it is not equivalent to a confirmed hardware change.

Power labels and valid channels come from the connected device/table. A missing table or unsupported backend cannot be fixed by displaying a successful-looking value. Stay within the permitted frequencies and power for your location and equipment.

## Arming information and stick guides

Arm information decodes the flight controller’s reported arming flags when a supported firmware/API layout is recognized. Unknown bits stay identified as unknown rather than being assigned an invented explanation. Check the reported firmware/API and the aircraft’s own configuration if a reason is unmapped.

Stick guides show manual positions for supported Betaflight/INAV commands and radio stick modes. Opening or selecting a guide does not transmit sticks, save FC settings or start calibration. Read its context and firmware-specific notes before manually using a command.

## Setup categories

The available categories follow your selected providers and hardware; fewer than twelve categories can be normal. Changing a parent option can reveal or hide categories without erasing their saved values.

| Category | What it controls or explains |
|---|---|
| Model setup | Protocol/FC selection, enabled providers and sensor mappings |
| RC link | Signal/LQ/SNR sources, protocol profile and warning thresholds |
| Model battery | Cell voltage thresholds and alert behaviour |
| Battery favourites | Five pack profiles with chemistry, cells and capacity |
| Flight controller | Supported status connection and polling settings |
| Indicators / timers | Radio arm/cut/throttle/limiter bindings, timer ownership and reset preferences |
| FC mode indicators | Reported mode and optional indicator bindings |
| VTX | Backend, supported hardware, cache and polling |
| VTX favourites | Eight selectable frequency favourites |
| GPS | Automatic home capture, satellite threshold, track retention and default zoom |
| User interface | Palette/accent, compass source, attitude markings/direction and opening view |
| Application | Storage/information, error logging and explicit legacy imports |

For example, battery categories require the voltage provider; VTX favourites require Video + favourites. GPS settings require the GPS provider. Model setup, Indicators/timers, User interface and Application remain the basic configuration path.

Edit a value, then use **Save settings** to apply/persist the draft. **Revert** discards unsaved draft changes. Values belong to the selected radio model. Reopen the application when a settings message requires it. Saved legacy files are imported only through the explicit import controls.

A radio arm-switch indication is not the same as an FC-confirmed armed state. Keep their bindings meaningful. If AERODECK is configured to own a model timer or clear native telemetry on a new flight, those options affect the radio’s corresponding state. Alerts run while the application session runs; they are not firmware-wide alarms when no session is active.

## Diagnostics and troubleshooting

| Problem | Check next |
|---|---|
| No AERODECK entry | Confirm `SCRIPTS/TOOLS/telem.lua` and restart the radio |
| Missing artwork/helper error | Copy the entire matching package, including nested icons; check card free space |
| Full app appears as a small summary | Use the actual App mode/full-display layout |
| Dashboard visible but touch does nothing | Give the native widget input focus |
| No voltage/current | Power the flight battery, check native telemetry sources and Model setup mappings/providers |
| Attitude unavailable or reversed | Check Ptch/Roll in EdgeTX, source selection and Roll display direction; verify physical motion |
| Starts responsive then degrades | Compare native telemetry and AERODECK diagnostics over time; record the version, mode and conditions |
| GPS count but no position/fix details | Check the actual position source; count and full satellite/fix data are distinct |
| FC/VTX information missing | Check the selected protocol/backend, FC connection and reported firmware/API |
| Preferences do not persist | Check SD access, model identity and the Save status; preserve the failed files for diagnosis |
| Unknown arming flag | Record the bit, FC firmware/API and status count; confirm the FC’s reported reason |

System/diagnostic views expose version, connection, rendering and error information. If enabled, diagnostic events collect in bounded memory; use the explicit **Save log** action to write them. Report the AERODECK version, radio/EdgeTX version, FC firmware, receiver/protocol, Tool vs widget mode, steps to reproduce, and screenshots or logs. Do not include activation keys or private configuration unnecessarily.

The installation procedure here does not change ExpressLRS, radio firmware or Betaflight firmware. Their updates are separate operations.
