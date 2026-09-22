'use strict';
// Run with node --test tests/dlog2.test.js (no npm dependencies).
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const ref = require('./fixtures/dlog2-reference.json');
const read = f => fs.readFileSync(path.join(root, 'js', f), 'utf8');
function context(files) {
  const c = vm.createContext({Float64Array, Float32Array, Int8Array, Int16Array,
    Uint8Array, Uint16Array, ArrayBuffer, console, addEventListener() {}, postMessage() {}});
  for (const f of files) vm.runInContext(read(f), c, {filename:f});
  return c;
}
const c = context(['lut.js','ring.js','bounding.js','brent.js','gamma.js','colourspace.js']);
const ga = new c.LUTGamma(), cs = new c.LUTColourSpace();
const idx = ga.gammas.findIndex(g => g.name === 'DJI D-Log2'), g = ga.gammas[idx];
const near = (a,b,eps=2e-12) => assert.ok(Math.abs(a-b) <= eps*Math.max(1,Math.abs(b)), `${a} != ${b}`);
const matrix = (a,b,eps) => a.forEach((v,i) => near(v,b[i],eps));
test('DJI CTL reference, negative signals, both joins and HDR headroom', () => {
  for (const [signal, linear] of ref.decode) near(g.linFromData(signal)*0.9,linear);
  near(g.linToData(0),64/1023);
  near(g.linToData(0.2),0.304985337243402);
  near(g.linFromData(1)*0.9,475);
});
test('all 10-bit values round trip, monotonicity, data/legal and vector/scalar parity', () => {
  for (const range of ['Data','Legal']) {
    const inputs = Float64Array.from({length:1024},(_,i)=>i/1023);
    const decoded = inputs.slice();
    g[range==='Data'?'linFromD':'linFromL'](decoded.buffer);
    for(let i=0;i<inputs.length;i++) {
      near(decoded[i],g['linFrom'+range](inputs[i]));
      near(g['linTo'+range](decoded[i]),inputs[i]);
      if(i) assert.ok(decoded[i]>decoded[i-1]);
    }
    g[range==='Data'?'linToD':'linToL'](decoded.buffer);
    matrix(decoded,inputs);
  }
  for (const linear of [-1,0,0.028961695254132/0.9,0.2,1,100,475/0.9]) {
    near(g.linFromLegal(g.linToLegal(linear)),linear);
    near(g.linToLegal(linear),(g.linToData(linear)*1023-64)/876);
  }
});
test('D-Gamut2 chromaticities and CAT02 ACES transform match independent CTL calculation', () => {
  const gamut = cs.g.find(x=>x.name==='DJI D-Gamut2');
  matrix(gamut.toXYZ,ref.toXYZ);
  const m = cs.mMult(cs.fromSys('ACES AP0').m,cs.toSys('DJI D-Gamut2').m);
  matrix(m,ref.toAP0);
  // DCTL rounds three constituent matrices to four decimals; not an exact oracle.
  matrix(m,ref.roundedDctlToAP0,1.1e-4);
  matrix(cs.mMult(cs.fromSys('DJI D-Gamut2').m,cs.toSys('DJI D-Gamut2').m),[1,0,0,0,1,0,0,0,1]);
  for(let row=0;row<3;row++) near(m[row*3]+m[row*3+1]+m[row*3+2],1);
});
test('input/output lists, manufacturer filters and default gamut/range are wired', () => {
  for(const list of [ga.inList,ga.outList]) assert.ok(list.some(x=>x.idx===idx));
  assert.ok(ga.gammaSub[idx].includes(ga.subIdx('DJI')));
  assert.equal(ga.gammaDat[idx],true);
  assert.equal(ga.gts[idx],'DJI D-Gamut2');
  for(const dir of ['In','Out']) {
    const i=cs['cs'+dir].findIndex(x=>x.name==='DJI D-Gamut2');
    assert.ok(i>=0); assert.ok(cs['cs'+dir+'Sub'][i].includes(cs.subIdx('DJI')));
  }
});
test('1D generation preserves D-Log2 identity on data and legal paths', () => {
  ga.curIn=idx; ga.curOut=idx; ga.clipB=false; ga.clipW=false; ga.bClip=-1e9; ga.wClip=1e9;
  for(const legal of [false,true]) {
    ga.inL=legal; ga.outL=legal;
    const result=ga.oneDCalc(0,1,{start:0,vals:1024,dim:1024});
    const values=new Float64Array(result.o);
    assert.equal(values.length,3072);
    values.forEach((v,i)=>near(v,Math.floor(i/3)/1023));
  }
});
test('33 cubed RGB pipeline survives wide-gamut round trip including negative channels', () => {
  ga.inL=false; ga.outL=false; ga.curIn=idx; ga.curOut=idx;
  const forward=cs.mMult(cs.fromSys('ACES AP0').m,cs.toSys('DJI D-Gamut2').m);
  const inverse=cs.mInverse(forward);
  for(let b=0;b<33;b++) {
    const decoded=ga.inCalcRGB(0,3,{R:0,G:0,B:b,vals:33*33,dim:33});
    const data=new Float64Array(decoded.o);
    const apply=m=>{ for(let i=0;i<data.length;i+=3) {
      const [r,g,b]=data.slice(i,i+3);
      for(let k=0;k<3;k++) data[i+k]=m[k*3]*r+m[k*3+1]*g+m[k*3+2]*b;
    }};
    apply(forward); apply(inverse);
    const out=new Float64Array(ga.outCalcRGB(0,4,decoded).o);
    for(let j=0;j<33*33;j++) {
      near(out[j*3],j%33/32,2e-10); near(out[j*3+1],Math.floor(j/33)/32,2e-10); near(out[j*3+2],b/32,2e-10);
    }
  }
});
test('external and inline worker engines contain working D-Log2 and D-Gamut2', () => {
  const external=context(['gammaworkerscombined.js','colourspaceworkerscombined.js']);
  near(new external.LUTGamma().gammas.find(x=>x.name==='DJI D-Log2').linToData(.2),g.linToData(.2));
  assert.ok(new external.LUTColourSpace().toSys('DJI D-Gamut2'));
  const inline=context([]);
  vm.runInContext(c.workerLUTString+c.workerGammaString,inline);
  vm.runInContext(c.workerRingString+c.workerBrentString+c.workerCSString,inline);
  near(inline.lutGammaWorker.gammas.gammas.find(x=>x.name==='DJI D-Log2').linToData(.2),g.linToData(.2));
  assert.ok(new inline.LUTColourSpace().toSys('DJI D-Gamut2'));
});
test('shipped main and fallback bundles contain exact current source', () => {
  for(const [source,bundles] of [['gamma.js',['lutcalccombined.js','gammaworkerscombined.js']],['colourspace.js',['lutcalccombined.js','colourspaceworkerscombined.js']]])
    for(const bundle of bundles) assert.equal(read(bundle).split(read(source)).length,2);
});
test('real gamma -> color -> gamma pipeline exports a finite identity cube', () => {
  vm.runInContext(read('lut-cube.js'),c);
  const engine = new c.LUTGamma(), color = new c.LUTColourSpace();
  engine.curIn=idx; engine.curOut=idx;
  engine.inL=false; engine.outL=false; engine.clip=false;
  engine.bClip=-1e9; engine.wClip=1e9;
  color.curIn=color.csIn.findIndex(x=>x.name==='DJI D-Gamut2');
  color.curOut=color.csOut.findIndex(x=>x.name==='DJI D-Gamut2');
  const dim=33, cube=new Float64Array(dim**3*3);
  for(let b=0;b<dim;b++) {
    const decoded=engine.inCalcRGB(0,3,{R:0,G:0,B:b,vals:dim*dim,dim});
    const converted=color.calc(0,1,decoded,true);
    cube.set(new Float64Array(engine.outCalcRGB(0,4,converted).o),b*dim*dim*3);
  }
  const writer=new c.cubeLUT({getPrecision:()=>10,getInfo(info){Object.assign(info,{
    name:'DLog2 identity test',dimension:dim,oneD:false,inGammaName:'DJI D-Log2',
    outGammaName:'DJI D-Log2',inGamutName:'DJI D-Gamut2',outGamutName:'DJI D-Gamut2',
    cineEI:0,blackLevel:0,legalIn:false,legalOut:false,version:'test',date:'2026-09-22'
  });}},true,0);
  const text=writer.build(cube.buffer,'DLog2-test','cube').lut;
  assert.match(text,/LUT_3D_SIZE 33/);
  assert.match(text,/DJI D-Log2\/DJI D-Gamut2 -> DJI D-Log2\/DJI D-Gamut2/);
  const rows=text.split('\n').filter(s=>/^[-.\d]/.test(s)).map(s=>s.split(' ').map(Number));
  assert.equal(rows.length,dim**3);
  rows.forEach(([r,g,b],i)=>{
    near(r,i%dim/(dim-1),1e-9);
    near(g,Math.floor(i/dim)%dim/(dim-1),1e-9);
    near(b,Math.floor(i/(dim*dim))/(dim-1),1e-9);
  });
});
