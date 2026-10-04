// Read-only development comparison of the existing analytic V-Log curve and Panasonic Rev.1.0.
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'js/gamma.js'), 'utf8');
const begin = source.indexOf('// Generalised Log\n');
const end = source.indexOf('// Generalised Log with a soft clip', begin);
if (begin < 0 || end < 0) throw new Error('legacy source span changed');
const context = { Math, Float64Array, constructor: null };
vm.runInNewContext(source.slice(begin, end) + '\nconstructor = LUTGammaLog;', context);
const old = new context.constructor('Panasonic V-Log',
  [0.198412698, -0.024801587, 0.241514, 0.9, 10, 0.598206, 0.00873, 0.181, 0.009]);
function decode(signal) {
  return signal < 0.181 ? (signal - 0.125) / 5.6
    : 10 ** ((signal - 0.598206) / 0.241514) - 0.00873;
}
function encode(scene) {
  return scene < 0.01 ? 5.6 * scene + 0.125
    : 0.241514 * Math.log10(scene + 0.00873) + 0.598206;
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
let worstEncode = { scaledError: -1 };
for (const scene of [-0.02, -0.001, 0, 0.01, 0.18, 0.9, 1, 10]) {
  const oldData = old.linToData(scene / 0.9);
  const expected = encode(scene);
  const scaledError = Math.abs(oldData - expected) / Math.max(1, Math.abs(expected));
  if (scaledError > worstEncode.scaledError) worstEncode = { scene, scaledError };
}
console.log(JSON.stringify({ source: 'js/gamma.js:LUTGammaLog Panasonic V-Log',
  range: 'Data→Data', legacyToSceneScale: 0.9,
  decodeFullCodeWorst: worstDecode, encodePointWorst: worstEncode }));
