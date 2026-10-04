'use strict';
// Research-only actual HGOut; all registered sample-based outputs excluded.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({console,addEventListener(){},postMessage(){}}),sourceSHA256={};
for(const name of ['lut.js','ring.js','bounding.js','brent.js','gamma.js','colourspace.js']){
 const src=fs.readFileSync(path.join(root,'js',name),'utf8');sourceSHA256[name]=crypto.createHash('sha256').update(src).digest('hex');vm.runInContext(src,c,{filename:name});
}
const e=new c.LUTColourSpace();e.tweaks=true;
const pairs=[['Rec2020','Rec709','rec2020','rec709.srgb'],['Rec709','Rec2020','rec709.srgb','rec2020'],
 ['Rec2020','Rec2020','rec2020','rec2020']];
const cases=[];
for(const [base,high,baseKey,highKey] of pairs)for(const linear of [true,false])for(const [low,upper] of [[0,2.3219],[-5,1],[2,6]]){
 e.curOut=e.csOut.findIndex(x=>x.name===base);const idx=e.csOut.findIndex(x=>x.name===high);
 if(e.curOut<0||idx<0)throw new Error('Registry missing '+base+'/'+high);
 if(!e.csOut[e.curOut].isMatrix()||!e.csOut[idx].isMatrix())throw new Error('Not an analytic matrix');
 e.setHG({twkHG:{doHG:true,gamut:idx,lin:linear,low,high:upper}});
 const xs=[[-1,-2,-3],[0,0,0],[1,0,0],[0,1,0],[0,0,1],[4,-2,1],[2,3,4]];
 for(const y of [e.hgLow*(1-Number.EPSILON),e.hgLow,e.hgLow*(1+Number.EPSILON),e.hgHigh*(1-Number.EPSILON),e.hgHigh,e.hgHigh*(1+Number.EPSILON)])xs.push([y,y,y]);
 for(let i=0;i<64;i++)xs.push([i%7/2-.5,i%11/3-1,i%13/4-.75]);
 const probes=xs.map(x=>{
  const lc=Float64Array.from(x),lf=Float64Array.from(x);e.HGOut(lc.buffer,true);e.HGOut(lf.buffer,false);
  for(let k=0;k<3;k++)if(lc[k]!==lf[k])throw new Error('Matrix lc/lf mismatch');
  return {input:x.map(String),output:Array.from(lc,String)};
 });
 cases.push({base,high,baseKey,highKey,linear,low,upper,workingLuma:Array.from(e.y,String),probes});
}
const output=JSON.stringify({sourceSHA256,cases},null,2)+'\n',target=path.join(root,'tests/fixtures/native-contracts/highlight-gamut-legacy-reference.json');
if(process.argv.includes('--check')){if(fs.readFileSync(target,'utf8')!==output)throw new Error('HG legacy changed');console.log('旧Highlight Gamut '+cases.length+'组/'+cases.reduce((n,v)=>n+v.probes.length*3,0)+'通道及lc/lf矩阵一致');}
else{fs.writeFileSync(target,output);console.log('已冻结旧Highlight Gamut '+cases.length+'组');}
