'use strict';
// Finish Alert Unified 1.2.x approved Chrome service worker. Metadata-only observer; no response text.
const HOST='com.corsenne.finish_alert';
const KEY='g4c2_routes';
const OPENED='g4c2_opened';
const TTL=20*60*1000;
let port=null;
const pending=new Map();
let lastError='';
function exactUrl(input) {
  if(typeof input!=='string')return null;
  try {
    const u=new URL(input);
    if(u.protocol!=='https:'||!['chatgpt.com','chat.openai.com'].includes(u.hostname)||
       u.port||u.username||u.password)return null;
    if(!/^\/(?:c\/[A-Za-z0-9_-]{8,100}|g\/[A-Za-z0-9_-]{3,100}\/c\/[A-Za-z0-9_-]{8,100})\/?$/.test(u.pathname))return null;
    return u.origin+u.pathname.replace(/\/$/,'');
  }catch(_){return null;}
}
function validId(id){return typeof id==='string'&&/^[A-Za-z0-9-]{12,50}$/.test(id);}
async function saveRoute(id,route) {
  const x=await chrome.storage.session.get({[KEY]:{}});
  const next={};const now=Date.now();
  for(const [key,r] of Object.entries(x[KEY]||{})) {
    if(validId(key)&&r?.at>now-TTL&&Object.keys(next).length<30)next[key]=r;
  }
  next[id]={...route,at:now};
  await chrome.storage.session.set({[KEY]:next});
}
async function consume(id) {
  const x=await chrome.storage.session.get({[OPENED]:{}});
  const next={};const now=Date.now();
  for(const [key,at] of Object.entries(x[OPENED]||{})) {
    if(validId(key)&&typeof at==='number'&&at>now-TTL&&Object.keys(next).length<30)next[key]=at;
  }
  if(next[id])return false;
  next[id]=now;
  await chrome.storage.session.set({[OPENED]:next});
  return true;
}
async function openExact(id) {
  if(!validId(id))return;
  const record=(await chrome.storage.session.get({[KEY]:{}}))[KEY]?.[id];
  if(!record?.at || record.at<Date.now()-TTL)return;
  const url=exactUrl(record.url);
  if(!url)return;
  // Reject replays before focusing; only this test event may be consumed once.
  if(!(await consume(id)))return;
  let tab=null;
  if(Number.isInteger(record.tabId)) {
    try{
      const candidate=await chrome.tabs.get(record.tabId);
      if(exactUrl(candidate.url)===url)tab=candidate;
    }catch(_){}
  }
  if(!tab){
    try{
      const tabs=await chrome.tabs.query({url:['https://chatgpt.com/*','https://chat.openai.com/*']});
      tab=tabs.find(t=>exactUrl(t.url)===url)||null;
    }catch(_){}
  }
  if(tab){
    try{
      const win=await chrome.windows.get(tab.windowId);
      if(win?.state==='minimized')await chrome.windows.update(tab.windowId,{state:'normal'});
      await chrome.windows.update(tab.windowId,{focused:true});
      await chrome.tabs.update(tab.id,{active:true});
      return;
    }catch(_){}
  }
  // Exact stored chat only. Never open a generic ChatGPT homepage.
  try{await chrome.tabs.create({url});}catch(_){}
}
function connect(){
  if(port)return port;
  let p;
  try{p=chrome.runtime.connectNative(HOST);}catch(e){lastError='native-host-unavailable';return null;}
  port=p;
  p.onMessage.addListener(msg=>{
    if(p!==port)return;
    if(msg?.type==='bridge.ready' && msg.ok!==true){
      lastError=String(msg.error||'desktop-offline').slice(0,100);
    }else if(msg?.type==='delivery.ack'&&validId(msg.eventId)){
      const r=pending.get(msg.eventId);
      if(r){pending.delete(msg.eventId);clearTimeout(r.timer);if(msg.ok===true&&msg.state!=='duplicate')activeRemote.add(msg.eventId);r.resolve({ok:msg.ok===true,state:msg.state||'',error:msg.error||''});scheduleIdleClose();}
    }else if(msg?.type==='notification.open'&&validId(msg.eventId)){
      activeRemote.delete(msg.eventId);scheduleIdleClose();
      void openExact(msg.eventId);
    }else if(msg?.type==='notification.closed'&&validId(msg.eventId)){
      activeRemote.delete(msg.eventId);scheduleIdleClose();
      void chrome.storage.session.get({[KEY]:{}}).then(async state=>{
        const next={...(state[KEY]||{})};
        if(Object.prototype.hasOwnProperty.call(next,msg.eventId)){
          delete next[msg.eventId];
          await chrome.storage.session.set({[KEY]:next});
        }
      }).catch(()=>{});
    }
  });
  p.onDisconnect.addListener(()=>{
    if(port===p)port=null;
    lastError='native-port-disconnected';
    for(const r of pending.values()){clearTimeout(r.timer);r.resolve({ok:false,error:'native-port-disconnected'});}
    pending.clear();
    activeRemote.clear();
    if(idleTimer){clearTimeout(idleTimer);idleTimer=0;}
  });
  return p;
}
// G4C2 OBSERVER CANDIDATE: real completion metadata only, never prompt/answer text.
const DIAG='g4c2_metadata_diagnostic';
const SEEN='g4c2_completed_cycles';
const CYCLE_TTL=120000;
const activeRemote=new Set();
let idleTimer=0;
let serialize=Promise.resolve();
function serial(task) {
 const next=serialize.then(task,task);
 serialize=next.catch(()=>{});
 return next;
}
function scheduleIdleClose() {
 if(idleTimer)clearTimeout(idleTimer);
 idleTimer=setTimeout(()=>{
   idleTimer=0;
   if(pending.size||activeRemote.size)return;
   const old=port;port=null;
   if(old)try{old.disconnect();}catch(_){}
 },90000);
}
function titleOf(message,sender) {
 const t=String(message.chatTitle||sender.tab?.title||'ChatGPTの会話')
   .replace(/[\x00-\x1f\x7f]/g,' ').trim();
 return (t||'ChatGPTの会話').slice(0,100);
}
function validCycle(message,sender) {
 if(sender?.id!==chrome.runtime.id || !sender.tab ||
    !Number.isInteger(sender.tab.id)||sender.tab.id<0 ||
    !Number.isInteger(sender.tab.windowId)||sender.tab.windowId<0 ||
    typeof sender.documentId!=='string' || sender.documentId.length>128 ||
    typeof message.cycleId!=='string' || !/^\d{11,17}-\d{1,8}$/.test(message.cycleId))return null;
 // Sender's browser URL is authoritative. Never trust message-supplied URLs.
 const url=exactUrl(sender.tab.url);
 if(!url)return null;
 return {url,tabId:sender.tab.id,windowId:sender.tab.windowId,
   cycleKey:sender.documentId+':'+message.cycleId};
}
async function claimCycle(key) {
 const raw=(await chrome.storage.session.get({[SEEN]:{}}))[SEEN]||{};
 const now=Date.now(),next={};
 for(const [k,v] of Object.entries(raw)) {
   if(typeof v==='number'&&v>now-CYCLE_TTL&&Object.keys(next).length<128)next[k]=v;
 }
 if(Object.prototype.hasOwnProperty.call(next,key))return false;
 next[key]=now;
 await chrome.storage.session.set({[SEEN]:next});
 return true;
}
async function completeFromContent(message,sender) {
 const route=validCycle(message,sender);
 if(!route)return {ok:false,error:'invalid-completion-source'};

 const settings=await chrome.storage.local.get({enabled:true,soundId:'female',soundVolume:85});
 if(settings.enabled===false)return {ok:true,suppressed:'disabled'};
 const soundId=['holo','soft','pulse','female'].includes(settings.soundId)?settings.soundId:'female';
 const soundVolume=Number.isFinite(Number(settings.soundVolume))?
     Math.max(0,Math.min(100,Math.round(Number(settings.soundVolume)))):85;
 if(!(await claimCycle(route.cycleKey)))return {ok:true,suppressed:'duplicate'};
 const id=crypto.randomUUID();
 await saveRoute(id,{tabId:route.tabId,url:route.url});
 const p=connect();
 if(!p)return {ok:false,error:lastError||'native-unavailable'};
 const event={version:2,source:'chatgpt',eventId:id,chatTitle:titleOf(message,sender),
   completedAt:new Date().toISOString(),conversationUrl:route.url,
   tabId:route.tabId,windowId:route.windowId};
 // One audio owner: G4 Tauri. No offscreen audio and NO Chrome fallback
 // in this isolated candidate (unknown ACK must not create two banners).
 return await new Promise(resolve=>{
   const timer=setTimeout(()=>{
     pending.delete(id);resolve({ok:false,error:'unknown-ack-timeout'});
     scheduleIdleClose();
   },8000);
   pending.set(id,{timer,resolve});
   try{p.postMessage({version:2,type:'deliver',event,
         soundId,soundVolume,audioOwner:'desktop'});}
   catch(_){pending.delete(id);clearTimeout(timer);
       resolve({ok:false,error:'native-post-failed'});scheduleIdleClose();}
 });
}
chrome.runtime.onMessage.addListener((m,sender,reply)=>{
 if(m?.type==='G4C2_STATUS'){
   void chrome.storage.session.get({[SEEN]:{},[DIAG]:{}}).then(x=>{
     const diag=x[DIAG]||{};
     reply({ok:true,mode:'G4C2_REAL_OBSERVER_ISOLATED',
       nativeConnected:!!port,claims:Object.keys(x[SEEN]||{}).length,
       received:diag.received||0,accepted:diag.accepted||0,
       lastResult:diag.lastResult||'none',activeNative:activeRemote.size,
       pendingNative:pending.size});
   }).catch(()=>reply({ok:false,error:'status-unavailable'}));
   return true;
 }
 if(m?.type==='VIEWED')return; // Source observer status, not a notification.
 if(m?.type!=='COMPLETE')return;
 void serial(async()=>{
   let outcome;
   try{outcome=await completeFromContent(m,sender);}
   catch(_){outcome={ok:false,error:'delivery-exception'};}
   // Persist ONLY a small result class and aggregate counts. No content, URL,
   // event ID, cycle ID, tab title or stack traces are recorded.
   try{
     const record=(await chrome.storage.session.get({[DIAG]:{}}))[DIAG]||{};
     const result=outcome?.suppressed==='duplicate'?'duplicate':
       outcome?.ok===true?'accepted':
       (['invalid-completion-source','native-unavailable','unknown-ack-timeout',
         'native-post-failed','native-port-disconnected','delivery-exception']
         .includes(outcome?.error)?outcome.error:'native-rejected');
     await chrome.storage.session.set({[DIAG]:{
       received:Math.min(1000,(record.received||0)+1),
       accepted:Math.min(1000,(record.accepted||0)+(outcome?.ok===true&&outcome?.suppressed!=='duplicate'?1:0)),
       lastResult:result
     }});
   }catch(_){}
   return outcome;
 }).then(reply).catch(()=>reply({ok:false,error:'delivery-exception'}));
 return true;
});
