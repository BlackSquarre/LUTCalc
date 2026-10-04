"""实际重读来源、解析参数与独立二进制参照，拒绝缺失或篡改。"""
from pathlib import Path
import hashlib,json,math,re,struct
root=Path(__file__).resolve().parents[2]
fixture=root/'tests/fixtures/native-contracts/arri-logc-compact-independent.json'
data=json.loads(fixture.read_text())
for name,expected in data['sourceSHA256'].items():
    assert hashlib.sha256((root/name).read_bytes()).hexdigest()==expected,name
raw=(root/'tests/fixtures/native-contracts/arri-logc-compact-decode.f64').read_bytes()
assert hashlib.sha256(raw).hexdigest()==data['decodeBinarySHA256']
assert len(raw)==225280*8 and all(math.isfinite(x[0]) for x in struct.iter_unpack('<d',raw))
assert len(data['cases'])==44 and len(data['grids'])==16
assert data['precision']==[80,120]
source=(root/'Native/Packages/LUTKit/Sources/LUTCore/ARRILogCCompact.swift').read_text()
rows=re.findall(r'case \(\.(\w+), \.(\w+), (\d+)\): parameters = Parameters\(([^\n]+)\)',source)
assert len(rows)==44
indexed={(firmware,domain,int(ei)):dict(field.split(': ') for field in fields.split(', ')) for firmware,domain,ei,fields in rows}
cursor=0
for case in data['cases']:
    assert indexed[(case['firmware'],case['domain'],case['exposureIndex'])]==case['parameters']
    assert case['decodeBinaryOffsetBytes']==cursor
    assert case['decodeBinaryCount']==5120
    cursor+=5120*8
    assert all(math.isfinite(float(p['input'])) and math.isfinite(float(p['output'])) for p in case['probes'])
assert cursor==len(raw)
channels=sum(g['size']**3*3 for g in data['grids'])
assert channels==7453488
print(f'公开来源SHA、44组解析参数、225280个独立解码值及16个完整网格轴参照核对通过；网格通道={channels}')
print('不证明实际相机误差、高EI shoulder、转换计划接线或完整FULL-02。')
