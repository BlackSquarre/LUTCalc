"""独立重读实际BMD Gen5完整CUBE及历史项目字节，不调用产品解析器。"""
from pathlib import Path
import json,hashlib,math,struct

root=Path(__file__).resolve().parents[2]
folder=root/'docs/native-validation/artifacts/2026-10-02-bmdgen5'
reference=root/'tests/fixtures/native-contracts/bmdgen5-independent.json'
raw=json.loads(reference.read_text())
binary=(root/'tests/fixtures/native-contracts/bmdgen5-grids.f64').read_bytes()
for name,expected in raw['sourceSHA256'].items():
    assert hashlib.sha256((root/name).read_bytes()).hexdigest()==expected
assert hashlib.sha256((root/'js/gamma.js').read_bytes()).hexdigest()==raw['legacySourceSHA256']
result=dict(threshold=2e-12,runs=[],historicalDiskProjects=[],referenceSHA256=hashlib.sha256(reference.read_bytes()).hexdigest())
for path in sorted(folder.glob('outputs-*/bmd-files-*')):
    errors=[];hashes={}
    for index,grid in enumerate(raw['grids']):
        file=path/f'case-{index}.cube';rows=[];size=None;offset=grid['offsetBytes']
        for line in file.read_text().splitlines():
            words=line.split()
            if not words or words[0].startswith('#') or words[0]=='TITLE':continue
            if words[0]=='LUT_3D_SIZE':size=int(words[1]);continue
            if words[0]=='DOMAIN_MIN':assert list(map(float,words[1:]))==[-.1]*3;continue
            if words[0]=='DOMAIN_MAX':assert list(map(float,words[1:]))==[1.2]*3;continue
            assert len(words)==3,words;rows.append(list(map(float,words)))
        assert size==grid['size'] and len(rows)==size**3
        for row in rows:
            expected=struct.unpack_from('<ddd',binary,offset);offset+=24
            for x,y in zip(row,expected):
                assert math.isfinite(x);error=abs(x-y)/max(1,abs(y));assert error<=2e-12,(file,x,y,error)
                errors.append(error)
        project=path/f'case-{index}.lutcalc/manifest.json';manifest=json.loads(project.read_text())
        assert manifest['schemaVersion']==20
        transfer='blackmagic.film-gen5-lutcalc-legacy.v1' if grid['legacy'] else 'blackmagic.film-gen5-published.v1'
        s=manifest['settings'];assert s['inputTransfer' if grid['decode'] else 'outputTransfer']==transfer
        assert s['inputSpace']==grid['source'] and s['outputSpace']==grid['target']
        assert s.get('adaptation','cieCAT02')==grid['cat'] and s['exposureStops']==0
        assert not (path/f'case-{index}.spi1d').exists()
        for item in [file,project]:hashes[str(item.relative_to(root))]=hashlib.sha256(item.read_bytes()).hexdigest()
    errors.sort();result['runs'].append(dict(path=str(path.relative_to(root)),files=len(raw['grids']),channels=len(errors),maximum=errors[-1],
        RMS=math.sqrt(math.fsum(x*x for x in errors)/len(errors)),P99=errors[math.ceil(len(errors)*.99)-1],SHA256=hashes))
original=(root/'tests/fixtures/native-contracts/bmdgen5-schema19-original.json').read_bytes()
source=json.loads((folder/'schema19-source.json').read_text());assert hashlib.sha256(original).hexdigest()==source['SHA256']
assert (root/source['source']).read_bytes()==original
for path in sorted(folder.glob('outputs-*/bmd-schema19-*')):
    before=(path/'manifest-before.json').read_bytes();after=(path/'manifest-after.json').read_bytes()
    assert before==after==original
    result['historicalDiskProjects'].append(dict(path=str(path.relative_to(root)),unchanged=True,SHA256=source['SHA256']))
assert result['runs'] and result['historicalDiskProjects']
(folder/'independent-files-final.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({**result,'runs':[{k:v for k,v in item.items() if k!='SHA256'} for item in result['runs']]},indent=2))
