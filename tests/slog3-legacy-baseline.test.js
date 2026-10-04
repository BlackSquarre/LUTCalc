'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const fixture = path.join(root, 'tests/fixtures/native-contracts/slog3-legacy-reference.json');
const generator = path.join(root, 'tools/native-validation/generate-slog3-legacy-baseline.js');

function checkWithMutation(mutation) {
  const code = `
    const fs = require('node:fs');
    const original = fs.readFileSync;
    fs.readFileSync = function(file, ...args) {
      const value = original.call(this, file, ...args);
      if (String(file) !== ${JSON.stringify(fixture)}) return value;
      const frozen = JSON.parse(value);
      ${mutation}
      return JSON.stringify(frozen);
    };
    process.argv.push('--check');
    require(${JSON.stringify(generator)});
  `;
  return spawnSync(process.execPath, ['-e', code], {cwd: root, encoding: 'utf8'});
}

test('legacy S-Log3 frozen baseline accepts this Node runtime', () => {
  const result = spawnSync(process.execPath, [generator, '--check'], {cwd: root, encoding: 'utf8'});
  assert.equal(result.status, 0, result.stderr);
});

test('legacy S-Log3 frozen baseline rejects source, numeric and structural drift', () => {
  for (const mutation of [
    `frozen.sourceSHA256 = 'changed';`,
    `frozen.fullCodeData[0].decoded[1] += 0.001;`,
    `frozen.fullCodeData[0].decoded.pop();`,
    `frozen.algorithmVersion = 'changed';`,
  ]) {
    const result = checkWithMutation(mutation);
    assert.notEqual(result.status, 0, mutation);
    assert.match(result.stderr, /frozen legacy S-Log3 baseline/, mutation);
  }
});
