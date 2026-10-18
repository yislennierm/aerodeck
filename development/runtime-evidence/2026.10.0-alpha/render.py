from pathlib import Path
import struct,zlib
w=Path(__file__).resolve().parent/'native'
def rgb(p):
 raw=p.read_bytes();assert len(raw)==480*272*2
 return bytes(c for(v,)in struct.iter_unpack('<H',raw)for c in (((v>>11)&31)*255//31,((v>>5)&63)*255//63,(v&31)*255//31))
def png(p,data,width=480,height=272):
 def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d))
 rows=b''.join(b'\0'+data[y*width*3:(y+1)*width*3]for y in range(height))
 p.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(rows))+chunk(b'IEND',b''))
imgs=[rgb(w/'early'/f'{n:03d}.raw')for n in [30,40,50,60]]
data=bytearray(960*544*3)
for n,img in enumerate(imgs):
 for y in range(272):
  start=((n//2*272+y)*960+n%2*480)*3;data[start:start+1440]=img[y*1440:(y+1)*1440]
png(w/'contact.png',data,960,544)
for p in w.glob('*.raw'):png(p.with_suffix('.png'),rgb(p))
