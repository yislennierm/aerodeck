# AERODECK contributor instructions

Read README.md, docs/USER-MANUAL.md, docs/PROJECT-STATUS.md, CONTRIBUTING.md and VERSION.json first. Source, current tests and source-bound evidence outrank old release notes.

## Product constraints

- AERODECK is independent of fpv. Keep personal model files, deployment records, ExpressLRS and Toolbox source outside the installable product.
- The primary target is TX16S MkII480x272/EdgeTX. Preserve Tool, full App mode and compact/hidden widget lifecycles.
- Native callbacks have a20000-instruction budget. Keep staged cold work, bounded caches/history, current attitude polling and deferred slow services. Do not raise the firmware budget to make tests pass.
- Production telemetry is live only. Missing/unknown/stale values must remain explicit. Sample providers belong only in development fixtures.
- FC writes require the application's actual explicit transaction path; a guide is not a command implementation.
- Preserve approved flat navy/cyan/soft-green colours, Material bitmap icons and AD branding. Review at native size and30–40cm viewing distance.
- Toolbox parity excludes only activation/licence enforcement. Do not equate code presence or an old audit count with hardware acceptance.

## Change and verification workflow

Inspect git status before changes. Preserve unrelated work. VERSION.json is authoritative; stamp with development/set_version.py. No extra runtime version reads.
Run the existing relevant checks, then the full acceptance commands before packaging. Tests and evidence must bind current runtime bytes. Do not rewrite historical reports or imply that a screenshot proves real telemetry/performance.
Use the portable package/preview entry points in CONTRIBUTING.md. Files under development/runtime-evidence are frozen historical evidence; some old scripts contain paths from the original machine and are not current entry points.
User documentation belongs in README.md/docs/USER-MANUAL.md. Put architecture, provenance and limitations in developer/status documents. Verify UI names and behaviours against Lua.
No radio deployment, release publication or unrelated push is implied by an ordinary edit. A Git submodule pointer changes only after the corresponding product commit is available.
