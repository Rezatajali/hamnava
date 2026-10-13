const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const code=fs.readFileSync(path.join(__dirname,'../web/files.js'),'utf8');
function browser({width=3200,height=2000}={}){
  const inputs=[], canvases=[], revoked=[];
  class Image {constructor(){this.naturalWidth=width;this.naturalHeight=height;}set src(_){queueMicrotask(()=>this.onload());}}
  class FileReader {async readAsDataURL(blob){this.result='data:'+blob.type+';base64,'+Buffer.from(await blob.arrayBuffer()).toString('base64');this.onload();}}
  const b={Blob,setTimeout,clearTimeout,Image,FileReader,addEventListener(){},removeEventListener(){},
    URL:{createObjectURL:()=> 'blob:test',revokeObjectURL:url=>revoked.push(url)},
    document:{body:{appendChild(){}},createElement(tag){
      if(tag==='input'){const events={};const input={style:{},files:[],setAttribute(k,v){this[k]=v;},addEventListener(k,v){events[k]=v;},click(){},remove(){this.removed=true;},cancel(){events.cancel();}};inputs.push(input);return input;}
      const canvas={getContext:()=>({fillRect(){},drawImage(){}}),toBlob:callback=>callback(new Blob(['jpeg-data'],{type:'image/jpeg'}))};canvases.push(canvas);return canvas;
    }}};
  vm.createContext(b);vm.runInContext(code,b);return {b,inputs,canvases,revoked};
}
function select(input,blob,name='scan.png'){blob.name=name;input.files=[blob];input.onchange();}
test('receipt camera picker sets capture; selected PNG becomes a bounded JPEG with original-type metadata',async()=>{
  const {b,inputs,canvases,revoked}=browser();const pending=b.hamnavaPickReceipt(true);
  assert.equal(inputs[0].capture,'environment');select(inputs[0],new Blob(['png'],{type:'image/png'}));
  const result=JSON.parse(await pending);
  assert.equal(result.originalType,'image/png');assert.equal(result.width,1600);assert.equal(result.height,1000);
  assert.equal(result.image.startsWith('data:image/jpeg;base64,'),true);assert.equal(result.bytes<=204800,true);
  assert.equal(canvases.length,1);assert.equal(inputs[0].removed,true);assert.deepEqual(revoked,['blob:test']);
});
test('cancelled gallery selection resolves and removes the picker without creating an image',async()=>{
  const {b,inputs,canvases}=browser();const pending=b.hamnavaPickReceipt(false);
  assert.equal(inputs[0].capture,undefined);inputs[0].cancel();
  assert.equal(await pending,'');assert.equal(inputs[0].removed,true);assert.equal(canvases.length,0);
});
test('SVG and oversized source files are rejected before canvas conversion',async()=>{
  const {b,inputs,canvases}=browser();let pending=b.hamnavaPickReceipt(false);
  select(inputs[0],new Blob(['<svg/>'],{type:'image/svg+xml'}),'unsafe.svg');assert.equal(JSON.parse(await pending).error,'image-format');
  pending=b.hamnavaPickReceipt(false);select(inputs[1],new Blob([new Uint8Array(16*1024*1024+1)],{type:'image/jpeg'}),'large.jpg');
  assert.equal(JSON.parse(await pending).error,'image-too-large');assert.equal(canvases.length,0);
});
test('excessive pixel dimensions are rejected and temporary image URLs are released',async()=>{
  const {b,inputs,canvases,revoked}=browser({width:8000,height:8000});const pending=b.hamnavaPickReceipt(false);
  select(inputs[0],new Blob(['png'],{type:'image/png'}));assert.equal(JSON.parse(await pending).error,'image-too-large');
  assert.equal(canvases.length,0);assert.deepEqual(revoked,['blob:test']);
});
