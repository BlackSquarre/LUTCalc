"""以确切二进制输入和70位Decimal独立验证黑白电平解析映射。"""
from pathlib import Path
from decimal import Decimal, localcontext
import json, hashlib, sys
ROOT=Path(__file__).resolve().parents[2]
def d(v): return Decimal.from_float(float(v))
cases=[]
with localcontext() as ctx:
    ctx.prec=70
    for black,high,bmap,hmap in [(0,1,.05,.85),(.05,.9,.01,1.2),(-.06,1.5,.5,.1),(.12,.72,.72,.72),(0,.9,.025,.91)]:
        b,h,bm,hm=map(d,[black,high,bmap,hmap])
        values=[-2,-0.0,0,.18,1,2,20,black,high]
        values += [float(b+(h-b)*Decimal(i)/64) for i in range(65)]
        cases.append({'settings':{'algorithm':'lutcalc.black-highlight-legal-affine.v1','enabled':True,
            'doBlack':True,'doHigh':True,'blackLevel':bmap,'blackLock':True,'highReferenceScene':.9,'highMap':hmap,'highLock':True},
            'defaults':[str(black),str(high)],'probes':[{'input':str(x),'output':str(bm+(hm-bm)*(d(x)-b)/(h-b))} for x in values]})
output=json.dumps({'precision':70,'sourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'cases':cases},ensure_ascii=False,indent=2)+'\n'
target=ROOT/'tests/fixtures/native-contracts/black-highlight-independent-reference.json'
if '--check' in sys.argv:
    assert target.read_text()==output
    print('独立黑白电平370点70位Decimal参照一致')
else:target.write_text(output);print('已生成独立黑白电平370点')
