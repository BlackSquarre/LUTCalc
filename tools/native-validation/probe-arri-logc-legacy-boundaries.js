'use strict';
// Research-only execution of the frozen legacy curve; no production dependency.
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm'), crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'js/gamma.js'), 'utf8');
const context = vm.createContext({console});
vm.runInContext(source, context, {filename: 'gamma.js'});
function nextUp(x) {
    const view = new DataView(new ArrayBuffer(8));
    view.setFloat64(0,x); view.setBigUint64(0,view.getBigUint64(0)+1n); return view.getFloat64(0);
}
const cases = [];
for (const ei of [800,1600,2000,2560,3200]) {
    const curve = new context.LUTGammaArri('LogC probe',3);
    curve.changeISO(ei); curve.changeRange(false,false);
    const probes = [];
    for (const linear of [0,.2,.8/.9,1,5,10,20,50,100]) {
        const scalar = curve.linToData(linear);
        const values = new Float64Array([linear]); curve.linToD(values.buffer);
        probes.push({linear,scalar,vector:values[0],absoluteDifference:Math.abs(scalar-values[0])});
    }
    const unit = curve.linFromData(1), justAboveUnit = curve.linFromData(nextUp(1));
    cases.push({ei,knee:curve.knee,xm:curve.xm,probes,
        decodeUnit:unit,decodeJustAboveUnit:justAboveUnit,decodeDiscontinuity:justAboveUnit-unit});
}
const result = {sourceSHA256:crypto.createHash('sha256').update(source).digest('hex'),
    scope:'实际旧SUP3标量/数组编码与高ISO解码延拓差异；不作为正确公式参照',cases};
const target = path.join(root,'docs/native-validation/artifacts/2026-10-02-logc-compact/legacy-boundary-probe.json');
fs.writeFileSync(target,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(cases.map(c=>({ei:c.ei,knee:c.knee,xm:c.xm,
    maximumScalarVectorDifference:Math.max(...c.probes.map(p=>p.absoluteDifference)),decodeDiscontinuity:c.decodeDiscontinuity})),null,2));
