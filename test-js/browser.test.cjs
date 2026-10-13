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
test('recording stop persists audio locally and releases microphone tracks', async () => {
  const clips=new Map();let released=0;
  class Recorder {
    static isTypeSupported(){return true;}
    constructor(){this.state='inactive';this.mimeType='audio/webm';}
    start(){this.state='recording';}
    stop(){this.state='inactive';this.ondataavailable({data:new Blob(['audio'],{type:this.mimeType})});queueMicrotask(()=>this.onstop?.());}
  }
  const db={close(){},transaction(){
    const tx={objectStore:()=>({put:(blob,key)=>{clips.set(key,blob);return {result:key};}})};
    queueMicrotask(()=>tx.oncomplete?.());return tx;
  }};
  const b=browser({isSecureContext:true,MediaRecorder:Recorder,
    navigator:{mediaDevices:{getUserMedia:async()=>({getTracks:()=>[{stop:()=>released++}]})}},
    indexedDB:{open(){const request={result:db};queueMicrotask(()=>request.onsuccess?.());return request;}}});
  const events=[];
  assert.equal(await b.hamnavaStart('alice/clip','fa-IR',raw=>events.push(JSON.parse(raw))),true);
  assert.equal(await b.hamnavaStop(),'alice/clip');assert.equal(released,1);
  assert.equal(clips.get('alice/clip').size,5);assert.equal(events.at(-1).value,'alice/clip');
});

test('recording prefers MP4 when supported and does not start a second speech microphone', async () => {
  let recognitionStarts=0, chosenType, released=0;
  class Recognition { constructor(){recognitionStarts++;} }
  class Recorder {
    static isTypeSupported(type){return type === 'audio/mp4';}
    constructor(stream, options){chosenType=options.mimeType;this.mimeType=chosenType;this.state='inactive';}
    start(){this.state='recording';}
    stop(){this.state='inactive';this.ondataavailable({data:new Blob(['mp4'],{type:this.mimeType})});queueMicrotask(()=>this.onstop?.());}
  }
  const db={close(){},transaction(){const tx={objectStore:()=>({put:()=>({result:'clip'})})};queueMicrotask(()=>tx.oncomplete?.());return tx;}};
  const b=browser({isSecureContext:true,MediaRecorder:Recorder,webkitSpeechRecognition:Recognition,
    navigator:{mediaDevices:{getUserMedia:async()=>({getTracks:()=>[{stop:()=>released++}]})}},
    indexedDB:{open(){const request={result:db};queueMicrotask(()=>request.onsuccess?.());return request;}}});
  assert.equal(await b.hamnavaStart('alice/ios','fa-IR',()=>{}),true);
  assert.equal(chosenType,'audio/mp4');assert.equal(recognitionStarts,0);
  assert.equal(await b.hamnavaStop(),'alice/ios');assert.equal(released,1);
});
test('dictation starts synchronously in the tap and never acquires a recording stream', async () => {
  let started=0, microphoneCalls=0;
  class Recognition {start(){started++;}stop(){this.onend();}abort(){}}
  const b=browser({webkitSpeechRecognition:Recognition,navigator:{mediaDevices:{getUserMedia(){microphoneCalls++;}}}});
  const pending=b.hamnavaStart('','fa-IR',()=>{});
  assert.equal(started,1);assert.equal(microphoneCalls,0);await pending;await b.hamnavaStop();
});
test('empty recordings are reported without claiming a saved clip, and release the microphone', async () => {
  let released=0;
  class Recorder {
    static isTypeSupported(){return true;}constructor(){this.state='inactive';}
    start(){this.state='recording';}stop(){this.state='inactive';queueMicrotask(()=>this.onstop?.());}
  }
  const b=browser({isSecureContext:true,MediaRecorder:Recorder,
    navigator:{mediaDevices:{getUserMedia:async()=>({getTracks:()=>[{stop:()=>released++}]})}}});
  const events=[];await b.hamnavaStart('alice/empty','fa-IR',raw=>events.push(JSON.parse(raw)));
  assert.equal(await b.hamnavaStop(),'');assert.equal(released,1);
  assert.equal(events.find(e=>e.type==='error').value,'recording-empty');
  assert.equal(events.at(-1).type,'stopped');assert.equal(events.at(-1).value,'');
});
test('busy microphones and synchronous recognition failures do not leave an active session', async () => {
  const b=browser({isSecureContext:true,MediaRecorder:function(){},navigator:{mediaDevices:{getUserMedia:async()=>{throw {name:'NotReadableError'};}}}});
  const events=[];assert.equal(await b.hamnavaStart('a/clip','fa-IR',raw=>events.push(JSON.parse(raw))),false);
  assert.equal(events[0].value,'microphone-busy');assert.equal(await b.hamnavaStop(),'');
  class Recognition {start(){throw {name:'NotAllowedError'};}}
  const r=browser({SpeechRecognition:Recognition});const speech=[];
  assert.equal(await r.hamnavaStart('','fa-IR',raw=>speech.push(JSON.parse(raw))),false);
  assert.equal(speech[0].value,'speech-permission-denied');assert.equal(await r.hamnavaStop(),'');
});

test('backgrounding stops recording and retains its blob instead of discarding it', async () => {
  const listeners={}, clips=new Map();let released=0;
  class Recorder {
    static isTypeSupported(){return true;}constructor(){this.state='inactive';this.mimeType='audio/mp4';}
    start(){this.state='recording';}stop(){this.state='inactive';this.ondataavailable({data:new Blob(['saved'],{type:this.mimeType})});queueMicrotask(()=>this.onstop?.());}
  }
  const db={close(){},transaction(){const tx={objectStore:()=>({put:(blob,key)=>{clips.set(key,blob);return {result:key};}})};queueMicrotask(()=>tx.oncomplete?.());return tx;}};
  const b=browser({document:{hidden:true,addEventListener:(type,callback)=>listeners[type]=callback},
    isSecureContext:true,MediaRecorder:Recorder,navigator:{mediaDevices:{getUserMedia:async()=>({getTracks:()=>[{stop:()=>released++}]})}},
    indexedDB:{open(){const request={result:db};queueMicrotask(()=>request.onsuccess?.());return request;}}});
  const events=[];await b.hamnavaStart('alice/background','fa-IR',raw=>events.push(JSON.parse(raw)));
  listeners.visibilitychange();await b.hamnavaStop();
  assert.equal(clips.get('alice/background').size,5);assert.equal(released>=1,true);
  assert.equal(events.at(-1).type,'stopped');assert.equal(events.at(-1).value,'alice/background');
});
test('backgrounding during a permission prompt resets UI and releases any late stream', async () => {
  const listeners={};let resolve,released=0;
  const b=browser({document:{hidden:true,addEventListener:(type,callback)=>listeners[type]=callback},
    isSecureContext:true,MediaRecorder:function(){},navigator:{mediaDevices:{getUserMedia:()=>new Promise(r=>resolve=r)}}});
  const events=[];const started=b.hamnavaStart('alice/pending','fa-IR',raw=>events.push(JSON.parse(raw)));
  listeners.visibilitychange();assert.equal(events.at(-1).type,'stopped');
  resolve({getTracks:()=>[{stop:()=>released++}]});assert.equal(await started,false);assert.equal(released,1);
});
