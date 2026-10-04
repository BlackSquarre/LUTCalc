"""从旧冻结元数据与独立 Decimal／Fraction 建立相机状态参照；不调用产品。"""
from pathlib import Path
from decimal import Decimal as D, localcontext, ROUND_HALF_UP
from fractions import Fraction as F
import hashlib,json,re,math,struct

root=Path(__file__).resolve().parents[2]
target=root/'tests/fixtures/native-contracts'
legacy=target/'exposure-batch-legacy-reference.json'
data=json.loads(legacy.read_text())
source=root/'js/lutcamerabox.js'
assert hashlib.sha256(source.read_bytes()).hexdigest()==data['sourceSHA256']['lutcamerabox.js']
def ident(c):
    make=re.sub('[^a-z0-9]+','-',c['make'].lower()).strip('-')
    model=re.sub('[^a-z0-9]+','-',c['model'].lower()).strip('-')
    return 'camera.'+(make+'.' if make else '')+model+'.v1'
profiles=[dict(id=ident(c),legacyIndex=i,**c) for i,c in enumerate(data['cameras'])]
assert len(profiles)==66 and len({c['id'] for c in profiles})==66
def true_round_float(x):
    f=F.from_float(abs(x))*10000
    q,r=divmod(f.numerator,f.denominator)
    if r*2>=f.denominator:q+=1
    result=q/10000
    return -result if math.copysign(1,x)<0 else result
round_cases=[]
for x in [0.,-0.,.00005,-.00005,.00015,-.00015,.12505,-.12505,1.005,-1.005,1.58585,-1.58585,52.99995,-52.99995]:
    for y in [math.nextafter(x,-math.inf),x,math.nextafter(x,math.inf)]:
        round_cases.append(dict(input=repr(y),output=repr(true_round_float(y))))
cases=[]
for c in profiles:
    for recorded in sorted(set([1,55,160,800,1501,c['iso'],c['iso']*3+1,1000000])):
        results=[]
        for precision in [80,120]:
            with localcontext() as context:
                context.prec=precision
                stop=(D(recorded)/D(c['iso'])).ln()/D(2).ln() if c['type']==0 else D('0.125')
                rounded=stop.quantize(D('.0001'),rounding=ROUND_HALF_UP) if c['type']==0 else stop
                gain=(rounded*D(2).ln()).exp()
                black=D('.18')*((D(str(c['bclip']))+rounded)*D(2).ln()).exp()
                clip=D('.18')*((D(str(c['wclip']))+rounded)*D(2).ln()).exp()
                results.append(list(map(float,[rounded,gain,black,clip])))
        assert results[0]==results[1]
        cases.append(dict(profileID=c['id'],recordedISO=recorded,previousManualStops=.125,
            stop=repr(results[0][0]),gain=repr(results[0][1]),black=repr(results[0][2]),clip=repr(results[0][3])))
grids=[]
for c,recorded,manual in [(profiles[0],1501,0.),(profiles[2],2401,0.),(profiles[6],2401,.125),(profiles[-1],2401,-.375)]:
    with localcontext() as context:
        context.prec=120
        stop=(((D(recorded)/D(c['iso'])).ln()/D(2).ln()).quantize(D('.0001'),rounding=ROUND_HALF_UP)) if c['type']==0 else D.from_float(manual)
        gain=(stop*D(2).ln()).exp()
        for size in [33,65]:
            # A separable linear scene chain: no colour matrix or camera default is implied.
            axis=[float(D.from_float(-.1+i/(size-1)*1.3)*gain) for i in range(size)]
            entry=dict(profileID=c['id'],recordedISO=recorded,previousManualStops=manual,size=size,minimum=-.1,maximum=1.2,outputs=list(map(repr,axis)))
            if size==33:
                entry['spi1dOutputs']=[repr(float(D.from_float(-.1+1.3*i/1023)*gain)) for i in range(1024)]
            grids.append(entry)
result=dict(method='旧元数据来源冻结；独立80/120位Decimal曝光与裁剪辅助量、Fraction精确Double舍入',
    sourceSHA256={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [source,legacy]},
    profiles=profiles,cases=cases,roundCases=round_cases,grids=grids,
    limitations=['注册参数是旧预设元数据，不是全部相机实测','线性网格不是相机默认色彩映射或真实裁剪证明'])
(target/'camera-state-independent.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('相机独立参照：',len(profiles),'profiles',len(cases),'cases',len(round_cases),'round cases',len(grids),'grids')
