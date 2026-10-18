"""Export original directional quad artwork to native-size EdgeTX RGB masks.
No runtime rotation: sixteen22.5-degree frames in each supported asset namespace.
Requires librsvg's rsvg-convert; source vectors remain editable.
"""
from pathlib import Path
import hashlib,json,subprocess,tempfile
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
MASTER=Path(__file__).with_name('quad-direction.svg')
exports=[]
source=MASTER.read_text();start=source.index('<g ');stop=source.rindex('</g>')+4;glyph=source[start:stop]
for index in range(16):
 angle=index*22.5
 rotated='<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 36 36"><rect width="36" height="36" fill="white"/><g transform="rotate('+str(angle)+' 18 18)">'+glyph+'</g></svg>'
 for folder,size in (('',18),('800x480/',30)):
  dest=ROOT/'sdcard/SCRIPTS/TOOLS/AERODECK/icons'/folder/('quad-heading-%02d-18.png'%index)
  with tempfile.TemporaryDirectory()as temporary:
   svg=Path(temporary)/'frame.svg';png=Path(temporary)/'frame.png';svg.write_text(rotated)
   subprocess.run(['/usr/local/bin/rsvg-convert','-w',str(size),'-h',str(size),'-o',str(png),str(svg)],check=True)
   Image.open(png).convert('RGB').save(dest)
  exports.append({'file':str(dest.relative_to(ROOT)),'size':[size,size],'bearingDegrees':angle,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
record={'name':'quad-direction','author':'AERODECK original vector artwork','license':'Apache-2.0','virtualSize':18,'purpose':'Nose-marked quad; body yaw preferred, GPS course fallback labelled explicitly','rotation':'Offline16frames; nearest22.5deg, maximum11.25deg visual quantization; exact native direction tick retained','masterSHA256':hashlib.sha256(MASTER.read_bytes()).hexdigest(),'exports':exports}
MASTER.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n')
print('Exported',len(exports),'RGB native masks')
