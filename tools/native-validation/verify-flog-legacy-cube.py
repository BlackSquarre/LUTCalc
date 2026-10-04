"""按旧 Fujifilm F-Log 九参数公式用 Decimal 独立核对一档曝光 CUBE。"""
from decimal import Decimal as D, getcontext
import argparse, json, math
from pathlib import Path
getcontext().prec=90
P0=D('0.1144737'); P1=D('-0.010630486'); P2=D('0.344676'); P3=D('0.5000004'); P5=D('0.790453'); P6=D('0.009468'); DEC=D('0.100537775'); ENC=D('0.000988889')
def enc(x): return P2*(x*P3+P6).log10()+P5 if x>=ENC else (x-P1)/P0
def dec(y): return ((D(10)**((y-P5)/P2))-P6)/P3 if y>=DEC else P0*y+P1
def verify(path,size):
 rows=[]; declared=None
 for line in Path(path).read_text().splitlines():
  t=line.split()
  if not t or t[0] in ('TITLE','DOMAIN_MIN','DOMAIN_MAX') or line.startswith('#'): continue
  if t[0]=='LUT_3D_SIZE': declared=int(t[1]); continue
  rows.append([D(x) for x in t])
 if declared != size or len(rows)!=size**3: raise ValueError('网格尺寸或节点数不匹配')
 axis=[enc(D(2)*dec(D(i)/(size-1))) for i in range(size)]
 e=[]
 for i,row in enumerate(rows):
  targets=[axis[i%size],axis[(i//size)%size],axis[i//(size*size)]]
  e.extend(float(abs(v-t)/max(D(1),abs(t))) for v,t in zip(row,targets))
 e.sort(); result={'nodes':len(rows),'channels':len(e),'maxScaled':e[-1],'rmsScaled':math.sqrt(math.fsum(x*x for x in e)/len(e)),'p99Scaled':e[math.ceil(.99*len(e))-1],'threshold':2e-12}
 if result['maxScaled']>result['threshold']: raise ValueError(result)
 return result
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--cube',required=True);p.add_argument('--size',type=int,required=True);a=p.parse_args();print(json.dumps(verify(a.cube,a.size),ensure_ascii=False,sort_keys=True))
