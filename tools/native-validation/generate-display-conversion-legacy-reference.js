'use strict';
// Research-only exact displayOut, including its strict buffer inverse branches.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({console,addEventListener(){},postMessage(){}}),sourceSHA256={};
for(const name of ['lut.js','ring.js','bounding.js','brent.js','gamma.js']){
 const src=fs.readFileSync(path.join(root,'js',name),'utf8');sourceSHA256[name]=crypto.createHash('sha256').update(src).digest('hex');vm.runInContext(src,c,{filename:name});
}
const e=new c.LUTGamma();e.tweaks=true;
const curves=[['rec709','Rec709'],['rec2020','Rec2020 12-bit'],['srgb','sRGB'],['dci26','DCI'],['sceneIRE','Scene Linear IRE'],['sceneReflectance','Scene Reflectance'],['cieLStar','CIE L*'],['bbc04','BBC 0.4'],['bbc05','BBC 0.5'],['bbc06','BBC 0.6'],['proPhoto','ProPhoto / ROMM']];
for(let i=15;i<=26;i++)curves.push(['gamma'+i,'γ'+(i/10).toFixed(1)]);
const gamuts=['rec709','rec2020','srgb','p3DCI','p3D60','p3D65','proPhoto'];
function next(x,dir){if(x===0)return dir>0?Number.MIN_VALUE:-Number.MIN_VALUE;const a=new Float64Array([x]),b=new BigUint64Array(a.buffer);b[0]+=BigInt((x>0)=== (dir>0)?1:-1);return a[0];}
const cases=[];
function make(base,out,baseGamut,outGamut,oneD){
 const i=e.gammas.findIndex(g=>g.name===base[1]),o=e.gammas.findIndex(g=>g.name===out[1]);
 if(Math.min(i,o)<0)throw new Error('Missing registration');
 e.setDisplay({twkDisplay:{doDisplay:true,inIdx:i,outIdx:o,inGt:gamuts.indexOf(baseGamut),outGt:gamuts.indexOf(outGamut)}});
 const points=[[-.5,-.2,-.01],[0,0,0],[.18,.18,.18],[1,1,1],[2,0,0],[0,2,0],[0,0,2],[8,-.25,.1]];
 if(e.gammas[i].params){const cut=e.gammas[i].params[4];for(const x of [next(cut,-1),cut,next(cut,1)])points.push([x,x,x]);}
 for(let j=0;j<32;j++)points.push([j%7/2-.5,j%11/3-1,j%13/4-.75]);
 const probes=points.map(p=>{const a=Float64Array.from(p);if(oneD)e.displayOut(a.buffer);else e.displayOut(a.buffer,{rgb:true});return {input:p.map(String),output:Array.from(a,String)};});
 cases.push({baseCurve:base[0],outputCurve:out[0],baseGamut,outputGamut:outGamut,oneD,probes});
}
for(const a of curves)for(const b of curves)make(a,b,'rec709','rec709',false);
for(const a of gamuts)for(const b of gamuts)for(const oneD of [false,true])make(curves[0],curves[2],a,b,oneD);
const output=JSON.stringify({sourceSHA256,curveParameters:curves.map(([id,name])=>({id,name,params:e.gammas.find(x=>x.name===name).params??null})),cases},null,2)+'\n',p=path.join(root,'tests/fixtures/native-contracts/display-conversion-legacy-reference.json');
if(process.argv.includes('--check')){if(fs.readFileSync(p,'utf8')!==output)throw new Error('Display reference changed');console.log('旧显示转换'+cases.length+'组/'+cases.reduce((n,x)=>n+x.probes.length*3,0)+'通道一致');}
else{fs.writeFileSync(p,output);console.log('已生成旧显示转换'+cases.length+'组/'+cases.reduce((n,x)=>n+x.probes.length*3,0)+'通道');}
