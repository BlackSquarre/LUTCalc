"""独立有理数原色求解与70位Decimal SDR Saturation参照。"""
from decimal import Decimal as D, localcontext
from pathlib import Path
import importlib.util
import json
import sys

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('independent_primaries',Path(__file__).with_name('generate-asccdl-independent-reference.py'))
prim=importlib.util.module_from_spec(spec)
spec.loader.exec_module(prim)

def generate():
    with localcontext() as ctx:
        ctx.prec=70
        matrix=prim.primaries([('.708','.292'),('.170','.797'),('.131','.046')])
        y=[prim.decimal(v) for v in matrix[1]]
        points=[[D(0)]*3,[D(-1),D(-2),D(-3)],[D(1),D(0),D(0)],
                [D(0),D(1),D(0)],[D(0),D(0),D(1)],[D(12)]*3,[D(24)]*3]
        for i in range(64):
            points.append([D(i%7)/6-D('.25'),D(i%11)/5-D('.5'),D(i%13)/3])
        cases=[]
        for gamma in map(D,['1','1.2','1.5','2']):
            probes=[]
            for p in points:
                q=[v/12 if v<0 else ctx.power(v/12,1/gamma) for v in p]
                l=sum(a*b for a,b in zip(y,q))
                # Independently eliminate Pb/Pr: q + L^gamma - L, all channels.
                result=[(v+ctx.power(l,gamma)-l)*12 for v in q] if l>0 else p
                probes.append({'input':[float(v) for v in p],'output':[str(v) for v in result]})
            cases.append({'gamma':float(gamma),'probes':probes})
        return {'method':'精确Rec2020/D65矩阵Y行与70位Decimal，独立消去Pb/Pr后重建三通道',
                'luma':[str(v) for v in y],'cases':cases}

if __name__=='__main__':
    target=ROOT/'tests/fixtures/native-contracts/sdr-saturation-independent-reference.json'
    text=json.dumps(generate(),ensure_ascii=False,indent=2)+'\n'
    if '--check' in sys.argv:
        assert target.read_text()==text,'独立SDR Saturation参照发生变化'
        print('独立SDR Saturation 284点有理数/70位Decimal参照一致')
    else:
        target.write_text(text)
        print('已冻结独立SDR Saturation 284点')
