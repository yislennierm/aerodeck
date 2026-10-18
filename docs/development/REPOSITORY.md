# Repository map

AERODECK separates what runs on the radio, what developers edit, what users read and what records earlier work.

```text
sdcard/            Installable Lua, widget and active bitmap assets
assets/            Editable icon masters and approved branding sources
tests/             Current portable checks
  fixtures/        Synthetic providers and UI adapters
  data/            Reference vectors and their licence
tools/             Versioning, checks, packaging, preview and context checks
docs/              User manual, support status and current project guidance
archive/           Frozen imported notes, screenshots, experiments and evidence
.build/            Local toolchains, reports and simulator state (ignored)
dist/              Built installation ZIPs and checksums (ignored)
```

## Start in the right place

| Task | Start here |
|---|---|
| Install or use the radio application | [User manual](../USER-MANUAL.md) |
| Change a screen or telemetry behaviour | `sdcard/SCRIPTS/TOOLS/telem.lua` and matching `tests/test_*.lua` |
| Work on widget lifecycle | `sdcard/WIDGETS/AERODECK/main.lua` |
| Change icons or the logo | `assets/icons/` or `assets/branding/aerodeck-v2/` |
| Check or package a change | [CONTRIBUTING.md](../../CONTRIBUTING.md) |
| Continue this work in another session | [CONTINUITY.md](CONTINUITY.md) and [PROJECT-STATE.md](PROJECT-STATE.md) |
| Investigate an older design or parity audit | [Archive index](../../archive/README.md) |

`VERSION.json` is the build version source of truth. [VERSIONING.md](VERSIONING.md) explains the policy. Source file hashes identify exact runtime bytes; a version label is not evidence of physical-radio performance.

The SD tree contains production code and active icons only. Older unused panel art lives in the archive. `tools/package.py` uses a production allowlist and excludes test fixtures, archives, development assets and personal settings.

Equipment models, deployments and Toolbox reference material remain in the separate equipment repository. AERODECK does not need that repository to run its checks or build its installation ZIP.
