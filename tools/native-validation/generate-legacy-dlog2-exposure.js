'use strict';
// Research-only runner for the actual legacy gamma -> colourspace -> gamma path.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const vm = require('node:vm');

const root = path.resolve(__dirname, '../..');
const args = process.argv.slice(2);
if (args.length % 2 !== 0) {
  throw new Error('usage: [--size 17|33|65] [--output-dir path] [--input-range Data|Legal] [--output-range Data|Legal]');
}
const options = new Map();
for (let index = 0; index < args.length; index += 2) {
  if (!['--size', '--output-dir', '--input-range', '--output-range', '--stage-fixture'].includes(args[index]) || options.has(args[index])) {
    throw new Error(`unknown or duplicate option: ${args[index]}`);
  }
  options.set(args[index], args[index + 1]);
}
const size = Number(options.get('--size') || 17);
if (![17, 33, 65].includes(size)) throw new Error('unsupported grid size');
const inputRange = options.get('--input-range') || 'Data';
const outputRange = options.get('--output-range') || 'Data';
const stageFixture = options.get('--stage-fixture');
if (!['Data', 'Legal'].includes(inputRange) || !['Data', 'Legal'].includes(outputRange)) {
  throw new Error('unsupported signal range');
}
if (stageFixture && (size !== 17 || inputRange !== 'Data' || outputRange !== 'Data')) {
  throw new Error('stage diagnostics currently require 17³ Data→Data');
}
const directory = options.has('--output-dir') ? path.resolve(options.get('--output-dir')) :
  path.join(root, 'tests/fixtures/native-contracts');
if (!fs.statSync(directory).isDirectory()) throw new Error('output directory missing');
const files = ['lut.js', 'ring.js', 'bounding.js', 'brent.js', 'gamma.js', 'colourspace.js'];
const context = vm.createContext({Float64Array, Float32Array, Int8Array, Int16Array,
  Uint8Array, Uint16Array, ArrayBuffer, console, addEventListener() {}, postMessage() {}});
const hashes = {};
for (const file of files) {
  const source = fs.readFileSync(path.join(root, 'js', file), 'utf8');
  hashes[file] = crypto.createHash('sha256').update(source).digest('hex');
  vm.runInContext(source, context, {filename: file});
}

const engine = new context.LUTGamma();
const color = new context.LUTColourSpace();
const gamma = engine.gammas.findIndex(value => value.name === 'DJI D-Log2');
const inputSpace = color.csIn.findIndex(value => value.name === 'DJI D-Gamut2');
const outputSpace = color.csOut.findIndex(value => value.name === 'DJI D-Gamut2');
if (gamma < 0 || inputSpace < 0 || outputSpace < 0) throw new Error('registry ID missing');
engine.curIn = gamma;
engine.curOut = gamma;
engine.inL = inputRange === 'Legal';
engine.outL = outputRange === 'Legal';
engine.eiMult = 2;
engine.clip = false;
engine.bClip = -1e9;
engine.wClip = 1e9;
color.curIn = inputSpace;
color.curOut = outputSpace;

const diagnosticIndices = new Set();
if (stageFixture) {
  for (const index of [0, size - 1, size * size - 1, size ** 3 - 1, (size ** 3 - 1) / 2]) {
    diagnosticIndices.add(index);
  }
  let state = 0x5eed2026;
  while (diagnosticIndices.size < 32) {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    diagnosticIndices.add(state % (size ** 3));
  }
}
const stageSamples = [];
const output = Buffer.alloc(size ** 3 * 3 * 8);
for (let b = 0; b < size; b++) {
  const decoded = engine.inCalcRGB(0, 3, {R: 0, G: 0, B: b, vals: size * size, dim: size});
  const decodedValues = stageFixture ? new Float64Array(decoded.o).slice() : null;
  const converted = color.calc(0, 1, decoded, true);
  const convertedValues = stageFixture ? new Float64Array(converted.o).slice() : null;
  const values = new Float64Array(engine.outCalcRGB(0, 4, converted).o);
  if (values.length !== size * size * 3) throw new Error(`wrong plane length ${b}`);
  if (stageFixture) {
    for (let local = 0; local < size * size; local++) {
      const index = b * size * size + local;
      if (diagnosticIndices.has(index)) {
        const offset = local * 3;
        stageSamples.push({index,
          decodedLegacy: Array.from(decodedValues.slice(offset, offset + 3)),
          colorLegacy: Array.from(convertedValues.slice(offset, offset + 3)),
          encodedData: Array.from(values.slice(offset, offset + 3))});
      }
    }
  }
  for (let index = 0; index < values.length; index++) {
    output.writeDoubleLE(values[index], (b * size * size * 3 + index) * 8);
  }
}
const suffix = inputRange === 'Data' && outputRange === 'Data' ? '' :
  `-in${inputRange}-out${outputRange}`;
const binary = path.join(directory, `legacy-dlog2-exposure${size}${suffix}.f64`);
const metadata = path.join(directory, `legacy-dlog2-exposure${size}${suffix}.json`);
fs.writeFileSync(binary, output);
fs.writeFileSync(metadata, JSON.stringify({
  source: 'Legacy LUTGamma.inCalcRGB -> LUTColourSpace.calc(g=true) -> LUTGamma.outCalcRGB',
  sourceHashes: hashes,
  size,
  nodeOrder: 'R-fast, G-middle, B-slow',
  littleEndianFloat64: true,
  inputTransfer: 'DJI D-Log2', outputTransfer: 'DJI D-Log2',
  inputSpace: 'DJI D-Gamut2', outputSpace: 'DJI D-Gamut2',
  exposureGain: 2, inputRange, outputRange,
  binarySHA256: crypto.createHash('sha256').update(output).digest('hex'),
}, null, 2) + '\n');
if (stageFixture) {
  fs.writeFileSync(path.resolve(stageFixture), JSON.stringify({
    source: 'Legacy full path stage samples before colourspace, before output gamma, after output gamma',
    sourceHashes: hashes,
    size, inputRange, outputRange, exposureGain: 2,
    sampling: {algorithm: 'LCG32 1664525/1013904223, uint32 wrap, modulo node count',
      seed: '0x5eed2026', count: 32, endpointsAndCenter: true},
    legacyLinearToSceneScale: 0.9,
    samples: stageSamples,
  }, null, 2) + '\n');
  console.log(`旧引擎固定种子阶段样本：${path.resolve(stageFixture)}，${stageSamples.length} 节点`);
}
console.log(`旧引擎 ${size}³ ${inputRange}→${outputRange} Float64 基线：${binary}，SHA-256 ${crypto.createHash('sha256').update(output).digest('hex')}`);
