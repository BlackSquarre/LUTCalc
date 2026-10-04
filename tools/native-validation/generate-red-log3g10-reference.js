'use strict';

// 研发参照：直接执行旧 gamma.js 的 RED Log3G10 LUTGammaLogLog 方法。
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const crypto = require('node:crypto');

const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'js/gamma.js'), 'utf8');
const context = vm.createContext({ Float64Array, Float32Array, Uint8Array, ArrayBuffer, Math });
vm.runInContext(source, context, { filename: 'gamma.js' });
const params = [0.224282, 155.975327, 0.01];
const curve = new context.LUTGammaLogLog('RED Log3G10', params);
const values = [-0.2, -0.1, -0.01, -0.01 + 1e-15, 0, 0.1, 0.18, 0.2, 0.5, 1, 4];
const apply = (x, method) => {
  const a = new Float64Array([x]);
  curve[method](a.buffer);
  return { input: x, output: String(a[0]) };
};
const wrapper = {
  scale: '0.85630498533724',
  offset: '0.06256109481916'
};
const output = {
  precision: 64,
  source: 'js/gamma.js:LUTGammaLogLog RED Log3G10',
  sourceSHA256: crypto.createHash('sha256').update(source).digest('hex'),
  params: params.map(String),
  wrapper,
  encode: values.map(x => apply(x, 'linToD')),
  decode: [0, 0.06256109481916, 0.1, 0.2, 0.5, 0.85630498533724, 1].map(x => apply(x, 'linFromD'))
};
const target = path.join(root, 'tests/fixtures/native-contracts/red-log3g10-legacy-reference.json');
fs.writeFileSync(target, JSON.stringify(output, null, 2) + '\n');
console.log(JSON.stringify({ path: target, sourceSHA256: output.sourceSHA256 }));
