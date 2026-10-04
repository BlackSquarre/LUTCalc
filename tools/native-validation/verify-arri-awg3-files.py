"""独立重读 AWG3 实际 CUBE／项目和历史原字节，核对来源与全通道误差。"""
from pathlib import Path
import hashlib, json, math, struct, sys

root = Path(__file__).resolve().parents[2]
folder = root/'docs/native-validation/artifacts/2026-10-02-awg3'
fixture = root/'tests/fixtures/native-contracts'
reference = json.loads((fixture/'arri-awg3-independent.json').read_text())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
for path, expected in reference['sourceSHA256'].items(): assert sha(root/path) == expected, path
assert reference['precision'] == [80,120]
assert len(reference['matrices']) == 60 and len(reference['codeCases']) == 44
assert reference['codeChannels'] == 675840
assert sha(fixture/'arri-awg3-codes.f64') == reference['codeBinarySHA256']
grids = reference['grids']; assert len(grids) == 8
for grid in grids: assert sha(fixture/grid['file']) == grid['SHA256'], grid['file']
schema_source = json.loads((folder/'schema17-source.json').read_text())
assert sha(root/schema_source['originalPath']) == schema_source['SHA256']
assert sha(root/schema_source['fixturePath']) == schema_source['SHA256']
runs, histories = [], []
for directory in sorted(folder.glob('outputs-*')):
    for output in sorted(directory.glob('awg3-files-*')):
        errors, hashes = [], {}
        for grid in grids:
            name = grid['file'].removesuffix('.f64')
            path = output/(name+'.cube')
            manifest_path = output/(name+'.lutcalc')/'manifest.json'
            manifest = json.loads(manifest_path.read_text())
            assert manifest['schemaVersion'] == 18
            settings = manifest['settings']; decoding = grid['direction'] == 'decode'
            slot = 'input' if decoding else 'output'
            assert settings[slot+'Space'] == 'arri.awg3.v1'
            assert settings[('output' if decoding else 'input')+'Space'] == 'aces.ap0.v1'
            assert settings[slot+'LogC'] == dict(algorithm='arri.logc-sup3-compact-published.v1',exposureIndex=grid['exposureIndex'])
            # TransformSettings Codable omits the historical CAT02 default.
            assert settings.get('adaptation','cieCAT02') == grid['adaptation'] and settings['exposureStops'] == 0
            assert manifest['cubeSize'] == grid['size']
            samples, size, low, high = [], None, None, None
            for line in path.read_text().splitlines():
                words = line.split('#')[0].split()
                if not words: continue
                if words[0] == 'LUT_3D_SIZE': size = int(words[1])
                elif words[0] == 'DOMAIN_MIN': low = list(map(float,words[1:]))
                elif words[0] == 'DOMAIN_MAX': high = list(map(float,words[1:]))
                elif words[0] != 'TITLE':
                    assert len(words) == 3, line
                    samples.extend(map(float,words))
            assert size == grid['size'] and len(samples) == size**3*3
            assert low == [grid['minimum']]*3 and high == [grid['maximum']]*3
            expected = struct.iter_unpack('<d',(fixture/grid['file']).read_bytes())
            for actual,(value,) in zip(samples,expected,strict=True):
                assert math.isfinite(actual)
                error = abs(actual-value)/max(1,abs(value))
                assert error <= 2e-12, (path,actual,value,error)
                errors.append(error)
            hashes[str(path.relative_to(root))] = sha(path)
            hashes[str(manifest_path.relative_to(root))] = sha(manifest_path)
        errors.sort()
        runs.append(dict(path=str(output.relative_to(root)),files=len(grids),channels=len(errors),maximum=errors[-1],
            RMS=math.sqrt(math.fsum(x*x for x in errors)/len(errors)),P99=errors[math.ceil(len(errors)*.99)-1],SHA256=hashes))
    for output in sorted(directory.glob('schema17-*')):
        before,after = output/'manifest-before.json',output/'manifest-after.json'
        assert before.read_bytes() == after.read_bytes() == (output/'schema17.lutcalc/manifest.json').read_bytes()
        raw = json.loads(before.read_text()); assert raw['schemaVersion'] == 17
        # Only runs using the frozen historical source prove this source identity.
        histories.append(dict(path=str(output.relative_to(root)),unchanged=True,SHA256=sha(before),
            matchesFrozenSource=sha(before)==schema_source['SHA256']))
assert runs and any(x['matchesFrozenSource'] for x in histories)
result = dict(threshold=2e-12,referenceSHA256=sha(fixture/'arri-awg3-independent.json'),runs=runs,historicalDiskProjects=histories,
    scope='本地完整文件和项目字节；不证明设备、File Provider、UI 或签名发行')
target = folder/(sys.argv[1] if len(sys.argv)>1 else 'independent-files-verified.json')
target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({**result,'runs':[{k:v for k,v in run.items() if k!='SHA256'} for run in runs]},ensure_ascii=False,indent=2))
