"""按旧 BMD Pocket Film 九参数公式用 Decimal 独立核对 CUBE。"""
from decimal import Decimal as D, getcontext
import argparse, json, math
from pathlib import Path
getcontext().prec = 90
P0=D('0.195367159')/D('0.9'); P1=D('-0.014273567')/D('0.9'); P2=D('0.36274758'); P3=D('1.05345192')*D('0.9'); P5=D('0.63659829'); P6=D('0.027616437'); DEC=D('0.096214896'); ENC=D('0.004523664')*D('0.9')
def enc(x):
    return P2*(x*P3+P6).log10()+P5 if x>=ENC else (x-P1)/P0
def dec(y):
    return ((D(10)**((y-P5)/P2))-P6)/P3 if y>=DEC else P0*y+P1
def verify(path, size):
    rows=[]; declared=None
    for line in Path(path).read_text().splitlines():
        t=line.split()
        if not t or t[0] in ('TITLE','DOMAIN_MIN','DOMAIN_MAX') or line.startswith('#'): continue
        if t[0]=='LUT_3D_SIZE': declared=int(t[1]); continue
        rows.append([D(x) for x in t])
    if declared != size or len(rows) != size**3: raise ValueError('网格尺寸或节点数不匹配')
    e=[]
    axis=[enc(D(2)*dec(D(i)/(size-1))) for i in range(size)]
    for i,row in enumerate(rows):
        r=i % size; g=(i//size) % size; b=i//(size*size)
        # The catalog preset intentionally exercises the one-stop exposure path:
        # data -> legacy decode -> scene 0.9 boundary -> gain 2 -> legacy encode.
        target=[axis[r],axis[g],axis[b]]
        e.extend(float(abs(v-t)/max(D(1),abs(t))) for v,t in zip(row,target))
    e.sort(); result={'nodes':len(rows),'channels':len(e),'maxScaled':e[-1],'rmsScaled':math.sqrt(math.fsum(x*x for x in e)/len(e)),'p99Scaled':e[math.ceil(.99*len(e))-1],'threshold':2e-12}
    if result['maxScaled'] > result['threshold']: raise ValueError(result)
    return result
if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--cube',required=True); p.add_argument('--size',type=int,required=True); a=p.parse_args(); print(json.dumps(verify(a.cube,a.size),ensure_ascii=False,sort_keys=True))
