"""独立 Decimal 读回 DaVinci Intermediate legacy CUBE。"""
import sys
from decimal import Decimal,getcontext
getcontext().prec=90
A=Decimal('0.0075'); B=Decimal(7); C=Decimal('0.07329248'); M=Decimal('10.44426855'); LC=Decimal('0.00262409'); GC=Decimal('0.02740668'); LS=Decimal('0.9'); S=Decimal('0.85630498533724'); O=Decimal('0.06256109481916')
def dec(v):
    l=(v-O)/S; return ((Decimal(2)**(l/C-B))-A)/LS if l>=GC else (l/M)/LS
def enc(v):
    x=v*LS; l=((x+A).ln()/Decimal(2).ln()+B)*C if x>LC else x*M; return l*S+O
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
    for x,c in zip(row,cs):w=max(w,abs(x-enc(Decimal(2)*dec(c))))
t=Decimal('3e-15')
if w>t:raise SystemExit(f'mismatch {n} {w}')
print(f'DaVinci Intermediate independent Decimal CUBE passed size={n} samples={len(rows)*3} maxAbsError={w} tolerance={t}')
