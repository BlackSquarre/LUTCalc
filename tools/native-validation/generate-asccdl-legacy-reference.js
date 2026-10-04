'use strict';
// Research-only execution of retained functions; no legacy script is shipped.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),context=vm.createContext({console});
const hashes={};
for(const file of ['colourspace.js','gamma.js']) {
 const src=fs.readFileSync(path.join(root,'js',file),'utf8');
 hashes[file]=crypto.createHash('sha256').update(src).digest('hex');
 vm.runInContext(src,context,{filename:file});
}
const obj=vm.runInContext('Object.create(LUTColourSpace.prototype)',context);
obj.g=[{name:'Sony S-Gamut3.cine',xy:new Float64Array([.766,.275,.225,.800,.089,-.087]),white:new Float64Array([.3127,.329,1-.3127-.329])}];
obj.y=obj.getYCoeffs('Sony S-Gamut3.cine');
const gamma=vm.runInContext('Object.create(LUTGamma.prototype)',context);
const parameters=[
 [1,1,1,0,0,0,1,1,1,1],
 [1.25,.75,1.5,-.125,.0625,-.25,2,1,2,.625],
 [.25,2,.5,-.05,.1,-.125,.5,1.25,2.5,1.75],
 [-1,0,2,.125,.25,-.5,0,-1,1,-.5],
 [1,1,1,0,0,0,1,1,1,0]
];
const points=[[-1,-.5,-.1],[0,0,0],[.1,.2,.3],[.2,.2,.2],[1,0,0],[0,1,0],[0,0,1],[2,4,8],[10,.01,-1]];
let seed=0x5eedcd10;
for(let i=0;i<48;i++) {
 const rgb=[];for(let c=0;c<3;c++){seed=(Math.imul(seed,1664525)+1013904223)>>>0;rgb.push(seed/4294967296*6-1);}
 points.push(rgb);
}
const cases=parameters.map(a=>{
 obj.asc=gamma.asc=new Float64Array(a);
 return {parameters:a,probes:points.map(input=>{
  const output=new Float64Array(input),independentOutput=new Float64Array(input);
  obj.ASCCDLOut(output.buffer);gamma.ASCCDLOut(independentOutput.buffer);
  if(![...output,...independentOutput].every(Number.isFinite))throw new Error('non-finite reference');
  return {input,output:Array.from(output),independentOutput:Array.from(independentOutput)};
 })};
});
const result={sourceSHA256:hashes,workingSpace:'Sony S-Gamut3.cine',referenceGrey:.2,luma:Array.from(obj.y),seed:'0x5eedcd10',cases};
const output=JSON.stringify(result,null,2)+'\n',target=path.join(root,'tests/fixtures/native-contracts/asccdl-legacy-reference.json');
if(process.argv.includes('--check')){if(fs.readFileSync(target,'utf8')!==output)throw new Error('legacy ASC-CDL reference changed');console.log('旧 ASC-CDL 3D/1D 参照与源码哈希一致');}
else {fs.writeFileSync(target,output);console.log(`已冻结 ${cases.reduce((n,c)=>n+c.probes.length,0)} 个3D和1D ASC-CDL取样`);}
