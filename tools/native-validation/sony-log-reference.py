"""独立 90 位 Decimal 参照：Sony S-Log 与 S-Log2 四个既有身份。"""
from decimal import Decimal as D, getcontext
import argparse, json, math
from pathlib import Path
getcontext().prec = 90

P = {
    "sony.slog.v1": (D("0.3241960136"), D("-0.0286107171"), D("0.3705223110"), D(1), D(10), D("0.6162444740"), D("0.0375840000"), D("0.0882900450"), D("0.000000000000001")),
    "sony.slog2.v1": (D("0.330000000129966"), D("-0.0291229262672453"), D("0.3705223107287920"), D("0.7077625570776260"), D(10), D("0.6162444730868150"), D("0.0375840001141552"), D("0.0879765396"), D(0)),
}
IDS = ["sony.slog.v1", "sony.slog.lutcalc-legacy.v1", "sony.slog2.v1", "sony.slog2.lutcalc-legacy.v1"]
def base_id(i): return "sony.slog.v1" if i in IDS[:2] else "sony.slog2.v1"
def legacy(i): return "legacy" in i
def encode(i, x):
    p=P[base_id(i)]; v=x if legacy(i) else x/D("0.9")
    return p[2]*(v*p[3]+p[6]).log10()+p[5] if v>=p[8] else (v-p[1])/p[0]
def decode(i, y):
    p=P[base_id(i)]; v=(D(p[4])**((y-p[5])/p[2])-p[6])/p[3] if y>=p[7] else p[0]*y+p[1]
    return v if legacy(i) else v*D("0.9")
def plan(i,x): return encode(i, decode(i,x)*D(2) if False else x)
def verify(path,size,i):
    rows=[]; declared=None
    for line in Path(path).read_text().splitlines():
        t=line.split()
        if not t or t[0] in ('TITLE','DOMAIN_MIN','DOMAIN_MAX') or line.startswith('#'): continue
        if t[0]=='LUT_3D_SIZE': declared=int(t[1]); continue
        rows.append([float(x) for x in t])
    if declared!=size or len(rows)!=size**3: raise ValueError('网格尺寸或节点数不匹配')
    targets=[float(encode(i,decode(i,D(k)/(size-1))*D(2))) for k in range(size)]
    e=[]
    for n,row in enumerate(rows):
        for c,v in enumerate(row):
            exp=targets[n//size**c%size];e.append(abs(v-exp)/max(1,abs(exp)))
    e.sort();r={'id':i,'nodes':len(rows),'channels':len(e),'maxScaled':e[-1],'rmsScaled':math.sqrt(math.fsum(x*x for x in e)/len(e)),'p99Scaled':e[math.ceil(.99*len(e))-1],'threshold':2e-12,'decimalPrecision':90}
    if r['maxScaled']>r['threshold']: raise ValueError(r)
    return r
if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--cube');a.add_argument('--size',type=int);a.add_argument('--id',choices=IDS);x=a.parse_args();print(json.dumps(verify(x.cube,x.size,x.id),ensure_ascii=False,sort_keys=True))
