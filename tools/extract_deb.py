import io,tarfile,sys
from pathlib import Path
def safe(n):
 n=n.removeprefix('./');p=Path(n)
 if p.is_absolute() or '..' in p.parts:raise RuntimeError('unsafe '+n)
 return p
def ext(payload,root):
 with tarfile.open(fileobj=io.BytesIO(payload),mode='r:*') as t:
  for m in t:
   r=safe(m.name)
   if not str(r) or str(r)=='.':continue
   d=root/r
   if m.isdir():d.mkdir(parents=True,exist_ok=True)
   elif m.issym():d.parent.mkdir(parents=True,exist_ok=True);d.symlink_to(m.linkname)
   elif m.isfile():d.parent.mkdir(parents=True,exist_ok=True);d.write_bytes(t.extractfile(m).read());d.chmod(m.mode&0o7777)
def main(inp,out):
 b=Path(inp).read_bytes();assert b[:8]==b'!<arch>\n';q=8;c=d=None
 while q<len(b):
  h=b[q:q+60];assert h[58:]==b'`\n';n=h[:16].decode().strip().rstrip('/');z=int(h[48:58]);q+=60;body=b[q:q+z];q+=z+z%2
  if n.startswith('control.tar'):c=body
  elif n.startswith('data.tar'):d=body
 r=Path(out);r.mkdir(parents=True,exist_ok=True);(r/'DEBIAN').mkdir(exist_ok=True);ext(c,r/'DEBIAN');ext(d,r)
 assert (r/'DEBIAN/control').is_file()
if __name__=='__main__':main(sys.argv[1],sys.argv[2])
