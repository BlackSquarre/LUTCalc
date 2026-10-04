'use strict';
// Research-only actual setFC -> FCOut -> fcOut, with no finalOut clipping.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({console,addEventListener(){},postMessage(){}}),sourceSHA256={};
for(const name of ['lut.js','ring.js','bounding.js','brent.js','gamma.js','colourspace.js']){
 const s=fs.readFileSync(path.join(root,'js',name),'utf8');sourceSHA256[name]=crypto.createHash('sha256').update(s).digest('hex');vm.runInContext(s,c,{filename:name});
}
const cs=new c.LUTColourSpace(),g=new c.LUTGamma();cs.tweaks=true;
function next(x,dir){if(x===0)return dir>0?Number.MIN_VALUE:-Number.MIN_VALUE;const a=new Float64Array([x]),b=new BigUint64Array(a.buffer);b[0]+=BigInt((x>0)===(dir>0)?1:-1);return a[0];}
const cases=[];
for(const values of [[6.1,.5,6],[null,null,null],[10,3,3.5]])for(let bits=0;bits<128;bits++){
 const fcs=Array.from({length:7},(_,i)=>Boolean(bits&(1<<i))),p={doFC:true,fcs};
 for(const [i,key] of ['blue','yellow','red'].entries())if(values[i]!==null)p[key]=values[i];
 cs.setFC({twkFC:p});
 const ys=[-10,-.5,0,.00001,.001,.1,.18,.2,.4,1,2,16,100];
 for(const t of cs.fcVals)if(t!==-10)ys.push(next(t,-1),t,next(t,1));
 const probes=ys.map(target=>{
  const work=[target/cs.y[0],0,0],y=cs.y[0]*work[0]+cs.y[1]*work[1]+cs.y[2]*work[2];
  const output=new Float64Array([-.125,.375,1.25]);let band=null;
  if(cs.doFC){const out={to:[]};cs.FCOut(Float64Array.from(work).buffer,out);band=new Uint8Array(out.fc)[0];g.fcOut(out.fc,output.buffer);}
  return {work:work.map(String),luma:String(y),band,output:Array.from(output,String)};
 });
 cases.push({settings:{algorithm:'lutcalc.false-colour-native-thresholds.v1',usage:'exportLUT',enabled:true,
   doPurple:fcs[0],doBlue:fcs[1],doGreen:fcs[2],doPink:fcs[3],doOrange:fcs[4],doYellow:fcs[5],doRed:fcs[6],
   blueStopsBelowGray:values[0],yellowStopsBelowClip:values[1],redStopsAboveGray:values[2]},active:cs.doFC,thresholds:Array.from(cs.fcVals,String),probes});
}
const output=JSON.stringify({sourceSHA256,luma:Array.from(cs.y,String),cases},null,2)+'\n';
const p=path.join(root,'tests/fixtures/native-contracts/false-colour-legacy-reference.json');
if(process.argv.includes('--check')){if(fs.readFileSync(p,'utf8')!==output)throw new Error('False Colour reference changed');console.log('旧False Colour '+cases.length+'组/'+cases.reduce((n,c)=>n+c.probes.length,0)+'分类一致');}
else{fs.writeFileSync(p,output);console.log('已冻结旧False Colour '+cases.length+'组');}
