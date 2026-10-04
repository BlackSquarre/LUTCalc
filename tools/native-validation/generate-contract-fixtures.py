#!/usr/bin/env python3
"""Generate exact rational contract examples, independently of the JS engine."""
from fractions import Fraction as Q
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[2]
out = root / 'tests/fixtures/native-contracts'
out.mkdir(parents=True, exist_ok=True)
def number(x):
    if isinstance(x, Q): return float(x)
    if isinstance(x, list): return [number(v) for v in x]
    if isinstance(x, dict): return {k:number(v) for k,v in x.items()}
    return x
ranges=[]
for bits in [8,10,12]:
    lo,hi,maximum=16*2**(bits-8),235*2**(bits-8),2**bits-1
    for code in [0,lo,hi,maximum]:
        legal=Q(code-lo,hi-lo)
        ranges.append(dict(bits=bits,code=code,data=Q(code,maximum),video=legal,black=lo,white=hi,maxCode=maximum))
grid=[dict(index=r+3*(g+3*b),coordinate=[Q(r,2),Q(g,2),Q(b,2)]) for b in range(3) for g in range(3) for r in range(3)]
def f(p):
    r,g,b=map(Q,p)
    return [r+2*g+4*b+r*g,3*r-g+2*b+g*b,-r+g+2*b+r*b]
vertices=[dict(coordinate=[r,g,b],value=f([r,g,b])) for b in [0,1] for g in [0,1] for r in [0,1]]
tetra=[]
# Explicit vertex paths and rational barycentric weights; no floating-point interpolator.
paths=[([0,1,2],[[0,0,0],[1,0,0],[1,1,0],[1,1,1]]),([0,2,1],[[0,0,0],[1,0,0],[1,0,1],[1,1,1]]),([1,0,2],[[0,0,0],[0,1,0],[1,1,0],[1,1,1]]),([1,2,0],[[0,0,0],[0,1,0],[0,1,1],[1,1,1]]),([2,0,1],[[0,0,0],[0,0,1],[1,0,1],[1,1,1]]),([2,1,0],[[0,0,0],[0,0,1],[0,1,1],[1,1,1]])]
for order,path in paths:
    point=[Q(0)]*3
    for axis,v in zip(order,[Q(4,5),Q(1,2),Q(1,5)]):point[axis]=v
    weights=[Q(1,5),Q(3,10),Q(3,10),Q(1,5)]
    expected=[sum(w*f(p)[c] for w,p in zip(weights,path)) for c in range(3)]
    assert sum(weights)==1
    assert [sum(w*p[c] for w,p in zip(weights,path)) for c in range(3)]==point
    tetra.append(dict(point=point,order=order,vertices=path,weights=weights,tetrahedral=expected,trilinear=f(point)))
assert tetra[0]['tetrahedral']==[Q(31,10),Q(5,2),Q(3,10)]
assert tetra[0]['trilinear']==[Q(3),Q(12,5),Q(13,50)]
A=[1,2,3,0,1,4,5,6,0]; inv=[-24,18,5,20,-15,-4,-5,4,1]
assert [sum(A[r*3+k]*inv[k*3+c] for k in range(3)) for r in range(3) for c in range(3)]==[1,0,0,0,1,0,0,0,1]
contract=dict(schemaVersion=1,purpose='开发测试专用，不得进入 App 运行资源；本文件不是任何厂商 LUT',tolerance=dict(scaled=2e-12,integer='exact'),rangeCases=ranges,grid3=grid,matrix=dict(rowMajor=A,inverseRowMajor=inv,input=[Q(1,4),Q(-1,2),Q(2)],output=[Q(21,4),Q(15,2),Q(-7,4)]),interpolation=dict(dimension=2,domainMin=[0,0,0],domainMax=[1,1,1],vertices=vertices,cases=tetra,tie=dict(point=[Q(1,2)]*3,tetrahedral=[4,Q(5,2),Q(3,2)],trilinear=f([Q(1,2)]*3))),scaleCases=[dict(legacy=Q(1,5),scene=Q(9,50)),dict(legacy=-Q(1,5),scene=-Q(9,50))],orderCase=dict(input=Q(1,5),exposureGain=2,offset=Q(1,10),exposureThenOffset=Q(1,2),offsetThenExposure=Q(3,5)),allocationCases=[dict(size=n,rgbDoubleBytes=24*n**3,planeBytes=24*n*n) for n in [17,33,65,129]])
# At the body diagonal, tetrahedral interpolation is between the two diagonal vertices.
assert contract['interpolation']['tie']['tetrahedral']==[v/2 for v in f([1,1,1])]
p=out/'numeric-contracts.json';p.write_text(json.dumps(number(contract),ensure_ascii=False,indent=2)+'\n')
invalid=[('missing-row','LUT_1D_SIZE 2\n0 0 0\n','rowCountMismatch'),('extra-row','LUT_1D_SIZE 2\n0 0 0\n1 1 1\n2 2 2\n','rowCountMismatch'),('nonfinite','LUT_1D_SIZE 2\n0 Infinity 0\n1 1 1\n','nonFiniteValue'),('bad-dimension','LUT_3D_SIZE 1\n0 0 0\n','invalidDimension'),('reversed-domain','LUT_1D_SIZE 2\nDOMAIN_MIN 1 0 0\nDOMAIN_MAX 0 1 1\n0 0 0\n1 1 1\n','invalidDomain'),('huge-dimension','LUT_3D_SIZE 2147483647\n','resourceLimit'),('partial-number','LUT_1D_SIZE 2\n0x 0 0\n1 1 1\n','invalidNumber')]
manifest=[]
for name,body,error in invalid:
    p=out/(name+'.cube');p.write_text(body);manifest.append(dict(file=p.name,expected='reject',error=error))
p=out/'valid-extended.cube';p.write_text('TITLE "扩展域"\nLUT_1D_SIZE 2\nDOMAIN_MIN -1 -2 -3\nDOMAIN_MAX 2 3 4\n-1e-3 +0.5 .25\n2 3 4\n');manifest.append(dict(file=p.name,expected='accept',dimension=1,size=2,domainMin=[-1,-2,-3],domainMax=[2,3,4],rows=[[-.001,.5,.25],[2,3,4]]))
(out/'parser-contracts.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
tracked=sorted(p for p in out.iterdir() if p.suffix in ['.cube','.json'] and p.name!='sha256.json')
(out/'sha256.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in tracked},indent=2)+'\n')
print('Generated exact rational numeric contracts and 8 parser cases.')
