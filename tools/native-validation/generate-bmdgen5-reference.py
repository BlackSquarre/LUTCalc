"""从冻结ACES双向CTL和旧注册，独立有理数/Decimal生成BMD Gen5参照。"""
from pathlib import Path
from fractions import Fraction as F
from decimal import Decimal as D, localcontext
import hashlib,json,math,re,struct

root=Path(__file__).resolve().parents[2]
target=root/'tests/fixtures/native-contracts'
folder=root/'research/colour/2026-10-02-bmdgen5'
sources=json.loads((folder/'sources.json').read_text())
texts=[]
for item in sources:
 p=root/item['file'];assert hashlib.sha256(p.read_bytes()).hexdigest()==item['SHA256'];texts.append(p.read_text())
params={}
for name in ['A','B','C','D','E','LIN_CUT']:
 values=[re.search(r'const float '+name+r' = ([\d.]+);',text).group(1) for text in texts]
 assert values[0]==values[1];params[name]=values[0]
blocks=[re.search(r'const Chromaticities BMD_CAM_WG_GEN5_PRI =\s*\{(.*?)\};',text,re.S).group(1) for text in texts]
assert blocks[0]==blocks[1]
rows=re.findall(r'\{\s*(-?[\d.]+),\s*(-?[\d.]+)\}',blocks[0]);assert len(rows)==4
geometry={
 'blackmagic.wide-gamut-gen5.v1':(rows[:3],rows[3]),
}
old=json.loads((target/'arri-awg3-independent.json').read_text())
# All previous published geometry is frozen in the existing independent generator.
# This copy is a research reference, not read from the product implementation.
geometry.update({
 'arri.awg3.v1':([('.6840','.3130'),('.2210','.8480'),('.0861','-.1020')],('.3127','.3290')),
 'dji.dgamut2.v1':([('.7347','.2653'),('.16','.84'),('.09','-.08')],('.3127','.3290')),
 'aces.ap0.v1':([('.7347','.2653'),('0','1'),('.0001','-.077')],('.32168','.33767')),
 'srgb.d65.v1':([('.640','.330'),('.300','.600'),('.150','.060')],('.3127','.3290')),
 'sony.sgamut3cine.v1':([('.766','.275'),('.225','.800'),('.089','-.087')],('.3127','.3290')),
 'sony.sgamut3.v1':([('.730','.280'),('.140','.855'),('.100','-.050')],('.3127','.3290')),
 'arri.awg4.v1':([('.7347','.2653'),('.1424','.8576'),('.0991','-.0308')],('.3127','.3290')),
 'panasonic.vgamut.v1':([('.730','.280'),('.165','.840'),('.100','-.030')],('.3127','.3290')),
 'fujifilm.fgamut.v1':([('.708','.292'),('.170','.797'),('.131','.046')],('.3127','.3290')),
 'fujifilm.fgamut-c.v1':([('.7347','.2653'),('.0263','.9737'),('.1173','-.0224')],('.3127','.3290')),
 'aces.ap1.v1':([('.713','.293'),('.165','.830'),('.128','.044')],('.32168','.33767')),
 'rec2020.d65.v1':([('.708','.292'),('.170','.797'),('.131','.046')],('.3127','.3290')),
 'apple.wide-gamut.v1':([('.725','.301'),('.221','.814'),('.068','-.076')],('.3127','.3290')),
 'kinefinity.wide-gamut.v1':([('.7571','.2282'),('.2139','1.1480'),('.0536','-.2236')],('.3127','.3290')),
 'romm.prophoto-d50.v1':([('.7347','.2653'),('.1596','.8404'),('.0366','.0001')],('.34567','.35850')),
})
cats = {'cieCAT02':[['.7328','.4296','-.1624'],['-.7036','1.6975','.0061'],['.003','.0136','.9834']],
        'bradford':[['.8951','.2664','-.1614'],['-.7502','1.7135','.0367'],['.0389','-.0685','1.0296']]}
def inverse(a):
    m = [list(row)+[F(int(i==j)) for j in range(3)] for i,row in enumerate(a)]
    for i in range(3):
        k = next(k for k in range(i,3) if m[k][i]); m[k],m[i] = m[i],m[k]
        scale = m[i][i]; m[i] = [x/scale for x in m[i]]
        for k in range(3):
            if k != i:
                scale = m[k][i]; m[k] = [m[k][j]-scale*m[i][j] for j in range(6)]
    return [row[3:] for row in m]
