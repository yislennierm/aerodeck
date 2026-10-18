# AERODECK project state

Read this with AGENTS.md when continuing work. This is a maintained engineering handover, not a copy of a conversation and not an automatic memory guarantee.

## Product and repositories

AERODECK is an independent public product repository: https://github.com/yislennierm/aerodeck. Its development baseline version is defined by VERSION.json. The private equipment repository pins selected commits as a submodule. Prefer the standalone product checkout for product changes; update the equipment pointer deliberately after the product commit is available.

The split preserved five relevant development commits. Their product-only IDs are mapped in `docs/migration.json`. A subsequent repository cleanup grouped historical records in `archive/imported/`, indexed by original path and hash. The production Lua and active PNG bytes were kept unchanged by that cleanup.

## Accepted product decisions

- Primary target: TX16S MkII, native480×272, viewed from roughly30–40cm.
- Keep the flat navy, near-white, cyan and soft-green UI. The pure LED-green/blue experiment was rejected. Keep the approved AD monogram and bitmap Material navigation icons.
- Home returns Flight; Arm info is the final toolbar item. Avoid duplicate navigation and redundant labels. Prioritize usable screen space and clear large values.
- The flight horizon uses markings without moving pitch/roll numeric clutter. Preserve the physically verified display conventions; do not “fix” a sign from a browser impression alone.
- GPS has one central plot with side data panels, a simple aircraft position marker, dynamic scale and a supplemental inspector. Local home is distinct from FC rescue/RTH home.
- Production values are live only. Keep missing/stale/unknown information explicit. Fixtures never ship in runtime packages.
- App mode renders the complete application without owning input. Input focus, compact widgets and hidden servicing are separate lifecycle paths.
- Keep staged startup, bounded caches/history and responsive attitude polling. Do not increase the native20000-instruction callback budget to hide excess work.
- Full Toolbox functional parity remains the goal. Only activation/licence enforcement is excluded; old audit counts do not establish complete hardware acceptance.

## Evidence and next work

The last recorded pre-split physical SD install was SPLASH-20261018. The calendar-versioned alpha was checked in portable/native simulation; this record does not assert a newer radio install. Hardware deployment and live telemetry/performance results must be checked in the equipment records.

Use `tools/run_checks.py` for fresh source-bound reports. Historical alpha/native evidence and the350-row parity assessment remain under `archive/imported/development/`. Their partial/unverified classifications still matter. Continue with real telemetry correctness, sustained responsiveness and source-backed parity closure, then native-size layout reviews and equipment acceptance.

The repository cleanup provides a clear product README, separated runtime/assets/tests/tools/archive, current entry points and durable chat continuation guidance. Its organization commit preserved all runtime bytes. A subsequent radio-battery fix changes runtime behaviour: native TX battery sampling now runs independently of budget-deferred quad acquisition. The regression reproduces an unchanged voltage during sustained moderate foreground usage, then verifies updates without background callbacks or page changes. Read [the battery investigation](RADIO-BATTERY.md) for source comparison, limits and hardware acceptance still required. Check git status and current reports before reporting either change as pushed or installed.

## Keep this useful

Follow-up radio-voltage investigation: Toolbox's actual compiled `UI/SNV` formatter clamps displayed numeric voltage to the configured min/max. A controlled4.2V input with a6.2V minimum reproduces Toolbox displaying6.2V; the user subsequently observed about4.02V in EdgeTX Hardware. At the user's request, AERODECK's header now uses the same numeric limits, with `<`/`>` markers outside the range. Preserve the separate unclamped native measurement for diagnostics/alarms. Regression checks cover both display limits, raw values, loss and recovery. Physical pack voltage remains unmeasured. Read RADIO-BATTERY.md before changing APIs, calibration or voltage scaling. Check current source/report hashes before deploying this local presentation change.

After meaningful work, update accepted decisions, unresolved issues and the next concrete step here. Record measurements in source-bound evidence, not as unsupported statements. Keep machine-specific paths, credentials, personal radio files and full chat transcripts out of public documentation.
