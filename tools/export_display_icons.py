#!/usr/bin/env python3
"""Native 800x480 masks from the existing approved SVG masters; no resampling."""
from pathlib import Path
import argparse
import hashlib
import io
import json
import subprocess
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--project-root', type=Path, default=Path('.'))
parser.add_argument('--output', type=Path)
parser.add_argument('--manifest', type=Path)
args = parser.parse_args()
project = args.project_root.resolve()
output = args.output or project / 'sdcard/SCRIPTS/TOOLS/AERODECK/icons/800x480'
manifest = args.manifest or project / 'assets/icons/display-800x480.json'
native = project / 'sdcard/SCRIPTS/TOOLS/AERODECK/icons'
masters = project / 'assets/icons/material/masters'
output.mkdir(parents=True, exist_ok=True)
records = []
for existing in sorted(native.glob('*.png')):
    name = existing.stem
    small = name.endswith('-18')
    icon = name[:-3] if small else name
    master = (project / 'assets/icons/home-outlined-30.svg'
              if icon == 'home' else project/'assets/icons/quad.svg' if icon=='quad' else masters / (icon + '.svg'))
    if not master.is_file():
        raise SystemExit('No approved master: ' + str(master))
    size = 30 if small else 50
    result = subprocess.run(['rsvg-convert', '-w', str(size), '-h', str(size),
                             str(master)], check=True, capture_output=True)
    image = Image.open(io.BytesIO(result.stdout)).convert('RGBA')
    flat = Image.new('RGB', image.size, 'white')
    flat.paste(image, mask=image.getchannel('A'))
    target = output / existing.name
    flat.save(target, optimize=False, compress_level=9)
    data = target.read_bytes()
    records.append({
        'file': 'sdcard/SCRIPTS/TOOLS/AERODECK/icons/800x480/' + target.name,
        'virtualSize': 18 if small else 30,
        'width': size, 'height': size, 'mode': 'RGB',
        'sha256': hashlib.sha256(data).hexdigest(),
        'sourceMaster': str(master.relative_to(project)),
        'sourceMasterSha256': hashlib.sha256(master.read_bytes()).hexdigest(),
        'original480AssetSha256': hashlib.sha256(existing.read_bytes()).hexdigest(),
    })
record = {
    'format': 1, 'target': '800x480', 'uniformScale': '5/3',
    'method': 'rsvg-convert direct SVG rasterization; alpha flattened onto RGB white; no raster resize',
    'license': 'Apache-2.0; existing Google Material Symbols and AERODECK quad masters; provenance retained',
    'renderer': subprocess.check_output(['rsvg-convert', '--version'], text=True).strip(),
    'pillowVersion': Image.__version__, 'exports': records,
    'hardwareVerified': False, 'nativeOtherResolutionVerified': False,
}
manifest.parent.mkdir(parents=True, exist_ok=True)
manifest.write_text(json.dumps(record, indent=2) + '\n')
print(str(len(records)) + ' deterministic native masks exported')
