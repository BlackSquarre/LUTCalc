"""以70位Decimal及独立Hermite基函数验证旧Knee数学；不读取旧实现或旧结果。"""
from pathlib import Path
from decimal import Decimal, localcontext
import hashlib, json, math, sys
ROOT=Path(__file__).resolve().parents[2]
def d(x): return Decimal.from_float(float(x))
def hermite(p,q,u,v,t):
    return (2*t**3-3*t**2+1)*p+(t**3-2*t**2+t)*u+(-2*t**3+3*t**2)*q+(t**3-t**2)*v
with localcontext() as ctx:
    ctx.prec=70
    ln2=Decimal(2).ln()
    def f(stop): return (d(stop)*ln2).exp()/5*d(.9)
    def prepare(start,clip,slope,smooth,legal):
        j=8.
        maximum=None
        while j>0:
            if f(j)<=d(.95): maximum=j;break
            j-=.1
        start=min(start,maximum or 0.)
        r=d(clip)-d(start);p=f(start);q=d(.99) if legal else d(959)/d(876)-d(.01)
        u=(f(start+.001)-f(start-.001))*r/d(.002);v=d(slope)/100*r
        mid=hermite(p,q,u,v,d(.5))
        # The old finite difference omits the constant term. Algebraically it
        # cancels in high precision; this is an independent basis expression.
        deriv=(hermite(p,q,u,v,d(.501))-hermite(p,q,u,v,d(.499)))/d(.002)
        u/=2;deriv/=2;v/=2
        mid=min(mid,d(.1)*p+d(.9)*q);deriv=max(deriv,(q-mid)/d(.9));split=d(.5)
        a=2*p+u-2*mid+deriv;b=-3*p-2*u+3*mid-deriv;disc=b*b-3*a*u
        if disc>=0 and a!=0:
            roots=[(-b+disc.sqrt())/(3*a),(-b-disc.sqrt())/(3*a)]
            if any(0<t<1 for t in roots):
                mid=d(.1)*p+d(.9)*q;deriv=(mid-p)*d(1.29)/d(6.59);split=d(10.89)*deriv/(d(1.29)*u)
        threshold=(d(start)*ln2).exp()*d(.2)
        def evaluate(x,normal):
            if x<threshold:return normal
            stop=(x/d(.2)).ln()/ln2
            if stop>=d(clip):return q+(stop-d(clip))*d(slope)/100
            t=(stop-d(start))/r
            if t<split:
                cubic=hermite(p,mid,u/(2*(1-split)),deriv/(2*(1-split)),t/split)
            else:
                cubic=hermite(mid,q,deriv/(2*split),v/(2*split),(t-split)/(1-split))
            return cubic*d(smooth)+(p*(1-t)+q*t)*(1-d(smooth))
        return start,clip,evaluate
    cases=[]
    for start,clip,slope,smooth,legal in [(.05,6,.25,1,True),(-5,.05,0,0,True),(-2,4,1,.35,False),(4,8,2.5,1,True)]:
        effective,_,evaluate=prepare(start,clip,slope,smooth,legal)
        xs=[-2.,-0.,0.,.2,.2*2**effective,.2*2**clip]
        xs += [.2*2**(effective+(clip-effective)*i/64) for i in range(129)]
        cases.append({'settings':{'algorithm':'lutcalc.knee-output-hermite.v1','enabled':True,'startStops':start,'clipStops':clip,
            'clipSlope':slope,'smoothness':smooth,'legal':legal},
            'probes':[{'input':repr(x),'encoded':str(d(x)*d(.9)),'output':str(evaluate(d(x),d(x)*d(.9)))} for x in xs]})
    _,_,evaluate=prepare(-2,4,1,.35,False)
    axes=[]
    for size in [33,65]:
        xs=[-.5+i/(size-1)*32.5 for i in range(size)]
        axes.append({'size':size,'minimum':-.5,'maximum':32.,'inputs':[repr(x) for x in xs],
            'outputs':[str(evaluate(d(x)/d(.9),d(x))) for x in xs]})
    output=json.dumps({'precision':70,'sourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'cases':cases,'gridAxes':axes},ensure_ascii=False,indent=2)+'\n'
target=ROOT/'tests/fixtures/native-contracts/knee-independent-reference.json'
if '--check' in sys.argv:
    assert target.read_text()==output
    print('独立Knee 540标量点及33³/65³轴参照一致')
else:target.write_text(output);print('已生成独立Knee 70位Decimal参照')
