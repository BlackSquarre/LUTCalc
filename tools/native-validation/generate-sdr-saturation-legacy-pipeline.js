'use strict';
// Research-only actual retained decode -> colourspace.calc(g=true) pipeline.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({console,addEventListener(){},postMessage(){}}),sourceSHA256={};
for(const name of ['lut.js','ring.js','bounding.js','brent.js','gamma.js','colourspace.js']) {
 const src=fs.readFileSync(path.join(root,'js',name),'utf8');
 sourceSHA256[name]=crypto.createHash('sha256').update(src).digest('hex');vm.runInContext(src,c,{filename:name});
}
const engine=new c.LUTGamma(),color=new c.LUTColourSpace();
engine.curIn=engine.gammas.findIndex(v=>v.name==='DJI D-Log2');engine.inL=false;engine.eiMult=2;
color.curIn=color.csIn.findIndex(v=>v.name==='DJI D-Gamut2');
color.curOut=color.csOut.findIndex(v=>v.name==='Rec2020');
if(Math.min(engine.curIn,color.curIn,color.curOut)<0)throw new Error('Registry ID missing');
color.nul=false;color.doFC=color.doWB=color.doPSSTCDL=color.doMulti=color.doHG=color.doGamutLim=false;
color.doASCCDL=color.doSDRSat=true;
color.asc=new Float64Array([1.25,.75,1.5,-.125,.0625,-.25,.5,1.25,2.5,.625]);color.sdrSatGamma=1.2;
const size=17,binary=Buffer.alloc(size**3*3*8);
for(let b=0;b<size;b++){
 const decoded=engine.inCalcRGB(0,3,{R:0,G:0,B:b,vals:size*size,dim:size});
 const converted=color.calc(0,1,decoded,true),values=new Float64Array(converted.o);
 for(let j=0;j<values.length;j++){
  if(!Number.isFinite(values[j]))throw new Error('Nonfinite pipeline reference');
  binary.writeDoubleLE(values[j]*.9,(b*size*size*3+j)*8);
 }
}
const metadata=JSON.stringify({sourceSHA256,source:'LUTGamma.inCalcRGB -> LUTColourSpace.calc(g=true), output legacy*.9 scene scale',
 size,order:'R-fast/G-middle/B-slow',input:'DLog2/DGamut2/Data',output:'Rec2020 scene-linear/Data',exposureGain:2,
 ascCDL:Array.from(color.asc),sdrGamma:color.sdrSatGamma,binarySHA256:crypto.createHash('sha256').update(binary).digest('hex')},null,2)+'\n';
const stem=path.join(root,'tests/fixtures/native-contracts/sdr-saturation-legacy-pipeline17');
if(process.argv.includes('--check')){
 if(!fs.readFileSync(stem+'.f64').equals(binary)||fs.readFileSync(stem+'.json','utf8')!==metadata)throw new Error('SDR legacy pipeline changed');
 console.log('旧输入解码/色域/曝光/CDL/SDR 17³全节点与源码哈希一致');
}else{fs.writeFileSync(stem+'.f64',binary);fs.writeFileSync(stem+'.json',metadata);console.log('已冻结4913节点旧生成流水线');}
