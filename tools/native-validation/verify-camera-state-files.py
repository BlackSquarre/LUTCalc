"""独立重读相机状态、完整 CUBE／SPI1D 和 schema18 原字节；不调用产品。"""
from pathlib import Path
import hashlib,json,math,sys
root=Path(__file__).resolve().parents[2]
folder=root/'docs/native-validation/artifacts/2026-10-02-camera-state'
fixture=root/'tests/fixtures/native-contracts/camera-state-independent.json'
reference=json.loads(fixture.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for path,value in reference['sourceSHA256'].items():assert sha(root/path)==value,path
original=json.loads((folder/'schema18-source.json').read_text())
assert sha(root/original['originalPath'])==sha(root/original['fixturePath'])==original['SHA256']
runs,histories=[],[]
for directory in sorted(folder.glob('outputs-*')):
    for output in sorted(directory.glob('camera-files-*')):
        errors,hashes=[],{}
        for index,grid in enumerate(reference['grids']):
            path=output/f'case-{index}.cube'
            project=output/f'case-{index}.lutcalc/manifest.json'
            manifest=json.loads(project.read_text());assert manifest['schemaVersion']==19
            settings=manifest['settings'];camera=settings['cameraExposure']
            assert camera['profileID']==grid['profileID'] and camera['recordedISO']==grid['recordedISO']
            assert camera['inputPolicy']=='camera.explicit-current-input.v1'
            assert camera['source']=='recorded-iso.v1' and camera['algorithm']=='lutcalc.camera-exposure-state.v1'
            assert camera['stopCorrection']==settings['exposureStops']
            assert settings['inputTransfer']==settings['outputTransfer']=='linear.scene.v1'
            assert manifest['algorithmVersions']['cameraProfile']==camera['profileID']
            values,size,low,high=[],None,None,None
            for line in path.read_text().splitlines():
                words=line.split('#')[0].split()
                if not words:continue
                if words[0]=='LUT_3D_SIZE':size=int(words[1])
                elif words[0]=='DOMAIN_MIN':low=list(map(float,words[1:]))
                elif words[0]=='DOMAIN_MAX':high=list(map(float,words[1:]))
                elif words[0]!='TITLE':
                    assert len(words)==3,line
                    values.append(list(map(float,words)))
            assert size==grid['size'] and len(values)==size**3
            assert low==[grid['minimum']]*3 and high==[grid['maximum']]*3
            axis=list(map(float,grid['outputs']))
            for node,rgb in enumerate(values):
                for c,y in enumerate([axis[node%size],axis[(node//size)%size],axis[node//(size*size)]]):
                    actual=rgb[c];assert math.isfinite(actual)
                    error=abs(actual-y)/max(1,abs(y));assert error<=2e-12,(path,node,c,error)
                    errors.append(error)
            hashes[str(path.relative_to(root))]=sha(path);hashes[str(project.relative_to(root))]=sha(project)
            if size==33:
                spi=output/f'case-{index}.spi1d';lines=spi.read_text().splitlines()
                assert any(line.strip()=='Length 1024' for line in lines)
                assert any(line.strip()=='Components 3' for line in lines)
                start=next(i for i,line in enumerate(lines) if line.strip()=='{')
                rows=[list(map(float,line.split())) for line in lines[start+1:] if line.strip() not in ['','}']]
                expected=list(map(float,grid['spi1dOutputs']));assert len(rows)==1024
                for row,y in zip(rows,expected,strict=True):
                    assert len(row)==3
                    for actual in row:
                        assert math.isfinite(actual)
                        error=abs(actual-y)/max(1,abs(y));assert error<=2e-12
                        errors.append(error)
                hashes[str(spi.relative_to(root))]=sha(spi)
        errors.sort();assert len(errors)==3739032
        runs.append(dict(path=str(output.relative_to(root)),cubeFiles=8,spi1dFiles=4,channels=len(errors),maximum=errors[-1],
            RMS=math.sqrt(math.fsum(x*x for x in errors)/len(errors)),P99=errors[math.ceil(len(errors)*.99)-1],SHA256=hashes))
    for output in sorted(directory.glob('camera-schema18-*')):
        before,after=output/'manifest-before.json',output/'manifest-after.json'
        assert before.read_bytes()==after.read_bytes()==(output/'schema18.lutcalc/manifest.json').read_bytes()
        assert sha(before)==original['SHA256'];histories.append(dict(path=str(output.relative_to(root)),unchanged=True,SHA256=sha(before)))
assert runs and histories
result=dict(threshold=2e-12,runs=runs,historicalDiskProjects=histories,referenceSHA256=sha(fixture),
    scope='显式线性输入的相机曝光与本地项目／文件；不证明全部默认曲线、设备裁剪、提供商、UI 或发布')
target=folder/(sys.argv[1] if len(sys.argv)>1 else 'independent-files-final.json')
target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({**result,'runs':[{k:v for k,v in run.items() if k!='SHA256'} for run in runs]},ensure_ascii=False,indent=2))
