"""独立重读本包真实 CUBE/SPI1D 全点，并核对来源与项目 EI；不调用产品解析器。"""
from pathlib import Path
import hashlib, json, math, re, sys

root = Path(__file__).resolve().parents[2]
fixture = json.loads((root/'tests/fixtures/native-contracts/arri-logc-scene-routing-independent.json').read_text())
base_path = root/'tests/fixtures/native-contracts/arri-logc-compact-independent.json'
assert hashlib.sha256(base_path.read_bytes()).hexdigest() == fixture['coefficientReferenceSHA256']
for path, expected in fixture['sourceSHA256'].items():
    assert hashlib.sha256((root/path).read_bytes()).hexdigest() == expected, path
base = json.loads(base_path.read_text())
expected_cubes = {}
for item in base['grids']:
    if item['domain'] == 'sceneExposure':
        name = f"{item['firmware']}-{item['exposureIndex']}-{item['direction']}-{item['size']}"
        expected_cubes[name] = item
for item in fixture['mixedGrids']:
    expected_cubes[f"mixed-{item['size']}"] = item
expected_spis = {f"{item['firmware']}-{item['direction']}": item for item in fixture['axes1024']}

directory = Path(sys.argv[1])
folders = sorted(p for p in directory.iterdir() if p.is_dir() and p.name.startswith('logc-files-'))
assert folders, directory
summaries = []
for folder in folders:
    errors = []; outputs = []; manifests = []
    def compare(actual, expected):
        assert math.isfinite(actual) and math.isfinite(expected)
        error = abs(actual-expected)/max(1,abs(expected))
        assert error <= 2e-12, (actual,expected,error)
        errors.append(error)
    cubes = {p.stem: p for p in folder.glob('*.cube')}
    spis = {p.stem: p for p in folder.glob('*.spi1d')}
    assert set(cubes) == set(expected_cubes) and set(spis) == set(expected_spis)
    for name, item in expected_cubes.items():
        path = cubes[name]; text = path.read_text(); size = item['size']
        assert re.search(r'^LUT_3D_SIZE\s+'+str(size)+r'\s*$',text,re.M)
        sample_lines = [line.split() for line in text.splitlines() if line.strip() and line.lstrip()[0] in '-+.0123456789']
        assert len(sample_lines) == size**3
        expected = list(map(float,item['outputs']))
        for i, fields in enumerate(sample_lines):
            assert len(fields) == 3
            for c, axis in enumerate([i%size,(i//size)%size,i//(size*size)]): compare(float(fields[c]),expected[axis])
        manifest_path = folder/(name+'.lutcalc')/'manifest.json'
        manifest = json.loads(manifest_path.read_text()); settings = manifest['settings']
        assert manifest['schemaVersion'] == 17 and manifest['cubeSize'] == size
        if name.startswith('mixed-'):
            assert settings['inputLogC']['exposureIndex'] == 800 and settings['outputLogC']['exposureIndex'] == 1600
            assert settings['inputLogC']['algorithm'] == 'arri.logc-sup2-compact-published.v1'
            assert settings['outputLogC']['algorithm'] == 'arri.logc-sup3-compact-published.v1'
            assert settings['exposureStops'] == item['exposureStops']
        else:
            slot = 'outputLogC' if item['direction'] == 'encode' else 'inputLogC'
            assert settings[slot]['exposureIndex'] == item['exposureIndex']
            assert settings[slot]['algorithm'] == f"arri.logc-{item['firmware']}-compact-published.v1"
        for slot in ['inputLogC','outputLogC']:
            if slot in settings: assert manifest['algorithmVersions'][slot] == settings[slot]['algorithm']
        outputs.append(str(path)); manifests.append(str(manifest_path))
    for name, item in expected_spis.items():
        path = spis[name]; text = path.read_text()
        assert re.search(r'^Length\s+1024\s*$',text,re.M) and re.search(r'^Components\s+3\s*$',text,re.M)
        samples = [line.split() for line in text.split('{',1)[1].split('}',1)[0].splitlines() if line.strip()]
        assert len(samples) == 1024
        expected = list(map(float,item['outputs']))
        for i, fields in enumerate(samples):
            assert len(fields) == 3
            for word in fields: compare(float(word),expected[i])
        outputs.append(str(path))
    errors.sort()
    summaries.append(dict(folder=str(folder),files=len(outputs),projects=len(manifests),channels=len(errors),
        maximum=errors[-1],RMS=math.sqrt(math.fsum(e*e for e in errors)/len(errors)),
        P99=errors[math.ceil(len(errors)*.99)-1],threshold=2e-12,
        SHA256={str(Path(p).relative_to(directory)):hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in outputs+manifests}))
historical = []
for folder in sorted(directory.glob('logc-schema16-*')):
    before = (folder/'manifest-before.json').read_bytes()
    after = (folder/'manifest-after.json').read_bytes()
    saved = (folder/'schema16.lutcalc/manifest.json').read_bytes()
    assert before == after == saved
    manifest = json.loads(saved)
    assert manifest['schemaVersion'] == 16
    assert 'inputLogC' not in manifest['settings'] and 'outputLogC' not in manifest['settings']
    historical.append(dict(folder=str(folder),schema=16,bytes=len(saved),SHA256=hashlib.sha256(saved).hexdigest(),unchanged=True))
result = dict(scope='独立Python全点文件重读；不是Files/Finder或目标软件往返',runs=summaries,historicalDiskProjects=historical)
print(json.dumps(result,ensure_ascii=False,indent=2))
