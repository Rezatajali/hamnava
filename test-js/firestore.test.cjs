const {test,before,after} = require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,deleteDoc,serverTimestamp,Timestamp}=require('firebase/firestore');
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-hamnava',firestore:{host:'127.0.0.1',port:8080,rules:fs.readFileSync('firestore.rules','utf8')}});});
after(async()=>{await env?.cleanup();});
const journal=()=>({title:'روز من',text:'سلام',tags:'',mood:'آرام',audioKey:'',locale:'fa-IR',createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
const transaction=()=>({cents:1250,kind:'expense',currency:'EUR',category:'غذا',note:'ناهار',date:Timestamp.now(),month:'2026-10',createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
test('owner can create/read/edit/delete journal; others and anonymous cannot',async()=>{
  const owner=env.authenticatedContext('alice').firestore(),other=env.authenticatedContext('bob').firestore(),anon=env.unauthenticatedContext().firestore();
  const path='users/alice/journal/entry';await assertSucceeds(setDoc(doc(owner,path),journal()));
  await assertSucceeds(getDoc(doc(owner,path)));await assertFails(getDoc(doc(other,path)));await assertFails(getDoc(doc(anon,path)));
  await assertFails(setDoc(doc(other,path),journal()));
  await assertSucceeds(updateDoc(doc(owner,path),{text:'روز تازه',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(owner,path),{createdAt:Timestamp.fromMillis(0),updatedAt:serverTimestamp()}));
  await assertSucceeds(deleteDoc(doc(owner,path)));
});
test('owner finance access is isolated; malformed amounts and unknown fields are rejected',async()=>{
  const owner=env.authenticatedContext('alice').firestore(),other=env.authenticatedContext('bob').firestore();
  const path='users/alice/transactions/tx';await assertSucceeds(setDoc(doc(owner,path),transaction()));
  await assertFails(getDoc(doc(other,path)));await assertFails(deleteDoc(doc(other,path)));
  for(const change of [{cents:-1},{cents:1.5},{currency:'USD'},{month:'2026-99'},{admin:true}]){
    await assertFails(setDoc(doc(owner,`${path}-${Object.keys(change)[0]}`),{...transaction(),...change}));
  }
});
test('journal rejects foreign audio key and extra fields; unrelated paths remain closed',async()=>{
  const db=env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db,'users/alice/journal/foreign'),{...journal(),audioKey:'bob/audio'}));
  await assertFails(setDoc(doc(db,'users/alice/journal/extra'),{...journal(),admin:true}));
  await assertFails(setDoc(doc(db,'public/data'),{text:'public'}));
});
