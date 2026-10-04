"""独立 Decimal 参照：REDLogFilm 的既有 Cineon 参数元组。"""
from decimal import Decimal as D, getcontext
import argparse, json, math
from pathlib import Path
getcontext().prec = 90
N=D(1023); BLACK=D(10)**((D(95)-D(685))/D(300))
P0=(D(10)**(-D(685)/D(300))-BLACK)/(D(1)-BLACK)/D('.9')
D0=((D(10)**((D('.0001')*N-D(685))/D(300))-BLACK)/(D(1)-BLACK)/D('.9')-P0)/D('.0001')
def enc(x,legacy=False):
    if legacy:
        if x<P0:return (x-P0)/D0
        x=x*D('.9')
    q=x*(D(1)-BLACK)+BLACK
    if q<=0:raise ValueError('负值不在公开编码定义域')
    return (D(685)+D(300)*q.log10())/N
def dec(y,legacy=False):
    if legacy and y<0:return y*D0+P0
    x=(D(10)**((N*y-D(685))/D(300))-BLACK)/(D(1)-BLACK)
    return x/D('.9') if legacy else x
def verify(path,size,legacy,linear=False):
    rows=[]; declared=None
    for line in Path(path).read_text().splitlines():
        t=line.split()
        if not t or t[0] in ('TITLE','DOMAIN_MIN','DOMAIN_MAX') or line.startswith('#'):continue
        if t[0]=='LUT_3D_SIZE':declared=int(t[1]);continue
        rows.append([float(x) for x in t])
    if declared!=size or len(rows)!=size**3:raise ValueError('网格尺寸或节点数不匹配')
    target=[float(dec(D(k)/(size-1),legacy)*D(2)) if linear else float(enc(dec(D(k)/(size-1),legacy)*D(2),legacy)) for k in range(size)]
    e=[]
    for i,row in enumerate(rows):
        for c,v in enumerate(row):
            x=target[i//size**c%size];e.append(abs(v-x)/max(1,abs(x)))
    e.sort();r={'nodes':len(rows),'channels':len(e),'maxScaled':e[-1],'rmsScaled':math.sqrt(math.fsum(x*x for x in e)/len(e)),'p99Scaled':e[math.ceil(.99*len(e))-1],'threshold':2e-12}
    if r['maxScaled']>r['threshold']:raise ValueError(r)
    return r
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--cube');p.add_argument('--size',type=int);p.add_argument('--legacy',action='store_true');p.add_argument('--linear',action='store_true');a=p.parse_args();print(json.dumps(verify(a.cube,a.size,a.legacy,a.linear),ensure_ascii=False,sort_keys=True))
