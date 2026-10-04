"""独立有理数原色/CAT方程及70位Decimal高光混合，全网格不降维抽样。"""
from pathlib import Path
from fractions import Fraction as F
from decimal import Decimal as D, localcontext
import hashlib, json, math, struct, sys
ROOT=Path(__file__).resolve().parents[2]
GEOMETRY={
 'work':([('.766','.275'),('.225','.800'),('.089','-.087')],('.3127','.329')),
 'rec2020.d65.v1':([('.708','.292'),('.170','.797'),('.131','.046')],('.3127','.329')),
 'srgb.d65.v1':([('.640','.330'),('.300','.600'),('.150','.060')],('.3127','.329')),
 'aces.ap0.v1':([('.7347','.2653'),('0','1'),('.0001','-.077')],('.32168','.33767')),
 'romm.prophoto-d50.v1':([('.7347','.2653'),('.1596','.8404'),('.0366','.0001')],('.34567','.35850')),
}
CAT={
 'cieCAT02':[['.7328','.4296','-.1624'],['-.7036','1.6975','.0061'],['.003','.0136','.9834']],
 'bradford':[['.8951','.2664','-.1614'],['-.7502','1.7135','.0367'],['.0389','-.0685','1.0296']],
}
def inverse(a):
    rows=[list(row)+[F(int(i==j)) for j in range(3)] for i,row in enumerate(a)]
    for i in range(3):
        k=next(k for k in range(i,3) if rows[k][i]);rows[k],rows[i]=rows[i],rows[k]
        pivot=rows[i][i];rows[i]=[x/pivot for x in rows[i]]
        for k in range(3):
            if k!=i:
                v=rows[k][i];rows[k]=[rows[k][j]-v*rows[i][j] for j in range(6)]
    return [row[3:] for row in rows]
def mul(a,b):return [[sum(a[i][k]*b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
def apply(m,p):return [sum(a*b for a,b in zip(row,p)) for row in m]
def white(key):
    x,y=map(F,GEOMETRY[key][1]);return [x/y,F(1),(1-x-y)/y]
def primaries(key):
    xy=[tuple(map(F,p)) for p in GEOMETRY[key][0]]
    c=[[x/y for x,y in xy],[F(1)]*3,[(1-x-y)/y for x,y in xy]]
    scale=apply(inverse(c),white(key));return [[c[i][j]*scale[j] for j in range(3)] for i in range(3)]
def dec(x):return D(x.numerator)/D(x.denominator)
def conversion(key,cat):
    a=[[F(x) for x in row] for row in CAT[cat]]
    if GEOMETRY[key][1]==GEOMETRY['work'][1]:adapt=[[F(int(i==j)) for j in range(3)] for i in range(3)]
    else:
        src,dst=apply(a,white('work')),apply(a,white(key))
        scale=[[dst[i]/src[i] if i==j else F(0) for j in range(3)] for i in range(3)]
        adapt=mul(mul(inverse(a),scale),a)
    return [[dec(x) for x in row] for row in mul(mul(inverse(primaries(key)),adapt),primaries('work'))]
def prepare(base,high,cat,low,upper,linear):
    b,h=conversion(base,cat),conversion(high,cat)
    y=[dec(x) for x in primaries('work')[1]];ln2=D(2).ln()
    lower=(D.from_float(low)*ln2).exp()/5;higher=(D.from_float(upper)*ln2).exp()/5
    def evaluate(p):
        bp,hp=apply(b,p),apply(h,p);lum=sum(a*x for a,x in zip(y,bp))
        if lum>=higher:return hp
        if lum<=lower:return bp
        ratio=(higher-lum)/(higher-lower) if linear else (D.from_float(upper)-(lum*5).ln()/ln2)/(D.from_float(upper)-D.from_float(low))
        return [ratio*x+(1-ratio)*z for x,z in zip(bp,hp)]
    return evaluate
with localcontext() as ctx:
    ctx.prec=70
    cases=[]
    for base,high in [('rec2020.d65.v1','srgb.d65.v1'),('srgb.d65.v1','rec2020.d65.v1'),('aces.ap0.v1','romm.prophoto-d50.v1'),('romm.prophoto-d50.v1','rec2020.d65.v1')]:
        for cat in CAT:
            for linear in [True,False]:
                low,upper=-2.,2.3219;evaluate=prepare(base,high,cat,low,upper,linear)
                points=[[-1.,-2.,-3.],[0.,0.,0.],[1.,0.,0.],[0.,1.,0.],[0.,0.,1.],[4.,-2.,1.],[2.,3.,4.]]
                for threshold in [2**low/5,2**upper/5]:
                    for t in [math.nextafter(threshold,-math.inf),threshold,math.nextafter(threshold,math.inf)]:points.append([t]*3)
                for i in range(64):points.append([i%7/2-.5,i%11/3-1,i%13/4-.75])
                cases.append({'base':base,'highlight':high,'adaptation':cat,'linear':linear,'low':low,'high':upper,
                    'probes':[{'input':[repr(x) for x in p],'output':[str(x) for x in evaluate([D.from_float(x) for x in p])]} for p in points]})
    grids=[]
    for linear in [True,False]:
        evaluate=prepare('rec2020.d65.v1','srgb.d65.v1','cieCAT02',-1.,3.,linear)
        for size in [33,65]:
            values=[D.from_float(-.5+i/(size-1)*2.5)/D.from_float(.9) for i in range(size)]
            binary=bytearray()
            for b in range(size):
                for g in range(size):
                    for r in range(size):
                        output=[v*D.from_float(.9) for v in evaluate([values[r],values[g],values[b]])]
                        binary.extend(struct.pack('<3d',*(float(x) for x in output)))
            name=f'highlight-gamut-independent-{ "linear" if linear else "log" }{size}.f64'
            path=ROOT/'tests/fixtures/native-contracts'/name
            if '--check' in sys.argv:assert path.read_bytes()==binary,name+'发生变化'
            else:path.write_bytes(binary)
            grids.append({'size':size,'linear':linear,'minimum':-.5,'maximum':2.,'low':-1.,'high':3.,'file':name,'sha256':hashlib.sha256(binary).hexdigest()})
            print(('核对' if '--check' in sys.argv else '生成')+name,flush=True)
    output=json.dumps({'precision':70,'method':'精确有理数原色/CAT、独立70位Decimal线性/对数混合、确切Double输入','sourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'cases':cases,'grids':grids},ensure_ascii=False,indent=2)+'\n'
target=ROOT/'tests/fixtures/native-contracts/highlight-gamut-independent-reference.json'
if '--check' in sys.argv:assert target.read_text()==output;print('独立Highlight Gamut 16组及四个全网格一致')
else:target.write_text(output);print('已冻结独立Highlight Gamut 16组及四个全网格')
