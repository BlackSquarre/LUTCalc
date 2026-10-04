'use strict';
// 研发参照：直接执行旧 gamma.js 的 BMD Pocket Film LUTGammaLog 方法。
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'js/gamma.js'), 'utf8');
const context = vm.createContext({ Float64Array, Float32Array, Uint8Array, ArrayBuffer });
vm.runInContext(source, context, { filename: 'gamma.js' });
const params = [0.195367159 / 0.9, -0.014273567 / 0.9, 0.36274758, 1.05345192 * 0.9, 10, 0.63659829, 0.027616437, 0.096214896, 0.004523664 * 0.9];
const curve = new context.LUTGammaLog('BMD Pocket Film', params);
const encodeCut = params[8];
const decodeCut = params[7];
const values = [-0.2, -0.014273567 / 0.9, 0, encodeCut - 1e-15, encodeCut, encodeCut + 1e-15, 0.05, 0.18, 0.2, 0.5, 1, 4];
const apply = (x, method) => { const a = new Float64Array([x]); curve[method](a.buffer); return { input: x, output: String(a[0]) }; };
const output = {
  precision: 64,
  source: 'js/gamma.js:LUTGammaLog BMD Pocket Film',
  sourceSHA256: crypto.createHash('sha256').update(source).digest('hex'),
  params: params.map(String),
  encodeCut: String(encodeCut), decodeCut: String(decodeCut),
  encode: values.map(x => apply(x, 'linToD')),
  decode: [0, decodeCut - 1e-15, decodeCut, decodeCut + 1e-15, 0.2, 0.5, 0.63659829, 1].map(x => apply(x, 'linFromD'))
};
const target = path.join(root, 'tests/fixtures/native-contracts/bmd-pocket-film-legacy-reference.json');
fs.writeFileSync(target, JSON.stringify(output, null, 2) + '\n');
console.log(JSON.stringify({ path: target, sourceSHA256: output.sourceSHA256 }));
