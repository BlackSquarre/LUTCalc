"""独立70位Decimal阈值和有理数工作空间Y；保留离散边界。"""
from pathlib import Path
from decimal import Decimal as D,localcontext
from fractions import Fraction as F
import json,hashlib,struct,sys,math,importlib.util
root=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('prim',Path(__file__).with_name('generate-asccdl-independent-reference.py'))
prim=importlib.util.module_from_spec(spec);spec.loader.exec_module(prim)
def settings(bits,values):
    s={'algorithm':'lutcalc.false-colour-native-thresholds.v1','usage':'exportLUT','enabled':True}
    s.update({name:bool(bits&(1<<i)) for i,name in enumerate(['doPurple','doBlue','doGreen','doPink','doOrange','doYellow','doRed'])})
    s.update(dict(zip(['blueStopsBelowGray','yellowStopsBelowClip','redStopsAboveGray'],values)))
    return s
def thresholds(s):
    t=[-10.]*10
    def power(x):return float(ctx.power(D(2),D.from_float(x)))*.2
    if s['doPurple']:t[0]=power(-8.)
    if s['doBlue']:t[0]=power(-10.);t[1]=power(-(s['blueStopsBelowGray'] if s['blueStopsBelowGray'] is not None else 6.1))
    if s['doGreen']:t[2:4]=[.174110113,.229739671]
    if s['doPink']:t[4:6]=[.354307008,.451585762]
    if s['doOrange']:t[6:8]=[.885767519,1.128964405]
    if s['doYellow']:
        red=s['redStopsAboveGray'] if s['redStopsAboveGray'] is not None else 5.95
        yellow=s['yellowStopsBelowClip'] if s['yellowStopsBelowClip'] is not None else .26
        t[8]=power(red-yellow);t[9]=power(5.95)
    if s['doRed']:t[9]=power(s['redStopsAboveGray'] if s['redStopsAboveGray'] is not None else 5.95)
    return t
def classify(y,t,s):
    if not any(s[k] for k in ['doPurple','doBlue','doGreen','doPink','doOrange','doYellow','doRed']):return None
    matches=[i for i,v in enumerate(t) if v!=-10 and y<=v];band=matches[0] if matches else 0
    if band==0 and s['doRed'] and y>t[9]:return 10
    if (band==0 and y>t[0]) or (band==0 and not s['doPurple'] and y<.1) or (band==9 and not s['doYellow']):return 8
    return band
palette={0:[.75,0,.75],1:[0,0,.75],3:[0,.7,0],5:[.75,.35,.35],7:[.9,.45,0],9:[.7,.7,0],10:[.75,0,0]}
with localcontext() as ctx:
    ctx.prec=70
    xy=[(F('.766'),F('.275')),(F('.225'),F('.800')),(F('.089'),F('-.087'))]
    m=[[x/y for x,y in xy],[F(1)]*3,[(1-x-y)/y for x,y in xy]]
    wx,wy=F('.3127'),F('.329');luma=prim.apply(prim.inverse(m),[wx/wy,F(1),(1-wx-wy)/wy])
    ld=[D(x.numerator)/D(x.denominator) for x in luma]
    cases=[]
    for values in [[6.1,.5,6.],[None,None,None],[10.,3.,3.5]]:
        for bits in range(128):
            s=settings(bits,values);t=thresholds(s)
            ys=[-10.,-.5,0.,.00001,.001,.1,.18,.2,.4,1.,2.,16.,100.]
            for x in t:
                if x!=-10:ys.extend([math.nextafter(x,-math.inf),x,math.nextafter(x,math.inf)])
            cases.append({'settings':s,'thresholds':list(map(repr,t)),
                'probes':[{'luma':repr(y),'band':classify(y,t,s),'output':list(map(repr,palette.get(classify(y,t,s),[-.125,.375,1.25])))} for y in ys]})
    grids=[]
    for name,s in [('defaults',settings(111,[6.1,.5,6.])),('all',settings(127,[None,None,None]))]:
        t=thresholds(s)
        for size in [33,65]:
            axis=[-.5+i/(size-1)*16.5 for i in range(size)];legacy=[D.from_float(x)/D.from_float(.9) for x in axis]
            binary=bytearray();bands=bytearray()
            for b in range(size):
                for g in range(size):
                    for r in range(size):
                        y=sum(ld[c]*legacy[i] for c,i in enumerate([r,g,b]));band=classify(y,[D.from_float(v) for v in t],s)
                        output=palette.get(band,[axis[r],axis[g],axis[b]])
                        binary.extend(struct.pack('<3d',*output));bands.append(band)
            stem=f'false-colour-independent-{name}{size}'
            for suffix,data in [('.f64',binary),('.u8',bands)]:
                p=root/'tests/fixtures/native-contracts'/(stem+suffix)
                if '--check' in sys.argv:assert p.read_bytes()==data
                else:p.write_bytes(data)
            grids.append({'settings':s,'size':size,'file':stem+'.f64','bandsFile':stem+'.u8','sha256':hashlib.sha256(binary).hexdigest()})
            print(stem,flush=True)
    output=json.dumps({'precision':70,'sourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'luma':list(map(str,ld)),'cases':cases,'grids':grids},ensure_ascii=False,indent=2)+'\n'
p=root/'tests/fixtures/native-contracts/false-colour-independent-reference.json'
if '--check' in sys.argv:assert p.read_text()==output;print('独立False Colour边界和全网格一致')
else:p.write_text(output);print('已生成独立False Colour边界和全网格')
