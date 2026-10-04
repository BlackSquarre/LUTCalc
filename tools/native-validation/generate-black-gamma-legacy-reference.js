'use strict';
// Research-only actual retained preparation and scalar kernel.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({console,addEventListener(){},postMessage(){}}),sourceSHA256={};
for(const name of ['lut.js','ring.js','bounding.js','brent.js','gamma.js']){
 const src=fs.readFileSync(path.join(root,'js',name),'utf8');sourceSHA256[name]=crypto.createHash('sha256').update(src).digest('hex');vm.runInContext(src,c,{filename:name});
}
const e=new c.LUTGamma();e.tweaks=true;e.doASCCDL=e.doKnee=e.doBlkHi=false;
const variants=[['Rec709','rec709.lutcalc-legacy.v1'],['DJI D-Log2','dji.dlog2.v1'],['S-Log3','slog3.lutcalc-legacy.v1']];
// Select actual registry spelling rather than silently substituting a variant.
const names=e.gammas.map(g=>g.name);
variants[0][0]=names.find(n=>n==='Rec709')||names.find(n=>n==='Rec709 (800%)');
variants[2][0]=names.find(n=>n==='Sony S-Log3')||names.find(n=>n==='S-Log3');
function adjacent(value,direction){
 const b=Buffer.alloc(8);b.writeDoubleLE(value);
 if(value===0)return direction>0 ? Number.MIN_VALUE : -Number.MIN_VALUE;
 let bits=b.readBigUInt64LE();bits += ((value>0)===(direction>0)) ? 1n : -1n;
 b.writeBigUInt64LE(bits);return b.readDoubleLE();
}
const cases=[];
for(const [name,nativeTransfer] of variants){
 e.curOut=names.indexOf(name);if(e.curOut<0)throw new Error('Missing registry '+name);
 for(const [upperStops,featherStops,power] of [[-1.5,2,.5],[0,2,2],[-9,0,10],[2,9,.01]]){
  e.setBlkGam({twkBlkGam:{doBlkGam:true,upperLim:upperStops,feather:featherStops,power}});
  const anchors=[e.blkLevel,e.blkGamLL,e.blkGamUL],xs=[-2,-0.0,0,1,2,30];
  for(const a of anchors)xs.push(a,a-1e-10,a+1e-10,adjacent(a,-1),adjacent(a,1));
  for(let i=0;i<=64;i++)xs.push(e.blkLevel+(e.blkGamUL-e.blkLevel)*i/64);
  const affine = nativeTransfer==='dji.dlog2.v1' ? [876/1023,64/1023]
    : nativeTransfer==='slog3.lutcalc-legacy.v1' ? [0.85630498533724,0.06256109481916] : [1,0];
  cases.push({name,nativeTransfer,upperStops,featherStops,power,anchors:anchors.map(String),
   nativeAnchors:anchors.map(v=>String(v*affine[0]+affine[1])),probes:xs.map(input=>{
   const v=new Float64Array([input]);e.blkGamOut(v.buffer);return {input:String(input),output:String(v[0])};})});
 }
}
const output=JSON.stringify({sourceSHA256,cases},null,2)+'\n',target=path.join(root,'tests/fixtures/native-contracts/black-gamma-legacy-reference.json');
if(process.argv.includes('--check')){if(fs.readFileSync(target,'utf8')!==output)throw new Error('Black Gamma reference changed');console.log('旧Black Gamma阈值准备与1032点（含相邻IEEE754边界）、源码哈希一致');}
else{fs.writeFileSync(target,output);console.log('已冻结旧Black Gamma '+cases.reduce((n,v)=>n+v.probes.length,0)+'点');}
