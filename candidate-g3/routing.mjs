// G3 routing core: source-owned identities, fail-closed target selection.
// This module has no I/O, timers, processes or browser privileges.
import path from 'node:path';

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
// Codex may use other session id shapes; no exact-thread navigation is allowed then.
export function canonicalThreadId(value) {
  if (typeof value!=='string'||!UUID.test(value)) return null;
  return value.toLowerCase();
}
export function exactCodexThreadLink(value) {
  if (typeof value!=='string') return null;
  const match=/^codex:\/\/threads\/([0-9a-f-]{36})$/.exec(value);
  const id=match&&canonicalThreadId(match[1]);
  return id ? 'codex://threads/'+id : null;
}
export function checkedCodexHookThread(hook,codexHome) {
  if (!hook||hook.hook_event_name!=='Stop'||hook.stop_hook_active===true)return null;
  const id=canonicalThreadId(hook.session_id);
  const transcript=hook.transcript_path;
  if(!id || typeof transcript!=='string' || typeof codexHome!=='string' || !codexHome)return null;
  const root=path.win32.resolve(codexHome,'sessions');
  const p=path.win32.resolve(transcript);
  const rel=path.win32.relative(root,p);
  if(!rel || rel.startsWith('..'+path.win32.sep)||rel==='..'||path.win32.isAbsolute(rel))return null;
  const basename=path.win32.basename(p);
  if(!/^rollout-[0-9T-]+-[0-9a-f-]{36}\.jsonl$/i.test(basename))return null;
  if(!basename.toLowerCase().endsWith('-'+id+'.jsonl'))return null;
  // Caller must additionally verify actual file existence, session_meta ID
  // and that the Codex Desktop link handler opens this exact chat.
  return 'codex://threads/'+id;
}
export function exactChatGPTConversationUrl(input) {
  if(typeof input!=='string')return null;
  try {
    const u=new URL(input);
    if(u.protocol!=='https:'||!['chatgpt.com','chat.openai.com'].includes(u.hostname)
       ||u.username||u.password||u.port||u.search||u.hash)return null;
    if(!/^\/(?:c\/[A-Za-z0-9_-]{8,100}|g\/[A-Za-z0-9_-]{3,100}\/c\/[A-Za-z0-9_-]{8,100})\/?$/.test(u.pathname))return null;
    return u.origin+u.pathname.replace(/\/$/,'');
  }catch {return null;}
}
export function chatGPTRestoreTarget(route,liveTabs=[]) {
  const url=exactChatGPTConversationUrl(route?.conversationUrl);
  if(!url)return {kind:'unavailable'};
  const match=(t)=>Number.isInteger(t?.id)&&t.id>=0 &&
    Number.isInteger(t?.windowId)&&t.windowId>=0 &&
    exactChatGPTConversationUrl(t.url)===url;
  const original=liveTabs.find(t=>t.id===route.tabId&&match(t));
  if(original)return {kind:'focus',tabId:original.id,windowId:original.windowId};
  const same=liveTabs.find(match);
  if(same)return {kind:'focus',tabId:same.id,windowId:same.windowId};
  return {kind:'create',url};
}
export function dispatchAfterAudioStop(active,clicked,options={}) {
  if(!active||typeof active.eventId!=='string'||active.eventId!==clicked)
    return {effects:[],result:'ignored'};
  const effects=[{type:'stop-audio',eventId:clicked},{type:'dismiss',eventId:clicked}];
  const source=active.source;
  if(source==='codex'){
    const url=exactCodexThreadLink(active.openTarget);
    if(url && options.codexDeepLinkVerified===true) effects.push({type:'open-codex',url});
  } else if(source==='chatgpt'){
    const target=chatGPTRestoreTarget(active,options.tabs||[]);
    if(target.kind!=='unavailable')effects.push({type:'open-chatgpt',target});
  }
  return {effects,result:'finished'};
}
