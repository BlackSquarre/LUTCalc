'use strict';
// 仅用于研发验证，不进入 Swift App。
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const referencePath = path.join(root, 'tests/fixtures/native-contracts/srgb-reference.json');
const outputPath = path.join(root, 'tests/fixtures/native-contracts/srgb-legacy-reference.json');
const context = vm.createContext({Float64Array, Float32Array, Uint8Array, ArrayBuffer, console});
for (const name of ['lut.js', 'ring.js', 'bounding.js', 'brent.js', 'gamma.js']) {
  vm.runInContext(fs.readFileSync(path.join(root, 'js', name), 'utf8'), context, {filename: name});
}
const gamma = new context.LUTGamma().gammas.find(item => item.name === 'sRGB');
if (!gamma) throw new Error('sRGB not registered');
const source = JSON.parse(fs.readFileSync(referencePath, 'utf8'));
const output = {
  source: 'js/gamma.js LUTGammaGam sRGB: legal-normalized methods, not Data code-range wrappers',
  algorithmVersion: 'srgb.lutcalc-legacy.v1',
  encode: source.encode.map(item => ({input: item.input, expected: gamma.linToLegal(item.input)})),
  decode: source.decode.map(item => ({input: item.input, expected: gamma.linFromLegal(item.input)})),
};
fs.writeFileSync(outputPath, JSON.stringify(output, null, 2) + '\n');
