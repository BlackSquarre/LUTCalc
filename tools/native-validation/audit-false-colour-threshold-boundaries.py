"""保留旧边界输入，用独立Decimal阈值记录离散分类差异。"""
from pathlib import Path
import json,hashlib,sys
root=Path(__file__).resolve().parents[2];folder=root/'tests/fixtures/native-contracts'
legacy=json.loads((folder/'false-colour-legacy-reference.json').read_text())
ind=json.loads((folder/'false-colour-independent-reference.json').read_text())
palette={0:[.75,0,.75],1:[0,0,.75],3:[0,.7,0],5:[.75,.35,.35],7:[.9,.45,0],9:[.7,.7,0],10:[.75,0,0]}
cases=[];changes=[]
for index,(old,new) in enumerate(zip(legacy['cases'],ind['cases'])):
    assert old['settings']==new['settings'];s=new['settings'];t=list(map(float,new['thresholds']));probes=[]
    for probe in old['probes']:
        y=float(probe['luma']);band=None
        if old['active']:
            band=next((i for i,v in enumerate(t) if v!=-10 and y<=v),0)
            if band==0 and s['doRed'] and y>t[9]:band=10
            elif (band==0 and y>t[0]) or (band==0 and not s['doPurple'] and y<.1) or (band==9 and not s['doYellow']):band=8
        entry={'work':probe['work'],'luma':probe['luma'],'band':band,'output':list(map(repr,palette.get(band,[-.125,.375,1.25])))}
        probes.append(entry)
        if band!=probe['band']:changes.append({'case':index,'input':entry,'legacyBand':probe['band'],
            'legacyThresholds':old['thresholds'],'independentThresholds':new['thresholds'],'settings':s})
    cases.append({'settings':s,'thresholds':new['thresholds'],'probes':probes})
output=json.dumps({'method':'相同旧Double输入、独立70位Decimal阈值的离散分类对照；未删相邻边界',
    'sourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'legacyFixtureSHA256':hashlib.sha256((folder/'false-colour-legacy-reference.json').read_bytes()).hexdigest(),
    'independentFixtureSHA256':hashlib.sha256((folder/'false-colour-independent-reference.json').read_bytes()).hexdigest(),
    'changedProbes':len(changes),'changes':changes,'cases':cases},ensure_ascii=False,indent=2)+'\n'
p=folder/'false-colour-boundary-audit.json'
if '--check' in sys.argv:assert p.read_text()==output
else:p.write_text(output)
print('实际旧输入的独立阈值分类差异：',len(changes),'；原输入和输出差异全部保留')
