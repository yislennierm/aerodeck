"""Build or verify the local RC1 install archive from tested production files.

Run from any directory. No radio operations, network, preference changes, or Git
commands. Development fixtures and obsolete panel art never enter the archive.
"""
from pathlib import Path
import argparse
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = 'REPLACEMENT-RC1-20261017'
MANIFEST = ROOT / 'development' / ('build-' + BUILD + '.json')
ARCHIVE = ROOT / 'AERODECK-install.zip'
REPORT = ROOT / 'development' / ('test-results-' + BUILD + '.json')
NATIVE = ROOT / 'development/ui-previews/replacement-rc1/verification.json'
DOCS = ('START-HERE.txt', 'AERODECK.txt', 'REPLACEMENT-RC1.txt', 'IMPLEMENTATION-STATUS.txt')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def production():
    paths = [ROOT / 'sdcard/SCRIPTS/TOOLS/telem.lua', ROOT / 'sdcard/WIDGETS/AERODECK/main.lua']
    folder = ROOT / 'sdcard/SCRIPTS/TOOLS/AERODECK'
    paths += sorted(folder.glob('*.lua'))
    paths += sorted((folder / 'icons').rglob('*.png'))
    paths += [folder / 'icons/LICENSE.txt', folder / 'icons/README.txt']
    result = {}
    for path in paths:
        require(path.is_file(), 'Missing production asset: ' + str(path))
        relative = path.relative_to(ROOT / 'sdcard').as_posix()
        require(relative not in result, 'Duplicate production asset')
        result[relative] = path.read_bytes()
    for name, data in result.items():
        if name.endswith('.lua'):
            require(b'fixtureFields' not in data and b'fixtureStatusResponses' not in data,
                    'Development fixture in runtime: ' + name)
    # Independent OLC implementation: retain upstream algorithm licence with distribution.
    result['LICENSES/open-location-code.txt'] = (ROOT / 'development/navigation-utils/LICENSE').read_bytes()
    for name in DOCS:
        result[name] = (ROOT / name).read_bytes()
    return result


def evidence(files):
    expected = {str(p.relative_to(ROOT)) for p in (ROOT / 'development').glob('test_*.lua')}
    current_runtime = {
        'sdcard/' + name: digest(data) for name, data in files.items()
        if name.startswith(('SCRIPTS/', 'WIDGETS/')) and name.endswith(('.lua', '.png'))
    }
    reports = []
    for path in (REPORT, REPORT.with_name(REPORT.stem + '-float32.json')):
        require(path.is_file(), 'Missing portable acceptance: ' + str(path))
        report = json.loads(path.read_text())
        require(report.get('result') == 'PASS', 'Portable acceptance is not PASS: ' + path.name)
        require(report.get('mainSHA256') == digest(files['SCRIPTS/TOOLS/telem.lua']), 'Main differs from portable evidence')
        require(report.get('runtimeSHA256') == current_runtime,
                'Portable evidence differs from the complete current Lua/PNG inventory: ' + path.name)
        require(report.get('tests') and all(t['exitCode'] == 0 for t in report['tests']), 'Portable suite incomplete')
        require({t['file'] for t in report['tests']} == expected, 'Portable evidence misses current suite inventory')
        for test in report['tests']:
            require(digest((ROOT / test['file']).read_bytes()) == test['sha256'], 'Test changed after acceptance: ' + test['file'])
        for name, sha in report['runtimeSHA256'].items():
            require(digest((ROOT / name).read_bytes()) == sha, 'Runtime changed after tests: ' + name)
        reports.append(report)
    require(reports[0]['runtimeSHA256'] == reports[1]['runtimeSHA256'], 'Numeric runtimes tested different production files')
    require(NATIVE.is_file(), 'Missing native acceptance: ' + str(NATIVE))
    native = json.loads(NATIVE.read_text())
    require(native.get('result') == 'PASS', 'Native acceptance is not PASS')
    require(native.get('mainSHA256') == reports[0]['mainSHA256'], 'Native acceptance differs from current main')
    require(native.get('runtimeSHA256') == current_runtime, 'Native acceptance differs from the complete current Lua/PNG inventory')
    require(native.get('syntheticDataOnly') is True and native.get('hardwareVerified') is False,
            'Native acceptance must distinguish fixtures and physical radio testing')
    require(native.get('widgetExecutionVerified') is True, 'Production widget must execute in the native firmware VM')
    shots = native.get('screenshots', [])
    require(shots, 'Missing native visual acceptance')
    for shot in shots:
        relative = Path(shot['file'])
        require(not relative.is_absolute() and '..' not in relative.parts, 'Unsafe evidence path')
        image = NATIVE.parent / relative
        require(shot.get('visuallyInspected') is True and image.is_file() and digest(image.read_bytes()) == shot['sha256'],
                'Native image changed or was not reviewed: ' + str(relative))
    return reports[0], native


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true', help='Verify an existing archive without writing it')
    args = parser.parse_args()
    files = production()
    report, native = evidence(files)
    payload = {name: {'sha256': digest(data), 'bytes': len(data)} for name, data in sorted(files.items())}
    runtime = {name: row for name, row in payload.items() if name.startswith(('SCRIPTS/', 'WIDGETS/'))}
    if not args.verify:
        staging = ARCHIVE.with_suffix('.zip.tmp')
        with zipfile.ZipFile(staging, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            for name, data in sorted(files.items()):
                require(not name.startswith('/') and '..' not in Path(name).parts, 'Unsafe archive path')
                z.writestr(name, data)
        staging.replace(ARCHIVE)
        manifest = {'build': BUILD, 'status': 'LOCAL RELEASE CANDIDATE', 'installed': False,
                    'archive': ARCHIVE.name, 'archiveSha256': digest(ARCHIVE.read_bytes()),
                    'archiveBytes': ARCHIVE.stat().st_size, 'runtimeCount': len(runtime),
                    'portableSuiteCount': len(report['tests']), 'files': payload,
                    'testEvidence': [str(REPORT.relative_to(ROOT)), str(REPORT.with_name(REPORT.stem + '-float32.json').relative_to(ROOT))],
                    'nativeEvidence': str(NATIVE.relative_to(ROOT)),
                    'hardwareRenderingVerified': False, 'hardwarePerformanceMeasured': False,
                    'fasterThanToolboxMeasured': False,
                    'exclusions': ['Activation/licence enforcement only'],
                    'notShipped': ['Synthetic fixtures', 'User settings/model/radio files', 'Compiled Lua caches', 'Obsolete full-panel artwork']}
        MANIFEST.write_text(json.dumps(manifest, indent=2) + '\n')
    manifest = json.loads(MANIFEST.read_text())
    require(manifest['files'] == payload, 'Manifest differs from production files/docs')
    require(manifest['archiveSha256'] == digest(ARCHIVE.read_bytes()), 'Archive checksum mismatch')
    with zipfile.ZipFile(ARCHIVE) as z:
        require(z.testzip() is None and len(z.namelist()) == len(set(z.namelist())) == len(files), 'Archive corruption or duplicate paths')
        require(set(z.namelist()) == set(files), 'Unexpected/missing archive entries')
        for name, data in files.items():
            require(z.read(name) == data, 'Archive differs from accepted source: ' + name)
    print('PASS:', len(report['tests']), 'suites;', len(runtime), 'runtime assets;', len(files), 'archive entries;', ARCHIVE.stat().st_size, 'bytes')
    print('Archive SHA256:', manifest['archiveSha256'])


if __name__ == '__main__':
    main()
