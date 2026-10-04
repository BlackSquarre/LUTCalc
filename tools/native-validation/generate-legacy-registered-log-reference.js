'use strict';
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),source=fs.readFileSync(path.join(root,'js/gamma.js'),'utf8');
const context=vm.createContext({Float64Array,Float32Array,Uint8Array,ArrayBuffer,Math}); vm.runInContext(source,context,{filename:'gamma.js'});
const params={
 bolex:[1/(5.9861078*0.9),-0.0625265/(0.9*5.9861078),0.2756705,5,10,0.4150634,0.0280665,0.1520070,0.014948/0.9],
 panalog:[0.324196014,-0.020278938,0.434198361,0.956463747,10,0.665276427,0.040913561,0.088290045,0],
 djiX5:[1/(6.025*0.9),-0.0929/(6.025*0.9),0.256663,0.9892*0.9,10,0.584555,0.0108,0.14,0.0078*0.9],
 protune:[0,0,876/1023,53.39427221,113,64/1023,1,0,0]
};
const values=[-0.2,-0.05,0,0.05,0.18,0.2,0.5,1,4];
const apply=(c,x,m)=>{const a=new Float64Array([x]);c[m](a.buffer);return {input:x,output:String(a[0])};};
const variants={}; for(const [name,p] of Object.entries(params)){const c=new context.LUTGammaLog(name,p);variants[name]={params:p.map(String),encode:values.map(x=>apply(c,x,'linToD')),decode:[0,p[7]-1e-15,p[7],p[7]+1e-15,0.2,0.5,1].map(x=>apply(c,x,'linFromD'))};}
const out={precision:64,source:'js/gamma.js:LUTGammaLog Bolex/Panalog/DJI X5',sourceSHA256:crypto.createHash('sha256').update(source).digest('hex'),variants};
fs.writeFileSync(path.join(root,'tests/fixtures/native-contracts/legacy-registered-log-reference.json'),JSON.stringify(out,null,2)+'\n'); console.log(JSON.stringify({path:'tests/fixtures/native-contracts/legacy-registered-log-reference.json',sourceSHA256:out.sourceSHA256}));
