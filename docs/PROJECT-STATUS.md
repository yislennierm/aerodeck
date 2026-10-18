# AERODECK current status

## Current product baseline

Version: **2026.10.0-alpha**. Primary target: TX16S MkII,480×272, EdgeTX2.12.4 with Betaflight/ELRS. This development alpha retains the approved flat navy/cyan/soft-green UI, Material bitmap navigation icons and120×120 AD startup logo. The rejected pure LED-green/blue palette is not the current theme.

The repository split changes ownership, tooling and documentation; all68 active Lua/PNG runtime files are byte-identical to the pre-split alpha. Five relevant development commits were extracted with rewritten product-only commit IDs. The fpv history is retained unchanged up to its migration commits. `migration.json` records the correspondence.

## Verification and deployment are separate

- The extracted runtime passes60 existing portable suites in LuaJIT and Lua5.3 int32/float32. New acceptance reports are generated in `.build/` by the documented commands.
- Native simulator screenshots and exact source hashes for the alpha are in `archive/imported/development/runtime-evidence/2026.10.0-alpha/`. They use sample telemetry and the unchanged20000-instruction callback budget.
- AERODECK's portable browser entry point is `tools/preview.py`. It needs Node and an externally supplied compatible EdgeTX WASM, not the old Codex workspace.
- The last recorded physical SD install before extraction was SPLASH-20261018. The calendar-versioned alpha was local/simulator-only. This migration does not install a radio.
- The equipment repository's `radiomaster_tx16s_mkII/LUA/DEPLOYMENT.txt` remains the authority for that radio's file-verified install. A GitHub artifact, version tag or submodule pointer does not prove an on-radio test.

## Scope and remaining acceptance

The runtime contains real sensor binding, protocol adapters, configuration, persistence, session services, VTX transactions, arming diagnostics and manual reference guides. Code presence does not establish complete Toolbox parity on every hardware/protocol combination.

The detailed frozen baseline is `archive/imported/development/implementation-status.json`, `archive/imported/IMPLEMENTATION-STATUS.txt` and `archive/imported/development/assessments/2026-10-17-deep-parity/`. Its classifications include implemented, partial and unverified paths. Keep that distinction when reporting progress. The only intentional excluded mechanism is activation/licence enforcement; functionality that was gated in Toolbox remains in scope.

Broader FrSky, INAV, Crossfire/Tracer and480×320/800×480 targets still require their specific integration and hardware acceptance. Claims of faster rendering or better MCU behaviour require controlled measurements. Native simulator responsiveness is not a physical-radio benchmark.

Further development priorities: confirm real telemetry correctness and horizon conventions, close the source-backed parity items, preserve long-running attitude responsiveness, and review changed layouts at native resolution before hardware acceptance. Keep packaging/checks portable and original-source licensing explicit before selecting product-wide distribution terms.

## Documentation authority

Use README.md and USER-MANUAL.md for users; CONTRIBUTING.md for current commands; AGENTS.md and AI-HANDOVER.md for assistants. The `.txt` documents, dated generators and evidence scripts under `archive/imported/` are historical records. Some contain paths or build names from the original workspace. Do not execute them as the current bootstrap or alter frozen evidence to make it look current.
