'use strict';
// Research-only execution of the retained legacy implementation.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'js/lut.js'), 'utf8');
const context = vm.createContext({ console });
vm.runInContext(source, context, { filename: 'js/lut.js' });
function makeSamples(size, field) {
  const samples = [];
  for (let b = 0; b < size; b++) for (let g = 0; g < size; g++) for (let r = 0; r < size; r++) {
    const x = r / (size - 1), y = g / (size - 1), z = b / (size - 1);
    samples.push(field === 'polynomial'
      ? [x*x + 0.3*y*z, y*y*y - 0.2*x*z, z*z + 0.1*x*y + 0.05*x*x*x]
      : [r % 2 === 0 ? x : -x, (g % 3 - 1) * y, (b % 2 === 0 ? z : -z) + 0.2*x*y]);
  }
  return samples;
}
function volume(size, samples) {
  context.referenceChannels = [0, 1, 2].map(c => Float64Array.from(samples.map(v => v[c])).buffer);
  return vm.runInContext('new LUTVolume({buffR: referenceChannels[0], buffG: referenceChannels[1], buffB: referenceChannels[2]})', context);
}
const points = [];
// All six faces, twelve edges and eight corners, plus fixed interior points.
for (const r of [0, 0.37, 1]) for (const g of [0, 0.53, 1]) for (const b of [0, 0.71, 1]) points.push([r,g,b]);
let state = 0x5eed2026;
function random() { state = (Math.imul(state,1664525) + 1013904223) >>> 0; return state / 4294967296; }
for (let i = 0; i < 64; i++) points.push([random(),random(),random()]);
const cases = [];
for (const size of [4, 5, 17]) for (const field of ['polynomial','alternating']) {
  const samples = makeSamples(size, field);
  const v = volume(size, samples);
  const probes = points.map(input => {
    const output = new Float64Array(input);
    v.RGBCub(output.buffer);
    if (!Array.from(output).every(Number.isFinite)) throw new Error('non-finite legacy reference');
    return { input, output: Array.from(output) };
  });
  cases.push({ size, field, samples, probes });
}
// Independent affine derivative says B=-0.1; old red-axis extrapolation writes rgb[27]
// instead of rgb[17], so the blue slope is lost. Keep this conflict separate.
const affine = [];
for(let b=0;b<4;b++) for(let g=0;g<4;g++) for(let r=0;r<4;r++) affine.push([r/3,g/3,r/3]);
const conflictInput = [-0.1, 0.5, 0.5];
const conflictOutput = new Float64Array(conflictInput);
volume(4, affine).RGBCub(conflictOutput.buffer);
const result = {
  sourceSHA256: crypto.createHash('sha256').update(source).digest('hex'),
  nodeOrder: 'R-fast, G-middle, B-slow',
  seed: '0x5eed2026',
  cases,
  outsideResearchConflict: { input: conflictInput, legacyOutput: Array.from(conflictOutput), analyticAffineOutput: [-0.1,0.5,-0.1] }
};
const output = JSON.stringify(result, null, 2) + '\n';
const target = path.join(root,'tests/fixtures/native-contracts/tricubic-legacy-reference.json');
if (process.argv.includes('--check')) {
  if (fs.readFileSync(target,'utf8') !== output) throw new Error('tricubic legacy reference changed');
  console.log('旧 tricubic 合成参照、源码哈希和域外冲突最小复现一致');
} else {
  fs.writeFileSync(target, output);
  console.log(`已冻结 ${cases.length} 组、${cases.reduce((n,c)=>n+c.probes.length,0)} 个 tricubic 合成取样`);
}
