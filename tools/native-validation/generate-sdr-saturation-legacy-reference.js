'use strict';
// Research-only retained SDRSatOut; no script or reference table ships in App.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const source=fs.readFileSync(path.join(root,'js/colourspace.js'),'utf8');
const c=vm.createContext({console});vm.runInContext(source,c,{filename:'colourspace.js'});
const obj=vm.runInContext('Object.create(LUTColourSpace.prototype)',c);
obj.g=[{name:'Rec2020',xy:new Float64Array([.708,.292,.170,.797,.131,.046]),white:new Float64Array([.3127,.329,.3583])}];
const luma=obj.getYCoeffs('Rec2020');obj.csOut=[{name:'Rec2020'}];obj.curOut=0;obj.Ys={Rec2020:luma};
const points=[[0,0,0],[-1,-2,-3],[1,0,0],[0,1,0],[0,0,1],[12,12,12],[24,24,24],[-2,1,3],[1e-15,1e-15,1e-15]];
let seed=0x5eed5011;
for(let i=0;i<64;i++){const p=[];for(let j=0;j<3;j++){seed=(Math.imul(seed,1664525)+1013904223)>>>0;p.push(seed/4294967296*32-4);}points.push(p);}
const cases=[1,1.2,1.5,2].map(gamma=>{obj.sdrSatGamma=gamma;return {gamma,probes:points.map(input=>{
 const out=Float64Array.from(input);obj.SDRSatOut(out.buffer);return {input,output:Array.from(out)};
})};});
const result={sourceSHA256:crypto.createHash('sha256').update(source).digest('hex'),
 source:'LUTColourSpace.SDRSatOut, getYCoeffs Rec2020/D65',legacyScale:12,luma:Array.from(luma),cases};
const output=JSON.stringify(result,null,2)+'\n',target=path.join(root,'tests/fixtures/native-contracts/sdr-saturation-legacy-reference.json');
if(process.argv.includes('--check')){if(fs.readFileSync(target,'utf8')!==output)throw new Error('SDR Saturation legacy reference changed');console.log('旧 SDR Saturation 292 点及源码哈希一致');}
else{fs.writeFileSync(target,output);console.log('已冻结旧 SDR Saturation 292 点');}
