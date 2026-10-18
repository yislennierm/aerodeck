# AERODECK contributor instructions

Read README.md, docs/USER-MANUAL.md, docs/PROJECT-STATUS.md, docs/development/PROJECT-STATE.md, CONTRIBUTING.md and VERSION.json first. Source, current tests and source-bound evidence outrank old release notes.

## Workspace and continuity

Run `python3 tools/context.py --check` from this product checkout before editing. Use an explicit working directory for commands when the chat still points at an older workspace. Prefer the standalone AERODECK checkout; allow an equipment submodule only when integration work is explicitly requested. Stale IDE tabs are not authority to recreate the old fpv source paths.

Keep durable engineering decisions and the next concrete step in docs/development/PROJECT-STATE.md. Use docs/development/CONTINUITY.md when changing folders or starting another chat. Repo files preserve project guidance; they do not reassign app chat metadata or preserve an entire transcript. Keep machine-specific pointers and private equipment data out of public docs.

## Product constraints

- AERODECK is independent of fpv. Keep personal model files, deployment records, ExpressLRS and Toolbox source outside the installable product.
- The primary target is TX16S MkII480x272/EdgeTX. Preserve Tool, full App mode and compact/hidden widget lifecycles.
- Native callbacks have a20000-instruction budget. Keep staged cold work, bounded caches/history, current attitude polling and deferred slow services. Do not raise the firmware budget to make tests pass.
- Production telemetry is live only. Missing/unknown/stale values must remain explicit. Sample providers belong only in development fixtures.
- FC writes require the application's actual explicit transaction path; a guide is not a command implementation.
- Preserve approved flat navy/cyan/soft-green colours, Material bitmap icons and AD branding. Review at native size and30–40cm viewing distance.
- Toolbox parity excludes only activation/licence enforcement. Do not equate code presence or an old audit count with hardware acceptance.

## Change and verification workflow

Inspect git status before changes. Preserve unrelated work. VERSION.json is authoritative; stamp with tools/set_version.py. No extra runtime version reads.
Run the existing relevant checks, then the full acceptance commands before packaging. Tests and evidence must bind current runtime bytes. Do not rewrite historical reports or imply that a screenshot proves real telemetry/performance.
Use the current tools/ entry points in CONTRIBUTING.md. tests/ contains current checks, assets/ holds editable artwork, and archive/imported/ holds frozen historical evidence. Do not rewrite archived report bytes or execute old dated generators as current tooling. archive/index.json maps each moved historical path and its hash.
User documentation belongs in README.md/docs/USER-MANUAL.md. Put architecture, provenance and limitations in developer/status documents. Verify UI names and behaviours against Lua.
No radio deployment, release publication or unrelated push is implied by an ordinary edit. A Git submodule pointer changes only after the corresponding product commit is available.
