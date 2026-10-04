'use strict';
// Research-only exact legacy adjustment paths for the omitted Data wrappers.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({console,addEventListener(){},postMessage(){}}),sourceSHA256={};
for(const name of ['lut.js','ring.js','bounding.js','brent.js','gamma.js','colourspace.js']){
 const src=fs.readFileSync(path.join(root,'js',name),'utf8');sourceSHA256[name]=crypto.createHash('sha256').update(src).digest('hex');vm.runInContext(src,c,{filename:name});
}
const e=new c.LUTGamma(),entries=[['CIE L*','cie.l-star.v1'],['ProPhoto / ROMM','romm.prophoto.v1'],
 ['BBC 0.4','bbc.gamma-0-4.v1'],['BBC 0.5','bbc.gamma-0-5.v1'],['BBC 0.6','bbc.gamma-0-6.v1'],
 ['BBC WHP283 (400%)','bbc.whp283-400.v1'],['BBC WHP283 (800%)','bbc.whp283-800.v1']];
for(let k=15;k<=26;k++)entries.push(['γ'+(k/10).toFixed(1),'gamma.'+Math.floor(k/10)+'-'+k%10+'.v1']);
e.tweaks=true;e.nul=e.outL=e.hdrOut=e.clip=false;e.bClip=-Infinity;e.wClip=Infinity;e.doASCCDL=e.doBlkGam=e.doDisplay=false;
const cases=[],color=new c.LUTColourSpace();color.tweaks=true;color.curOut=color.csOut.findIndex(x=>x.name==='Rec2020');
for(const [name,transfer] of entries)for(const [levels,knee,limiter,secondary,both,blackGamma] of [[true,false,false,false,true,false],[false,true,false,false,true,false],[false,false,true,false,true,false],[true,true,true,false,true,false],[true,true,true,true,true,true],[true,true,true,true,false,true]]){
 e.curOut=e.gammas.findIndex(v=>v.name===name);if(e.curOut<0)throw new Error('Missing '+name);
 e.doKnee=e.doBlkHi=e.doBlkGam=false;e.changedOut=e.changedASCCDL=e.changedHDR=false;e.highRef=.9;
 e.setKnee({twkKnee:{doKnee:knee,kneeStart:-2,kneeClip:4,clipSlope:1,smoothness:.35,legal:false}});
 e.setBlkHi({twkBlkHi:{doBlkHi:levels,doBlack:true,doHigh:true,blackLevel:.05,blackLock:true,highMap:.85,highLock:true,highRef:.9}});
 if(blackGamma)e.setBlkGam({twkBlkGam:{doBlkGam:true,upperLim:0,feather:2,power:.5}});
 color.setGamutLim({twkGamutLim:{doGamutLim:limiter,lin:false,level:.6,...(secondary?{gamut:'Rec709',both}:{})}});
 const points=[[-.5,-.25,-.01],[0,0,0],[.18,.18,.18],[.9,.9,.9],[2,0,0],[0,2,0],[0,0,2],[8,1,-.1]];
 for(let i=0;i<64;i++)points.push([i%7/2-.5,i%11/3-1,i%13/4-.75]);
 const probes=points.map(input=>{
  const values=Float64Array.from(input,x=>x/.9);
  const payload={o:values.buffer,to:[],doGamutLim:false};
  if(limiter)color.gamutLimOut(values.buffer,payload);
  e.outCalcRGB(0,4,payload);
  return {inputScene:input.map(String),outputData:Array.from(values,String)};
 });
 cases.push({transfer,levels,knee,limiter,secondary,both,blackGamma,probes});
}
const output=JSON.stringify({sourceSHA256,cases},null,2)+'\n',target=path.join(root,'tests/fixtures/native-contracts/output-code-units-legacy-reference.json');
if(process.argv.includes('--check')){if(fs.readFileSync(target,'utf8')!==output)throw new Error('Output units legacy changed');console.log('旧19曲线/114组/24624通道Knee、黑白电平、Post Limiter参照一致');}
else{fs.writeFileSync(target,output);console.log('已生成旧19曲线/114组/24624通道');}
