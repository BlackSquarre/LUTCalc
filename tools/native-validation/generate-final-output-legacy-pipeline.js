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
const linear=process.argv.includes('--linear');
color.setGamutLim({twkGamutLim:{doGamutLim:true,lin:linear,level:linear?0.5:0.85,gamut:'Rec709',both:true}});
color.setHG({twkHG:{doHG:true,gamut:color.csOut.findIndex(v=>v.name==='Rec709'),lin:false,low:-1,high:3}});
color.setMulti({twkMulti:{doMulti:true,sat:Float64Array.from(sat).buffer,pStop:Float64Array.from(tones.map(v=>v.stop)).buffer,
 pHue:Uint8Array.from(tones.map(v=>v.hue)).buffer,pSat:Uint8Array.from(tones.map(v=>v.saturation)).buffer}});
engine.curOut=engine.curIn;engine.outL=false;engine.nul=false;engine.hdrOut=false;
engine.doKnee=engine.doBlkHi=engine.doDisplay=false;engine.clip=true;engine.clipB=true;engine.clipW=true;engine.clipL=true;
engine.bClip=-1023;engine.wClip=67025937;
engine.doASCCDL=true;engine.asc=color.asc;engine.tweaks=true;
engine.highRef=.72;engine.changedOut=engine.changedASCCDL=engine.changedHDR=false;
engine.setKnee({twkKnee:{doKnee:true,kneeStart:-2,kneeClip:4,clipSlope:1,smoothness:.35,legal:false}});
const levelOut=engine.setBlkHi({twkBlkHi:{doBlkHi:true,doBlack:true,doHigh:true,blackLevel:.025,blackLock:true,highRef:.72,highMap:.91,highLock:true}});
engine.setBlkGam({twkBlkGam:{doBlkGam:true,upperLim:0,feather:2,power:.5}});
const display={doDisplay:true,inIdx:engine.gammas.findIndex(v=>v.name==='Rec709'),outIdx:engine.gammas.findIndex(v=>v.name==='sRGB'),inGt:1,outGt:4};
if(Math.min(display.inIdx,display.outIdx)<0)throw new Error('Display registry missing');
engine.setDisplay({twkDisplay:display});
color.setFC({twkFC:{doFC:true,fcs:[true,true,true,true,true,true,true],blue:6.1,yellow:.5,red:6}});
const size=17,binary=Buffer.alloc(size**3*3*8);
for(let b=0;b<size;b++){
 const decoded=engine.inCalcRGB(0,3,{R:0,G:0,B:b,vals:size*size,dim:size});
 const converted=color.calc(0,1,decoded,true);const values=new Float64Array(engine.outCalcRGB(0,4,converted).o);
 for(let j=0;j<values.length;j++){if(!Number.isFinite(values[j]))throw new Error('Nonfinite reference');binary.writeDoubleLE(values[j],(b*size*size*3+j)*8);}
}
const metadata=JSON.stringify({sourceSHA256,size,source:'LUTGamma.inCalcRGB -> LUTColourSpace.calc(g=true) -> LUTGamma.outCalcRGB; Highlight Gamut -> SDR -> Knee -> Black Highlight -> Black Gamma; False Colour stage5 snapshot/stage18 overlay; Display Conversion stage16 including auxiliary; Gamut Limiter stage12/17; Final Output stage19 format bounds and both Legal clip in Data output',
 order:'R-fast/G-middle/B-slow',input:'DLog2/DGamut2 Data',output:'DLog2/Rec2020 Data',exposureGain:2,finalOutput:{mode:"both",clipLegal:true,minimumCode10:-1023,maximumCode10:67025937,forceBlackLegal:false},falseColour:{blueStopsBelowGray:6.1,yellowStopsBelowClip:.5,redStopsAboveGray:6,doOrange:true},displayConversion:{baseCurve:"rec709",outputCurve:"srgb",baseGamut:"rec2020",outputGamut:"p3D60"},ascCDL:Array.from(color.asc),
 saturationByStop:sat,tones,sdrGamma:1.2,gamutLimiter:{mode:linear?"linear":"postGamma",linearStops:-1,postLevel:.85,secondarySpace:"srgb.d65.v1",protectBoth:true},highlightGamut:{highlightSpace:"srgb.d65.v1",transition:"logarithmicStops",lowStops:-1,highStops:3},knee:{startStops:-2,clipStops:4,clipSlope:1,smoothness:.35,legal:false,prepared:[engine.kS,engine.kC,engine.kp0,engine.kp1,engine.kp2,engine.kd0,engine.kd1,engine.kd2,engine.ks]},blackHighlight:{blackLevel:.025,highMap:.91,highReferenceScene:.72,blackLock:true,highLock:true,prepared:[engine.al,engine.bl],defaults:[levelOut.blackDef,levelOut.highDef]},blackGamma:{upperStops:0,featherStops:2,power:.5},encodedLegalAnchors:[engine.blkLevel,engine.blkGamLL,engine.blkGamUL],binarySHA256:crypto.createHash('sha256').update(binary).digest('hex')},null,2)+'\n';
const stem=path.join(root,'tests/fixtures/native-contracts/final-output-legacy-pipeline17'+(linear?'-linear':'-post'));
if(process.argv.includes('--check')){
 if(!fs.readFileSync(stem+'.f64').equals(binary)||fs.readFileSync(stem+'.json','utf8')!==metadata)throw new Error('Final Output pipeline changed');
 console.log('旧解码/色域/曝光/CDL/Multitone/Highlight Gamut/SDR/Knee/黑白电平/Black Gamma 17³全节点及源码哈希一致');
}else{fs.writeFileSync(stem+'.f64',binary);fs.writeFileSync(stem+'.json',metadata);console.log('已冻结4913个旧Final Output限幅组合链节点');}
