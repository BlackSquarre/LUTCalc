"""独立有理数原色、70位Decimal跨度压缩与两阶段采样参照。"""
from pathlib import Path
from fractions import Fraction as F
from decimal import Decimal as D, localcontext
import importlib.util,json,hashlib,struct,sys
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('prim',Path(__file__).with_name('generate-asccdl-independent-reference.py'))
prim=importlib.util.module_from_spec(spec);spec.loader.exec_module(prim)
def dec(x):return D(x.numerator)/D(x.denominator)
def exact(x):return D.from_float(float(x))
with localcontext() as ctx:
    ctx.prec=70
    matrices={
        'rec2020.d65.v1':prim.primaries([('.708','.292'),('.170','.797'),('.131','.046')]),
        'srgb.d65.v1':prim.primaries([('.640','.330'),('.300','.600'),('.150','.060')]),
    }
    def encoder(x):return exact(4.5)*x if x<exact(.018) else exact(1.099)*ctx.power(x,exact(.45))-exact(.099)
    def prepare(base,secondary,both,linear,sceneOutput=False):
        y=[dec(x) for x in matrices[base][1]]
        m=[[dec(x) for x in row] for row in prim.multiply(prim.inverse(matrices[secondary]),matrices[base])] if secondary and secondary!=base else None
        level=exact(.5) if linear else exact(.85)
        def evaluate(p):
            if linear:
                primary=[max(D(0),x) for x in p];other=prim.apply(m,primary) if m else None
            else:
                # Stage12 snapshot precedes clamp and the complete output path.
                other=prim.apply(m,p) if m else None
                enc=(lambda x:x*exact(.9)) if sceneOutput else encoder
                primary=[max(D(0),enc(x)) for x in p]
                if other:other=[enc(x) for x in other]
            span=max(primary)-min(primary)
            if other:
                alternate=max(other)-min(other);span=max(span,alternate) if both else alternate
            if span<=level:return primary
            lum=sum(a*x for a,x in zip(y,primary));ratio=level/span
            return [lum+(x-lum)*ratio for x in primary]
        return evaluate
    cases=[]
    for base in matrices:
        for secondary in [None,*matrices]:
            for both in [True,False]:
                for linear in [True,False]:
                    evaluate=prepare(base,secondary,both,linear)
                    xs=[[-2.,-1.,-.5],[0.,0.,0.],[.2,.2,.2],[2.,2.,2.],[2.,0.,0.],[0.,2.,0.],[0.,0.,2.],[.5,0.,0.],[5.,-2.,1.]]
                    xs += [[i%7/2-.5,i%11/3-1,i%13/4-.75] for i in range(64)]
                    cases.append({'base':base,'secondary':secondary,'both':both,'linear':linear,
                        'probes':[{'input':[repr(x) for x in p],'output':[str(x) for x in evaluate([exact(x) for x in p])]} for p in xs]})
    grids=[]
    for linear in [True,False]:
        evaluate=prepare('rec2020.d65.v1','srgb.d65.v1',True,linear,sceneOutput=True)
        for size in [33,65]:
            xs=[exact(-.5+i/(size-1)*2.5)/exact(.9) for i in range(size)]
            binary=bytearray()
            for b in range(size):
                for g in range(size):
                    for r in range(size):
                        output=evaluate([xs[r],xs[g],xs[b]])
                        if linear:output=[v*exact(.9) for v in output]
                        binary.extend(struct.pack('<3d',*(float(x) for x in output)))
            name=f'gamut-limiter-independent-{"linear" if linear else "post"}{size}.f64'
            path=ROOT/'tests/fixtures/native-contracts'/name
            if '--check' in sys.argv:assert path.read_bytes()==binary,name+'变化'
            else:path.write_bytes(binary)
            grids.append({'linear':linear,'size':size,'file':name,'sha256':hashlib.sha256(binary).hexdigest()})
            print(('核对' if '--check' in sys.argv else '生成')+name,flush=True)
    output=json.dumps({'precision':70,'method':'独立有理数原色与Decimal通道跨度、明确阶段12次级快照和阶段17钳零','sourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'matrixSourceSHA256':hashlib.sha256(Path(prim.__file__).read_bytes()).hexdigest(),'cases':cases,'grids':grids},ensure_ascii=False,indent=2)+'\n'
target=ROOT/'tests/fixtures/native-contracts/gamut-limiter-independent-reference.json'
if '--check' in sys.argv:assert target.read_text()==output;print('独立Limiter 24组及四个完整网格一致')
else:target.write_text(output);print('已生成独立Limiter 24组及四个完整网格')
