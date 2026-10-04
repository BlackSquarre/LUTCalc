'use strict';
// Snapshot the executable registry and direct baked-sample dependencies.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const files = ['lut.js', 'ring.js', 'bounding.js', 'brent.js', 'gamma.js', 'colourspace.js', 'lutcamerabox.js'];
const c = vm.createContext({Float64Array, Float32Array, Int8Array, Int16Array,
  Uint8Array, Uint16Array, ArrayBuffer, console, addEventListener() {}, postMessage() {}});
for (const file of files) vm.runInContext(fs.readFileSync(path.join(root, 'js', file), 'utf8'), c, {filename: file});
const ga = new c.LUTGamma(), cs = new c.LUTColourSpace();
const camera = {cameras: []};
c.LUTCameraBox.prototype.cameraList.call(camera);
const tableClasses = ['LUTGammaIOLUT', 'LUTGammaLUTSL3', 'LUTGammaLUTSimple', 'LUTGammaDLog'];
const classes = Object.keys(c).filter(k => /^LUTGamma/.test(k) && typeof c[k] === 'function');
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(path.join(root, file))).digest('hex');
const gammas = ga.gammas.map((g, index) => ({index, name: g.name,
  class: classes.find(k => g instanceof c[k]),
  sampleTableBased: tableClasses.some(k => g instanceof c[k]),
  defaultGamut: ga.gts[index], dataDefault: ga.gammaDat[index]}));
const assets = fs.readdirSync(root).filter(p => p.endsWith('.labin')).map(p => ({path: p,
  bytes: fs.statSync(path.join(root, p)).size, sha256: hash(p)}));
const result = {date: '2026-09-23', method: '运行散装 JS 注册表；sampleTableBased 只标记四个已审计的直接采样表类，不代表其余条目已经全部证明为纯算法。',
  gammas, matrixGamuts: cs.g.map(g => g.name), inputGamuts: cs.csIn.map(g => g.name),
  outputGamuts: cs.csOut.map(g => g.name), cameras: camera.cameras, assets,
  sourceHashes: files.map(p => ({path: 'js/' + p, sha256: hash('js/' + p)}))};
const output = path.join(root, 'research/colour/2026-09-23/current-inventory.json');
fs.mkdirSync(path.dirname(output), {recursive: true});
fs.writeFileSync(output, JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({gammaCount: gammas.length, matrixCount: cs.g.length,
  cameraCount: camera.cameras.length, tableCount: gammas.filter(g => g.sampleTableBased).length,
  tableGammas: gammas.filter(g => g.sampleTableBased).map(g => ({name: g.name, class: g.class})),
  cameras: camera.cameras.map(x => x.make + ' ' + x.model)}, null, 2));