def mul(a,b): return [[sum(a[i][k]*b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
def apply(a,p): return [sum(x*y for x,y in zip(row,p)) for row in a]
def white(key):
    x,y = map(F,geometry[key][1]); return [x/y,F(1),(1-x-y)/y]
def primaries(key):
    xy = [tuple(map(F,p)) for p in geometry[key][0]]
    basis = [[x/y for x,y in xy],[F(1)]*3,[(1-x-y)/y for x,y in xy]]
    scale = apply(inverse(basis),white(key))
    return [[basis[i][j]*scale[j] for j in range(3)] for i in range(3)]
def conversion(source,target,cat):
    cone = [[F(x) for x in row] for row in cats[cat]]
    a,b = apply(cone,white(source)),apply(cone,white(target))
    diagonal = [[b[i]/a[i] if i==j else F(0) for j in range(3)] for i in range(3)]
    adaptation = mul(mul(inverse(cone),diagonal),cone)
    return mul(mul(inverse(primaries(target)),adaptation),primaries(source))
def decimal(x): return D(x.numerator)/D(x.denominator)
def decimal_matrix(m): return [[decimal(x) for x in row] for row in m]

def rounded(operation):
 out=[]
 for precision in [80,120]:
  with localcontext() as ctx:
   ctx.prec=precision;out.append(float(operation()))
 assert out[0]==out[1] and math.isfinite(out[0]),out
 return repr(out[0])
js=root/'js/gamma.js';text=js.read_text()
legacyWords=re.search(r"'BMDFilm Gen5', \[ ([^\]]+) \]",text).group(1).split(', ')
assert len(legacyWords)==9
legacy=[D(x) for x in legacyWords]
constants={name:D(value) for name,value in params.items()}
publishedCut=float(params['LIN_CUT']);publishedLogCut=float(params['D'])*publishedCut+float(params['E'])
def curve(x,legacyMode,decoding):
 if legacyMode:
  if decoding:
   return (legacy[4]**((x-legacy[5])/legacy[2])-legacy[6])/legacy[3] if x>=D.from_float(float(legacy[7])) else legacy[0]*x+legacy[1]
  return legacy[2]*(x*legacy[3]+legacy[6]).ln()/legacy[4].ln()+legacy[5] if x>=D.from_float(float(legacy[8])) else (x-legacy[1])/legacy[0]
 if decoding:
  return ((x-constants['C'])/constants['A']).exp()-constants['B'] if x>=D.from_float(publishedLogCut) else (x-constants['E'])/constants['D']
 return constants['A']*(x+constants['B']).ln()+constants['C'] if x>=D.from_float(publishedCut) else constants['D']*x+constants['E']
curves=[]
for legacyMode in [False,True]:
 for decoding in [False,True]:
  cut=float(legacy[7 if decoding else 8]) if legacyMode else publishedLogCut if decoding else publishedCut
  xs=[-.5,-.1,-.02,-0.0,0.0,1e-308,.005,.18,1,10]+([] if decoding else [100])
  xs += [math.nextafter(cut,-math.inf),cut,math.nextafter(cut,math.inf)]
  xs += [i/((1<<bits)-1) for bits in [10,12] for i in range(1<<bits)]
  points=[[repr(x),rounded(lambda x=x:curve(D.from_float(x),legacyMode,decoding))] for x in xs]
  curves.append(dict(legacy=legacyMode,decode=decoding,points=points))
  print('curve',legacyMode,decoding,len(points),flush=True)
matrices=[]
for other in geometry:
 for cat in cats:
  for source,targetID in [('blackmagic.wide-gamut-gen5.v1',other),(other,'blackmagic.wide-gamut-gen5.v1')]:
   m=conversion(source,targetID,cat)
   matrices.append(dict(source=source,target=targetID,cat=cat,values=[rounded(lambda x=x:decimal(x)) for row in m for x in row]))
fixture=dict(sourceSHA256={item['file']:item['SHA256'] for item in sources},legacySourceSHA256=hashlib.sha256(js.read_bytes()).hexdigest(),params=params,legacyParameters=legacyWords,primaries=rows,curves=curves,matrices=matrices,grids=[])
# Full colour grids: both curve versions and directions, no product math.
with (target/'bmdgen5-grids.f64').open('wb') as stream:
 for legacyMode in [False,True]:
  for decoding in [True,False]:
   source='blackmagic.wide-gamut-gen5.v1' if decoding else 'aces.ap0.v1'
   dest='aces.ap0.v1' if decoding else 'blackmagic.wide-gamut-gen5.v1'
   cat='cieCAT02' if decoding else 'bradford'
   matrix=conversion(source,dest,cat)
   for size in [33,65]:
    offset=stream.tell();axis=[-.1+1.3*i/(size-1) for i in range(size)]
    previous=None
    for precision in [80,120]:
     with localcontext() as ctx:
      ctx.prec=precision;dm=decimal_matrix(matrix);dx=[D.from_float(x) for x in axis]
      if decoding:
       dx=[curve(x,legacyMode,True)*(D('.9') if legacyMode else 1) for x in dx]
      # Precompute each row's axis terms to avoid repeated multiplications.
      terms=[[[dm[c][j]*x for x in dx] for j in range(3)] for c in range(3)]
      values=[]
      for b in range(size):
       for g in range(size):
        for r in range(size):
         for c in range(3):
          y=terms[c][0][r]+terms[c][1][g]+terms[c][2][b]
          if not decoding:y=curve(y/(D('.9') if legacyMode else 1),legacyMode,False)
          values.append(float(y))
     if previous is not None:assert previous==values,'full-grid precision disagreement'
     previous=values
     print('grid',legacyMode,decoding,size,precision,flush=True)
    stream.write(struct.pack('<'+'d'*len(values),*values))
    fixture['grids'].append(dict(legacy=legacyMode,decode=decoding,source=source,target=dest,cat=cat,size=size,minimum=-.1,maximum=1.2,offsetBytes=offset,channels=len(values)))
(target/'bmdgen5-independent.json').write_text(json.dumps(fixture,indent=2)+'\n')
print('independent generation complete',flush=True)
