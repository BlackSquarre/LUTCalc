'use strict';
// 研发用：直接执行旧 gamma.js 的 Sony S-Log/S-Log2 方法，禁止进入 App。
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'js/gamma.js'), 'utf8');
const context = vm.createContext({ Float64Array, Float32Array, Uint8Array, ArrayBuffer });
vm.runInContext(source, context, { filename: 'gamma.js' });
const curves = [
  ['sony.slog.lutcalc-legacy.v1', [0.3241960136,-0.0286107171,0.3705223110,1,10,0.6162444740,0.0375840000,0.0882900450,0.000000000000001]],
  ['sony.slog2.lutcalc-legacy.v1', [0.330000000129966,-0.0291229262672453,0.3705223107287920,0.7077625570776260,10,0.6162444730868150,0.0375840001141552,0.0879765396,0]],
];
const points = [-0.1, 0, 0.18, 0.2, 0.328, 1, 4];
const variants = curves.map(([id, params]) => {
  const curve = new context.LUTGammaLog(id, params);
  const apply = (x, method) => { const a = new Float64Array([x]); curve[method](a.buffer); return { input:x, output:String(a[0]) }; };
  return { id, encode: points.map(x => apply(x, 'linToD')), decode: points.map(x => apply(x, 'linFromD')) };
});
const output = { precision:64, sourceSHA256:crypto.createHash('sha256').update(source).digest('hex'), variants };
const target = path.join(root, 'tests/fixtures/native-contracts/sony-log-legacy-reference.json');
fs.writeFileSync(target, JSON.stringify(output) + '\n');
console.log(JSON.stringify({path:target, sourceSHA256:output.sourceSHA256, variants:variants.length}));
