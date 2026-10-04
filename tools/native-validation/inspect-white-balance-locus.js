'use strict';
// Research-only minimal reproduction of the retained sampled Planck dependency.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const c=vm.createContext({console,addEventListener(){},postMessage(){}}),sourceSHA256={};
for(const name of ['lut.js','ring.js','bounding.js','brent.js','gamma.js','colourspace.js']) {
 const source=fs.readFileSync(path.join(root,'js',name),'utf8');
 sourceSHA256[name]=crypto.createHash('sha256').update(source).digest('hex');
 vm.runInContext(source,c,{filename:name});
}
const cs=new c.LUTColourSpace(),probes=[];
for(const t of [100,1000,3200,5500,6500,10000,50100]) {
 probes.push({temperature:t,XYZ:Array.from(cs.planck.XYZ(t)),uv:Array.from(cs.planck.uv(t))});
}
const adjustments=[];
for(const shifts of [[0,0,0,0],[100,0,0,0],[0,0,0.5,0],[0,100,0.5,-0.5],[-500,-300,0,0]]) {
 cs.wb.setVals(5500,...shifts);
 adjustments.push({ctMired:shifts[0],lampMired:shifts[1],duv:shifts[2],dpl:shifts[3],base:cs.wb.base,
  ct:cs.wb.ct,lamp:cs.wb.lamp,matrix:Array.from(cs.wb.N)});
}
const output=JSON.stringify({sourceSHA256,dependency:'Planck.setLoci creates 501-point RGB spline table; XYZ/uv/Duv/CCT all read it',
 workingSpace:cs.system.name,systemCCT:cs.wb.CCT0,probes,adjustments},null,2)+'\n';
const target=path.join(root,'docs/native-validation/artifacts/2026-10-02-sdr-saturation/white-balance-locus-reproduction.json');
fs.writeFileSync(target,output);console.log('旧白平衡轨迹依赖与五组参数最小复现已保存，仅研发证据');
