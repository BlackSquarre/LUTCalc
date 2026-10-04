"""独立 Decimal 参照：Canon C-Log 的既有 LUTCalc 解析注册。"""
from decimal import Decimal as D, getcontext
import argparse,json,math
from pathlib import Path
getcontext().prec=90
A=D('0.3734467748');B=D('-0.0467265867');C=D('0.45310179472141');S=D('10.1596');O=D('0.1251224801564');CUT=D('0.00391002619746')
def enc(x):
    return C*(x*S+D(1)).log10()+O if x>=D('-0.0452664') else (x-B)/A
def dec(y):
    return ((D(10)**((y-O)/C)-D(1))/S) if y>=CUT else A*y+B
def verify(path,size):
    rows=[];declared=None
    for line in Path(path).read_text().splitlines():
        t=line.split()
        if not t or t[0] in ('TITLE','DOMAIN_MIN','DOMAIN_MAX') or line.startswith('#'):continue
        if t[0]=='LUT_3D_SIZE':declared=int(t[1]);continue
        rows.append([float(x) for x in t])
    if declared!=size or len(rows)!=size**3:raise ValueError('网格尺寸或节点数不匹配')
    target=[float(enc(dec(D(k)/(size-1))*D(2))) for k in range(size)]
    e=[]
    for i,row in enumerate(rows):
        for c,v in enumerate(row):
            x=target[i//size**c%size];e.append(abs(v-x)/max(1,abs(x)))
    e.sort();r={'nodes':len(rows),'channels':len(e),'maxScaled':e[-1],'rmsScaled':math.sqrt(math.fsum(x*x for x in e)/len(e)),'p99Scaled':e[math.ceil(.99*len(e))-1],'threshold':2e-12}
    if r['maxScaled']>r['threshold']:raise ValueError(r)
    return r
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--cube');p.add_argument('--size',type=int);a=p.parse_args();print(json.dumps(verify(a.cube,a.size),ensure_ascii=False,sort_keys=True))
