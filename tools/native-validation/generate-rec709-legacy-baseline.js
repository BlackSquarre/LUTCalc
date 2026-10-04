'use strict';
// 仅用于研发验证，不进入 Swift App。
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '../..');
const outputPath = path.join(root, 'tests/fixtures/native-contracts/rec709-legacy-reference.json');
const context = vm.createContext({Float64Array, Float32Array, Uint8Array, ArrayBuffer, console});
for (const name of ['lut.js', 'ring.js', 'bounding.js', 'brent.js', 'gamma.js']) {
  vm.runInContext(fs.readFileSync(path.join(root, 'js', name), 'utf8'), context, {filename: name});
}
const gamma = new context.LUTGamma().gammas.find(item => item.name === 'Rec709');
if (!gamma) throw new Error('Rec709 not registered');
const near = (x, direction) => {
  const view = new DataView(new ArrayBuffer(8));
  view.setFloat64(0, x);
  let bits = view.getBigUint64(0);
  bits += BigInt(direction);
  view.setBigUint64(0, bits);
  return view.getFloat64(0);
};
const encodeInputs = [-0.25, -0.01, -0.0, 0, 0.001, 0.01,
  near(0.018, -1), 0.018, near(0.018, 1), 0.18, 0.5, 1, 2, 4];
const decodeInputs = [-0.25, -0.01, -0.0, 0, 0.02,
  near(0.081, -1), 0.081, near(0.081, 1), 0.08112,
  0.08124794403514048, 0.18, 0.5, 1, 2];
const fullCodeData = [10, 12].map(bits => ({
  bits,
  decoded: Array.from({length: 2 ** bits}, (_, code) => gamma.linFromLegal(code / (2 ** bits - 1))),
}));
const output = {
  source: 'js/gamma.js LUTGammaGam Rec709 registered behavior; research fixture only',
  algorithmVersion: 'rec709.lutcalc-legacy.v1',
  encode: encodeInputs.map(input => ({input, expected: gamma.linToLegal(input)})),
  decode: decodeInputs.map(input => ({input, expected: gamma.linFromLegal(input)})),
  fullCodeData,
};
fs.writeFileSync(outputPath, JSON.stringify(output, null, 2) + '\n');
