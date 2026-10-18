"""Stamp VERSION.json into Tool/widget constants, or verify with --check.

Constants avoid another SD-card read during radio startup. Historical packages,
test evidence and deployment records retain their original identities.
"""
from pathlib import Path
import argparse
import json
import re

ROOT = Path(__file__).resolve().parents[1]
TARGETS = {
    'sdcard/SCRIPTS/TOOLS/telem.lua': 'BUILD_ID',
    'sdcard/WIDGETS/AERODECK/main.lua': 'BUILD',
}


def version():
    value = json.loads((ROOT / 'VERSION.json').read_text())['version']
    if not isinstance(value, str) or not re.fullmatch(
        r'[1-9][0-9]{3}\.(?:[1-9]|1[0-2])\.(?:0|[1-9][0-9]*)(?:-(?:alpha|beta|rc[1-9][0-9]*))?', value
    ):
        raise SystemExit('VERSION.json must use YYYY.M.PATCH with optional -alpha, -beta or -rcN')
    return value


def stamp(check=False):
    value = version()
    pending = []
    for name, key in TARGETS.items():
        path = ROOT / name
        text = path.read_text()
        pattern = rf"(?m)^local {key}='([^']+)'$"
        found = re.findall(pattern, text)
        if len(found) != 1:
            raise SystemExit('Expected exactly one version constant in ' + name)
        if found[0] != value:
            pending.append((path, re.sub(pattern, f"local {key}='{value}'", text)))
    if check and pending:
        raise SystemExit('Version mismatch; run python3 development/set_version.py')
    for path, text in pending:
        path.write_text(text)
    return value


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    print(stamp(check=args.check))
