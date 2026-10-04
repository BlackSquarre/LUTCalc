"""独立有理数原色/CAT与70位Decimal显示曲线；不读旧矩阵或旧输出。"""
from pathlib import Path
from decimal import Decimal as D,localcontext
from fractions import Fraction as F
import importlib.util,json,hashlib,struct,math,sys
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('prim',Path(__file__).with_name('generate-asccdl-independent-reference.py'))
prim=importlib.util.module_from_spec(spec);spec.loader.exec_module(prim)
geometry={
 'rec709':([('.64','.33'),('.3','.6'),('.15','.06')],('.3127','.329')),
 'rec2020':([('.708','.292'),('.17','.797'),('.131','.046')],('.3127','.329')),
 'srgb':([('.64','.33'),('.3','.6'),('.15','.06')],('.3127','.329')),
 'proPhoto':([('.7347','.2653'),('.1596','.8404'),('.0366','.0001')],('.34567','.35850')),
}
for name,white in [('p3DCI',('.314','.351')),('p3D60',('.32168','.33767')),('p3D65',('.3127','.329'))]:geometry[name]=([('.68','.32'),('.265','.69'),('.15','.06')],white)
def exact(v):return D.from_float(float(v))
def decimal(v):return D(v.numerator)/D(v.denominator)
def white(name):
 x,y=map(F,geometry[name][1]);return [x/y,F(1),(1-x-y)/y]
def matrix(name):
 xy=[tuple(map(F,p)) for p in geometry[name][0]];p=[[x/y for x,y in xy],[F(1)]*3,[(1-x-y)/y for x,y in xy]]
 s=prim.apply(prim.inverse(p),white(name));return [[p[i][j]*s[j] for j in range(3)] for i in range(3)]
def convert(src,dst):
 a=[[F(v) for v in r] for r in [['.7328','.4296','-.1624'],['-.7036','1.6975','.0061'],['.003','.0136','.9834']]]
 s,d=prim.apply(a,white(src)),prim.apply(a,white(dst));diag=[[d[i]/s[i] if i==j else F(0) for j in range(3)] for i in range(3)]
 cat=prim.multiply(prim.multiply(prim.inverse(a),diag),a)
 return [[decimal(v) for v in row] for row in prim.multiply(prim.multiply(prim.inverse(matrix(dst)),cat),matrix(src))]
