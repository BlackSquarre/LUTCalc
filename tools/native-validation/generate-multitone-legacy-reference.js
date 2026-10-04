'use strict';
// Research-only actual setMulti/multiOut. Nothing from this file ships in App.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({console,addEventListener(){},postMessage(){}}),sourceSHA256={};
for(const name of ['lut.js','ring.js','bounding.js','brent.js','gamma.js','colourspace.js']){
 const src=fs.readFileSync(path.join(root,'js',name),'utf8');sourceSHA256[name]=crypto.createHash('sha256').update(src).digest('hex');vm.runInContext(src,c,{filename:name});
}
const cs=new c.LUTColourSpace();cs.curOut=cs.csOut.findIndex(v=>v.name==='Rec2020');cs.tweaks=true;
const points=[[0,0,0],[-1,-2,-3],[1,0,0],[0,1,0],[0,0,1],[-1,0,1],[.2,.2,.2],[100,200,300]];
for(let k=-10;k<=10;k++){const y=.2*2**k;points.push([y,y,y]);}
let seed=0x5eed9009;
for(let i=0;i<64;i++){const p=[];for(let j=0;j<3;j++){seed=(Math.imul(seed,1664525)+1013904223)>>>0;p.push(seed/4294967296*24-1);}points.push(p);}
const cases=[
 {saturationByStop:Array(17).fill(1),tones:[]},
 {saturationByStop:Array.from({length:17},(_,i)=>i/8),tones:[]},
 {saturationByStop:Array(17).fill(.4),tones:[{stop:0,hue:170,saturation:255}]},
 {saturationByStop:Array.from({length:17},(_,i)=>.15+(i%5)*.35),tones:[{stop:-3,hue:17,saturation:245},{stop:0,hue:101,saturation:187},{stop:4,hue:231,saturation:213}]}
].map(item=>{
 cs.setMulti({twkMulti:{doMulti:true,sat:Float64Array.from(item.saturationByStop).buffer,
  pStop:Float64Array.from(item.tones.map(v=>v.stop)).buffer,pHue:Uint8Array.from(item.tones.map(v=>v.hue)).buffer,pSat:Uint8Array.from(item.tones.map(v=>v.saturation)).buffer}});
 return {...item,preparedToneRGB:Array.from(cs.multiRGB),probes:points.map(input=>{const output=Float64Array.from(input);cs.multiOut(output.buffer);return {input,output:Array.from(output)};})};
});
const result={sourceSHA256,workingSpace:cs.system.name,outputSpace:'Rec2020',luma:Array.from(cs.y),cases};
const output=JSON.stringify(result,null,2)+'\n',target=path.join(root,'tests/fixtures/native-contracts/multitone-legacy-reference.json');
if(process.argv.includes('--check')){if(fs.readFileSync(target,'utf8')!==output)throw new Error('Multitone legacy fixture changed');console.log('旧Multitone 372点与颜色准备/源码哈希一致');}
else{fs.writeFileSync(target,output);console.log('已冻结旧Multitone 372点');}
