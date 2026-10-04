'use strict';
// 研发用：直接运行旧曲线方法，禁止加入 App 或运行依赖。
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'js/gamma.js'), 'utf8');
const context = vm.createContext({ Float64Array, Float32Array, Uint8Array, ArrayBuffer });
vm.runInContext(source, context, { filename: 'gamma.js' });
const independent = JSON.parse(fs.readFileSync(path.join(root,
  'tests/fixtures/native-contracts/camera-transfer-decimal.json'), 'utf8'));
const curves = [
  ['nikon.nlog.lutcalc-legacy.v1', new context.LUTGammaNLog('Nikon N-Log')],
  ['cineon.lutcalc-legacy.v1', new context.LUTGammaCineon('Cineon',
    { cv: 1023, bp: 95, wp: 685, nGamma: 0.6, cv2d: 0.002 })],
];
const variants = curves.map(([id, curve]) => {
  const samples = independent.variants.find(item => item.id === id);
  const apply = (point, method) => {
    const array = new Float64Array([point.input]);
    curve[method](array.buffer);
    if (!Number.isFinite(array[0])) throw new Error('非有限旧输出');
    return { input: point.input, output: String(array[0]) };
  };
  return { id, encode: samples.encode.map(point => apply(point, 'linToD')),
    decode: samples.decode.map(point => apply(point, 'linFromD')) };
});
const output = { precision: 64, threshold: 2e-12, sourceSHA256:
  crypto.createHash('sha256').update(source).digest('hex'), variants };
const target = path.join(root, 'tests/fixtures/native-contracts/camera-transfer-legacy.json');
fs.writeFileSync(target, JSON.stringify(output) + '\n');
console.log(JSON.stringify({ path: target, sourceSHA256: output.sourceSHA256, variants: variants.length }));
