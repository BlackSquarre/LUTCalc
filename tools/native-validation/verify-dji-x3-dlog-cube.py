"""独立 Decimal 读回 DJI X3 DLog legacy soft-clip CUBE。"""
import sys
from decimal import Decimal,getcontext
getcontext().prec=90
p=(Decimal('0.188272019'),Decimal('-0.011778504'),Decimal('0.473218054'),Decimal('6.086793376'),Decimal(10),Decimal('0.419294419'),Decimal('0.169033387'),Decimal('0.095812746'),Decimal('0.00625'),Decimal('0.902863937'),Decimal('1.59668525'),Decimal('22.90700861'),Decimal('-17.39462704'))
def dec(v):
 a,b,c,d,e,f,g,h,i,j,k,l,m=p
 return (Decimal(2)**(l*v+m)*Decimal('0.2')) if v>=j else ((Decimal(10)**((v-f)/c)-g)/d if v>=h else a*v+b)
def enc(v):
 a,b,c,d,e,f,g,h,i,j,k,l,m=p
 return ((v/Decimal('0.2')).ln()/Decimal(2).ln()-m)/l if v>=k else (c*(v*d+g).ln()/e.ln()+f if v>=i else (v-b)/a)
def read(path):
 n=None;r=[]
 for line in open(path,encoding='utf8'):
  f=line.split()
  if not f or f[0].startswith('#'):continue
  if f[0].upper()=='LUT_3D_SIZE':n=int(f[1])
  elif len(f)==3:r.append(tuple(Decimal(x) for x in f))
 if n is None or len(r)!=n**3:raise SystemExit('invalid cube')
 return n,r
n,rows=read(sys.argv[1]);w=Decimal(0)
for i,row in enumerate(rows):
 cs=(Decimal(i%n)/Decimal(n-1),Decimal((i//n)%n)/Decimal(n-1),Decimal(i//(n*n))/Decimal(n-1))
 for x,c0 in zip(row,cs):w=max(w,abs(x-enc(Decimal(2)*dec(c0))))
t=Decimal('3e-15')
if w>t:raise SystemExit(f'mismatch {n} {w}')
print(f'DJI X3 DLog independent Decimal CUBE passed size={n} samples={len(rows)*3} maxAbsError={w} tolerance={t}')
