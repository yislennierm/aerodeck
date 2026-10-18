"""Run the native sample-data browser preview in a disposable local directory.

Requires Python3.10+, Node22+ and a compatible externally built TX16S WASM.
Never copies fixtures to sdcard/ or operates a radio. Ctrl-C stops the preview.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/preview'))
from navigation_metadata import screen_routes
from runtime_inventory import inventory


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wasm', type=Path, default=ROOT / '.build/tx16s.wasm')
    parser.add_argument('--node', default=shutil.which('node'))
    parser.add_argument('--port', type=int, choices=[8766, 8767], default=8766)
    args = parser.parse_args()
    if not args.node or not args.wasm.is_file():
        parser.error('Provide Node22+ and --wasm PATH to a compatible EdgeTX TX16S WASI-threads simulator')
    workspace = ROOT / '.build/preview'
    fixture = ROOT / 'tools/preview/fixtures'
    runtime = workspace / 'runtime'
    if runtime.exists():
        shutil.rmtree(runtime)
    shutil.copytree(fixture / 'settings', runtime / 'settings')
    (runtime / 'sd').mkdir()
    shutil.copy2(fixture / 'edgetx.sdcard.version', runtime / 'sd/edgetx.sdcard.version')
    current = inventory(ROOT)
    for name in current:
        dest = runtime / 'sd' / name.removeprefix('sdcard/')
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, dest)
    # Wrapper synthesizes inputs; production main/helpers/icons remain exact.
    for source, dest in [('main.lua', 'WIDGETS/AERODECK/main.lua'),
                         ('QAENV.lua', 'SCRIPTS/TOOLS/QAENV.lua'),
                         ('QAMSP.lua', 'SCRIPTS/TOOLS/QAMSP.lua')]:
        shutil.copy2(fixture / source, runtime / 'sd' / dest)
    code = (ROOT / 'sdcard/SCRIPTS/TOOLS/telem.lua').read_text()
    build = re.search(r"local BUILD_ID='([^']+)'", code)[1]
    metadata = {'build': build, 'sourceSHA256': current['sdcard/SCRIPTS/TOOLS/telem.lua'],
                'runtimeSHA256': current, 'runtimeCount': len(current),
                'canonicalRoot': str(ROOT), 'localOnly': True, 'installed': False,
                'sampleTelemetry': True, 'lastFileVerifiedRadioBuild': 'equipment repository',
                'releaseValidation': 'Preview is not release or hardware acceptance',
                'nativeCallbackInstructionBudget': 20000, 'nativeBudgetHookModified': False,
                'screenRoutes': screen_routes(code),
                'simulatorSHA256': hashlib.sha256(args.wasm.read_bytes()).hexdigest()}
    (workspace / 'preview-build.json').write_text(json.dumps(metadata, indent=2) + '\n')
    env = dict(os.environ, EDGETX_SIM_SD=str(runtime / 'sd'),
               EDGETX_SIM_SETTINGS=str(runtime / 'settings'),
               AERODECK_SIM_WASM=str(args.wasm.resolve()), AERODECK_PREVIEW_HOME=str(workspace),
               AERODECK_PREVIEW_PORT=str(args.port))
    command = [args.node, '--disable-warning=ExperimentalWarning',
               str(ROOT / 'tools/preview/host-pump.cjs'),
               str(ROOT / 'tools/preview/interactive-review.js')]
    print(f'Preparing sample-data native preview at http://127.0.0.1:{args.port}/', flush=True)
    try:
        return subprocess.call(command, env=env)
    except KeyboardInterrupt:
        return 0


if __name__ == '__main__':
    sys.exit(main())
