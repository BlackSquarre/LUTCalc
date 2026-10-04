'use strict';
// 研发用：直接执行旧 gamma.js 的 Canon C-Log 方法，禁止进入 App。
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'js/gamma.js'), 'utf8');
const context = vm.createContext({ Float64Array, Float32Array, Uint8Array, ArrayBuffer });
vm.runInContext(source, context, { filename: 'gamma.js' });
const params = [0.3734467748,-0.0467265867,0.45310179472141,10.1596,10,0.1251224801564,1,0.00391002619746,-0.0452664];
const curve = new context.LUTGammaLog('C-Log', params);
const values = [-0.1,-0.0467265867,-0.0452664,0,0.00391002619746,0.18,0.2,0.5,1,4];
const apply = (x, method) => { const a = new Float64Array([x]); curve[method](a.buffer); return {input:x,output:String(a[0])}; };
const output = {precision:64,sourceSHA256:crypto.createHash('sha256').update(source).digest('hex'),encode:values.map(x=>apply(x,'linToD')),decode:values.map(x=>apply(x,'linFromD'))};
const target=path.join(root,'tests/fixtures/native-contracts/canon-clog-legacy-reference.json');fs.writeFileSync(target,JSON.stringify(output)+'\n');console.log(JSON.stringify({path:target,sourceSHA256:output.sourceSHA256}));
