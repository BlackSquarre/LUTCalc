'use strict';
// Verify fixture integrity and cross-check the synthetic interpolation oracle.
const fs=require('node:fs'), path=require('node:path'), vm=require('node:vm'), crypto=require('node:crypto'), assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'), base=path.join(root,'tests/fixtures/native-contracts');
for(const [file,hash] of Object.entries(JSON.parse(fs.readFileSync(path.join(base,'sha256.json')))))
  assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(base,file))).digest('hex'),hash,file);
const f=JSON.parse(fs.readFileSync(path.join(base,'numeric-contracts.json')));
const c=vm.createContext({Float64Array,Float32Array,Int8Array,Int16Array,Uint8Array,Uint16Array,ArrayBuffer,console,addEventListener(){},postMessage(){}});
for(const file of ['lut.js','ring.js','bounding.js','brent.js','colourspace.js'])vm.runInContext(fs.readFileSync(path.join(root,'js',file),'utf8'),c);
const lut=new c.LUTs().newLUT({dims:3,s:2,min:[0,0,0],max:[1,1,1],C:[0,1,2].map(channel=>Float64Array.from(f.interpolation.vertices,v=>v.value[channel]).buffer)});
const near=(a,b)=>assert.ok(Math.abs(a-b)<=2e-12*Math.max(1,Math.abs(b)),`${a} != ${b}`);
let checks=0;
for(const test of [...f.interpolation.cases,f.interpolation.tie])for(const [method,key] of [['RGBTet','tetrahedral'],['RGBLin','trilinear']]) {
 const v=Float64Array.from(test.point);lut[method](v.buffer);v.forEach((a,i)=>near(a,test[key][i]));checks++;
}
const cs=new c.LUTColourSpace();
Array.from(cs.mMult(f.matrix.rowMajor,f.matrix.input)).forEach((v,i)=>near(v,f.matrix.output[i]));
Array.from(cs.mInverse(f.matrix.rowMajor)).forEach((v,i)=>near(v,f.matrix.inverseRowMajor[i]));
const report={date:'2026-09-23',status:'passed',interpolationCases:checks,matrixCases:2,fixtureHashesVerified:true,scope:'有理数预期值与旧引擎的域内合成插值/矩阵交叉检查；不是 Swift 实现验证、解析器验收或全部精度证明'};
const p=path.join(root,'research/native-handoff/2026-09-23/fixture-verification.json');fs.writeFileSync(p,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
