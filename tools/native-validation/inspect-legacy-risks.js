'use strict';
// Observe legacy edge cases in isolated VM contexts; do not modify the engine.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const files = ['lut.js','ring.js','bounding.js','brent.js','gamma.js','colourspace.js','lut-cube.js'];
const c = vm.createContext({Float64Array, Float32Array, Int8Array, Int16Array,
  Uint8Array, Uint16Array, ArrayBuffer, console, addEventListener(){}, postMessage(){}});
for (const name of files) vm.runInContext(fs.readFileSync(path.join(root,'js',name),'utf8'),c,{filename:name});
const rows = [];
const ga = new c.LUTGamma();
ga.nul=true; ga.inL=true; ga.outL=true; ga.sIn=false;
const actual = Array.from(new Float64Array(ga.inCalcRGB(0,3,{R:0,G:0,B:1,vals:4,dim:2}).o));
const expected = [0,0,1,1,0,1,0,1,1,1,1,1];
rows.push({id:'LEG-01',scope:'inCalcRGB 的 nul/inL/outL 分支，独立调用',actual,expected,mismatched:actual.filter((v,i)=>v!==expected[i]).length});
for (const [id,body] of [['LEG-02',['0 0 0']],['LEG-03',['0 Infinity 0','1 1 1']]]) {
  let captured;
  const parser = new c.cubeLUT({},true,0);
  const accepted=parser.parse('probe',['LUT_1D_SIZE 2',...body],{setLUT(_dest,p){captured=p;return true;}},0);
  const channels=captured.C.map(b=>Array.from(new Float64Array(b),v=>Number.isFinite(v)?v:String(v)));
  rows.push({id,scope:'CUBE 解析器，分别输入缺行和 Infinity',accepted,channels});
}
rows.push({id:'LEG-04',scope:'常量函数无根',actual:new c.Brent({f:()=>1},0,1).findRoot(.5,0),expectedStatus:'notBracketed'});
const before=new Set(Object.keys(c));
const rootValue=new c.Brent({f:x=>x*x},0,2).findRoot(1,2);
rows.push({id:'LEG-05',scope:'Brent 局部变量作用域',rootValue,newGlobals:Object.keys(c).filter(k=>!before.has(k))});
const methods={};
for(const name of ['RGBCub','RGBTet','RGBLin']) {
  try {
    if(typeof c.LUTSpline.prototype[name]!=='function') {methods[name]='missing';continue;}
    c.LUTSpline.prototype[name].call({FCub(){},FTet(){},FLin(){}},new Float64Array([.1,.2,.3]).buffer);
    methods[name]='returned';
  } catch(e) {methods[name]=e.name+': '+e.message;}
}
rows.push({id:'LEG-06',scope:'LUTSpline 批量方法；未证明当前 UI 路径会调用',methods});
const cs=new c.LUTColourSpace();
cs.nul=false; cs.doFC=cs.doWB=cs.doPSSTCDL=cs.doASCCDL=cs.doMulti=cs.doHG=cs.doSDRSat=cs.doGamutLim=false;
cs.csOut=[{cb:()=>false,lf:()=>{}}];cs.curOut=0;
const converted=cs.calc(0,1,{o:new Float64Array([NaN,.2,.3]).buffer,eiMult:1},false);
rows.push({id:'LEG-07',scope:'colourspace.calc 曝光分支；下游输出模拟为恒等以定位行为',input:['NaN',.2,.3],actual:Array.from(new Float64Array(converted.o))});
const report={date:'2026-09-23',node:process.version,scope:'只读最小复现；不代表端到端 UI 审计，也不把旧缺陷写成新实现应遵守的预期',sourceHashes:files.map(name=>({path:'js/'+name,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,'js',name))).digest('hex')})),observations:rows};
const out=path.join(root,'research/native-handoff/2026-09-23/legacy-observations.json');
fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(rows,null,2));
