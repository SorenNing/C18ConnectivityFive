import struct,zlib,math
from pathlib import Path

def png(w,h,kind):
 rows=[]
 for y in range(h):
  row=bytearray([0])
  for x in range(w):
   sx=x*w/96;sy=y*h/96;a=0;dx=sx-48;dy=sy-48;r=(dx*dx+dy*dy)**.5;ang=math.atan2(dy,dx)
   if kind=='data':
    if 31<=sx<=64 and 23<=sy<=73 and (sx<=33 or sx>=62 or sy<=25 or sy>=71 or (sx>=55 and sy<=32)):a=255
    if 41<=sx<=54 and 47<=sy<=62 and (sx<=43 or sx>=52 or sy<=49 or sy>=60 or sx==47 or sy==55):a=255
    if 14<=r<=18 and (-2.7<ang<-.25 or .4<ang<2.7):a=255
    if 68<=sx<=78 and 35<=sy<=44:a=255
    if 18<=sx<=28 and 52<=sy<=61:a=255
   else:
    if abs(sx-48)<4 and 29<sy<68:a=255
    if 35<sx<61 and 29<sy<34:a=255
    if 30<sx<66 and 34<sy<38 and abs(sx-48)>8:a=255
    if (sx-48)**2+(sy-66)**2<8**2:a=255
    if abs(sx-34)<3 and 31<sy<57:a=255
    if abs(sx-62)<3 and 31<sy<57:a=255
   row+=bytes((255,255,255,a))
  rows.append(bytes(row))
 def C(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
 return b'\x89PNG\r\n\x1a\n'+C(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+C(b'IDAT',zlib.compress(b''.join(rows),9))+C(b'IEND',b'')
Path('Resources/CCSIM.bundle').mkdir(parents=True,exist_ok=True)
Path('Resources/C18DataSwitchGlyph.png').write_bytes(png(96,96,'data'))
for s in (50,100,150):Path(f'Resources/CCSIM.bundle/CCSIM{"@2x" if s==100 else "@3x" if s==150 else ""}.png').write_bytes(png(s,s,'sim'))
