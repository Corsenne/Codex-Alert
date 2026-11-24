import assert from 'node:assert/strict';
import { test } from 'node:test';
import { enqueue, complete, initialState } from './serial-queue.ts';
const evt=(source,id)=>({source,eventId:id,title:'Test',completedAt:'2026-11-23T01:00:00Z'});

test('one visible and one audio even with simultaneous different sources',()=>{
  let s=initialState;
  const a=enqueue(s,evt('chatgpt','a'));s=a.state;
  const b=enqueue(s,evt('codex','b'));s=b.state;
  assert.equal(s.active?.eventId,'a');assert.equal(s.waiting.length,1);
  assert.deepEqual(a.effects.map(x=>x.type),['show','play']);
  assert.deepEqual(b.effects,[]);
  const done=complete(s,'a','timeout');
  assert.deepEqual(done.effects.map(x=>x.type),['stop','hide','show','play']);
  assert.equal(done.state.active?.eventId,'b');
});

test('click stops current audio before opening chat and starting next event',()=>{
  let s=enqueue(initialState,evt('codex','d')).state;
  s=enqueue(s,evt('chatgpt','c')).state;
  const done=complete(s,'d','click');
  assert.deepEqual(done.effects.map(x=>x.type),['stop','hide','open','show','play']);
  assert.equal(done.effects[2].event.source,'codex');
  assert.equal(done.state.active?.eventId,'c');
});

test('close x only stops and dismisses; stale click cannot open next event',()=>{
  const s=enqueue(initialState,evt('chatgpt','a')).state;
  const done=complete(s,'a','dismiss');
  assert.deepEqual(done.effects.map(x=>x.type),['stop','hide']);
  assert.equal(done.state.active,null);
  assert.equal(complete(done.state,'a','click').result,'ignored');
});

test('duplicate from same source eventId cannot show or play twice, including after dismissal',()=>{
  let s=enqueue(initialState,evt('chatgpt','a')).state;
  assert.equal(enqueue(s,evt('chatgpt','a')).result,'duplicate');
  s=complete(s,'a','timeout').state;
  assert.equal(enqueue(s,evt('chatgpt','a')).result,'duplicate');
  assert.equal(enqueue(s,evt('codex','a')).result,'started','source scoping retained');
});

test('bounded queue does not silently overwrite pending notifications',()=>{
  let s=enqueue(initialState,evt('codex','top')).state;
  for(let i=0;i<64;i++){
    const r=enqueue(s,evt('codex',`q-${i}`)); assert.equal(r.result,'queued');s=r.state;
  }
  const rejected=enqueue(s,evt('chatgpt','overflow'));
  assert.equal(rejected.result,'full');assert.equal(rejected.state,s);
});

test('invalid and late completion ids are ignored',()=>{
  const s=enqueue(initialState,evt('codex','one')).state;
  assert.equal(complete(s,'other','click').result,'ignored');
  assert.equal(enqueue(s,{...evt('codex','bad'),source:'bad'}).result,'ignored');
});
