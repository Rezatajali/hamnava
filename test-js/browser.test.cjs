const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const code = fs.readFileSync(require('node:path').join(__dirname, '../web/browser.js'), 'utf8');
function browser(extra = {}) {
  const memory = new Map();
  const context = {console, setTimeout, clearTimeout, Blob, addEventListener(){},
    sessionStorage:{getItem:k=>memory.get(k),setItem:(k,v)=>memory.set(k,v),removeItem:k=>memory.delete(k)},
    ...extra};
  vm.createContext(context); vm.runInContext(code,context); return context;
}
test('unsupported browser reports capabilities and never claims recognition', async () => {
  const b = browser(); assert.equal(b.hamnavaCanRecord(), false); assert.equal(b.hamnavaCanRecognize(), false);
  const events=[]; assert.equal(await b.hamnavaStart('', 'fa-IR', raw=>events.push(JSON.parse(raw))), false);
  assert.equal(events[0].value,'speech-unavailable'); assert.equal(await b.hamnavaStop(),'');
});
test('recognition emits final text separately from interim and stops cleanly', async () => {
  let instance;
  class Recognition { constructor(){instance=this;} start(){} stop(){this.onend();} abort(){} }
  const b=browser({SpeechRecognition:Recognition}); const events=[];
  assert.equal(await b.hamnavaStart('', 'fa-IR', raw=>events.push(JSON.parse(raw))),true);
  const final=[{transcript:'امروز خوب بود'}];final.isFinal=true;const interim=[{transcript:'و فردا'}];interim.isFinal=false;
  instance.onresult({resultIndex:0,results:[final,interim]});
  assert.equal(events.find(e=>e.type==='text').value,'امروز خوب بود');
  assert.equal(events.find(e=>e.type==='interim').value,'و فردا');
  assert.equal(await b.hamnavaStart('', 'fa-IR',()=>{}),false);
  await b.hamnavaStop(); assert.equal(events.at(-1).type,'stopped');
});
test('microphone denial leaves no active session', async () => {
  const b=browser({isSecureContext:true,MediaRecorder:function(){},navigator:{mediaDevices:{getUserMedia:async()=>{throw {name:'NotAllowedError'};}}}});
  const events=[];assert.equal(await b.hamnavaStart('uid/clip','fa-IR',raw=>events.push(JSON.parse(raw))),false);
  assert.equal(events[0].value,'permission-denied');assert.equal(await b.hamnavaStop(),'');
});
test('cancel while permission is pending releases late microphone stream', async () => {
  let resolve, stopped=0;
  const b=browser({isSecureContext:true,MediaRecorder:function(){},navigator:{mediaDevices:{getUserMedia:()=>new Promise(r=>resolve=r)}}});
  const start=b.hamnavaStart('uid/clip','fa-IR',()=>{});b.hamnavaCancel();
  resolve({getTracks:()=>[{stop:()=>stopped++}]});assert.equal(await start,false);assert.equal(stopped,1);
});
test('drafts are scoped to user and clearing one does not affect another', () => {
  const b=browser();b.hamnavaSetDraft('a','private');b.hamnavaSetDraft('b','other');
  b.hamnavaSetDraft('a','');assert.equal(b.hamnavaDraft('a'),'');assert.equal(b.hamnavaDraft('b'),'other');
});
test('speech synthesis refuses to substitute a different language', async () => {
  let spoken=false;
  const b=browser({speechSynthesis:{getVoices:()=>[{lang:'en-US'}],cancel(){},speak(){spoken=true;}}});
  assert.equal(await b.hamnavaSpeak('سلام','fa-IR'),false);assert.equal(spoken,false);
});
