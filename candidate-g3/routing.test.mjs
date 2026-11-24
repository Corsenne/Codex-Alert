import assert from 'node:assert/strict';
import {test} from 'node:test';
import {canonicalThreadId,exactCodexThreadLink,checkedCodexHookThread,exactChatGPTConversationUrl,chatGPTRestoreTarget,dispatchAfterAudioStop} from './routing.mjs';

const U='019d25ff-3701-75d1-b331-160b90f8a456';
const BASE='C:\\Users\\tester\\.codex';
const H={hook_event_name:'Stop',session_id:U,turn_id:'turn-1234',transcript_path:BASE+'\\sessions\\2026\\11\\23\\rollout-2026-11-23T12-40-12-'+U+'.jsonl',stop_hook_active:false};
const C='https://chatgpt.com/c/12345678-abcd-efgh-ijkl-123456789abc';
test('Codex exact link accepts only UUID thread and zero extras',()=>{
  assert.equal(canonicalThreadId(U),U);
  assert.equal(exactCodexThreadLink('codex://threads/'+U),'codex://threads/'+U);
  for(const v of ['codex://threads/new','codex://settings','https://evil.example',
    'codex://threads/'+U+'?x=1','codex://threads/'+U+'#fragment',
    'codex://threads/'+U+'/../../settings','codex://threads/../../evil',
    'codex://threads/'+U+'%0A','codex://threads/abc']) assert.equal(exactCodexThreadLink(v),null);
});
test('Stop Hook requires local matching transcript filename and session id',()=>{
  assert.equal(checkedCodexHookThread(H,BASE),'codex://threads/'+U);
  assert.equal(checkedCodexHookThread({...H,transcript_path:null},BASE),null);
  assert.equal(checkedCodexHookThread({...H,transcript_path:'C:\\Elsewhere\\rollout-2026-11-23T12-40-12-'+U+'.jsonl'},BASE),null);
  assert.equal(checkedCodexHookThread({...H,session_id:'thr_abc'},BASE),null);
  assert.equal(checkedCodexHookThread({...H,hook_event_name:'SubagentStop'},BASE),null);
  assert.equal(checkedCodexHookThread({...H,stop_hook_active:true},BASE),null);
});
test('ChatGPT URL restricts host, path and query',()=>{
  assert.equal(exactChatGPTConversationUrl(C),C);
  assert.equal(exactChatGPTConversationUrl('https://chatgpt.com/c/12345678/'),'https://chatgpt.com/c/12345678');
  for(const v of ['https://evil.com/c/12345678','javascript:alert(1)','https://chatgpt.com/',
    'https://chatgpt.com/c/12345678?x=1','https://chatgpt.com.evil.com/c/12345678',
    'https://chatgpt.com/c/12345678#x'])assert.equal(exactChatGPTConversationUrl(v),null);
});
test('ChatGPT prefers same original tab only if URL still matches',()=>{
 const route={tabId:12,conversationUrl:C};
 const tabs=[{id:12,windowId:2,url:C},{id:14,windowId:3,url:C}];
 assert.deepEqual(chatGPTRestoreTarget(route,tabs),{kind:'focus',tabId:12,windowId:2});
});
test('ChatGPT ignores a reused original tab and focuses an exact matching alternate',()=>{
 const route={tabId:12,conversationUrl:C};
 const tabs=[{id:12,windowId:2,url:'https://chatgpt.com/c/99999999'},{id:14,windowId:3,url:C}];
 assert.deepEqual(chatGPTRestoreTarget(route,tabs),{kind:'focus',tabId:14,windowId:3});
});
test('ChatGPT closed target creates only exact saved URL; unknown URL aborts',()=>{
 assert.deepEqual(chatGPTRestoreTarget({tabId:12,conversationUrl:C},[]),{kind:'create',url:C});
 assert.deepEqual(chatGPTRestoreTarget({tabId:12,conversationUrl:null},[]),{kind:'unavailable'});
});
test('click always stops audio before opening a validated exact target',()=>{
 const e={source:'codex',eventId:'e1',openTarget:'codex://threads/'+U};
 assert.deepEqual(dispatchAfterAudioStop(e,'e1',{codexDeepLinkVerified:true}).effects.map(x=>x.type),
 ['stop-audio','dismiss','open-codex']);
 assert.deepEqual(dispatchAfterAudioStop(e,'e1',{codexDeepLinkVerified:false}).effects.map(x=>x.type),
 ['stop-audio','dismiss']);
});
test('stale click never stops current sound or opens another event',()=>{
 assert.deepEqual(dispatchAfterAudioStop({source:'chatgpt',eventId:'new',conversationUrl:C},'old'),
 {effects:[],result:'ignored'});
});
test('ChatGPT click refuses generic homepage fallback',()=>{
 const e={source:'chatgpt',eventId:'chat1',conversationUrl:null,tabId:77};
 assert.deepEqual(dispatchAfterAudioStop(e,'chat1').effects.map(x=>x.type),['stop-audio','dismiss']);
});
