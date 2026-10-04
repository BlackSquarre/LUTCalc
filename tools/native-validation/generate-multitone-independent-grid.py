"""对确切Double网格坐标计算70位Decimal Multitone参照；check核对完整性和来源漂移。"""
from decimal import Decimal as D, localcontext
from pathlib import Path
import hashlib,importlib.util,json,struct,sys

ROOT=Path(__file__).resolve().parents[2]
DIR=ROOT/'tests/fixtures/native-contracts'
META=DIR/'multitone-independent-grid.json'
PRIM=Path(__file__).with_name('generate-asccdl-independent-reference.py')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
sources={str(p.relative_to(ROOT)):sha(p) for p in [Path(__file__),PRIM]}

if '--check' in sys.argv:
    metadata=json.loads(META.read_text())
    assert metadata['sourceSHA256']==sources,'独立网格生成来源发生变化，请重新生成'
    for row in metadata['grids']:
        path=DIR/row['file']
        assert sha(path)==row['SHA256'] and path.stat().st_size==row['size']**3*3*8,'独立网格内容发生变化'
    print('Multitone 33³/65³独立Decimal全网格完整性与来源哈希一致')
    sys.exit(0)

spec=importlib.util.spec_from_file_location('prim',PRIM)
prim=importlib.util.module_from_spec(spec);spec.loader.exec_module(prim)
with localcontext() as ctx:
    ctx.prec=70
    y=[prim.decimal(v) for v in prim.primaries([('.766','.275'),('.225','.800'),('.089','-.087')])[1]]
    ln2=D(2).ln();grids=[]
    for size in [33,65]:
        axis=[-.18+i/(size-1)*(46.08-(-.18)) for i in range(size)]
        exact=[D.from_float(v) for v in axis]
        out=bytearray()
        for b in range(size):
            for g in range(size):
                for r in range(size):
                    p=[exact[r],exact[g],exact[b]]
                    l=sum(a*v for a,v in zip(y,p))
                    sat=D(0) if l<=0 else min(D(2),max(D(0),((l/D('.18')).ln()/ln2+8)/8))
                    for v in p:out.extend(struct.pack('<d',float(l+sat*(v-l))))
        path=DIR/f'multitone-independent-grid{size}.f64';path.write_bytes(out)
        grids.append({'size':size,'file':path.name,'SHA256':sha(path),
                      'axisDoubleBits':[struct.pack('<d',v).hex() for v in axis]})
        print(f'已计算{size}³确切Double输入的70位Decimal全节点参照',flush=True)
    META.write_text(json.dumps({'sourceSHA256':sources,'method':'确切IEEE754坐标、精确原色有理数Y、70位Decimal log2与饱和度；最终参照舍入Double',
                               'sceneDomain':[-.18,46.08],'saturationByStop':[i/8 for i in range(17)],'tones':[],
                               'grids':grids},ensure_ascii=False,indent=2)+'\n')
