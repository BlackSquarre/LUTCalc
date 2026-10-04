'use strict';
// Research-only actual two-stage limiter, never shipped with the product.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({console,addEventListener(){},postMessage(){}}),sourceSHA256={};
for(const name of ['lut.js','ring.js','bounding.js','brent.js','gamma.js','colourspace.js']){
 const src=fs.readFileSync(path.join(root,'js',name),'utf8');sourceSHA256[name]=crypto.createHash('sha256').update(src).digest('hex');vm.runInContext(src,c,{filename:name});
}
const color=new c.LUTColourSpace(),gamma=new c.LUTGamma();color.tweaks=true;gamma.nul=false;
gamma.doKnee=gamma.doBlkHi=gamma.doBlkGam=gamma.doDisplay=false;
const cases=[];
for(const base of ['Rec2020','Rec709'])for(const secondary of [null,'Rec709','Rec2020'])for(const both of [true,false])for(const linear of [true,false]){
 color.curOut=color.csOut.findIndex(v=>v.name===base);
 const level=linear?2**-1:.85;
 color.setGamutLim({twkGamutLim:{doGamutLim:true,lin:linear,level,...(secondary?{gamut:secondary,both}:{})}});
 gamma.curOut=gamma.gammas.findIndex(v=>v.name==='Rec709');
 const xs=[[-2,-1,-.5],[0,0,0],[.2,.2,.2],[2,2,2],[2,0,0],[0,2,0],[0,0,2],[.5,0,0],[.5*(1+Number.EPSILON),0,0],[5,-2,1]];
 for(let i=0;i<64;i++)xs.push([i%7/2-.5,i%11/3-1,i%13/4-.75]);
 const probes=xs.map(x=>{
  const values=Float64Array.from(x),out={to:[]};color.gamutLimOut(values.buffer,out);
  const stage12=Array.from(values,String),secondary12=out.og?Array.from(new Float64Array(out.og),String):null;
  if(!linear){gamma.gammas[gamma.curOut].linToL(values.buffer,{rgb:true});gamma.gamutLimOut(values.buffer,out.gLimY,out.gLimL,out.og,out.gLimB);}
  return {input:x.map(String),stage12,secondary12,output:Array.from(values,String)};
 });
 cases.push({base,secondary,both,linear,linearStops:-1,postLevel:.85,luma:Array.from(color.gLimY,String),probes});
}
// Encoded-kernel probes separate from gamma preparation, with explicit
// alternate values and negative channels to verify secondary is not clamped.
const encoded=[];gamma.doKnee=gamma.doBlkHi=gamma.doBlkGam=gamma.doDisplay=false;
gamma.curOut=gamma.gammas.findIndex(v=>v.name==='Scene Reflectance');
for(const both of [true,false])for(const secondary of [null,[-.5,1.5,.25],[2,2,2]]){
 const primary=[-.5,1.5,.25],v=Float64Array.from(primary),og=secondary?Float64Array.from(secondary.map(x=>x/.9)):undefined;
 const y=[.2627002120112671,.6779980715188708,.05930171646986195];
 gamma.gamutLimOut(v.buffer,y,.85,og?.buffer,both);
 encoded.push({primary,secondary,both,luma:y,level:.85,output:Array.from(v,String)});
}
const output=JSON.stringify({sourceSHA256,cases,encoded},null,2)+'\n',target=path.join(root,'tests/fixtures/native-contracts/gamut-limiter-legacy-reference.json');
if(process.argv.includes('--check')){if(fs.readFileSync(target,'utf8')!==output)throw new Error('Limiter legacy changed');console.log('旧Gamut Limiter '+cases.length+'组/'+cases.reduce((n,v)=>n+v.probes.length*3,0)+'通道与独立编码分支一致');}
else{fs.writeFileSync(target,output);console.log('已冻结旧Gamut Limiter '+cases.length+'组');}
