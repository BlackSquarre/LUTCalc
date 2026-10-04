"""用独立导数二次式核对旧Knee最小复现，不将结果表打包产品。"""
from pathlib import Path
from decimal import Decimal, localcontext
import json, hashlib, sys
ROOT=Path(__file__).resolve().parents[2]
fixture=ROOT/'tests/fixtures/native-contracts/knee-legacy-reference.json'
f=json.loads(fixture.read_text())
example=next(x for x in f['survey']['examples'] if x['name']=='Rec709' and x['start']==1 and x['clip']==6 and x['slope']==0)
with localcontext() as ctx:
    ctx.prec=70
    p0,p1,p2,d0,d1,d2=[Decimal.from_float(float(x)) for x in example['coefficients']]
    split=Decimal.from_float(example['split'])
    segments=[]
    for p,q,u,v in [(p0,p1,d0/(2*(1-split)),d1/(2*(1-split))),
                    (p1,p2,d1/(2*split),d2/(2*split))]:
        # Hermite derivative is a quadratic. Check its endpoint values and
        # stationary point rather than infer monotonicity from dense samples.
        a=2*p+u-2*q+v;b=-3*p-2*u+3*q-v
        points=[Decimal(0),Decimal(1)]
        if a!=0 and 0 < -b/(3*a) < 1:points.append(-b/(3*a))
        values=[(3*a*t*t+2*b*t+u,t) for t in points]
        minimum,t=min(values)
        segments.append({'minimumDerivative':str(minimum),'atLocalParameter':str(t),'nondecreasing':minimum>=0})
    assert segments[0]['nondecreasing'] and not segments[1]['nondecreasing']
result={'scope':'旧Knee单调性研究，非功能通过证明','precision':70,'example':example,'segments':segments,
        'survey':{k:v for k,v in f['survey'].items() if k!='examples'},
        'fixtureSHA256':hashlib.sha256(fixture.read_bytes()).hexdigest(),
        'scriptSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
output=json.dumps(result,ensure_ascii=False,indent=2)+'\n'
target=ROOT/'docs/native-validation/artifacts/2026-10-02-knee/derivative-audit.json'
if '--check' in sys.argv:
    assert target.read_text()==output
    print('旧Rec709 Knee第二段存在负导数的70位独立复现一致')
else:target.write_text(output);print(output)
