"""Exact production Lua/PNG inventory shared by private preview helpers."""
from pathlib import Path
import hashlib

def inventory(project):
    root = Path(project)
    helper = root / 'sdcard/SCRIPTS/TOOLS/AERODECK'
    icons = helper / 'icons'
    assert helper.is_dir() and icons.is_dir(), 'Runtime directories missing'
    files = [root / 'sdcard/SCRIPTS/TOOLS/telem.lua',
             root / 'sdcard/WIDGETS/AERODECK/main.lua',
             *sorted(helper.glob('*.lua')), *sorted(icons.rglob('*.png'))]
    result = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in files}
    assert len(result) == len(files), 'Duplicate runtime path'
    return result

def match_inventory(project, expected):
    actual = inventory(project)
    assert actual == expected, 'Runtime file set or content hash changed'
    return len(actual)
