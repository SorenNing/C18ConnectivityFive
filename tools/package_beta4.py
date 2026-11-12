import io,tarfile,gzip,hashlib,re
from pathlib import Path
from mkdeb import pack
BASE=Path('dist/base');PKG=Path('dist/pkg');MEMBERS=Path('dist/members');OUT=Path('dist/com.evgeniy558.controlcenter18_3.0-beta4-five4_iphoneos-arm64e.deb');SIM_MODULE=Path('Library/ControlCenter/Bundles/CCSIM.bundle')
def copy(t,m,r):
 n=m.name
 if not n or n in('./','.'):return
 p=Path(n.removeprefix('./'));assert not p.is_absolute() and '..' not in p.parts;d=r/p
 if m.isdir():d.mkdir(parents=True,exist_ok=True)
 elif m.issym():d.parent.mkdir(parents=True,exist_ok=True);d.symlink_to(m.linkname)
 elif m.isfile():d.parent.mkdir(parents=True,exist_ok=True);d.write_bytes(t.extractfile(m).read());d.chmod(m.mode&0o7777)
def extract(path,r):
 b=Path(path).read_bytes();q=8;c=d=None
 while q<len(b):
  h=b[q:q+60];n=h[:16].decode().strip().rstrip('/');z=int(h[48:58]);q+=60;body=b[q:q+z];q+=z+z%2
  if n.startswith('control.tar'):c=body
  elif n.startswith('data.tar'):d=body
 with tarfile.open(fileobj=io.BytesIO(c),mode='r:*')as t:
  for m in t:copy(t,m,r/'DEBIAN')
 with tarfile.open(fileobj=io.BytesIO(d),mode='r:*')as t:
  for m in t:copy(t,m,r)
def tgz(path,r,deb):
 buf=io.BytesIO()
 with tarfile.open(fileobj=buf,mode='w',format=tarfile.USTAR_FORMAT)as t:
  for p in [r]+sorted(r.rglob('*')):
   x=p.relative_to(r)
   if deb and x.parts and x.parts[0]=='DEBIAN':continue
   i=tarfile.TarInfo('.' if p==r else './'+x.as_posix());i.uid=i.gid=0;i.uname=i.gname='root';i.mtime=0
   if p.is_dir():i.type=tarfile.DIRTYPE;i.mode=0o755;t.addfile(i)
   elif p.is_file():z=p.read_bytes();i.size=len(z);i.mode=p.stat().st_mode&0o7777;t.addfile(i,io.BytesIO(z))
 with open(path,'wb')as f:
  with gzip.GzipFile(fileobj=f,mode='wb',mtime=0)as z:z.write(buf.getvalue())
def main():
 import shutil
 for p in(PKG,MEMBERS):
  if p.exists():shutil.rmtree(p)
  p.mkdir(parents=True)
 extract('dist/beta4.deb',PKG)
 g=Path('Resources/C18DataSwitchGlyph.png');assert g.exists() and g.read_bytes()[:8]==b'\x89PNG\r\n\x1a\n';d=PKG/'Library/MobileSubstrate/DynamicLibraries/C18DataSwitchGlyph.png';d.parent.mkdir(parents=True,exist_ok=True);d.write_bytes(g.read_bytes())
 b=PKG/SIM_MODULE;assert b.is_dir()
 for n in ('CCSIM.png','CCSIM@2x.png','CCSIM@3x.png'):(b/n).write_bytes((Path('Resources/CCSIM.bundle')/n).read_bytes())
 l=PKG/'Library/MobileSubstrate/DynamicLibraries/C18ConnectivityFive.dylib';l.parent.mkdir(parents=True,exist_ok=True);l.write_bytes(Path('build/C18ConnectivityFive.dylib').read_bytes());l.chmod(0o755);(PKG/'Library/MobileSubstrate/DynamicLibraries/C18ConnectivityFive.plist').write_bytes(Path('C18ConnectivityFive.plist').read_bytes())
 c=PKG/'DEBIAN/control';s=c.read_text();s=re.sub(r'^Version:.*$','Version: 3.0-beta4-five4',s,flags=re.M);s=re.sub(r'^Maintainer:.*$','Maintainer: Ning&evgeniy558',s,flags=re.M);s=re.sub(r'^Author:.*$','Author: Ning&evgeniy558',s,flags=re.M);c.write_text(s);(MEMBERS/'debian-binary').write_bytes(b'2.0\n');tgz(MEMBERS/'control.tar.gz',PKG/'DEBIAN',False);tgz(MEMBERS/'data.tar.gz',PKG,True);pack(str(OUT),str(MEMBERS));print(OUT,hashlib.sha256(OUT.read_bytes()).hexdigest())
if __name__=='__main__':main()
