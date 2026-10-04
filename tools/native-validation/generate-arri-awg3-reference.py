"""独立有理数原色/CAT与80/120位Decimal生成AWG3参照；不调用产品或旧引擎。"""
from pathlib import Path
from fractions import Fraction as F
from decimal import Decimal as D, localcontext
import hashlib, json, math, re, struct, sys

root = Path(__file__).resolve().parents[2]
target = root/'tests/fixtures/native-contracts'
research = root/'research/colour/2026-10-02-logc3'
source = research/'arri-logc3-vfx-2017.pdf.txt'
text = source.read_text()
rows = [re.search(r'^'+name+r' ([\d.]+) (-?[\d.]+)$',text,re.M).groups() for name in ['Red','Green','Blue','White']]
old = (research/'arri-logc-vfx-2012-mirror.pdf.txt').read_text()
assert rows == [re.search(r'^'+name+r' ([\d.]+) (-?[\d.]+)$',old,re.M).groups() for name in ['Red','Green','Blue','White']]
dji_source = root/'research/colour/2026-10-02-awg3/Dlog2_DGamut2_to_ACES_AP0_cat02.ctl'
dji_reference = root/'tests/fixtures/dlog2-reference.json'
dji_fixture = json.loads(dji_reference.read_text())
assert hashlib.sha256(dji_source.read_bytes()).hexdigest() == dji_fixture['sha256'][dji_source.name]
dji_block = re.search(r'const Chromaticities DGamut2_PRI\s*=\s*\{(.*?)\};',dji_source.read_text(),re.S).group(1)
dji_rows = re.findall(r'\{\s*(-?[\d.]+),\s*(-?[\d.]+)\s*\}',dji_block)
assert len(dji_rows) == 4
geometry = {
 'arri.awg3.v1':(rows[:3],rows[3]),
 'dji.dgamut2.v1':(dji_rows[:3],dji_rows[3]),
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
}
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
    results = []
    for precision in [80,120]:
        with localcontext() as context:
            context.prec = precision; results.append(float(operation()))
    assert results[0] == results[1] and math.isfinite(results[0]), results
    return results[0]
dji_xyz = [float(x) for row in primaries('dji.dgamut2.v1') for x in row]
assert max(abs(a-b) for a,b in zip(dji_xyz,dji_fixture['toXYZ'])) <= 2e-12
probes = [[-.1,.3,1.2],[0,0,0],[1,0,0],[0,1,0],[0,0,1],[1,1,1],[-10,10,1e-6]]
probes += [[i%7/2-.5,i%11/3-1,i%13/4-.75] for i in range(32)]
matrices = []
for other in geometry:
    for cat in cats:
        for source_id,target_id in [('arri.awg3.v1',other),(other,'arri.awg3.v1')]:
            m = conversion(source_id,target_id,cat)
            values = [repr(rounded(lambda x=x: decimal(x))) for row in m for x in row]
            outputs = []
            for p in probes:
                ys = [repr(rounded(lambda c=c: apply(decimal_matrix(m),[D.from_float(x) for x in p])[c])) for c in range(3)]
                outputs.append(dict(input=list(map(repr,p)),output=ys))
            matrices.append(dict(source=source_id,target=target_id,adaptation=cat,values=values,probes=outputs))
curve_reference = target/'arri-logc-compact-independent.json'
curves = {r['exposureIndex']:r['parameters'] for r in json.loads(curve_reference.read_text())['cases']
          if r['firmware']=='sup3' and r['domain']=='sceneExposure'}
def curve(parameters,direction,value):
    p = {k:D(v) for k,v in parameters.items()}
    cut = float(p['cut']) if direction=='encode' else float(p['e'])*float(p['cut'])+float(p['f'])
    if direction=='encode': return p['c']*(p['a']*value+p['b']).log10()+p['d'] if value>D.from_float(cut) else p['e']*value+p['f']
    return ((((value-p['d'])/p['c'])*D(10).ln()).exp()-p['b'])/p['a'] if value>D.from_float(cut) else (value-p['f'])/p['e']
