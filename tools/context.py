"""Check the product checkout before continuing a chat or starting work.

Run from the product root. Reports local paths only to stdout; no conversation
transcript, credentials, personal equipment settings or app database is touched.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import sys
from runtime_inventory import inventory
from set_version import stamp

ROOT = Path(__file__).resolve().parents[1]


def git(*args, cwd=ROOT):
    result = subprocess.run(['git', '-C', str(cwd), *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Fail if invoked from another repository')
    parser.add_argument('--allow-submodule', action='store_true', help='Allow deliberate equipment integration work')
    args = parser.parse_args()
    working_root = git('rev-parse', '--show-toplevel', cwd=Path.cwd())
    superproject = git('rev-parse', '--show-superproject-working-tree')
    current = inventory(ROOT)
    same = bool(working_root and Path(working_root).resolve() == ROOT)
    role_ok = not superproject or args.allow_submodule
    data = {'project': 'AERODECK', 'repositoryRoot': str(ROOT),
            'activeDirectory': str(Path.cwd()), 'activeGitRoot': working_root,
            'workingInProductRepository': same, 'checkoutRole': 'submodule' if superproject else 'standalone',
            'origin': git('remote', 'get-url', 'origin'), 'branch': git('branch', '--show-current'),
            'commit': git('rev-parse', 'HEAD'), 'version': stamp(check=True),
            'runtimeFiles': len(current),
            'runtimeIdentity': hashlib.sha256(json.dumps(current, sort_keys=True).encode()).hexdigest(),
            'dirty': bool(git('status', '--porcelain')), 'continuationGuide': 'docs/development/CONTINUITY.md',
            'projectState': 'docs/development/PROJECT-STATE.md',
            'chatAssociationChanged': False}
    print(json.dumps(data, indent=2))
    if args.check and (not same or not role_ok):
        print('Select the standalone AERODECK folder, then rerun this check. Use --allow-submodule only for explicit equipment integration.', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
