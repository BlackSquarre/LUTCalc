'use strict';
// 仅用于研发验证旧 JS 注册实现；不进入 Swift App。
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const vm = require('node:vm');

const root = path.resolve(__dirname, '../..');
const source = path.join(root, 'js/gamma.js');
const official = JSON.parse(fs.readFileSync(path.join(root,
  'tests/fixtures/native-contracts/slog3-sony-reference.json'), 'utf8'));
const outputPath = path.join(root, 'tests/fixtures/native-contracts/slog3-legacy-reference.json');
const context = vm.createContext({Float64Array, Float32Array, Uint8Array, ArrayBuffer, console});
for (const name of ['lut.js', 'ring.js', 'bounding.js', 'brent.js', 'gamma.js']) {
  vm.runInContext(fs.readFileSync(path.join(root, 'js', name), 'utf8'), context, {filename: name});
}
const curve = new context.LUTGamma().gammas.find(item => item.name === 'S-Log3');
if (!curve) throw new Error('S-Log3 not registered');
const encode = scene => curve.linToData(scene / 0.9);
const decode = data => 0.9 * curve.linFromData(data);
const baseline = {
  source: 'js/gamma.js LUTGammaLog S-Log3 registration and methods; research fixture only',
  sourceSHA256: crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex'),
  algorithmVersion: 'slog3.lutcalc-legacy.v1',
  linearScale: 'legacyGrey02; scene = legacy * 0.9',
  encode: official.encode.map(({input}) => ({input, expected: encode(input)})),
  decode: official.decode.map(({input}) => ({input, expected: decode(input)})),
  fullCodeData: official.fullCodeData.map(({bits}) => ({
    bits,
    decoded: Array.from({length: 2 ** bits}, (_, code) => decode(code / (2 ** bits - 1))),
  })),
  planExposureOne: official.planExposureOne.map(({input}) => ({
    input, expected: input.map(channel => encode(2 * decode(channel))),
  })),
};
const rendered = JSON.stringify(baseline, null, 2) + '\n';
if (process.argv.includes('--check')) {
  const frozenText = fs.readFileSync(outputPath, 'utf8');
  if (frozenText === rendered) {
    // The usual path is byte-for-byte validation on the generating runtime.
  } else {
    // V8 has changed Math.log/Math.pow rounding between Node releases. Keep
    // the source hash and all non-numeric fields frozen, while allowing the
    // few-ULP drift that those equivalent runtimes can produce.
    const frozen = JSON.parse(frozenText);
    const currentSourceHash = baseline.sourceSHA256;
    if (frozen.sourceSHA256 !== currentSourceHash) {
      throw new Error('frozen legacy S-Log3 baseline source hash differs from current JS source');
    }
    const tolerance = Number.EPSILON * 8;
    let numericDifferences = 0;
    let largest = {absolute: 0, relative: 0, path: ''};
    const compare = (expected, actual, path) => {
      if (typeof expected === 'number' && typeof actual === 'number') {
        const absolute = Math.abs(expected - actual);
        const relative = absolute / Math.max(Math.abs(expected), Math.abs(actual), Number.MIN_VALUE);
        if (absolute > 0) numericDifferences++;
        if (relative > largest.relative) largest = {absolute, relative, path};
        if (relative > tolerance) {
          throw new Error(`frozen legacy S-Log3 baseline numeric drift at ${path}: ${expected} vs ${actual}`);
        }
        return;
      }
      if (Array.isArray(expected) && Array.isArray(actual)) {
        if (expected.length !== actual.length) throw new Error(`frozen legacy S-Log3 baseline length drift at ${path}`);
        for (let i = 0; i < expected.length; i++) compare(expected[i], actual[i], `${path}[${i}]`);
        return;
      }
      if (expected && actual && typeof expected === 'object' && typeof actual === 'object') {
        const expectedKeys = Object.keys(expected);
        const actualKeys = Object.keys(actual);
        if (expectedKeys.length !== actualKeys.length || expectedKeys.some(key => !Object.hasOwn(actual, key))) {
          throw new Error(`frozen legacy S-Log3 baseline key drift at ${path}`);
        }
        for (const key of expectedKeys) compare(expected[key], actual[key], `${path}.${key}`);
        return;
      }
      if (expected !== actual) throw new Error(`frozen legacy S-Log3 baseline drift at ${path}`);
    };
    compare(frozen, baseline, '$');
    console.warn(`旧 S-Log3 基线跨 Node 运行时存在 ${numericDifferences} 个数值舍入差异；最大相对差异 ${largest.relative}（${largest.path}），均在 ${tolerance} 相对门槛内`);
  }
} else {
  fs.writeFileSync(outputPath, rendered);
}
let largest = {error: -1};
for (let i = 0; i < official.fullCodeData.length; i++) {
  const a = official.fullCodeData[i];
  const b = baseline.fullCodeData[i];
  for (let code = 0; code < a.decoded.length; code++) {
    const error = Math.abs(a.decoded[code] - b.decoded[code]);
    if (error > largest.error) largest = {bits: a.bits, code, error};
  }
}
console.log(`旧 S-Log3 解码全码最大官方差异：${JSON.stringify(largest)}`);
