'use strict';
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'js/gamma.js'), 'utf8');
const context = vm.createContext({ Float64Array, Float32Array, Uint8Array, ArrayBuffer, Math });
vm.runInContext(source, context, { filename: 'gamma.js' });
const variants = {
  film: [0.261115778 * 0.9, -0.024248528 * 0.9, 0.367608577, 0.86786483 / 0.9, 10, 0.644065346, 0.03135747, 0.114002127, 0.005519226 / 0.9],
  film4k: [0.37237694 * 0.9, -0.034580801 * 0.9, 0.582240088, 2.617961052 / 0.9, 10, 0.461883884, 0.231964429, 0.10772883, 0.005534931 / 0.9],
  film46k: [0.195367159 / 0.9, -0.014273567 / 0.9, 0.36274758, 1.05345192 * 0.9, 10, 0.63659829, 0.027616437, 0.096214896, 0.004523664 * 0.9]
};
const inputs = [-0.2, -0.05, 0, 0.05, 0.18, 0.2, 0.5, 1, 4];
const apply = (curve, x, method) => { const a = new Float64Array([x]); curve[method](a.buffer); return { input: x, output: String(a[0]) }; };
const curves = {};
for (const [name, params] of Object.entries(variants)) {
  const curve = new context.LUTGammaLog(name, params);
  curves[name] = {
    params: params.map(String),
    encodeCut: String(params[8]), decodeCut: String(params[7]),
    encode: inputs.map(x => apply(curve, x, 'linToD')),
    decode: [0, params[7] - 1e-15, params[7], params[7] + 1e-15, 0.2, 0.5, 1].map(x => apply(curve, x, 'linFromD'))
  };
}
const output = { precision: 64, source: 'js/gamma.js:LUTGammaLog BMD Film family', sourceSHA256: crypto.createHash('sha256').update(source).digest('hex'), variants: curves };
const target = path.join(root, 'tests/fixtures/native-contracts/bmd-film-legacy-reference.json');
fs.writeFileSync(target, JSON.stringify(output, null, 2) + '\n');
console.log(JSON.stringify({ path: target, sourceSHA256: output.sourceSHA256 }));
