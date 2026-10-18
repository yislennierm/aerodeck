# Developing AERODECK

Clone this product directly to develop it independently of your equipment repository:

```sh
git clone https://github.com/yislennierm/aerodeck.git
cd aerodeck
```

The repository is currently private; your GitHub account needs access. Use Python 3.12+, LuaJIT, a C compiler and `make` for the portable checks. Node 22+ and a compatible EdgeTX WASI-threads TX16S simulator are additional dependencies for the optional native browser preview. System package installation remains your choice; no bootstrap script changes your system packages.

## Source layout

- `sdcard/SCRIPTS/TOOLS/telem.lua`: application entry and screen composition.
- `sdcard/SCRIPTS/TOOLS/AERODECK/`: telemetry/protocol/storage/session/UI helpers and runtime assets.
- `sdcard/WIDGETS/AERODECK/main.lua`: compact, hidden and full App mode lifecycle.
- `development/test_*.lua`: portable behavioural checks, each run in its own process.
- `development/`: editable assets, parity work and frozen historical evidence.
- `tools/`: current portable package and preview entry points.
- `docs/`: user manual, project status and AI handover.

The product's SD export contains only AERODECK. Personal model files, hardware deployment logs, Toolbox and other Lua applications belong in `fpv`. Old top-level `.txt` notes and dated evidence are retained for provenance; the README/manual and current entry points supersede their operational instructions.

## Check and package

Run these commands from the repository root:

```sh
python3 development/set_version.py --check
python3 tools/build_lua32.py
python3 development/run_checks.py --lua luajit --report .build/checks-luajit.json
python3 development/run_checks.py --lua .build/lua-5.3.6/src/lua --report .build/checks-lua32.json
python3 tools/package.py --reports .build/checks-luajit.json .build/checks-lua32.json
```

The Lua build uses [official Lua 5.3.6 source and its published checksum](https://www.lua.org/ftp/), builds into `.build/`, and verifies 4-byte integer/float representations. The packaging command checks every runtime and test hash against both passing reports. It includes only production Lua/icons, required licences, the manual and installation/manifest files. Outputs and checksums go in `dist/`; none of these commands touches a radio.

The old `development/package_release.py` and dated generators belong to historical releases. Use `tools/package.py` for new builds. Portable checks do not establish on-radio appearance, throughput or performance.

## Browser preview

Provide an externally built compatible TX16S `tx16s.wasm`, then run:

```sh
python3 tools/preview.py --wasm /path/to/tx16s.wasm --port 8766
```

Open <http://127.0.0.1:8766/> after startup. Use port 8767 if another preview is running. Ctrl-C stops it. The full-screen interaction uses a development-only wrapper and sample telemetry; production main/helpers/icons remain byte-exact. Source drift is detected and requires restarting the preview. No connected radio is used.

The loading-screen link displays a recorded native capture only when its manifest matches the current source; otherwise it reports unavailable. Do not substitute an old image to hide a source mismatch.

The externally built simulator must export the `simuLcd*`, touch/key, FatFS and WASI-threads API used in `tools/preview/host-pump.cjs`. Consult [EdgeTX's WASM build configuration](https://github.com/EdgeTX/edgetx/blob/main/cmake/wasm/CMakeLists.txt) for its build process. This repository does not bundle or automatically build the EdgeTX firmware. The validated local WASM fingerprint is recorded in `docs/migration.json`; a different firmware binary requires revalidation.

## Change workflow

1. Inspect `git status`, then create a short feature branch from `main`.
2. Read the relevant source and tests before changing behaviour.
3. Keep `VERSION.json` authoritative. After editing it, run `python3 development/set_version.py` to synchronize the Tool/widget literals.
4. Run relevant checks during editing and both complete portable suites before packaging. Review changed screens at native resolution in the simulator.
5. Record hardware acceptance separately: version/hash, radio/firmware/model/protocol, reproduction steps and result. User equipment records belong in `fpv`; sanitized general results may be added here.
6. Merge a reviewed change. Tag a candidate only after its intended acceptance checks; publish installation ZIPs/checksums as release assets, rather than committing repeated ZIPs.

Keep `main` usable. Use the calendar version policy in `VERSIONING.txt`; `-alpha` denotes ongoing development, and a version string is not a hardware acceptance result.

## Work through fpv

From a new equipment checkout:

```sh
git clone --recurse-submodules https://github.com/yislennierm/fpv.git
```

For an existing checkout:

```sh
git pull --ff-only
git submodule update --init --recursive
```

These commands assume your working trees are clean. Commit or preserve local changes before switching a submodule commit. To develop inside `fpv/software/aerodeck`, switch it to a named feature branch first; ordinary submodule updates can leave a detached HEAD.

Commit and push product changes in AERODECK first. Then, from the fpv root, stage `software/aerodeck` and commit the new pointer when that version is the one you want the equipment project to use. Updating AERODECK does not automatically advance fpv or deploy a radio.
