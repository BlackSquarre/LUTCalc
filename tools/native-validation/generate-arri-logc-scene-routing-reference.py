"""独立生成 Log C scene 接线的 1D、曝光组合和输出锚点参照；不调用产品。"""
from pathlib import Path
from decimal import Decimal, localcontext
import hashlib, json, math

root = Path(__file__).resolve().parents[2]
source = root / 'tests/fixtures/native-contracts/arri-logc-compact-independent.json'
raw = json.loads(source.read_text())
rows = {(r['firmware'], r['exposureIndex']): r for r in raw['cases'] if r['domain'] == 'sceneExposure'}

def formula(row, direction, value):
    p = {key: Decimal(text) for key, text in row['parameters'].items()}
    boundary = float(p['cut']) if direction == 'encode' else float(p['e']) * float(p['cut']) + float(p['f'])
    if direction == 'encode':
        return p['c'] * (p['a'] * value + p['b']).log10() + p['d'] if value > Decimal.from_float(boundary) else p['e'] * value + p['f']
    return ((((value-p['d'])/p['c'])*Decimal(10).ln()).exp()-p['b'])/p['a'] if value > Decimal.from_float(boundary) else (value-p['f'])/p['e']

def independent(operation):
    results = []
    for precision in [80, 120]:
        with localcontext() as context:
            context.prec = precision
            results.append(float(operation()))
    assert results[0] == results[1] and math.isfinite(results[0]), results
    return repr(results[0])

axes = []
for firmware, ei in [('sup2', 800), ('sup3', 1600)]:
    for direction in ['encode', 'decode']:
        values = [-.1 + i/1023*(1.2-(-.1)) for i in range(1024)]
        axes.append(dict(firmware=firmware, exposureIndex=ei, direction=direction,
                         minimum=-.1, maximum=1.2,
                         outputs=[independent(lambda x=x: formula(rows[(firmware,ei)],direction,Decimal.from_float(x))) for x in values]))
mixed = []
for size in [33,65]:
    values = [-.1 + i/(size-1)*(1.2-(-.1)) for i in range(size)]
    mixed.append(dict(size=size, minimum=-.1, maximum=1.2, exposureStops=1/3,
        outputs=[independent(lambda x=x: formula(rows[('sup3',1600)],'encode',
            formula(rows[('sup2',800)],'decode',Decimal.from_float(x)) *
            (Decimal(2).ln()*Decimal.from_float(1/3)).exp())) for x in values]))
anchors = [dict(legacy=x, legal=independent(lambda x=x:
    (formula(rows[('sup3',1600)],'encode',Decimal.from_float(x*.9))-Decimal(64)/1023)/(Decimal(876)/1023)))
    for x in [-.1,0,.2,1,10]]
result = dict(precision=[80,120], coefficientReferenceSHA256=hashlib.sha256(source.read_bytes()).hexdigest(),
    sourceSHA256=raw['sourceSHA256'], scope='scene公开式显式EI接线；同空间载体，不证明相机色域/shoulder',
    axes1024=axes, mixedGrids=mixed, anchorProbes=anchors)
target = root/'tests/fixtures/native-contracts/arri-logc-scene-routing-independent.json'
target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(dict(reference=str(target.relative_to(root)), SHA256=hashlib.sha256(target.read_bytes()).hexdigest(),
    axes=len(axes), axisValues=sum(len(a['outputs']) for a in axes), mixedGrids=len(mixed),
    sourceSHA256=raw['sourceSHA256']),ensure_ascii=False,indent=2))
