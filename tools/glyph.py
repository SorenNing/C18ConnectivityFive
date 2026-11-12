import struct,zlib,math
from pathlib import Path
W=96;H=96;raw=[]
for y in range(H):
 row=bytearray([0])
 for x in range(W):
  a=0;dx=x-48;dy=y-48;r=(dx*dx+dy*dy)**.5;ang=math.atan2(dy,dx)
  if 31<=x<=64 and 23<=y<=73 and (x<=33 or x>=62 or y<=25 or y>=71 or (x>=55 and y<=32)):a=255
  if 41<=x<=54 and 47<=y<=62 and (x<=43 or x>=52 or y<=49 or y>=60 or x==47 or y==55):a=255
  if 14<=r<=18 and (-2.7<ang<-.25 or .4<ang<2.7):a=255
  if 68<=x<=78 and 35<=y<=44:a=255
  if 18<=x<=28 and 52<=y<=61:a=255
  row+=bytes((255,255,255,a))
 raw.append(bytes(row))
def C(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
p=b'\x89PNG\r\n\x1a\n'+C(b'IHDR',struct.pack('>IIBBBBB',W,H,8,6,0,0,0))+C(b'IDAT',zlib.compress(b''.join(raw),9))+C(b'IEND',b'')
Path('Resources').mkdir(exist_ok=True);Path('Resources/C18DataSwitchGlyph.png').write_bytes(p)
