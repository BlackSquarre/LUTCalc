'use strict';
// Research-only retained PSST fixed sampling dependencies and neutral output.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({console,addEventListener(){},postMessage(){}}),sourceSHA256={};
for(const name of ['lut.js','ring.js','bounding.js','brent.js','gamma.js','colourspace.js']){
 const src=fs.readFileSync(path.join(root,'js',name),'utf8');sourceSHA256[name]=crypto.createHash('sha256').update(src).digest('hex');vm.runInContext(src,c,{filename:name});
}
const cs=new c.LUTColourSpace(),dependencies=[];
for(const name of ['psstF','psstB','psstY','psstM']){
 const d=cs[name].getDetails(),values=new Float64Array(d.L);
 dependencies.push({name,count:values.length,monotonic:d.p,periodRise:d.r,
  valuesSHA256:crypto.createHash('sha256').update(Buffer.from(d.L)).digest('hex'),first:values[0],last:values[values.length-1]});
}
const probes=[];
for(const input of [[0,0,0],[.2,.2,.2],[1,0,0],[0,1,0],[0,0,1],[.3,.4,.5],[-1,0,1],[2,4,8]]){
 const out=Float64Array.from(input);cs.PSSTCDLOut(out.buffer);
 probes.push({input,output:Array.from(out),maximumAbsoluteNeutralDifference:Math.max(...input.map((v,i)=>Math.abs(v-out[i])))});
}
const output=JSON.stringify({sourceSHA256,source:'initPSSTCDL -> PSSTCDLOut -> Ring cubic/linear',
 workingSpace:cs.system.name,luma:Array.from(cs.y),defaultChromaScale:cs.psstMC,defaultLumaScale:cs.psstYC,dependencies,probes},null,2)+'\n';
const target=path.join(root,'docs/native-validation/artifacts/2026-10-02-multitone/psst-fixed-rings-reproduction.json');
fs.writeFileSync(target,output);console.log('PSST固定环采样依赖和默认控制输出已保存，仅研发证据');
