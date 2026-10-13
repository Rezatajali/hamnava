const assert=require('node:assert/strict');
const {test,before,after} = require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,deleteDoc,serverTimestamp,Timestamp,writeBatch}=require('firebase/firestore');
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
const receipt = parent => ({name:'receipt.jpg',originalType:'image/jpeg',image:'data:image/jpeg;base64,/9j/',bytes:3,width:1,height:1,transactionId:parent,createdAt:serverTimestamp()});
async function createWithReceipts(db,uid,parent,ids,changes={}) {
  const batch=writeBatch(db);
  batch.set(doc(db,`users/${uid}/transactions/${parent}`),{...transaction(),receiptIds:ids});
  for(const id of ids) batch.set(doc(db,`users/${uid}/receipts/${id}`),{...receipt(parent),...changes});
  return batch.commit();
}
test('receipts are atomically linked to owner transactions and isolated from other accounts',async()=>{
  const alice=env.authenticatedContext('alice').firestore(),bob=env.authenticatedContext('bob').firestore(),anon=env.unauthenticatedContext().firestore();
  await assertSucceeds(createWithReceipts(alice,'alice','receipt-tx',['receipt-one']));
  const path='users/alice/receipts/receipt-one';
  await assertSucceeds(getDoc(doc(alice,path)));await assertFails(getDoc(doc(bob,path)));await assertFails(getDoc(doc(anon,path)));
  await assertFails(setDoc(doc(alice,'users/alice/receipts/orphan'),receipt('receipt-tx')));
  await assertFails(updateDoc(doc(alice,path),{name:'changed.jpg'}));
  await assertFails(updateDoc(doc(alice,'users/alice/transactions/other-link'),{receiptIds:['receipt-one']}));
  await assertSucceeds(updateDoc(doc(alice,'users/alice/transactions/receipt-tx'),{month:'2026-11',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(alice,'users/alice/transactions/receipt-tx'),{receiptIds:[],updatedAt:serverTimestamp()}));
  const legacy={...(await getDoc(doc(alice,'users/alice/transactions/receipt-tx'))).data()};delete legacy.receiptIds;
  await assertFails(setDoc(doc(alice,'users/alice/transactions/receipt-tx'),{...legacy,note:'old client',updatedAt:serverTimestamp()}));
  await assertFails(deleteDoc(doc(alice,path)));
  await assertFails(deleteDoc(doc(alice,'users/alice/transactions/receipt-tx')));
  const unlink=writeBatch(alice);unlink.update(doc(alice,'users/alice/transactions/receipt-tx'),{receiptIds:[],updatedAt:serverTimestamp()});unlink.delete(doc(alice,path));
  await assertSucceeds(unlink.commit());
});
test('receipt size, image type, extra fields and the three-image limit are enforced atomically',async()=>{
  const db=env.authenticatedContext('alice').firestore();
  for(const [index,change] of [{image:'data:image/svg+xml;base64,PHN2Zz4='},{bytes:204801},{width:1601},{height:1601},{originalType:'application/pdf'},{admin:true},{image:'data:image/jpeg;base64,'+'A'.repeat(280001)}].entries()){
    const parent=`bad-photo-${index}`;
    await assertFails(createWithReceipts(db,'alice',parent,[`bad-photo-image-${index}`],change));
    assert.equal((await getDoc(doc(db,`users/alice/transactions/${parent}`))).exists(),false);
  }
  await assertSucceeds(createWithReceipts(db,'alice','three-images',['one','two','three']));
  await assertFails(createWithReceipts(db,'alice','four-images',['four-a','four-b','four-c','four-d']));
  assert.equal((await getDoc(doc(db,'users/alice/receipts/four-a'))).exists(),false);
  await assertFails(setDoc(doc(db,'users/alice/transactions/stolen-link'),{...transaction(),receiptIds:['one']}));
  const cleanup=writeBatch(db);for(const id of ['one','two','three'])cleanup.delete(doc(db,`users/alice/receipts/${id}`));cleanup.delete(doc(db,'users/alice/transactions/three-images'));
  await assertSucceeds(cleanup.commit());
});
