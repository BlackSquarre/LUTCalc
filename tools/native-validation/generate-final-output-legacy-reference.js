'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({console,addEventListener(){},postMessage(){}}),sourceSHA256={};
for(const name of ['lut.js','ring.js','bounding.js','brent.js','gamma.js']){const s=fs.readFileSync(path.join(root,'js',name),'utf8');sourceSHA256[name]=crypto.createHash('sha256').update(s).digest('hex');vm.runInContext(s,c,{filename:name});}
const e=new c.LUTGamma();e.curOut=e.gammas.findIndex(v=>v.name==='Rec709');
const modes=['none','both','blackOnly','whiteOnly'],cases=[];
for(const outL of [false,true])for(const mode of modes)for(const clipLegal of [false,true])for(const cb of [false,true])
for(const limits of [[0,67025937],[-1023,67025937],[64,1019],[0,1023],[1000,64]])
for(const hdr of [null,0.6])for(const display of [false,true]){
 e.outL=outL;e.clip=mode!=='none';e.clipB=mode==='both'||mode==='blackOnly';e.clipW=mode==='both'||mode==='whiteOnly';e.clipL=clipLegal;
 e.bClip=limits[0];e.wClip=limits[1];e.hdrOut=hdr!==null;e.doDisplay=display;e.gammas[e.curOut].mxO=hdr;
 const input=[-10,-1,-.1,-0,0,.01,.18,.5,1,959/876,2,16,65519,1e100];
 const a=Float64Array.from(input);e.finalOut(a.buffer,cb);
 cases.push({settings:{algorithm:'lutcalc.final-output-code-limits.v1',enabled:true,mode,clipLegal,minimumCode10:limits[0],maximumCode10:limits[1],forceBlackLegal:cb},
  outputRange:outL?'video':'data',hdrOutputActive:hdr!==null,hdrMaximumLegal:hdr,displayConversionActive:display,input:input.map(String),output:Array.from(a,String)});
}
const output=JSON.stringify({sourceSHA256,cases},null,2)+'\n',p=path.join(root,'tests/fixtures/native-contracts/final-output-legacy-reference.json');
if(process.argv.includes('--check')){if(fs.readFileSync(p,'utf8')!==output)throw new Error('Final output changed');console.log('旧finalOut '+cases.length+'组一致');}
else{fs.writeFileSync(p,output);console.log('已冻结旧finalOut '+cases.length+'组');}
