"""独立 Decimal 读回 Bolex/Panalog/DJI X5/Protune/DJI X3 legacy CUBE。"""
import sys
from decimal import Decimal, getcontext
getcontext().prec=90
P={
'bolex':(Decimal(1)/(Decimal('5.9861078')*Decimal('0.9')),-Decimal('0.0625265')/(Decimal('0.9')*Decimal('5.9861078')),Decimal('0.2756705'),Decimal(5),Decimal('0.4150634'),Decimal('0.0280665'),Decimal('0.1520070'),Decimal('0.014948')/Decimal('0.9'),Decimal(10)),
'panalog':(Decimal('0.324196014'),Decimal('-0.020278938'),Decimal('0.434198361'),Decimal('0.956463747'),Decimal('0.665276427'),Decimal('0.040913561'),Decimal('0.088290045'),Decimal(0),Decimal(10)),
'djiX5':(Decimal(1)/(Decimal('6.025')*Decimal('0.9')),-Decimal('0.0929')/(Decimal('6.025')*Decimal('0.9')),Decimal('0.256663'),Decimal('0.9892')*Decimal('0.9'),Decimal('0.584555'),Decimal('0.0108'),Decimal('0.14'),Decimal('0.0078')*Decimal('0.9'),Decimal(10)),
'protune':(Decimal(0),Decimal(0),Decimal(876)/Decimal(1023),Decimal('53.39427221'),Decimal(64)/Decimal(1023),Decimal(1),Decimal(0),Decimal(0),Decimal(113))}
def dec(v,p):
 a,b,c,d,e,f,g,h,base=p; return (base**((v-e)/c)-f)/d if v>=g else a*v+b
def enc(v,p):
 a,b,c,d,e,f,g,h,base=p
 if v>=h: return c*((v*d+f).ln()/base.ln())+e
 if a==0: return c*((Decimal('1e-15')*d+f).ln()/base.ln())+e
 return (v-b)/a
def read(path):
 n=None;r=[]
 for line in open(path,encoding='utf8'):
  f=line.split()
  if not f or f[0].startswith('#'):continue
  if f[0].upper()=='LUT_3D_SIZE':n=int(f[1])
  elif len(f)==3:r.append(tuple(Decimal(x) for x in f))
 if n is None or len(r)!=n**3:raise SystemExit('invalid cube')
 return n,r
name=sys.argv[2];n,rows=read(sys.argv[1]);worst=Decimal(0)
for i,row in enumerate(rows):
 cs=(Decimal(i%n)/Decimal(n-1),Decimal((i//n)%n)/Decimal(n-1),Decimal(i//(n*n))/Decimal(n-1))
 for x,c in zip(row,cs):worst=max(worst,abs(x-enc(Decimal(2)*dec(c,P[name]),P[name])))
tol=Decimal('3e-15')
if worst>tol:raise SystemExit(f'mismatch {name} {n} {worst}')
print(f'{name} independent Decimal CUBE passed size={n} samples={len(rows)*3} maxAbsError={worst} tolerance={tol}')
