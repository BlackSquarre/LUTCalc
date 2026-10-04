"""独立70位Decimal的1D显示曲线参照；1D按旧语义跳过矩阵。"""
from pathlib import Path
from decimal import Decimal as D, localcontext
import hashlib,json,sys
root=Path(__file__).resolve().parents[2]
with localcontext() as ctx:
    ctx.prec=70
    exponent=D.from_float(1/.45);offset=D.from_float(.099);slope=D.from_float(4.5);cut=D.from_float(.081)
    axis=[]
    for i in range(1024):
        x=D.from_float(-.5+i/1023*2.5)
        linear=ctx.power((x+offset)/(1+offset),exponent) if x>=cut else x/slope
        axis.append(str(linear*D.from_float(.9)))
output=json.dumps({'precision':70,'sourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'baseCurve':'rec709','outputCurve':'sceneReflectance','oneDMatrix':'跳过矩阵，独立通道',
    'domain':[-.5,2.],'axis1024':axis},ensure_ascii=False,indent=2)+'\n'
p=root/'tests/fixtures/native-contracts/display-conversion-export-reference.json'
if '--check' in sys.argv:assert p.read_text()==output;print('独立1024点显示曲线一致')
else:p.write_text(output);print('已冻结独立1024点显示曲线')
