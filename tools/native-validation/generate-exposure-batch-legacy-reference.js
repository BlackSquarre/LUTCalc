'use strict';
// Research-only execution of camera and set-generation handlers; no DOM app.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),context=vm.createContext({console,modalBox:{className:''}}),sourceSHA256={};
for(const name of ['lutcamerabox.js','lutgeneratebox.js']) {
 const source=fs.readFileSync(path.join(root,'js',name),'utf8');sourceSHA256[name]=crypto.createHash('sha256').update(source).digest('hex');vm.runInContext(source,context,{filename:name});
}
const cameraBox={cameras:[]};context.LUTCameraBox.prototype.cameraList.call(cameraBox);
const cameraCases=[];
for(const camera of cameraBox.cameras)for(const recorded of [camera.iso,camera.iso*3+1]) {
 const box={cameras:[camera],current:0,cineeiInput:{value:String(recorded)},nativeLabel:{innerHTML:String(camera.iso)},shiftInput:{value:'0'}};
 context.LUTCameraBox.prototype.changeCineEI.call(box);
 cameraCases.push({camera,recordedISO:recorded,stopShift:String(box.shiftInput.value),workerGain:String(Math.pow(2,parseFloat(box.shiftInput.value))),exactISORatio:String(recorded/camera.iso)});
}
function run(minimum,maximum,parts){
 const values=[],box={inputs:{name:{value:'Probe'},stopShift:{value:'0.125'},d:[{checked:true}],isApp:false,isChromeApp:false},
 genSetMin:{options:[{value:minimum}],selectedIndex:0},genSetMax:{options:[{value:maximum}],selectedIndex:0},genSetStep:{options:[{value:parts}],selectedIndex:0},
 setProgText:{innerHTML:''},setProgHolder:{className:''},dimension:1,lT:0,lut:new Float64Array(3),formats:{output(){}},
 oneDLUT(){values.push({stop:String(this.setVal),gain:String(Math.pow(2,this.setVal)),visibleStop:String(this.inputs.stopShift.value),filename:String(this.inputs.name.value)});
 context.LUTGenerateBox.prototype.got1D.call(this,{o:new Float64Array(3).buffer,start:0,vals:1});}};
 try{context.LUTGenerateBox.prototype.generateSet.call(box);return {minimum,maximum,subdivisions:parts,values,restoredName:box.inputs.name.value,restoredStop:box.inputs.stopShift.value};}
 catch(error){return {minimum,maximum,subdivisions:parts,values,error:String(error)};}
}
const cases=[];for(const min of [-4,-3,-2,-1])for(const max of [1,2,3,4])for(const parts of [1,2,3,4])cases.push(run(min,max,parts));
const output=JSON.stringify({sourceSHA256,cameras:cameraBox.cameras,cameraCases,cases,minimumZeroReproduction:run(0,1,3)},null,2)+'\n';
const target=path.join(root,'tests/fixtures/native-contracts/exposure-batch-legacy-reference.json');
if(process.argv.includes('--check')){if(fs.readFileSync(target,'utf8')!==output)throw new Error('Exposure/camera research changed');console.log('旧64组曝光序列、66个相机注册和最小复现一致');}
else{fs.writeFileSync(target,output);console.log('已冻结旧64组曝光序列、66个相机注册和最小复现');}