parameters={
 'rec709':('gam',1/.45,4.5,.099,.018,.081),
 'rec2020':('gam',1/.45,4.5,.0993,.0181,.08145),
 'srgb':('gam',2.4,12.92,.055,.0031308,.04015966),
 'dci26':('gam',2.6,1.,0.,1e-7,1e-7),
 'cieLStar':('gam',3.,24389./2700.,.16,216./24389.,216./2700.),
 'proPhoto':('gam',1.8,16.,0.,math.pow(16,1.8/-.8),math.pow(math.pow(16,1.8/-.8),1/1.8)),
}
for n,e,o,c in [('bbc04',.4,-.02262,.037703),('bbc05',.5,-.01011,.020202),('bbc06',.6,-.00334,.008857)]:parameters[n]=('bbc',e,5.,o,c,math.pow((c+o)/(1+o),e))
for k in range(15,27):parameters[f'gamma{k}']=('gam',k/10,1.,0.,1e-7,1e-7)
curves=[*parameters,'sceneIRE','sceneReflectance']
with localcontext() as ctx:
 ctx.prec=70
 def decode(name,x):
  if name=='sceneIRE':return x
  if name=='sceneReflectance':return x/exact(.9)
  kind,e,s,o,low,cut=parameters[name];ee,ss,oo,cc=map(exact,[e,s,o,cut])
  if kind=='bbc':return (1+oo)*ctx.power(x,exact(1/e))-oo if x>cc else x/ss
  return ctx.power((x+oo)/(1+oo),ee) if x>=cc else x/ss
 def encode(name,x):
  if name=='sceneIRE':return x
  if name=='sceneReflectance':return x*exact(.9)
  kind,e,s,o,cut,high=parameters[name];ss,oo,cc=map(exact,[s,o,cut])
  if kind=='bbc':return ctx.power((x+oo)/(1+oo),exact(e)) if x>cc else x*ss
  return (1+oo)*ctx.power(x,exact(1/e))-oo if x>=cc else x*ss
 def settings(base,out,src,dst):return {'algorithm':'lutcalc.display-sdr-decode-matrix-encode.v1','enabled':True,'baseCurve':base,'outputCurve':out,'baseGamut':src,'outputGamut':dst}
 def prepare(s,oneD):
  m=convert(s['baseGamut'],s['outputGamut']) if not oneD and s['baseGamut']!=s['outputGamut'] else None
  def evaluate(p):
   p=[decode(s['baseCurve'],x) for x in p]
   if m:p=prim.apply(m,p)
   return [encode(s['outputCurve'],x) for x in p]
  return evaluate
 points=[[-.5,-.2,-.01],[0.,0.,0.],[.18,.18,.18],[1.,1.,1.],[2.,0.,0.],[0.,2.,0.],[0.,0.,2.],[8.,-.25,.1]]
 points += [[i%7/2-.5,i%11/3-1,i%13/4-.75] for i in range(16)]
 cases=[]
 for base in curves:
  for out in curves:
   s=settings(base,out,'rec709','rec709');ev=prepare(s,True)
   cases.append({'settings':s,'oneD':True,'probes':[{'input':[repr(x) for x in p],'output':[str(x) for x in ev([exact(x) for x in p])]} for p in points]})
 for src in geometry:
  for dst in geometry:
   s=settings('rec709','sceneReflectance',src,dst);ev=prepare(s,False)
   cases.append({'settings':s,'oneD':False,'probes':[{'input':[repr(x) for x in p],'output':[str(x) for x in ev([exact(x) for x in p])]} for p in points]})
 grids=[]
 for name,s in [('p3dci',settings('rec709','sceneReflectance','rec2020','p3DCI')),('d50d60',settings('proPhoto','sceneIRE','proPhoto','p3D60'))]:
  m=convert(s['baseGamut'],s['outputGamut'])
  for size in [33,65]:
   axis=[decode(s['baseCurve'],exact(-.5+i/(size-1)*2.5)) for i in range(size)]
   binary=bytearray()
   for b in range(size):
    for g in range(size):
     for r in range(size):
      output=[encode(s['outputCurve'],x) for x in prim.apply(m,[axis[r],axis[g],axis[b]])]
      binary.extend(struct.pack('<3d',*(float(x) for x in output)))
   filename=f'display-conversion-independent-{name}{size}.f64';p=ROOT/'tests/fixtures/native-contracts'/filename
   if '--check' in sys.argv:assert p.read_bytes()==binary,filename+'变化'
   else:p.write_bytes(binary)
   grids.append({'size':size,'settings':s,'file':filename,'sha256':hashlib.sha256(binary).hexdigest()});print(('核对' if '--check' in sys.argv else '生成')+filename,flush=True)
 output=json.dumps({'precision':70,'sourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'matrixHelperSHA256':hashlib.sha256(Path(prim.__file__).read_bytes()).hexdigest(),'method':'独立23曲线方程、直接有理数原色与CAT02、七个白点矩阵组合、四个完整Double输入网格','cases':cases,'grids':grids},ensure_ascii=False,indent=2)+'\n'
p=ROOT/'tests/fixtures/native-contracts/display-conversion-independent-reference.json'
if '--check' in sys.argv:assert p.read_text()==output;print('独立显示转换'+str(len(cases))+'组与四个全网格一致')
else:p.write_text(output);print('已生成独立显示转换'+str(len(cases))+'组及四个全网格')
