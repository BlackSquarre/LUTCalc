"""独立70位Decimal阶段19：格式边界、模式、Legal/Data和HDR上下文。"""
from pathlib import Path
from decimal import Decimal as D,localcontext
import json,hashlib,struct,sys
root=Path(__file__).resolve().parents[2]
with localcontext() as ctx:
 ctx.prec=70
 def exact(x):return D.from_float(float(x))
 def settings(mode,clip,limits,cb):return {'algorithm':'lutcalc.final-output-code-limits.v1','enabled':True,'mode':mode,'clipLegal':clip,'minimumCode10':limits[0],'maximumCode10':limits[1],'forceBlackLegal':cb}
 def evaluate(x,s,legal,hdr,display):
  lo=(D(0) if s['forceBlackLegal'] else (exact(s['minimumCode10'])-64)/876) if legal else (D(64)/1023 if s['forceBlackLegal'] else exact(s['minimumCode10'])/1023)
  hi=(exact(s['maximumCode10'])-64)/876 if legal else exact(s['maximumCode10'])/1023
  black=s['mode'] in ['both','blackOnly'];white=s['mode'] in ['both','whiteOnly']
  if s['mode']!='none':
   lower=D(0) if legal or not s['clipLegal'] else D(64)/1023
   upper=D(1) if legal or not s['clipLegal'] else D(959)/1023
   if black:lo=max(lo,lower)
   if white:hi=min(hi,upper)
  if hdr is not None and not display:
   cap=exact(hdr) if legal else exact(hdr)*exact(.85630498533724)+exact(.06256109481916)
   hi=min(hi,cap)
  mapped=x if legal else (x*876+64)/1023
  return min(hi,max(lo,mapped))
 cases=[]
 for legal in [False,True]:
  for mode in ['none','both','blackOnly','whiteOnly']:
   for clip in [False,True]:
    for cb in [False,True]:
     for limits in [[0,67025937],[-1023,67025937],[64,1019],[0,1023],[1000,64]]:
      for hdr in [None,.6]:
       for display in [False,True]:
        s=settings(mode,clip,limits,cb);points=[-10,-1,-.1,-0.,0,.01,.18,.5,1,959/876,2,16,65519,1e100]
        cases.append({'settings':s,'outputRange':'video' if legal else 'data','hdrMaximumLegal':hdr,'displayConversionActive':display,
         'input':list(map(repr,points)),'output':[str(evaluate(exact(x),s,legal,hdr,display)) for x in points]})
 grids=[]
 for legal in [False,True]:
  s=settings('both',True,[-1023,67025937],False)
  for size in [33,65]:
   axis=[-.5+i/(size-1)*2.5 for i in range(size)];v=[float(evaluate(exact(x),s,legal,None,False)) for x in axis];binary=bytearray()
   for b in range(size):
    for g in range(size):
     for r in range(size):binary.extend(struct.pack('<3d',v[r],v[g],v[b]))
   name=f'final-output-independent-{("legal" if legal else "data")}{size}.f64';p=root/'tests/fixtures/native-contracts'/name
   if '--check' in sys.argv:assert p.read_bytes()==binary
   else:p.write_bytes(binary)
   grids.append({'settings':s,'outputRange':'video' if legal else 'data','size':size,'file':name,'sha256':hashlib.sha256(binary).hexdigest()})
 axis1024=[str(evaluate(exact(-.5+i/1023*2.5),settings('both',True,[-1023,67025937],False),False,None,False)) for i in range(1024)]
 output=json.dumps({'axis1024':axis1024,'precision':70,'sourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'cases':cases,'grids':grids},ensure_ascii=False,indent=2)+'\n'
p=root/'tests/fixtures/native-contracts/final-output-independent-reference.json'
if '--check' in sys.argv:assert p.read_text()==output;print('独立Final Output完整集合一致')
else:p.write_text(output);print('已生成独立Final Output完整集合')