def plan(parameters,matrix,direction,point):
    if direction=='decode': return apply(matrix,[curve(parameters,'decode',x) for x in point])
    return [curve(parameters,'encode',x) for x in apply(matrix,point)]
def prepared(ei,cat,direction,precision):
    source_id,target_id = ('arri.awg3.v1','aces.ap0.v1') if direction=='decode' else ('aces.ap0.v1','arri.awg3.v1')
    with localcontext() as context:
        context.prec = precision; m = decimal_matrix(conversion(source_id,target_id,cat))
    return m
def independent_plan(ei,cat,direction,point,prepared_matrices):
    results = []
    for precision,matrix in prepared_matrices:
        with localcontext() as context:
            context.prec = precision
            results.append([float(y) for y in plan(curves[ei],matrix,direction,[D.from_float(x) for x in point])])
    assert results[0] == results[1] and all(math.isfinite(x) for x in results[0]), (ei,cat,direction,point,results)
    return results[0]
binary = bytearray(); cases = []
for ei in curves:
    for cat in cats:
        for direction in ['decode','encode']:
            prepared_matrices = [(precision,prepared(ei,cat,direction,precision)) for precision in [80,120]]
            case = dict(exposureIndex=ei,adaptation=cat,direction=direction,offsetBytes=len(binary))
            for depth in [10,12]:
                for code in range(1<<depth):
                    scalar = code/((1<<depth)-1)
                    point = [scalar,.001+scalar*.73,1-scalar*.83]
                    binary.extend(struct.pack('<3d',*independent_plan(ei,cat,direction,point,prepared_matrices)))
            cases.append(case); print(f'已生成全码 {ei} {cat} {direction}',flush=True)
(target/'arri-awg3-codes.f64').write_bytes(binary)
grids = []
for ei,cat,direction in [(800,'cieCAT02','decode'),(1600,'bradford','decode'),(800,'cieCAT02','encode'),(1600,'bradford','encode')]:
    prepared_matrices = [(precision,prepared(ei,cat,direction,precision)) for precision in [80,120]]
    for size in [33,65]:
        axes = [-.1+i/(size-1)*1.3 for i in range(size)]; blob = bytearray()
        for b in range(size):
            for g in range(size):
                for r in range(size): blob.extend(struct.pack('<3d',*independent_plan(ei,cat,direction,[axes[r],axes[g],axes[b]],prepared_matrices)))
        name = f'arri-awg3-{direction}-{cat}-ei{ei}-{size}.f64'; (target/name).write_bytes(blob)
        grids.append(dict(exposureIndex=ei,adaptation=cat,direction=direction,size=size,minimum=-.1,maximum=1.2,file=name,SHA256=hashlib.sha256(blob).hexdigest()))
        print('已生成完整网格 '+name,flush=True)
xyz = [repr(rounded(lambda x=x:decimal(x))) for row in primaries('arri.awg3.v1') for x in row]
published = [float(word) for line in text.split('The ALEXA Wide Gamut RGB to CIE 1931 XYZ conversion matrix is\n')[1].splitlines()[:3] for word in line.split()]
sources = {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in
    [dji_source,dji_reference,research/'arri-logc3-vfx-2017.pdf',source,research/'arri-logc-vfx-2012-mirror.pdf',research/'arri-logc-vfx-2012-mirror.pdf.txt',curve_reference]}
result = dict(precision=[80,120],method='精确有理数原色/CAT、独立Decimal、确切Double输入；不调用产品/旧引擎',
    sourceSHA256=sources,geometry=geometry,rgbToXYZ=xyz,matrices=matrices,codeCases=cases,
    codeBinarySHA256=hashlib.sha256(binary).hexdigest(),codeChannels=len(binary)//8,grids=grids,
    publishedRoundedXYZMaximumDifference=max(abs(float(x)-y) for x,y in zip(xyz,published)))
(target/'arri-awg3-independent.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(dict(matrixCases=len(matrices),codeCases=len(cases),codeChannels=len(binary)//8,grids=len(grids),
    publishedRoundedXYZMaximumDifference=result['publishedRoundedXYZMaximumDifference']),ensure_ascii=False),flush=True)
