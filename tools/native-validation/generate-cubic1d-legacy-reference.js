'use strict';
// Research-only legacy execution. This file and its fixture are not App resources.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'js/lut.js'), 'utf8');
const context = vm.createContext({console});
vm.runInContext(source, context, {filename: 'js/lut.js'});
const cases = [];
for (const size of [3, 5, 17]) for (const field of ['increasing','decreasing','alternating','flat']) {
  const values = Array.from({length:size}, (_,i) => {
    const t = i/(size-1);
    return field === 'increasing' ? t*t : field === 'decreasing' ? 1-t*t
      : field === 'flat' ? 0.375 : i%2 === 0 ? t : -t;
  });
  context.params = {buff: Float64Array.from(values).buffer, fL:-2, fH:3};
  const spline = vm.runInContext('new LUTSpline(params)', context);
  const positions = [-0.25,0,1e-8,0.07,0.25,0.5,0.79,1-1e-8,1,1.25];
  for(let i=0;i<size;i++) positions.push(i/(size-1));
  const probes = positions.map(t => {const input = -2+5*t; return {input, output:spline.fCub(input)};});
  cases.push({size,field,values,lower:-2,upper:3,slopes:[spline.FC[0],spline.FC[size-1]],probes});
}
// The retained volume has one shared unit-domain input spline. Wrap only the
// shaper domain so this fixture is representable by the native CUBE model.
const shaper = [0,0.0625,0.25,0.5625,1];
const samples=[];
for(let b=0;b<4;b++) for(let g=0;g<4;g++) for(let r=0;r<4;r++) {
  const x=r/3,y=g/3,z=b/3;
  samples.push([x*x+0.3*y*z,y*y*y-0.2*x*z,z*z+0.1*x*y]);
}
context.volumeParams = {
  buffR:Float64Array.from(samples.map(v=>v[0])).buffer,
  buffG:Float64Array.from(samples.map(v=>v[1])).buffer,
  buffB:Float64Array.from(samples.map(v=>v[2])).buffer,
  inSpline:Float64Array.from(shaper).buffer
};
const volume = vm.runInContext('new LUTVolume(volumeParams)', context);
const combinedProbes=[];
for(const x of [0,0.19,0.5,0.91,1]) for(const y of [0,0.37,1]) for(const z of [0,0.71,1]) {
  const output=new Float64Array([x,y,z]); volume.RGBCub(output.buffer);
  combinedProbes.push({input:[-2+5*x,-2+5*y,-2+5*z],output:Array.from(output)});
}
const result={sourceSHA256:crypto.createHash('sha256').update(source).digest('hex'),cases,
  combined:{size:4,lower:-2,upper:3,shaper,samples,probes:combinedProbes}};
const output=JSON.stringify(result,null,2)+'\n';
const target=path.join(root,'tests/fixtures/native-contracts/cubic1d-legacy-reference.json');
if(process.argv.includes('--check')) {
  if(fs.readFileSync(target,'utf8')!==output) throw new Error('1D cubic legacy reference changed');
  console.log('旧 1D cubic 和组合 shaper 合成参照及源码哈希一致');
} else {
  fs.writeFileSync(target,output);
  console.log(`已冻结 ${cases.reduce((n,c)=>n+c.probes.length,0)} 个标量与 ${combinedProbes.length} 个组合取样`);
}
