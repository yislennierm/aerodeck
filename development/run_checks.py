"""Run all AERODECK portable checks and bind results to exact source/assets.

Default: LuaJIT (or Lua if available). Use --lua PATH for a separately configured
Lua5.3 int32/float32 interpreter. These are synthetic portable checks, not radio
performance measurements. Each test runs in a fresh interpreter process.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
from set_version import stamp

ROOT = Path(__file__).resolve().parents[1]
BUILD = re.search(r"local BUILD_ID='([^']+)'", (ROOT / 'sdcard/SCRIPTS/TOOLS/telem.lua').read_text()).group(1)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    stamp(check=True)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua', default=shutil.which('luajit') or shutil.which('lua'))
    parser.add_argument('--report', type=Path, default=ROOT / 'development' / ('test-results-' + BUILD + '.json'))
    args = parser.parse_args()
    if not args.lua:
        parser.error('Install LuaJIT or specify --lua PATH')
    runtime = [ROOT / 'sdcard/SCRIPTS/TOOLS/telem.lua', ROOT / 'sdcard/WIDGETS/AERODECK/main.lua']
    folder = ROOT / 'sdcard/SCRIPTS/TOOLS/AERODECK'
    runtime += sorted(folder.glob('*.lua')) + sorted((folder / 'icons').rglob('*.png'))
    bound = {str(p.relative_to(ROOT)): sha(p) for p in runtime}
    binary = Path(args.lua)
    version = subprocess.run([str(binary), '-v'], capture_output=True, text=True)
    probe = subprocess.run([str(binary), '-e',
                            "print(string.packsize and string.packsize('j') or 'JIT',string.packsize and string.packsize('n') or 'double')"],
                           capture_output=True, text=True)
    report = {'build': BUILD, 'numericRepresentation': probe.stdout.strip(),
              'started': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'runtime': (version.stdout + version.stderr).strip(), 'interpreter': str(binary),
              'interpreterSHA256': sha(binary), 'syntheticDataOnly': True,
              'hardwarePerformanceMeasured': False, 'mainSHA256': bound['sdcard/SCRIPTS/TOOLS/telem.lua'],
              'runtimeSHA256': bound, 'tests': []}
    compatibility = 'loadstring=loadstring or load;unpack=unpack or table.unpack'
    for path in sorted((ROOT / 'development').glob('test_*.lua')):
        started = time.monotonic()
        try:
            result = subprocess.run([str(binary), '-e', compatibility, str(path.relative_to(ROOT))],
                                    cwd=ROOT, capture_output=True, text=True, timeout=120)
            code, output = result.returncode, result.stdout + result.stderr
        except subprocess.TimeoutExpired as error:
            code, output = 124, 'Test exceeded120s: ' + str(error)
        report['tests'].append({'file': str(path.relative_to(ROOT)), 'sha256': sha(path),
                                'exitCode': code, 'seconds': round(time.monotonic() - started, 3),
                                'output': output.strip()})
        print(('PASS ' if code == 0 else 'FAIL ') + path.name, flush=True)
    if any(sha(ROOT / name) != value for name, value in bound.items()):
        raise SystemExit('Runtime changed during testing; evidence was not written')
    report['result'] = 'PASS' if all(t['exitCode'] == 0 for t in report['tests']) else 'FAIL'
    report['completed'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(report['result'], len(report['tests']), 'suites;', args.report)
    return 0 if report['result'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
