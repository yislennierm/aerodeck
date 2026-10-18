"""Build the scoped roll patch from current behavioral and native evidence.

The frozen RC1 archive remains intact. Only telem.lua may differ at runtime.
"""
from pathlib import Path
import argparse
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = 'ROLL-DISPLAY-20261018'
ARCHIVE = ROOT / 'AERODECK-roll-display-install.zip'
MANIFEST = ROOT / 'development' / ('build-' + BUILD + '.json')
BASE_SHA = '07c80ba04dcc429b04e2e3deafa11a94b3b8077da6bac6cc6d77e7265aa323de'
NATIVE = ROOT / 'development/ui-previews/roll-display-20261018/verification.json'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(value, why):
    if not value:
        raise SystemExit(why)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    baseline = ROOT / 'AERODECK-install.zip'
    require(sha(baseline.read_bytes()) == BASE_SHA, 'Frozen RC1 baseline differs')
    with zipfile.ZipFile(baseline) as original:
        require(original.testzip() is None, 'Invalid baseline archive')
        baseline_runtime = {n: original.read(n) for n in original.namelist()
                            if n.startswith(('SCRIPTS/', 'WIDGETS/'))}
        olc_licence = original.read('LICENSES/open-location-code.txt')
    require(len(baseline_runtime) == 66, 'Expected 66 baseline runtime assets')
    files = {name: (ROOT / 'sdcard' / name).read_bytes() for name in baseline_runtime}
    require({n for n in files if files[n] != baseline_runtime[n]} == {'SCRIPTS/TOOLS/telem.lua'},
            'Patch changed runtime outside telem.lua')
    main_sha = sha(files['SCRIPTS/TOOLS/telem.lua'])
    require(("local BUILD_ID='" + BUILD + "'").encode() in files['SCRIPTS/TOOLS/telem.lua'], 'Wrong build ID')
    runtime = {'sdcard/' + name: sha(data) for name, data in files.items()
               if name.endswith(('.lua', '.png'))}
    require(len(runtime) == 64, 'Expected complete active runtime map')
    tests = {str(p.relative_to(ROOT)) for p in (ROOT / 'development').glob('test_*.lua')}
    require(len(tests) == 49, 'Expected complete 49-suite inventory')
    for suffix in ('', '-float32'):
        report = json.loads((ROOT / 'development' / ('test-results-' + BUILD + suffix + '.json')).read_text())
        require(report['build'] == BUILD and report['result'] == 'PASS', 'Portable checks incomplete')
        require(report['runtimeSHA256'] == runtime, 'Portable evidence is stale')
        require({t['file'] for t in report['tests']} == tests, 'Missing current tests')
        for test in report['tests']:
            require(test['exitCode'] == 0 and sha((ROOT / test['file']).read_bytes()) == test['sha256'], 'Changed/failing test')
    native = json.loads(NATIVE.read_text())
    require(native['result'] == 'PASS' and native['mainSHA256'] == main_sha, 'Native acceptance is stale')
    require(native['runtimeSHA256'] == runtime, 'Native runtime differs')
    require(native['syntheticDataOnly'] is True and native['hardwareVerified'] is False,
            'Native and physical acceptance must remain distinct')
    require(native['widgetExecutionVerified'] is True and native['nativeCallbackInstructionBudget'] == 20000,
            'Actual widget budget was not verified')
    require(native['nativeBudgetHookModified'] is False, 'Modified native instruction budget')
    required_checks = {'normal0DefaultPreservesNativeHorizonDirection',
                       'reversed1ProjectsRollAtDisplayBoundary', 'nativeUiSelectorSaveWritesOwnedModelFile',
                       'allThreeHudSurfacesAgree', 'rawTelemetryRollUnchanged',
                       'displayReadoutsMatchProjection', 'fixedArcSkyPointerConsistent'}
    checks = native['nativeChecks']
    require(required_checks <= set(checks) and all(v is True for v in checks.values()), 'Incomplete scoped checks')
    warm = native['warm']
    require(warm['elapsedSeconds'] >= 50 and warm['samples'] >= 1000
            and warm['blankFrames'] == warm['ordinaryUpdatingFrames'] == warm['instructionErrors'] == 0
            and warm['forcedGarbageCollection'] is False, 'Scoped warm check incomplete')
    require(sha((NATIVE.parent / warm['file']).read_bytes()) == warm['sha256'], 'Warm evidence changed')
    for support in native['supportingEvidence']:
        relative = Path(support['file'])
        require(not relative.is_absolute() and '..' not in relative.parts, 'Unsafe evidence path')
        require(sha((NATIVE.parent / relative).read_bytes()) == support['sha256'], 'Native evidence changed')
    for report in native['portableReports']:
        require(report['testInventory'] == 49 and report['result'] == 'PASS', 'Native bound reports incomplete')
        require(sha((ROOT / 'development' / report['file']).read_bytes()) == report['sha256'], 'Bound portable report changed')
    require(len(native['screenshots']) >= 24, 'Missing scoped pose screenshots')
    for shot in native['screenshots']:
        relative = Path(shot['file'])
        require(not relative.is_absolute() and '..' not in relative.parts, 'Unsafe screenshot path')
        require(shot['visuallyInspected'] is True and shot['sourceSha256'] == main_sha
                and shot['runtimeSHA256'] == runtime
                and sha((NATIVE.parent / relative).read_bytes()) == shot['sha256'],
                'Unreviewed or changed native screenshot')
    files['LICENSES/open-location-code.txt'] = olc_licence
    for name in ('START-HERE.txt', 'AERODECK.txt', 'ROLL-DISPLAY.txt'):
        files[name] = (ROOT / name).read_bytes()
    payload = {name: {'sha256': sha(data), 'bytes': len(data)} for name, data in sorted(files.items())}
    if not args.verify:
        temporary = ARCHIVE.with_suffix('.zip.tmp')
        with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as package:
            for name, data in sorted(files.items()):
                package.writestr(name, data)
        temporary.replace(ARCHIVE)
        manifest = {'build': BUILD, 'status': 'LOCAL PATCH CANDIDATE', 'installed': False,
                    'baselineBuild': 'REPLACEMENT-RC1-20261017', 'baselineArchiveSHA256': BASE_SHA,
                    'archive': ARCHIVE.name, 'archiveSHA256': sha(ARCHIVE.read_bytes()),
                    'mainSHA256': main_sha, 'runtimeCount': 66, 'portableSuiteCount': 49,
                    'runtimeChanged': ['SCRIPTS/TOOLS/telem.lua'], 'files': payload,
                    'nativeEvidence': str(NATIVE.relative_to(ROOT)), 'hardwareVerified': False,
                    'fasterThanToolboxMeasured': False}
        MANIFEST.write_text(json.dumps(manifest, indent=2) + '\n')
    manifest = json.loads(MANIFEST.read_text())
    require(manifest['files'] == payload and manifest['archiveSHA256'] == sha(ARCHIVE.read_bytes()),
            'Patch manifest differs')
    with zipfile.ZipFile(ARCHIVE) as package:
        require(package.testzip() is None and len(package.namelist()) == len(set(package.namelist())) == len(files),
                'Archive corruption or duplicate entries')
        require(set(package.namelist()) == set(files), 'Missing/extra archive file')
        for name, data in files.items():
            require(package.read(name) == data, 'Archive differs from accepted source')
    print('PASS: 49 suites in both runtimes; 66 runtime assets;', len(files), 'archive entries')
    print('Archive SHA256:', manifest['archiveSHA256'])


if __name__ == '__main__':
    main()
