'use strict';
// Research-only actual legacy preparation and evaluation; never bundled.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({console,addEventListener(){},postMessage(){}}),sourceSHA256={};
for(const name of ['lut.js','ring.js','bounding.js','brent.js','gamma.js']){
 const src=fs.readFileSync(path.join(root,'js',name),'utf8');sourceSHA256[name]=crypto.createHash('sha256').update(src).digest('hex');vm.runInContext(src,c,{filename:name});
}
const e=new c.LUTGamma(),names=e.gammas.map(g=>g.name);e.tweaks=true;e.nul=false;
const cases=[],invalid=[],survey={prepared:0,fallback:0,nonMonotonic:0,invalidSplit:0,examples:[]};
function prepare(name,p,cdl){
 e.curOut=names.indexOf(name);if(e.curOut<0)throw new Error('Missing '+name);
 e.doASCCDL=!!cdl;e.asc=Float64Array.from(cdl??[1,1,1,0,0,0,1,1,1,1]);
 const feedback=e.setKnee({twkKnee:{doKnee:true,...p}});
 return {feedback,active:e.doKnee,coefficients:[e.kS,e.kC,e.kL,e.kR,e.kp0,e.kp1,e.kp2,e.kd0,e.kd1,e.kd2,e.ks,e.kD2]};
}
const variants=['Rec709','DJI D-Log2',names.includes('Sony S-Log3')?'Sony S-Log3':'S-Log3','Scene Reflectance'];
const parameters=[
 {kneeStart:.05,kneeClip:6,clipSlope:.25,smoothness:1,legal:true},
 {kneeStart:-5,kneeClip:.05,clipSlope:0,smoothness:0,legal:true},
 {kneeStart:2,kneeClip:8,clipSlope:2.5,smoothness:.35,legal:false},
 {kneeStart:-2,kneeClip:4,clipSlope:1,smoothness:1,legal:false},
 {kneeStart:7.5,kneeClip:8,clipSlope:.25,smoothness:1,legal:true}
];
for(const name of variants)for(const p of parameters)for(const cdl of [null,[1.25,.75,1.5,-.125,.0625,-.25,.5,1.25,2.5,.625],[.001,.001,.001,0,0,0,1,1,1,1]]){
 const q=prepare(name,p,cdl),xs=[-2,-0,0,.2,e.kL,e.kL*(1-Number.EPSILON),e.kL*(1+Number.EPSILON),.2*2**e.kC];
 for(let i=0;i<=128;i++)xs.push(.2*2**(e.kS+(e.kC-e.kS)*i/64));
 const values=Float64Array.from(xs);if(e.doKnee)e.kneeOut(values.buffer);else e.gammas[e.curOut].linToL(values.buffer);
 cases.push({name,parameters:p,cdl,maximumStart:String(q.feedback.max),active:q.active,coefficients:q.coefficients.map(String),
  probes:xs.map((x,i)=>({input:String(x),encoded:String(e.gammas[e.curOut].linToLegal(x)),output:String(values[i])}))});
}
for(const p of [{kneeStart:0,kneeClip:0,clipSlope:.25,smoothness:1,legal:true},{kneeStart:1,kneeClip:.05,clipSlope:0,smoothness:1,legal:true}]){
 const q=prepare('DJI D-Log2',p,null);invalid.push({reason:'nonpositive span',parameters:p,...q,coefficients:q.coefficients.map(String)});
}
const negative=[0,0,0,-1,-1,-1,1,1,1,1],q=prepare('Rec709',parameters[0],negative);
invalid.push({reason:'nonpositive CDL clip luminance',parameters:parameters[0],cdl:negative,...q,coefficients:q.coefficients.map(String)});
// Dense preparation survey exposes legacy monotonicity claims, including its
// unchecked second segment. Values remain diagnostic, never acceptance tables.
for(const name of variants)for(const start of [-5,-2,0,.05,1,4,7.5])for(const clip of [.05,1,4,6,8])for(const slope of [0,.25,2.5]){
 if(start>=clip)continue;
 prepare(name,{kneeStart:start,kneeClip:clip,clipSlope:slope,smoothness:1,legal:true},null);survey.prepared++;
 if(e.ks!==.5)survey.fallback++;
 if(!(e.ks>0&&e.ks<1)){survey.invalidSplit++;continue;}
 let last=-Infinity,decrease=false;
 for(let i=0;i<=1000;i++){
  const x=.2*2**(e.kS+e.kR*i/1000),y=e.kneeVal(x);
  if(y<last-1e-12)decrease=true;last=y;
 }
 if(decrease){survey.nonMonotonic++;if(survey.examples.length<12)survey.examples.push({name,start,clip,slope,split:e.ks,coefficients:[e.kp0,e.kp1,e.kp2,e.kd0,e.kd1,e.kd2].map(String)});}
}
const output=JSON.stringify({sourceSHA256,cases,invalid,survey},null,2)+'\n',target=path.join(root,'tests/fixtures/native-contracts/knee-legacy-reference.json');
if(process.argv.includes('--check')){if(fs.readFileSync(target,'utf8')!==output)throw new Error('Knee legacy changed');console.log('旧Knee '+cases.length+'组 '+cases.reduce((n,v)=>n+v.probes.length,0)+'点和调查一致');}
else{fs.writeFileSync(target,output);console.log(JSON.stringify(survey));}
