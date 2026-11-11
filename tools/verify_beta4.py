import io,tarfile,hashlib,struct,plistlib,sys
from pathlib import Path
p=Path(sys.argv[1]);b=p.read_bytes();assert b[:8]==b'!<arch>\n';q=8;m={}
while q<len(b):h=b[q:q+60];assert h[58:]==b'`\n';n=h[:16].decode().strip().rstrip('/');z=int(h[48:58]);q+=60;m[n]=b[q:q+z];q+=z+z%2
assert set(m)=={'debian-binary','control.tar.gz','data.tar.gz'}
files={};control=''
for n,body in m.items():
 if n.startswith(('control','data')):
  with tarfile.open(fileobj=io.BytesIO(body),mode='r:*')as t:
   for x in t:
    name=x.name.removeprefix('./');assert not name.startswith('/') and '..' not in Path(name).parts
    if x.isfile():
     d=t.extractfile(x).read();files[name]=d
     if n.startswith('control')and name=='control':control=d.decode()
assert 'Ning&evgeniy558' in control
lib='Library/MobileSubstrate/DynamicLibraries/C18ConnectivityFive.dylib';assert lib in files and files[lib][:4]==bytes.fromhex('cafebabe');print('VERIFY_OK',len(b),hashlib.sha256(b).hexdigest())
