// Read-only development comparison between the old analytic LogC4 code and ARRI's formula.
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'js/gamma.js'), 'utf8');
const begin = source.indexOf('// ARRI LogC4');
const end = source.indexOf('// Canon C-Log3', begin);
if (begin < 0 || end < 0) throw new Error('legacy source span changed');
const context = { Math, Float64Array, constructor: null };
vm.runInNewContext(source.slice(begin, end) + '\nconstructor = LUTGammaLogC4;', context);
const legacy = new context.constructor('LogC4');
legacy.changeRange(false, false);

const a = (2 ** 18 - 16) / 117.45;
const b = (1023 - 95) / 1023;
const c = 95 / 1023;
const s = 7 * Math.log(2) * 2 ** (7 - 14 * c / b) / (a * b);
const t = (2 ** (-14 * c / b + 6) - 64) / a;
function decode(signal) {
  return signal < 0 ? signal * s + t : (2 ** (14 * (signal - c) / b + 6) - 64) / a;
}
function encode(scene) {
  return scene < t ? (scene - t) / s : ((Math.log2(a * scene + 64) - 6) / 14) * b + c;
}
let decodeWorst = { scaledError: -1 };
for (const bits of [10, 12]) {
  const maximum = (1 << bits) - 1;
  for (let code = 0; code <= maximum; code++) {
    const signal = code / maximum;
    const actual = legacy.linFromData(signal) * 0.9;
    const expected = decode(signal);
    const scaledError = Math.abs(actual - expected) / Math.max(1, Math.abs(expected));
    if (scaledError > decodeWorst.scaledError) decodeWorst = { bits, code, scaledError };
  }
}
let encodeWorst = { scaledError: -1 };
for (const scene of [-0.5, -0.1, -0.02, t, 0, 0.001, 0.18, 1, 10, 100, 1000]) {
  const actual = legacy.linToData(scene / 0.9);
  const expected = encode(scene);
  const scaledError = Math.abs(actual - expected) / Math.max(1, Math.abs(expected));
  if (scaledError > encodeWorst.scaledError) encodeWorst = { scene, scaledError };
}
console.log(JSON.stringify({ source: 'js/gamma.js:LUTGammaLogC4',
  range: 'Data→Data', legacyToSceneScale: 0.9,
  decodeFullCodeWorst: decodeWorst, encodePointWorst: encodeWorst }));
