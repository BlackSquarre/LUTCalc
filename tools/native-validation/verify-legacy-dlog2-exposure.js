'use strict';
// Research-only source and Float64 fixture provenance check.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const root = path.resolve(__dirname, '../..');
const args = process.argv.slice(2);
if (args.length !== 0 && (![4, 6].includes(args.length) || args[0] !== '--metadata' ||
    args[2] !== '--binary' || (args.length === 6 && args[4] !== '--stages'))) {
  throw new Error('usage: [--metadata metadata.json --binary samples.f64 [--stages stages.json]]');
}
const metadataPath = args.length ? path.resolve(args[1]) :
  path.join(root, 'tests/fixtures/native-contracts/legacy-dlog2-exposure17.json');
const binaryPath = args.length ? path.resolve(args[3]) :
  path.join(root, 'tests/fixtures/native-contracts/legacy-dlog2-exposure17.f64');
const metadata = JSON.parse(fs.readFileSync(metadataPath, 'utf8'));
if (![17, 33, 65].includes(metadata.size) || metadata.littleEndianFloat64 !== true ||
    metadata.nodeOrder !== 'R-fast, G-middle, B-slow' || metadata.exposureGain !== 2 ||
    !['Data', 'Legal'].includes(metadata.inputRange) ||
    !['Data', 'Legal'].includes(metadata.outputRange) ||
    metadata.inputTransfer !== 'DJI D-Log2' || metadata.outputTransfer !== 'DJI D-Log2' ||
    metadata.inputSpace !== 'DJI D-Gamut2' || metadata.outputSpace !== 'DJI D-Gamut2') {
  throw new Error('legacy fixture metadata mismatch');
}
const expectedSources = ['lut.js', 'ring.js', 'bounding.js', 'brent.js', 'gamma.js', 'colourspace.js'];
if (Object.keys(metadata.sourceHashes).sort().join() !== expectedSources.slice().sort().join()) {
  throw new Error('legacy source set mismatch');
}
for (const file of expectedSources) {
  const actual = crypto.createHash('sha256').update(fs.readFileSync(path.join(root, 'js', file))).digest('hex');
  if (actual !== metadata.sourceHashes[file]) throw new Error(`legacy source changed: ${file}`);
}
const binary = fs.readFileSync(binaryPath);
if (binary.length !== metadata.size ** 3 * 3 * 8) throw new Error('legacy Float64 byte count mismatch');
const hash = crypto.createHash('sha256').update(binary).digest('hex');
if (hash !== metadata.binarySHA256) throw new Error('legacy Float64 SHA-256 mismatch');
if (args.length === 6) {
  const stage = JSON.parse(fs.readFileSync(path.resolve(args[5]), 'utf8'));
  if (metadata.size !== 17 || metadata.inputRange !== 'Data' || metadata.outputRange !== 'Data' ||
      stage.size !== metadata.size || stage.inputRange !== metadata.inputRange ||
      stage.outputRange !== metadata.outputRange || stage.exposureGain !== 2 ||
      stage.legacyLinearToSceneScale !== 0.9 ||
      JSON.stringify(stage.sourceHashes) !== JSON.stringify(metadata.sourceHashes) ||
      stage.sampling.seed !== '0x5eed2026' || stage.sampling.count !== 32 ||
      stage.sampling.algorithm !== 'LCG32 1664525/1013904223, uint32 wrap, modulo node count') {
    throw new Error('legacy stage metadata mismatch');
  }
  const indices = new Set([0, 16, 288, 4912, 2456]);
  let state = 0x5eed2026;
  while (indices.size < 32) {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    indices.add(state % (17 ** 3));
  }
  if (!Array.isArray(stage.samples) || stage.samples.length !== 32 ||
      stage.samples.map(sample => sample.index).join() !== Array.from(indices).sort((a, b) => a - b).join()) {
    throw new Error('legacy stage sample indices mismatch');
  }
  for (const sample of stage.samples) {
    for (const key of ['decodedLegacy', 'colorLegacy', 'encodedData']) {
      if (!Array.isArray(sample[key]) || sample[key].length !== 3 || !sample[key].every(Number.isFinite)) {
        throw new Error(`legacy stage channel mismatch: ${sample.index}/${key}`);
      }
    }
    for (let channel = 0; channel < 3; channel++) {
      if (sample.encodedData[channel] !== binary.readDoubleLE((sample.index * 3 + channel) * 8)) {
        throw new Error(`legacy stage final output mismatch: ${sample.index}/${channel}`);
      }
    }
  }
  console.log(`旧阶段诊断 32 个固定种子节点与完整 Float64 输出一致`);
}
console.log(`旧完整链 ${metadata.size}³ 夹具与六份源码哈希通过：${hash}`);
