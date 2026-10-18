"""Build a source-bound install ZIP from passing portable reports.

No radio operations. Historical manifests/packages are not rewritten. Outputs
are reproducible for the same input files and reports and are placed in dist/.
"""
from pathlib import Path
import argparse
import hashlib
import json
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
from set_version import stamp
from runtime_inventory import inventory


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reports', type=Path, nargs=2, required=True,
                        help='Passing LuaJIT and Lua5.3 int32/float32 reports')
    args = parser.parse_args()
    build = stamp(check=True)
    runtime = inventory(ROOT)
    expected_tests = {str(p.relative_to(ROOT)) for p in (ROOT / 'tests').glob('test_*.lua')}
    evidence = []
    representations = set()
    for path in args.reports:
        report = json.loads(path.read_text())
        assert report['build'] == build and report['result'] == 'PASS', 'Version/failing report mismatch'
        assert report['runtimeSHA256'] == runtime, 'Runtime differs from tested bytes'
        assert {t['file'] for t in report['tests']} == expected_tests, 'Suite inventory changed'
        for test in report['tests']:
            assert test['exitCode'] == 0 and digest((ROOT / test['file']).read_bytes()) == test['sha256'], 'Test changed/failed'
        representations.add(report['numericRepresentation'])
        evidence.append({'file': path.name, 'sha256': digest(path.read_bytes())})
    assert any('JIT' in value for value in representations) and any(value.split() == ['4', '4'] for value in representations), 'Require LuaJIT and Lua5.3 int32/float32 coverage'
    payload = {name.removeprefix('sdcard/'): (ROOT / name).read_bytes() for name in runtime}
    for name in ['SCRIPTS/TOOLS/AERODECK/icons/LICENSE.txt', 'SCRIPTS/TOOLS/AERODECK/icons/README.txt']:
        payload[name] = (ROOT / 'sdcard' / name).read_bytes()
    payload['LICENSES/open-location-code.txt'] = (ROOT / 'tests/data/navigation-utils/LICENSE').read_bytes()
    payload['USER-MANUAL.md'] = (ROOT / 'docs/USER-MANUAL.md').read_bytes()
    payload['INSTALL.txt'] = (f'AERODECK {build}\nMerge SCRIPTS, WIDGETS and LICENSES into the SD root.\nPreserve settings, safely eject and restart the radio.\nSee USER-MANUAL.md.\n').encode()
    payload['AERODECK-MANIFEST.json'] = (json.dumps({'version': build, 'runtimeSHA256': {name.removeprefix('sdcard/'): h for name, h in runtime.items()}, 'portableReports': evidence, 'hardwareAcceptanceClaimed': False}, indent=2) + '\n').encode()
    out = ROOT / 'dist'
    out.mkdir(exist_ok=True)
    archive = out / f'AERODECK-{build}-install.zip'
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as z:
        for name, data in sorted(payload.items()):
            entry = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            z.writestr(entry, data)
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None and len(z.namelist()) == len(payload)
        for name, data in payload.items():
            assert z.read(name) == data
    sha = digest(archive.read_bytes())
    archive.with_suffix('.zip.sha256').write_text(sha + '  ' + archive.name + '\n')
    print(json.dumps({'archive': str(archive), 'sha256': sha, 'runtimeFiles': len(runtime), 'entries': len(payload)}, indent=2))


if __name__ == '__main__':
    main()
