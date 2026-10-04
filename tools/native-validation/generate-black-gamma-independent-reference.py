"""以确切二进制输入和 70 位 Decimal 验证 Black Gamma；仅研发参照。"""
from decimal import Decimal, localcontext
from pathlib import Path
import json, hashlib, sys, math
ROOT=Path(__file__).resolve().parents[2]

def d(x): return Decimal.from_float(float(x))
cases=[]
with localcontext() as ctx:
    ctx.prec=70
    for black,lower,upper in [(0,.045,.18),(.1,.2,.5),(-.2,-.15,.3),(0,.5,.5)]:
        for power in [.01,.5,1,2,10]:
            b,l,u=d(black),d(lower),d(upper)
            values=[black,black-1e-10,black+1e-10,lower,lower-1e-10,lower+1e-10,upper,upper-1e-10,upper+1e-10,-2,30]
            values += [math.nextafter(a,direction) for a in [black,lower,upper] for direction in [-math.inf,math.inf]]
            values += [float(b+(u-b)*Decimal(i)/64) for i in range(65)]
            probes=[]
            for value in values:
                x=d(value);y=x
                if b<x<=u:
                    curved=((x-b)/(u-b))**d(power)*(u-b)+b
                    y=curved
                    if x>l and x>curved:
                        t=((x-l)/(u-l))**2
                        y=x*t+curved*(1-t)
                probes.append({'input':str(value),'output':str(y)})
            cases.append({'name':'independent Decimal','upperStops':0,'featherStops':0 if lower==upper else 2,
                          'power':power,'anchors':[str(black),str(lower),str(upper)],'probes':probes})
source=Path(__file__)
result={'precision':70,'sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'cases':cases}
output=json.dumps(result,ensure_ascii=False,indent=2)+'\n'
target=ROOT/'tests/fixtures/native-contracts/black-gamma-independent-reference.json'
if '--check' in sys.argv:
    assert target.read_text()==output
    print('独立Black Gamma 1640点70位Decimal参照一致')
else:
    target.write_text(output)
    print('已生成独立Black Gamma 1640点')
