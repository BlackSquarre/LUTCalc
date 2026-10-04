"""从保存的实际失败日志复算单节点，区分产品误差与Double参照误差。"""
from pathlib import Path
from decimal import Decimal as D,localcontext
import hashlib,importlib.util,json,re

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'docs/native-validation/artifacts/2026-10-02-multitone'
log=ART/'grid-diagnostic.log'
row=re.search(r'Multitone failing grid=65 index=148136 channel=2 p=RGB64\(r: ([^,]+), g: ([^,]+), b: ([^)]+)\).*actual=([^ ]+) expected=([^\n]+)',log.read_text())
assert row is not None
prim_path=Path(__file__).with_name('generate-asccdl-independent-reference.py')
spec=importlib.util.spec_from_file_location('prim',prim_path);prim=importlib.util.module_from_spec(spec);spec.loader.exec_module(prim)
with localcontext() as ctx:
    ctx.prec=70
    p=[D.from_float(float(v)) for v in row.groups()[:3]]
    y=[prim.decimal(v) for v in prim.primaries([('.766','.275'),('.225','.800'),('.089','-.087')])[1]]
    l=sum(a*b for a,b in zip(y,p));sat=((l/D('.18')).ln()/D(2).ln()+8)/8
    output=[l+sat*(v-l) for v in p]
    actual,old=map(float,row.groups()[3:])
    result={'logSHA256':hashlib.sha256(log.read_bytes()).hexdigest(),'grid':65,'index':148136,'channel':2,
        'inputExactBinaryDecimal':[str(v) for v in p],'Y':str(l),'saturation':str(sat),
        'output':[str(v) for v in output],'reportedSwift':actual,'reportedDoubleReference':old,
        'SwiftScaledError':str(abs(D.from_float(actual)-output[2])/max(D(1),abs(output[2]))),
        'doubleReferenceScaledError':str(abs(D.from_float(old)-output[2])/max(D(1),abs(output[2])))}
(ART/'grid-148136-independent-diagnostic.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('第148136节点已按实际日志与70位Decimal复算；产品和原Double参照均保留各自误差')
