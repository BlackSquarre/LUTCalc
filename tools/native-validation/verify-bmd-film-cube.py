"""独立 Decimal 读回 BMD Film family legacy 同空间曝光 CUBE。"""
import sys
from decimal import Decimal, getcontext
getcontext().prec = 90
P = {
    'film': ('0.2350042002', '-0.0218236752', '0.367608577', '0.9642942555555556', '0.644065346', '0.03135747', '0.114002127', '0.006132473333333333'),
    'film4k': ('0.335139246', '-0.0311227209', '0.582240088', '2.908845613333333', '0.461883884', '0.231964429', '0.10772883', '0.006149923333333333'),
    'film46k': ('0.21707462111111112', '-0.01585951888888889', '0.36274758', '0.948106728', '0.63659829', '0.027616437', '0.096214896', '0.0040712976'),
}
def decode(v, p):
    slope, intercept, log_scale, input_scale, log_offset, input_offset, cut, _ = map(Decimal, p)
    return (Decimal(10) ** ((v-log_offset)/log_scale) - input_offset) / input_scale if v >= cut else slope*v + intercept
def encode(v, p):
    slope, intercept, log_scale, input_scale, log_offset, input_offset, _, cut = map(Decimal, p)
    return log_scale * (v*input_scale + input_offset).log10() + log_offset if v >= cut else (v-intercept)/slope
def read(path):
    size=None; rows=[]
    for line in open(path, encoding='utf-8'):
        f=line.split()
        if not f or f[0].startswith('#'): continue
        if f[0].upper()=='LUT_3D_SIZE': size=int(f[1])
        elif len(f)==3: rows.append(tuple(Decimal(x) for x in f))
    if size is None or len(rows)!=size**3: raise SystemExit('invalid cube')
    return size,rows
variant=sys.argv[2]; size,rows=read(sys.argv[1]); p=P[variant]; worst=Decimal(0)
for i,row in enumerate(rows):
    coords=(Decimal(i%size)/Decimal(size-1),Decimal((i//size)%size)/Decimal(size-1),Decimal(i//(size*size))/Decimal(size-1))
    for actual, c in zip(row,coords): worst=max(worst,abs(actual-encode(Decimal(2)*decode(c,p),p)))
tol=Decimal('3e-15')
if worst>tol: raise SystemExit(f'mismatch {variant} {size} {worst}')
print(f'BMD {variant} independent Decimal CUBE passed size={size} samples={len(rows)*3} maxAbsError={worst} tolerance={tol}')
