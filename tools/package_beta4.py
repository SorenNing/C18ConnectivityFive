import io,tarfile,gzip,hashlib,re
from pathlib import Path
from mkdeb import pack
BASE=Path('dist/base');PKG=Path('dist/pkg');MEMBERS=Path('dist/members');OUT=Path('dist/com.evgeniy558.controlcenter18_3.0-beta4-five4_iphoneos-arm64e.deb');SIM_MODULE=Path('Library/ControlCenter/Bundles/CCSIM.bundle')
SIM_BUTTON_ICONS={'CCSIM.png':(50,'f7d5e9c9d43b1317c12cc631f48f04e04d57648fd6cfb67bcaae7a1b6f4c7743'),'CCSIM@2x.png':(100,'d300cd5e9d59ea6cd408fb474ebce41142768738e70d22a16a0c88ebdded8d01'),'CCSIM@3x.png':(150,'a447eea7f4a11f424615b4435589d65d1bf0db75901b9aa277bbdba6f3c18e5c')}
DATA_SWITCH_GLYPH=Path('Resources/C18DataSwitchGlyph.png');DATA_SWITCH_GLYPH_SHA256='34c2b0e4a79fa6a1b1b53f0c7e534519c4ad80bbd4c689ac58e88423fbaa6440'
def install(root):
 b=root/SIM_MODULE;assert b.is_dir();d=DATA_SWITCH_GLYPH.read_bytes();assert hashlib.sha256(d).hexdigest()==DATA_SWITCH_GLYPH_SHA256;t=root/'Library/MobileSubstrate/DynamicLibraries/C18DataSwitchGlyph.png';t.parent.mkdir(parents=True,exist_ok=True);t.write_bytes(d);t.chmod(0o644)
 for n,(s,h) in SIM_BUTTON_ICONS.items():
  d=(Path('Resources/CCSIM.bundle')/n).read_bytes();assert hashlib.sha256(d).hexdigest()==h;t=b/n;t.write_bytes(d);t.chmod(0o644)
def copy(tar,m,root):
 n=m.name
 if not n or n in('./','.'):return
 r=Path(n.removeprefix('./'));assert not r.is_absolute() and '..' not in r.parts;d=root/r
 if m.isdir():d.mkdir(parents=True,exist_ok=True)
 elif m.issym():d.parent.mkdir(parents=True,exist_ok=True);d.symlink_to(m.linkname)
 elif m.isfile():d.parent.mkdir(parents=True,exist_ok=True);d.write_bytes(tar.extractfile(m).read());d.chmod(m.mode&0o7777)
def extract(path,root):
 b=Path(path).read_bytes();q=8;data=control=None
 while q<len(b):
  h=b[q:q+60];n=h[:16].decode().strip().rstrip('/');z=int(h[48:58]);q+=60;body=b[q:q+z];q+=z+z%2
  if n.startswith('control.tar'):control=body
  elif n.startswith('data.tar'):data=body
 with tarfile.open(fileobj=io.BytesIO(control),mode='r:*')as t:
  for m in t:copy(t,m,root/'DEBIAN')
 with tarfile.open(fileobj=io.BytesIO(data),mode='r:*')as t:
  for m in t:copy(t,m,root)
def tgz(path,root,deb):
 buf=io.BytesIO()
 with tarfile.open(fileobj=buf,mode='w',format=tarfile.USTAR_FORMAT)as t:
  for p in [root]+sorted(root.rglob('*')):
   r=p.relative_to(root)
   if deb and r.parts and r.parts[0]=='DEBIAN':continue
   i=tarfile.TarInfo('.' if p==root else './'+r.as_posix());i.uid=i.gid=0;i.uname=i.gname='root';i.mtime=0
   if p.is_dir():i.type=tarfile.DIRTYPE;i.mode=0o755;t.addfile(i)
   elif p.is_symlink():i.type=tarfile.SYMTYPE;i.linkname=p.readlink().as_posix();i.mode=0o777;t.addfile(i)
   elif p.is_file():d=p.read_bytes();i.size=len(d);i.mode=p.stat().st_mode&0o7777;t.addfile(i,io.BytesIO(d))
 with open(path,'wb')as f:
  with gzip.GzipFile(fileobj=f,mode='wb',mtime=0)as g:g.write(buf.getvalue())
def main():
 for p in(PKG,MEMBERS):
  import shutil
  if p.exists():shutil.rmtree(p)
  p.mkdir(parents=True)
 extract('dist/beta4.deb',PKG);install(PKG);l=PKG/'Library/MobileSubstrate/DynamicLibraries/C18ConnectivityFive.dylib';l.parent.mkdir(parents=True,exist_ok=True);l.write_bytes(Path('build/C18ConnectivityFive.dylib').read_bytes());l.chmod(0o755);p=PKG/'Library/MobileSubstrate/DynamicLibraries/C18ConnectivityFive.plist';p.write_bytes(Path('C18ConnectivityFive.plist').read_bytes());c=PKG/'DEBIAN/control';s=c.read_text();s=re.sub(r'^Version:.*$','Version: 3.0-beta4-five4',s,flags=re.M);s=re.sub(r'^Maintainer:.*$','Maintainer: Ning&evgeniy558',s,flags=re.M);s=re.sub(r'^Author:.*$','Author: Ning&evgeniy558',s,flags=re.M);c.write_text(s);(MEMBERS/'debian-binary').write_bytes(b'2.0\n');tgz(MEMBERS/'control.tar.gz',PKG/'DEBIAN',False);tgz(MEMBERS/'data.tar.gz',PKG,True);pack(str(OUT),str(MEMBERS));print(OUT,hashlib.sha256(OUT.read_bytes()).hexdigest())
if __name__=='__main__':main()
