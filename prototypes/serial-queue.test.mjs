import assert from 'node:assert/strict';
import {test} from 'node:test';
import {enqueue,complete,initialState} from './serial-queue.ts';
const evt=(source,id)=>({source,eventId:id,title:'Test',completedAt:'2026-11-23T01:00:00Z'});
test('one visible and one audio, cross-source FIFO',()=>{
  let s=initialState;
  const a=enqueue(s,evt('chatgpt','a'));s=a.state;
  const b=enqueue(s,evt('codex','b'));s=b.state;
  assert.equal(s.active?.eventId,'a');assert.equal(s.waiting.length,1);
  assert.deepEqual(a.effects.map(x=>x.type),['show','play']);assert.deepEqual(b.effects,[]);
  const done=complete(s,'a','timeout');
  assert.deepEqual(done.effects.map(x=>x.type),['stop','hide','show','play']);
  assert.equal(done.state.active?.eventId,'b');
});
test('click stops before opening the correct source and advancing',()=>{
  let s=enqueue(initialState,evt('codex','d')).state;
  s=enqueue(s,evt('chatgpt','c')).state;
  const result=complete(s,'d','click');
  assert.deepEqual(result.effects.map(x=>x.type),['stop','hide','open','show','play']);
  assert.equal(result.effects[2].event.source,'codex');
});
test('close X stops audio but does not navigate',()=>{
  const s=enqueue(initialState,evt('chatgpt','a')).state;
  const done=complete(s,'a','dismiss');
  assert.deepEqual(done.effects.map(x=>x.type),['stop','hide']);
  assert.equal(complete(done.state,'a','click').result,'ignored');
});
test('same source+id cannot retrigger, even after dismissal',()=>{
  let s=enqueue(initialState,evt('chatgpt','a')).state;
  assert.equal(enqueue(s,evt('chatgpt','a')).result,'duplicate');
  s=complete(s,'a','timeout').state;
  assert.equal(enqueue(s,evt('chatgpt','a')).result,'duplicate');
  assert.equal(enqueue(s,evt('codex','a')).result,'started');
});
test('queue overflow reported instead of silent event loss',()=>{
  let s=enqueue(initialState,evt('codex','top')).state;
  for(let i=0;i<64;i++){const r=enqueue(s,evt('codex','q'+i));assert.equal(r.result,'queued');s=r.state;}
  const overflow=enqueue(s,evt('chatgpt','overflow'));
  assert.equal(overflow.result,'full');assert.equal(overflow.state,s);
});
test('invalid and stale event transitions are ignored',()=>{
  const s=enqueue(initialState,evt('codex','one')).state;
  assert.equal(complete(s,'other','click').result,'ignored');
  assert.equal(enqueue(s,{...evt('codex','bad'),source:'other'}).result,'ignored');
});
