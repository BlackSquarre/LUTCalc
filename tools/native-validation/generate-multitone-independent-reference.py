"""精确有理数HSL/原色方程与70位Decimal Multitone独立参照。"""
from decimal import Decimal as D, localcontext
from fractions import Fraction as F
from pathlib import Path
import importlib.util,json,sys

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('prim',Path(__file__).with_name('generate-asccdl-independent-reference.py'))
prim=importlib.util.module_from_spec(spec);spec.loader.exec_module(prim)

def hsl(hue,saturation):
    # Independent six-sector vertices, interpolated at L=1/2.
    h=F(6*hue,255);s=F(saturation,255);sector=min(5,int(h));t=h-sector
    vertices=[[1,0,0],[1,1,0],[0,1,0],[0,1,1],[0,0,1],[1,0,1],[1,0,0]]
    return [F(1,2)*(1-s)+s*((1-t)*vertices[sector][c]+t*vertices[sector+1][c]) for c in range(3)]

def generate():
    with localcontext() as ctx:
        ctx.prec=70
        work=prim.primaries([('.766','.275'),('.225','.800'),('.089','-.087')])
        rec709=prim.primaries([('.640','.330'),('.300','.600'),('.150','.060')])
        rec2020=prim.primaries([('.708','.292'),('.170','.797'),('.131','.046')])
        toneMatrix=prim.multiply(prim.inverse(rec2020),rec709)
        y=[prim.decimal(v) for v in work[1]]
        specs=[([D(1)]*17,[]),([D(i)/8 for i in range(17)],[]),
            ([D('.4')]*17,[{'stop':0,'hue':170,'saturation':255}]),
            ([D('.15')+D(i%5)*D('.35') for i in range(17)],
             [{'stop':-3,'hue':17,'saturation':245},{'stop':0,'hue':101,'saturation':187},{'stop':4,'hue':231,'saturation':213}])]
        points=[[D(0)]*3,[D(-1),D(-2),D(-3)],[D(1),D(0),D(0)],[D(0),D(1),D(0)],[D(0),D(0),D(1)],
                [D('.2')]*3,[D(100),D(200),D(300)]]
        for i in range(64):points.append([D(i%7)/6-D('.25'),D(i%11)/5-D('.5'),D(i%13)/3])
        cases=[]
        for sat,tones in specs:
            colors=[]
            for tone in tones:
                h=hsl(tone['hue'],tone['saturation'])
                colors.append([prim.decimal(sum(toneMatrix[i][j]*h[j] for j in range(3))) for i in range(3)])
            probes=[]
            for p in points:
                l=sum(a*b for a,b in zip(y,p));mono=[l]*3
                if l<=0:s=sat[0]
                else:
                    stop=(l/D('.2')).ln()/D(2).ln();index=stop+8
                    if index<=0:s=sat[0]
                    elif index>=16:s=sat[16]
                    else:
                        k=int(index);r=index-k;s=(1-r)*sat[k]+r*sat[k+1]
                    if s<1 and tones:
                        if stop<=tones[0]['stop']:mono=colors[0][:]
                        elif stop>=tones[-1]['stop']:mono=colors[-1][:]
                        else:
                            k=next(k for k in range(1,len(tones)) if stop<tones[k]['stop'])
                            r=(stop-tones[k-1]['stop'])/D(tones[k]['stop']-tones[k-1]['stop'])
                            mono=[(1-r)*a+r*b for a,b in zip(colors[k-1],colors[k])]
                        l2=sum(a*b for a,b in zip(y,mono))
                        mono=[v*l/l2 for v in mono] if l2>0 else [l]*3
                output=[m+s*(v-m) for m,v in zip(mono,p)]
                probes.append({'input':[float(v) for v in p],'output':[str(v) for v in output]})
            cases.append({'saturationByStop':[float(v) for v in sat],'tones':tones,'probes':probes})
        return {'method':'精确HSL六顶点插值/Rec709到Rec2020矩阵、工作空间Y、有理数+70位Decimal对数与色调插值',
                'workingLuma':[str(v) for v in y],'cases':cases}

if __name__=='__main__':
    target=ROOT/'tests/fixtures/native-contracts/multitone-independent-reference.json'
    text=json.dumps(generate(),ensure_ascii=False,indent=2)+'\n'
    if '--check' in sys.argv:
        assert target.read_text()==text,'Multitone independent reference changed'
        print('独立Multitone 284点有理数/70位Decimal参照一致')
    else:target.write_text(text);print('已冻结独立Multitone 284点')
