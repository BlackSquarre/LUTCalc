"""独立80位Decimal精确曝光序列与增益；不运行旧JS生成预期。"""
from pathlib import Path
from decimal import Decimal as D,localcontext
import json,hashlib,sys
root=Path(__file__).resolve().parents[2]
with localcontext() as ctx:
 ctx.prec=80
 def gain(n,d):return str(ctx.power(D(2),D(n)/D(d)))
 cases=[]
 for minimum in [-4,-3,-2,-1]:
  for maximum in [1,2,3,4]:
   for subdivisions in [1,2,3,4]:
    numerator=list(range(minimum*subdivisions,maximum*subdivisions+1))
    cases.append(dict(minimum=minimum,maximum=maximum,subdivisions=subdivisions,numerators=numerator,stops=[str(D(n)/D(subdivisions)) for n in numerator],gains=[gain(n,subdivisions) for n in numerator]))
 result=dict(precision=80,sourceSHA256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),cases=cases,gains=[gain(n,3) for n in range(-3,4)],fullGains=[gain(n,3) for n in range(4)])
text=json.dumps(result,ensure_ascii=False,indent=2)+'\n'
p=root/'tests/fixtures/native-contracts/exposure-batch-independent-reference.json'
if '--check' in sys.argv:assert p.read_text()==text;print('曝光批量独立64组序列与Decimal增益一致')
else:p.write_text(text);print('已生成曝光批量独立64组序列与Decimal增益')
