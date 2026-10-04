"""从归档的 ARRI 公式参数生成独立 Decimal 参照；不调用产品或旧引擎。"""
from pathlib import Path
from decimal import Decimal,localcontext
import hashlib,json,math,re,struct
root=Path(__file__).resolve().parents[2]
research=root/'research/colour/2026-10-02-logc3'
target=root/'tests/fixtures/native-contracts'
def tables(path):
    sections=path.read_text().split('EI cut a b c d e f e*cut+f\n')[1:]
    result=[]
    for section in sections:
        rows=[]
        for line in section.splitlines()[:11]:
            fields=line.split()
            assert len(fields)==9,line
            rows.append(dict(exposureIndex=int(fields[0]),parameters=dict(zip(['cut','a','b','c','d','e','f'],fields[1:8])),publishedRoundedJunction=fields[8]))
        result.append(rows)
    return result
old=tables(research/'arri-logc-vfx-2012-mirror.pdf.txt')
current=tables(research/'arri-logc3-vfx-2017.pdf.txt')
assert len(old)==4 and len(current)==2 and old[:2]==current
eis=[160,200,250,320,400,500,640,800,1000,1280,1600]
cases=[];binary=bytearray();grids=[];gaps=[]
def evaluate(row,direction,x,precision):
    with localcontext() as context:
        context.prec=precision
        p={key:Decimal(value) for key,value in row['parameters'].items()}
        xf=Decimal.from_float(x)
        # The Double API prepares the branch boundary in IEEE binary64.
        # Arithmetic inside the selected documented formula is independent Decimal.
        fp={key:float(value) for key,value in row['parameters'].items()}
        boundary=fp['cut'] if direction=='encode' else fp['e']*fp['cut']+fp['f']
        if direction=='encode':
            output=p['c']*(p['a']*xf+p['b']).log10()+p['d'] if x>boundary else p['e']*xf+p['f']
        else:
            output=(((xf-p['d'])/p['c'])*Decimal(10).ln()).exp()-p['b'] if x>boundary else None
            output=output/p['a'] if output is not None else (xf-p['f'])/p['e']
        return float(output)
def independent(row,direction,x):
    a=evaluate(row,direction,x,80);b=evaluate(row,direction,x,120)
    assert a==b and math.isfinite(a),(row['exposureIndex'],direction,x,a,b)
    return a
for firmware,domain,rows in [('sup3','sensorSignal',current[0]),('sup3','sceneExposure',current[1]),
                            ('sup2','sensorSignal',old[2]),('sup2','sceneExposure',old[3])]:
    assert [row['exposureIndex'] for row in rows]==eis
    for row in rows:
        case=dict(firmware=firmware,domain=domain,**row)
        p={key:float(value) for key,value in row['parameters'].items()}
        cut=p['cut'];junction=p['e']*cut+p['f']
        probes=[]
        for direction,boundary in [('encode',cut),('decode',junction)]:
            inputs=[-.1,0,.18,1,1.2,10] + ([100] if direction=='encode' else [2]) + [math.nextafter(boundary,-math.inf),boundary,math.nextafter(boundary,math.inf)]
            for x in inputs:
                probes.append(dict(direction=direction,input=repr(x),output=repr(independent(row,direction,x))))
        case['probes']=probes
        case['decodeBinaryOffsetBytes']=len(binary)
        for depth in [10,12]:
            for code in range(1<<depth):binary.extend(struct.pack('<d',independent(row,'decode',code/((1<<depth)-1))))
        case['decodeBinaryCount']=1024+4096
        gap=independent(row,'encode',math.nextafter(cut,math.inf))-independent(row,'encode',cut)
        gaps.append(dict(firmware=firmware,domain=domain,exposureIndex=row['exposureIndex'],junctionGap=gap))
        if (firmware,domain,row['exposureIndex']) in [('sup2','sceneExposure',800),('sup3','sceneExposure',1600),('sup3','sensorSignal',1600),('sup3','sensorSignal',160)]:
            for size in [33,65]:
                for direction in ['encode','decode']:
                    lo,hi=-.1,1.2
                    axes=[lo+i/(size-1)*(hi-lo) for i in range(size)]
                    grids.append(dict(firmware=firmware,domain=domain,exposureIndex=row['exposureIndex'],size=size,
                        direction=direction,minimum=repr(lo),maximum=repr(hi),outputs=[repr(independent(row,direction,x)) for x in axes]))
        cases.append(case)
sourceFiles=[research/item for item in ['arri-logc3-vfx-2017.pdf','arri-logc3-vfx-2017.pdf.txt','arri-logc-vfx-2012-mirror.pdf','arri-logc-vfx-2012-mirror.pdf.txt']]
sourceHashes={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sourceFiles}
result=dict(sourceSHA256=sourceHashes,precision=[80,120],scope='44组公开紧凑公式参数；不含高EI shoulder或实际相机传感器误差承诺',
    branchPolicy='IEEE binary64 cut和e*cut+f；公开十进制公式在选定分支中用80/120位独立计算',cases=cases,grids=grids,junctionGaps=gaps,
    decodeBinarySHA256=hashlib.sha256(binary).hexdigest(),decodeValues=len(binary)//8)
(target/'arri-logc-compact-independent.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
(target/'arri-logc-compact-decode.f64').write_bytes(binary)
print(json.dumps(dict(cases=len(cases),decodeValues=len(binary)//8,gridCases=len(grids),maximumJunctionGap=max(abs(x['junctionGap']) for x in gaps),sourceSHA256=sourceHashes),ensure_ascii=False,indent=2))
