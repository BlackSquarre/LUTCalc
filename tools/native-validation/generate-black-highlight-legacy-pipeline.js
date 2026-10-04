'use strict';
// Research-only available chain including setBlkHi -> setBlkGam dependency.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({console,addEventListener(){},postMessage(){}}),sourceSHA256={};
for(const name of ['lut.js','ring.js','bounding.js','brent.js','gamma.js','colourspace.js']){
 const src=fs.readFileSync(path.join(root,'js',name),'utf8');sourceSHA256[name]=crypto.createHash('sha256').update(src).digest('hex');vm.runInContext(src,c,{filename:name});
}
const engine=new c.LUTGamma(),color=new c.LUTColourSpace();
engine.curIn=engine.gammas.findIndex(v=>v.name==='DJI D-Log2');engine.inL=false;engine.eiMult=2;
color.curIn=color.csIn.findIndex(v=>v.name==='DJI D-Gamut2');color.curOut=color.csOut.findIndex(v=>v.name==='Rec2020');
if(Math.min(engine.curIn,color.curIn,color.curOut)<0)throw new Error('Registry ID missing');
color.nul=false;color.doFC=color.doWB=color.doPSSTCDL=color.doHG=color.doGamutLim=false;
color.doASCCDL=color.doSDRSat=true;color.tweaks=true;
color.asc=new Float64Array([1.25,.75,1.5,-.125,.0625,-.25,.5,1.25,2.5,.625]);color.sdrSatGamma=1.2;
const sat=Array.from({length:17},(_,i)=>.15+(i%5)*.35),tones=[{stop:-3,hue:17,saturation:245},{stop:0,hue:101,saturation:187},{stop:4,hue:231,saturation:213}];
color.setMulti({twkMulti:{doMulti:true,sat:Float64Array.from(sat).buffer,pStop:Float64Array.from(tones.map(v=>v.stop)).buffer,
 pHue:Uint8Array.from(tones.map(v=>v.hue)).buffer,pSat:Uint8Array.from(tones.map(v=>v.saturation)).buffer}});
engine.curOut=engine.curIn;engine.outL=false;engine.nul=false;engine.hdrOut=false;
engine.doKnee=engine.doBlkHi=engine.doDisplay=false;engine.clip=false;
engine.bClip=-Infinity;engine.wClip=Infinity;
engine.doASCCDL=true;engine.asc=color.asc;engine.tweaks=true;
engine.highRef=.72;engine.changedOut=engine.changedASCCDL=engine.changedHDR=false;
const levelOut=engine.setBlkHi({twkBlkHi:{doBlkHi:true,doBlack:true,doHigh:true,blackLevel:.025,blackLock:true,highRef:.72,highMap:.91,highLock:true}});
engine.setBlkGam({twkBlkGam:{doBlkGam:true,upperLim:0,feather:2,power:.5}});
const size=17,binary=Buffer.alloc(size**3*3*8);
for(let b=0;b<size;b++){
 const decoded=engine.inCalcRGB(0,3,{R:0,G:0,B:b,vals:size*size,dim:size});
 const converted=color.calc(0,1,decoded,true);const values=new Float64Array(engine.outCalcRGB(0,4,converted).o);
 for(let j=0;j<values.length;j++){if(!Number.isFinite(values[j]))throw new Error('Nonfinite reference');binary.writeDoubleLE(values[j],(b*size*size*3+j)*8);}
}
const metadata=JSON.stringify({sourceSHA256,size,source:'LUTGamma.inCalcRGB -> LUTColourSpace.calc(g=true) -> LUTGamma.outCalcRGB; Black Highlight before Black Gamma; no final clipping',
 order:'R-fast/G-middle/B-slow',input:'DLog2/DGamut2 Data',output:'DLog2/Rec2020 Data',exposureGain:2,ascCDL:Array.from(color.asc),
 saturationByStop:sat,tones,sdrGamma:1.2,blackHighlight:{blackLevel:.025,highMap:.91,highReferenceScene:.72,blackLock:true,highLock:true,prepared:[engine.al,engine.bl],defaults:[levelOut.blackDef,levelOut.highDef]},blackGamma:{upperStops:0,featherStops:2,power:.5},encodedLegalAnchors:[engine.blkLevel,engine.blkGamLL,engine.blkGamUL],binarySHA256:crypto.createHash('sha256').update(binary).digest('hex')},null,2)+'\n';
const stem=path.join(root,'tests/fixtures/native-contracts/black-highlight-legacy-pipeline17');
if(process.argv.includes('--check')){
 if(!fs.readFileSync(stem+'.f64').equals(binary)||fs.readFileSync(stem+'.json','utf8')!==metadata)throw new Error('Black Highlight pipeline changed');
 console.log('旧解码/色域/曝光/CDL/Multitone/SDR/编码/黑白电平/Black Gamma 17³全节点及源码哈希一致');
}else{fs.writeFileSync(stem+'.f64',binary);fs.writeFileSync(stem+'.json',metadata);console.log('已冻结4913个旧黑白电平组合链节点');}
