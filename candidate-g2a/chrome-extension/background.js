'use strict';

// Desktop Edition Lite: only currently-unseen chats are persisted.
// No completion history, counters, recurring polls, or per-event diagnostic storage.
const HOST_NAME = 'com.corsenne.finish_alert';
const PROTOCOL_VERSION = 2; // Compatible v2: audioOwner opt-in requires G2 native companion.
const DEFAULTS = Object.freeze({enabled:true, soundId:'holo', soundVolume:85});
const SOUNDS = new Set(['holo','soft','pulse','female']);
const MAX_PENDING_CHATS = 48;
const NATIVE_TIMEOUT_MS = 10000;
const ROUTE_TTL_MS = 20*60*1000; // Covers up to 64 queued 8-second banners.
const CYCLE_TTL_MS = 120000;
let creatingOffscreen = null;
let nativePort = null;
let nativeIdleTimer = 0;
let nativeStatus = '通知時に接続';
let nativeError = '';
let completionQueue = Promise.resolve();
const pendingNative = new Map();
const recentCycles = new Map();
const recentRoutes = new Map();
const activeDesktopRoutes = new Map(); // event IDs still waiting/visible in the native FIFO

function serial(task) {
  const next = completionQueue.then(task,task);
  completionQueue = next.catch(()=>{});
  return next;
}
function isChatGPT(url) {
  try {
    const u = new URL(url);
    return u.protocol === 'https:' && (u.hostname==='chatgpt.com' || u.hostname==='chat.openai.com');
  } catch (_) {return false;}
}
function validConversationUrl(url) {
  try {
    const u = new URL(url);
    if (!isChatGPT(url)) return null;
    const path = u.pathname;
    if (!/^\/(?:c\/[A-Za-z0-9_-]{8,100}|g\/[A-Za-z0-9_-]{3,100}\/c\/[A-Za-z0-9_-]{8,100})\/?$/.test(path)) return null;
    return u.origin+path;
  } catch (_) {return null;}
}
function chatKey(url,tabId) {
  const valid=validConversationUrl(url);
  return valid ? 'chat:'+new URL(valid).pathname.replace(/\/$/,'') : 'tab:'+String(tabId);
}
function sanitizeTitle(input) {
  const cleaned=String(input||'').replace(/[\x00-\x1f\x7f]/g,' ').replace(/\s+/g,' ').trim()
    .replace(/\s*(?:[-|–—]\s*)?ChatGPT\s*$/i,'').slice(0,100);
  return cleaned&&!/^(?:ChatGPT|New chat|新しいチャット)$/i.test(cleaned)?cleaned:'ChatGPTの会話';
}
function soundChoice(input) {return SOUNDS.has(input)?input:'holo';}
function volumeChoice(input) {
  const n=Number(input);
  return Number.isFinite(n)?Math.max(0,Math.min(100,Math.round(n))):85;
}
function safeEventId() {return crypto.randomUUID();}
function pruneRecent() {
  const now=Date.now();
  for (const [key,value] of recentCycles) if (value<now-CYCLE_TTL_MS)recentCycles.delete(key);
  for (const [key,value] of recentRoutes) if (value.at<now-ROUTE_TTL_MS)recentRoutes.delete(key);
  while (recentCycles.size>100) recentCycles.delete(recentCycles.keys().next().value);
  while (recentRoutes.size>80) recentRoutes.delete(recentRoutes.keys().next().value);
}
function toPending(item) {
  if (!item || typeof item!=='object')return null;
  if (typeof item.eventId!=='string' || !/^[a-zA-Z0-9-]{12,50}$/.test(item.eventId))return null;
  const tabId=Number.isInteger(item.tabId)?item.tabId:-1;
  const conversationUrl=validConversationUrl(item.conversationUrl);
  const key=chatKey(conversationUrl,tabId);
  return {key,eventId:item.eventId,tabId,conversationUrl};
}
async function migrateLegacyStorage() {
  const all=await chrome.storage.local.get(['pendingChats','events','completedCount','lastEvent','lastCompletion','sound','onlyWhenAway']);
  if (!Array.isArray(all.pendingChats)) {
    // Preserve only unread v1.0 items; read history and totals are discarded.
    const legacy=Array.isArray(all.events)?all.events:[];
    const seen=new Set();const pending=[];
    for (const old of legacy) {
      if (old.read)continue;
      const x=toPending(old);
      if (x && !seen.has(x.key)) {pending.push(x);seen.add(x.key);}
      if (pending.length>=MAX_PENDING_CHATS)break;
    }
    await chrome.storage.local.set({pendingChats:pending});
  }
  if (all.events!==undefined || all.completedCount!==undefined || all.lastEvent!==undefined ||
      all.lastCompletion!==undefined || all.sound!==undefined || all.onlyWhenAway!==undefined) {
    await chrome.storage.local.remove(['events','completedCount','lastEvent','lastCompletion','sound','onlyWhenAway']);
  }
}
const storageReady=migrateLegacyStorage();
async function getPending() {
  await storageReady;
  const {pendingChats}=await chrome.storage.local.get({pendingChats:[]});
  return Array.isArray(pendingChats)?pendingChats.map(toPending).filter(Boolean):[];
}
async function savePending(pending) {
  await chrome.storage.local.set({pendingChats:pending.slice(0,MAX_PENDING_CHATS)});
  await updatePresence(pending);
}
async function updatePresence(alreadyLoaded) {
  const pending=alreadyLoaded||await getPending();
  // Show one pale-cyan dot in the icon, rather than a yellow count/badge capsule.
  // Clear any badge retained by v1.1 on upgrade. Icons are static, no animation/timer.
  await chrome.action.setBadgeText({text:''});
  const suffix=pending.length?'-unread':'';
  await chrome.action.setIcon({path:{
    16:`assets/icon16${suffix}.png`,
    48:`assets/icon48${suffix}.png`,
    128:`assets/icon128${suffix}.png`
  }});
  await chrome.action.setTitle({title:pending.length?'Finish Alert — 未確認あり':'Finish Alert — 確認済み'});
  return pending.length>0;
}
async function status() {
  const pending=await getPending();
  return {ok:true,hasUnread:pending.length>0,nativeStatus,nativeError};
}
async function ensureOffscreen() {
  const target=chrome.runtime.getURL('offscreen.html');
  const contexts=await chrome.runtime.getContexts({contextTypes:['OFFSCREEN_DOCUMENT'],documentUrls:[target]});
  if (contexts.length)return;
  if (!creatingOffscreen)creatingOffscreen=chrome.offscreen.createDocument({
    url:'offscreen.html',reasons:['AUDIO_PLAYBACK'],justification:'通知音の再生'
  }).finally(()=>{creatingOffscreen=null;});
  await creatingOffscreen;
}
async function playSound(soundId,volume) {
  if(volumeChoice(volume)===0)return {ok:true};
  try {await ensureOffscreen();return await chrome.runtime.sendMessage({target:'offscreen',type:'PLAY_SOUND',soundId:soundChoice(soundId),volume:volumeChoice(volume)});}
  catch(e){return {ok:false,error:String(e.message)};}
}
async function stopSound(){
  try {
    await ensureOffscreen();
    return await chrome.runtime.sendMessage({target:'offscreen',type:'STOP_SOUND'});
  } catch (e) {return {ok:false,error:String(e.message)};}
}
function cancelNativeIdle() {
  if (nativeIdleTimer) {clearTimeout(nativeIdleTimer); nativeIdleTimer=0;}
}
function scheduleNativeIdle() {
  cancelNativeIdle();
  nativeIdleTimer=setTimeout(()=>{
    nativeIdleTimer=0;
    if(pendingNative.size){scheduleNativeIdle();return;}
    const now=Date.now();
    for(const [id,start] of activeDesktopRoutes)if(now-start>ROUTE_TTL_MS)activeDesktopRoutes.delete(id);
    if(activeDesktopRoutes.size){
      // Keep the bridge alive only while an ACKed banner is queued/visible.
      // The host exits after bounded inactivity if the worker disappears.
      if(nativePort)try{nativePort.postMessage({version:2,type:'bridge.ping'});}catch(_){}
      scheduleNativeIdle();return;
    }
    const old=nativePort; nativePort=null;
    nativeStatus='通知時に接続';nativeError='';
    if(old)try{old.disconnect();}catch(_){}
  },90000); // Close idle native-host port; desktop tray remains available.
}
function closeNative(reason) {
  cancelNativeIdle();
  nativeStatus='切断';nativeError=String(reason||'Native Messaging disconnected').slice(0,160);
  const port=nativePort;nativePort=null;
  // The transport may have delivered the event even if its ACK was lost.
  // Only a proven pre-delivery failure can safely trigger a Chrome fallback.
  const state = /(?:native messaging host not found|specified native messaging host is forbidden|access to the specified native messaging host is forbidden)/i.test(nativeError)
    ? 'not_sent' : 'unknown';
  for (const req of pendingNative.values()) {
    clearTimeout(req.timer);
    req.resolve({ok:false,state,error:nativeError});
  }
  pendingNative.clear();
  activeDesktopRoutes.clear();
  if(port)try{port.disconnect();}catch(_){}
}
function connectNative() {
  if(nativePort)return nativePort;
  let port;
  try{port=chrome.runtime.connectNative(HOST_NAME);}
  catch(e){nativeStatus='未導入';nativeError=String(e.message);return null;}
  nativePort=port;nativeStatus='接続試行中';nativeError='';
  port.onMessage.addListener(message=>{
    if(nativePort!==port)return;
    if(message?.type==='bridge.ready'){
      nativeStatus=message.ok?'接続済':'接続不可';
      nativeError=message.ok?'':String(message.error||'desktop-unavailable');
    }else if(message?.type==='delivery.ack' && typeof message.eventId==='string'){
      const req=pendingNative.get(message.eventId);
      if(req){
        clearTimeout(req.timer);pendingNative.delete(message.eventId);
        if(message.ok===true && message.state!=='duplicate')activeDesktopRoutes.set(message.eventId,Date.now());
        req.resolve({ok:message.ok===true,state:message.ok===true?'confirmed':'rejected',error:message.error||''});
        scheduleNativeIdle();
      }
    }else if(message?.type==='notification.open' && typeof message.eventId==='string'){
      void serial(()=>openEvent(message.eventId));scheduleNativeIdle();
    }else if(message?.type==='notification.closed' && typeof message.eventId==='string'){
      activeDesktopRoutes.delete(message.eventId);
      scheduleNativeIdle();
    }else if(message?.type==='bridge.disconnected')closeNative('デスクトップアプリとの通信が切断');
  });
  port.onDisconnect.addListener(()=>{if(nativePort===port)closeNative(chrome.runtime.lastError?.message||'Native host closed');});
  return port;
}
async function deliverNative(event,soundId,volume) {
  const port=connectNative();
  if(!port)return {ok:false,state:'not_sent',error:nativeError};
  return new Promise(resolve=>{
    const timer=setTimeout(()=>{
      pendingNative.delete(event.eventId);
      // Unknown outcome is NOT proof the banner failed: it may be visible now.
      resolve({ok:false,state:'unknown',error:'desktop-ack-timeout'});
      closeNative('ACK timeout');
    },NATIVE_TIMEOUT_MS);
    pendingNative.set(event.eventId,{resolve,timer});
    try{port.postMessage({version:PROTOCOL_VERSION,type:'deliver',event,soundId:soundChoice(soundId),soundVolume:volumeChoice(volume),audioOwner:'desktop'});scheduleNativeIdle();}
    catch(e){
      clearTimeout(timer);pendingNative.delete(event.eventId);
      // A postMessage error cannot prove whether some bytes reached the host.
      resolve({ok:false,state:'unknown',error:String(e.message)});
      closeNative(e.message);
    }
  });
}
async function chromeNotice(event) {
  if(chrome.notifications.getPermissionLevel && await chrome.notifications.getPermissionLevel()==='denied')
    throw new Error('Chrome通知が許可されていません');
  return chrome.notifications.create('finish-'+event.eventId,{
    type:'basic',iconUrl:'assets/icon128.png',title:event.chatTitle,
    message:'ChatGPTの回答が完了しました。クリックして確認できます。',priority:2
  });
}
async function isViewing(tab) {
  if(!tab?.active)return false;
  try {const win=await chrome.windows.get(tab.windowId);return !!win.focused && win.state!=='minimized';}
  catch(_){return false;}
}
async function markViewed(tab,urlOverride) {
  if(!tab||!Number.isInteger(tab.id)||!isChatGPT(tab.url)||!(await isViewing(tab)))return false;
  const target=chatKey(validConversationUrl(urlOverride)||tab.url,tab.id);
  const pending=await getPending();
  const rest=pending.filter(p=>p.key!==target);
  if(rest.length===pending.length)return false;
  await savePending(rest);
  return true;
}
async function markActiveTabId(tabId) {
  try {return await markViewed(await chrome.tabs.get(tabId));}
  catch(_){return false;}
}
async function handleComplete(message,sender) {
  const tab=sender.tab;
  if(!tab||!Number.isInteger(tab.id)||!isChatGPT(tab.url)||typeof message.cycleId!=='string'||message.cycleId.length>100)
    return {ok:false,error:'invalid-completion-source'};
  const settings=await chrome.storage.local.get(DEFAULTS);
  if(!settings.enabled)return {ok:true,suppressed:'disabled'};
  const dedupeKey=`${sender.documentId||'tab-'+tab.id}:${message.cycleId}`;
  pruneRecent();
  if(recentCycles.has(dedupeKey))return {ok:true,suppressed:'duplicate'};
  recentCycles.set(dedupeKey,Date.now());
  const event={version:PROTOCOL_VERSION,eventId:safeEventId(),conversationUrl:validConversationUrl(tab.url),
    chatTitle:sanitizeTitle(message.chatTitle||tab.title),tabId:tab.id,windowId:tab.windowId,
    completedAt:new Date().toISOString()};
  recentRoutes.set(event.eventId,{at:Date.now(),tabId:tab.id,conversationUrl:event.conversationUrl});
  // A foreground, active ChatGPT tab has already been seen. Still notify if enabled.
  if(!(await isViewing(tab))) {
    const pending=await getPending();
    const entry=toPending(event);
    const rest=pending.filter(p=>p.key!==entry.key);
    await savePending([entry,...rest]);
  }
  // Unified G2: Native desktop owns audible playback and starts it only when
  // its single active banner is actually shown. Chrome plays only on a proven
  // rejected/not-sent delivery, NEVER on an ambiguous ACK timeout.
  // This requires installing the v1.2 desktop receiver BEFORE this extension.
  const desktop = await deliverNative(event,settings.soundId,settings.soundVolume);
  const full = desktop.state === 'rejected' && desktop.error === 'queue-full';
  const fallback = desktop.state === 'not_sent' || (desktop.state === 'rejected' && !full);
  if (fallback) {
    try {await chromeNotice(event);}
    catch(e) {return {ok:false,error:'notification-failed:'+e.message};}
    const audioResult=await playSound(settings.soundId,settings.soundVolume);
    if (!audioResult?.ok)console.warn('Finish Alert: fallback sound unavailable',audioResult?.error || 'unknown');
  } else if (full) {
    // Never play an overlapping fallback sound while the native queue is full.
    // Explicit failure is reported, not silently presented as success.
    console.error('Finish Alert: Windows queue full; notification was not accepted');
    return {ok:false,error:'queue-full'};
  } else if (desktop.state === 'unknown') {
    console.warn('Finish Alert: native delivery unconfirmed, no duplicate banner/sound',desktop.error);
  }
  return {ok:true,delivery:desktop.ok?'desktop':fallback?'chrome-fallback':'desktop-unconfirmed'};
}
async function openEvent(eventId) {
  pruneRecent();
  const pending=await getPending();
  const route=recentRoutes.get(eventId)||pending.find(x=>x.eventId===eventId);
  if(!route)return {ok:false,error:'event-expired'};
  let opened=false;
  if(Number.isInteger(route.tabId)&&route.tabId>=0){
    try {
      const tab=await chrome.tabs.get(route.tabId);
      if(isChatGPT(tab.url)&&(!route.conversationUrl||chatKey(tab.url,tab.id)===chatKey(route.conversationUrl,tab.id))){
        await chrome.windows.update(tab.windowId,{focused:true});
        await chrome.tabs.update(tab.id,{active:true});opened=true;
      }
    }catch(_){}
  }
  if(!opened)await chrome.tabs.create({url:route.conversationUrl||'https://chatgpt.com/'});
  // Clicking opens the conversation, so acknowledge the matching conversation only.
  const rest=pending.filter(x=>x.key!==chatKey(route.conversationUrl,route.tabId));
  if(rest.length!==pending.length)await savePending(rest);
  return {ok:true};
}
chrome.runtime.onMessage.addListener((msg,sender,reply)=>{
  if(!msg||msg.target==='offscreen')return;
  const task=async()=>{
    if(msg.type==='COMPLETE')return serial(()=>handleComplete(msg,sender));
    if(msg.type==='VIEWED'){
      if(!sender.tab||!isChatGPT(sender.tab.url)||!isChatGPT(msg.url))return {ok:false};
      return {ok:true,acknowledged:await serial(()=>markViewed(sender.tab,msg.url))};
    }
    if(msg.type==='GET_STATUS')return status();
    if(msg.type==='PREVIEW_SOUND')return playSound(soundChoice(msg.soundId),volumeChoice(msg.volume));
    return {ok:false,error:'unknown-message'};
  };
  task().then(reply).catch(e=>reply({ok:false,error:String(e.message)}));
  return true;
});
chrome.tabs.onActivated.addListener(info=>{void serial(()=>markActiveTabId(info.tabId));});
chrome.tabs.onUpdated.addListener((tabId,changeInfo,tab)=>{
  if(tab.active&&(changeInfo.url||changeInfo.status==='complete'))void serial(()=>markActiveTabId(tabId));
});
chrome.windows.onFocusChanged.addListener(windowId=>{
  if(windowId===chrome.windows.WINDOW_ID_NONE || windowId<0)return;
  void serial(async()=>{
    const tabs=await chrome.tabs.query({active:true,windowId});
    if(tabs[0])await markViewed(tabs[0]);
  });
});
chrome.notifications.onClicked.addListener(id=>{
  if(/^finish-[0-9a-f-]{36}$/.test(id))void serial(async()=>{await stopSound();return openEvent(id.slice(7));}).finally(()=>chrome.notifications.clear(id));
  else void chrome.notifications.clear(id);
});
chrome.runtime.onInstalled.addListener(()=>{void storageReady.then(()=>updatePresence());});
chrome.runtime.onStartup.addListener(()=>{void storageReady.then(()=>updatePresence());});
void storageReady.then(()=>updatePresence()).catch(console.error);
