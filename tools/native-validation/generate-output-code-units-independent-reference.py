"""独立70位Decimal传递函数、Legal映射与耦合跨度压缩；不读取旧结果。"""
from pathlib import Path
from decimal import Decimal as D,localcontext
from fractions import Fraction as F
import importlib.util,json,hashlib,sys
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('prim',Path(__file__).with_name('generate-asccdl-independent-reference.py'))
prim=importlib.util.module_from_spec(spec);spec.loader.exec_module(prim)
def exact(v):return D.from_float(float(v))
entries=[('cie.l-star.v1','gam',3.,24389./2700.,.16,216./24389.),('romm.prophoto.v1','gam',1.8,16.,0.,1./512.)]
entries += [(f'bbc.gamma-0-{int(exponent*10)}.v1','bbc',exponent,5.,offset,cut) for exponent,offset,cut in [(.4,-.02262,.037703),(.5,-.01011,.020202),(.6,-.00334,.008857)]]
entries += [('bbc.whp283-400.v1','whp',.139401137752,0.,0.,0.),('bbc.whp283-800.v1','whp',.097401889128,0.,0.,0.)]
entries += [(f'gamma.{k//10}-{k%10}.v1','gam',k/10,1.,0.,1e-7) for k in range(15,27)]
with localcontext() as ctx:
 ctx.prec=70
 scale,offset=exact(.85630498533724),exact(.06256109481916)
 m=prim.primaries([('.708','.292'),('.170','.797'),('.131','.046')]);y=[D(a.numerator)/D(a.denominator) for a in m[1]]
 target=prim.primaries([('.640','.330'),('.300','.600'),('.150','.060')])
 matrix=[[D(v.numerator)/D(v.denominator) for v in row] for row in prim.multiply(prim.inverse(target),m)]
 cases=[];axes=[]
 for name,kind,exponent,slope,off,cut in entries:
  exponent,slope,off,cut=map(exact,[exponent,slope,off,cut])
  def encode(x):
   if kind=='whp':
    root=exponent.sqrt()
    if x>exponent:return root/2*x.ln()+root*(1-root.ln())
    return x.sqrt() if x>0 else D(0)
   if kind=='bbc':return ctx.power((x+off)/(1+off),exponent) if x>cut else x*slope
   # The exponent reciprocal is calculated in Double by the original API.
   return (1+off)*ctx.power(x,exact(1/float(exponent)))-off if x>=cut else x*slope
  black=encode(D(0));high=encode(D(1));a=(exact(.85)-exact(.05))/(high-black)
  def mapped(scene):return exact(.05)+(encode(scene/exact(.9))-black)*a
  def evaluate(p,secondary,both):
   other=prim.apply(matrix,p) if secondary else None
   if other:other=[mapped(x) for x in other]
   rgb=[max(D(0),mapped(x)) for x in p];span=max(rgb)-min(rgb)
   if other:
    alternate=max(other)-min(other);span=max(span,alternate) if both else alternate
   if span>exact(.6):
    lum=sum(a*b for a,b in zip(y,rgb));rgb=[lum+(v-lum)*exact(.6)/span for v in rgb]
   return [v*scale+offset for v in rgb]
  xs=[[-.5,-.25,-.01],[0.,0.,0.],[.18,.18,.18],[.9,.9,.9],[2.,0.,0.],[0.,2.,0.],[0.,0.,2.],[8.,1.,-.1]]
  xs += [[i%7/2-.5,i%11/3-1,i%13/4-.75] for i in range(64)]
  for secondary,both in [(False,True),(True,True),(True,False)]:
   cases.append({'transfer':name,'secondary':secondary,'both':both,'probes':[{'inputScene':[repr(x) for x in p],'outputData':[str(v) for v in evaluate([exact(x) for x in p],secondary,both)]} for p in xs]})
  axes.append({'transfer':name,**{f'size{size}':[str(mapped(exact(-.5+i/(size-1)*2.5))*scale+offset) for i in range(size)] for size in [33,65,1024]}})
 output=json.dumps({'precision':70,'sourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'matrixHelperSHA256':hashlib.sha256(Path(prim.__file__).read_bytes()).hexdigest(),'method':'独立70位传递方程、Legal仿射、Rec2020有理数Y和通道跨度；19曲线完整33³/65³节点用可分离轴参照','cases':cases,'axes':axes},ensure_ascii=False,indent=2)+'\n'
p=ROOT/'tests/fixtures/native-contracts/output-code-units-independent-reference.json'
if '--check' in sys.argv:assert p.read_text()==output;print('独立19曲线12312耦合通道与全部33³/65³轴参照一致')
else:p.write_text(output);print('已生成独立19曲线12312耦合通道及完整网格轴参照')
