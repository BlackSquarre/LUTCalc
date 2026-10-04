"""从精确原色色度/D65方程与70位Decimal公式生成独立CDL参照。"""
import json
from fractions import Fraction as F
from decimal import Decimal as D, localcontext
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def inverse(a):
    rows=[list(row)+[F(int(i==j)) for j in range(3)] for i,row in enumerate(a)]
    for i in range(3):
        k=next(k for k in range(i,3) if rows[k][i])
        rows[k],rows[i]=rows[i],rows[k]
        v=rows[i][i];rows[i]=[x/v for x in rows[i]]
        for k in range(3):
            if k!=i:
                v=rows[k][i];rows[k]=[rows[k][j]-v*rows[i][j] for j in range(6)]
    return [row[3:] for row in rows]

def multiply(a,b):
    return [[sum(a[i][k]*b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]

def primaries(xy):
    xy=[(F(x),F(y)) for x,y in xy]
    c=[[x for x,y in xy],[y for x,y in xy],[1-x-y for x,y in xy]]
    w=[F('.3127')/F('.329'),F(1),(1-F('.3127')-F('.329'))/F('.329')]
    scale=[sum(a*b for a,b in zip(row,w)) for row in inverse(c)]
    return [[c[i][j]*scale[j] for j in range(3)] for i in range(3)]

def decimal(v):return D(v.numerator)/D(v.denominator)
def apply(m,p):return [sum(a*b for a,b in zip(row,p)) for row in m]

def generate():
    with localcontext() as ctx:
        ctx.prec=70
        work=primaries([('.766','.275'),('.225','.8'),('.089','-.087')])
        rec=primaries([('.708','.292'),('.17','.797'),('.131','.046')])
        into=[[decimal(v) for v in row] for row in multiply(inverse(work),rec)]
        out=[[decimal(v) for v in row] for row in multiply(inverse(rec),work)]
        y=[decimal(v) for v in work[1]]
        slope=[D('1.25'),D('.75'),D('1.5')];offset=[D('-.125'),D('.0625'),D('-.25')]
        power=[D('.5'),D('1.25'),D('2.5')];sat=D('.625')
        points=[]
        for i in range(64):
            p=[D(i%7)/D(6)-D('.1'),D(i%11)/10,D(i%13)/12]
            linear=apply(into,[v*2 for v in p]);q=[]
            for c in range(3):
                v=linear[c]/D('.9')*slope[c]+offset[c]
                q.append(v if v<0 else ctx.power(v,power[c]))
            l=sum(a*b for a,b in zip(y,q))
            graded=[(l+sat*(v-l))*D('.9') for v in q]
            output=apply(out,graded)
            points.append({'input':[float(v) for v in p],'output':[str(v) for v in output]})
        return {'method':'精确有理数原色矩阵，70位Decimal SOP/饱和度，Rec2020→工作空间→Rec2020，曝光+1',
            'luma':[str(v) for v in y], 'lumaRational':[[v.numerator,v.denominator] for v in work[1]],
            'inputToWork':[[str(v) for v in row] for row in into],
            'workToOutput':[[str(v) for v in row] for row in out],
            'slope':[str(v) for v in slope],'offset':[str(v) for v in offset],
            'power':[str(v) for v in power],'saturation':str(sat),'probes':points}

if __name__=='__main__':
    import sys
    target=ROOT/'tests/fixtures/native-contracts/asccdl-independent-reference.json'
    text=json.dumps(generate(),ensure_ascii=False,indent=2)+'\n'
    if '--check' in sys.argv:
        assert target.read_text()==text,'独立CDL参照发生变化'
        print('独立CDL有理数/70位Decimal参照一致')
    else:
        target.write_text(text)
        print('已冻结64个跨色域CDL独立参照点与原色矩阵')
