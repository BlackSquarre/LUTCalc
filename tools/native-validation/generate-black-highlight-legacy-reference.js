'use strict';
// Research-only actual setBlkHi/blkHiOut, with exact numeric fixture strings.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({console,addEventListener(){},postMessage(){}}),sourceSHA256={};
for(const name of ['lut.js','ring.js','bounding.js','brent.js','gamma.js']){
 const src=fs.readFileSync(path.join(root,'js',name),'utf8');sourceSHA256[name]=crypto.createHash('sha256').update(src).digest('hex');vm.runInContext(src,c,{filename:name});
}
const e=new c.LUTGamma(),names=e.gammas.map(g=>g.name);e.tweaks=true;e.doASCCDL=e.doKnee=false;e.nul=false;
const variants=['Rec709','DJI D-Log2',names.includes('Sony S-Log3')?'Sony S-Log3':'S-Log3','Scene Reflectance'];
const cases=[],changes=[];
for(const name of variants){
 e.curOut=names.indexOf(name);if(e.curOut<0)throw new Error('Missing '+name);
 for(const p of [
 {doBlack:true,doHigh:true},
 {doBlack:true,doHigh:false,blackLevel:.025,blackLock:true},
 {doBlack:false,doHigh:true,highMap:.85,highLock:true},
 {doBlack:true,doHigh:true,blackLevel:.05,highMap:.85},
 {doBlack:true,doHigh:true,blackLevel:.5,blackLock:true,highMap:.1,highLock:true},
 {doBlack:true,doHigh:true,blackLevel:.025,blackLock:true,highMap:.91,highLock:true,highRef:.72}
 ]){
  e.highRef=p.highRef??.9;e.changedOut=e.changedASCCDL=e.changedHDR=false;
  const out=e.setBlkHi({twkBlkHi:{doBlkHi:true,...p}});
  const settings={algorithm:'lutcalc.black-highlight-legal-affine.v1',enabled:true,doBlack:p.doBlack,doHigh:p.doHigh,
   blackLock:p.blackLock??false,highLock:p.highLock??false,highReferenceScene:p.highRef??.9};
  if(p.blackLevel!==undefined)settings.blackLevel=p.blackLevel;
  if(p.highMap!==undefined)settings.highMap=p.highMap;
  const xs=[-2,-0.0,0,.18,1,2,20,out.blackDef,out.highDef];
  for(let i=0;i<=64;i++)xs.push(out.blackDef+(out.highDef-out.blackDef)*i/64);
  cases.push({name,settings,defaults:[String(out.blackDef),String(out.highDef)],probes:xs.map(input=>{
   const values=new Float64Array([input]);e.blkHiOut(values.buffer);return {input:String(input),output:String(values[0])};})});
 }
 for(const changed of ['changedOut','changedASCCDL','changedHDR','changedRef']){
  for(const lock of [false,true]){
   e.highRef=.9;e.changedOut=e.changedASCCDL=e.changedHDR=false;
   if(changed!=='changedRef')e[changed]=true;
   const out=e.setBlkHi({twkBlkHi:{doBlkHi:true,doBlack:true,doHigh:true,blackLevel:.05,highMap:.85,blackLock:lock,highLock:lock,highRef:changed==='changedRef'?.72:.9}});
   changes.push({name,changed,lock,blackDefault:String(out.blackDef),highDefault:String(out.highDef),blackMap:String(out.blackLevel),highMap:String(out.highMap)});
  }
 }
}
const result={sourceSHA256,cases,changes},output=JSON.stringify(result,null,2)+'\n';
const target=path.join(root,'tests/fixtures/native-contracts/black-highlight-legacy-reference.json');
if(process.argv.includes('--check')){if(fs.readFileSync(target,'utf8')!==output)throw new Error('Black Highlight legacy changed');console.log('旧黑白电平24组/1776点与32组默认值重置、源码哈希一致');}
else{fs.writeFileSync(target,output);console.log('已冻结旧黑白电平 '+cases.reduce((n,v)=>n+v.probes.length,0)+'点');}
