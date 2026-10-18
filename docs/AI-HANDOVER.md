# AI project handover

Copy the following prompt when opening this repository with an AI coding assistant. Keep product documentation separate from private equipment records.

```text
Work on AERODECK as an independent EdgeTX product. Read AGENTS.md, README.md,
docs/USER-MANUAL.md, docs/PROJECT-STATUS.md, CONTRIBUTING.md and VERSION.json
before proposing changes. Then inspect the actual Lua, tests and relevant evidence.

Produce or update a source-backed project overview covering:
1. End-user purpose, supported/verified hardware, install/update/rollback and controls.
2. Every screen, data source, units, missing/stale behaviour and configuration dependency.
3. Which actions only display information, which save local settings, and which write
   to the radio or flight controller. Trace each claimed feature to its implementation.
4. Architecture: Tool/widget lifecycle, telemetry, retained state, storage, assets,
   protocols, configuration and rendering/instruction/memory constraints.
5. Current local source identity, test results, simulator evidence, published artifacts
   and hardware-installed version. Treat these as separate facts.
6. Toolbox feature parity: inspect its reference source when available. Exclude only
   activation/licence enforcement; do not omit functions merely because they were gated.
7. Known gaps and risks, with exact source/evidence references and actionable next steps.

Do not invent features, sensor readings, fixes, performance numbers or hardware results.
Historic audit completion counts are not proof that current hardware passes. Mark facts
as source-implemented, portable-tested, simulator-observed or hardware-confirmed as
appropriate. Report when the Toolbox reference or equipment records are unavailable.

Preserve the approved flat navy/cyan/soft-green UI and AD logo. Optimize for a TX16S
480x272 display viewed from about30–40cm. Protect the responsive attitude path,
bounded caches/history, staged startup and unmodified native callback budget. Do not
add repeated SD reads or unbounded work to drawing callbacks.

Keep the README/manual focused on users. Put internal architecture, audit evidence
and AI instructions in developer documents. Verify the text against current source,
repair broken links, and include exact commands that work from a fresh clone.

Before implementing the requested change, inspect git status and preserve unrelated
work. Keep AERODECK changes in this repo; fpv pins a tested commit as a submodule.
Use CONTRIBUTING.md for tests/package/preview instructions. Do not deploy to a radio,
push changes or publish a release unless the current task authorizes those actions.

Requested task: [describe the concrete feature, defect or documentation change here]
```

Start with [PROJECT-STATUS.md](PROJECT-STATUS.md) for the distinction between the extracted alpha, earlier hardware installs and historical evidence. The `fpv` repository owns your equipment-specific deployment authority.
