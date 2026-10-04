// Read-only comparison of the old Apple Log paths and the public ACES analytic curve.
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'js/gamma.js'), 'utf8');
const begin = source.indexOf('// Apple Log\n');
const end = source.indexOf('// Log2 - encoding log for LOGCalc', begin);
if (begin < 0 || end < 0) throw new Error('legacy Apple Log source span changed');
const context = { Math, Float64Array, constructor: null };
vm.runInNewContext(source.slice(begin, end) + '\nconstructor = LUTGammaAppleLog;', context);
const old = new context.constructor('Apple Log');
const r0 = -0.05641088, rt = 0.01, c = 47.28711236;
const b = 0.00964052, g = 0.08550479, d = 0.69336945;
const pt = c * (rt - r0) * (rt - r0);
function decode(signal) {
  return signal >= pt ? 2 ** ((signal - d) / g) - b
    : signal >= 0 ? Math.sqrt(signal / c) + r0 : r0;
}
function encode(scene) {
  return scene >= rt ? g * Math.log2(scene + b) + d
    : scene >= r0 ? c * (scene - r0) ** 2 : 0;
}
let worstDecode = { scaledError: -1 };
for (const bits of [10, 12]) {
  const maximum = (1 << bits) - 1;
  for (let code = 0; code <= maximum; code++) {
    const signal = code / maximum;
    const oldScene = old.linFromData(signal) * 0.9;
    const expected = decode(signal);
    const scaledError = Math.abs(oldScene - expected) / Math.max(1, Math.abs(expected));
    if (scaledError > worstDecode.scaledError) worstDecode = { bits, code, scaledError };
  }
}
let worstVectorEncode = { scaledError: -1 };
for (const scene of [-0.1, r0, 0, rt, 0.18, 1, 10]) {
  const buffer = new Float64Array([scene / 0.9]);
  old.linToD(buffer.buffer);
  const actual = buffer[0];
  const expected = encode(scene);
  const scaledError = Math.abs(actual - expected) / Math.max(1, Math.abs(expected));
  if (scaledError > worstVectorEncode.scaledError) worstVectorEncode = { scene, scaledError };
}
const brokenScalarEncode = old.linToData(0.18 / 0.9);
if (!Number.isNaN(brokenScalarEncode)) throw new Error('legacy scalar encode bug changed');
console.log(JSON.stringify({ source: 'js/gamma.js:LUTGammaAppleLog',
  range: 'Data→Data', legacyToSceneScale: 0.9,
  decodeFullCodeWorst: worstDecode, vectorEncodePointWorst: worstVectorEncode,
  scalarEncodeAtScene018: 'NaN (legacy this.r0/this.rt typo)' }));
