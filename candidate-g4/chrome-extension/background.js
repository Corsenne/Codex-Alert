'use strict';
// G4 isolated test: NO content script, NO automatic completion detection.
const HOST='com.corsenne.finish_alert_g4_test';
const KEY='g4_routes';
const OPENED='g4_opened';
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
      if(r){pending.delete(msg.eventId);clearTimeout(r.timer);r.resolve({ok:msg.ok===true,state:msg.state||'',error:msg.error||''});}
    }else if(msg?.type==='notification.open'&&validId(msg.eventId)){
      void openExact(msg.eventId);
    }else if(msg?.type==='notification.closed'&&validId(msg.eventId)){
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
  });
  return p;
}
async function sendTest(){
  const tabs=await chrome.tabs.query({active:true,currentWindow:true});
  const tab=tabs?.[0];
  const url=exactUrl(tab?.url);
  if(!url||!Number.isInteger(tab?.id)||!Number.isInteger(tab?.windowId))return {ok:false,error:'open-an-existing-chatgpt-conversation-first'};
  const id=crypto.randomUUID();
  await saveRoute(id,{tabId:tab.id,url});
  const p=connect();
  if(!p)return {ok:false,error:lastError};
  const event={version:2,eventId:id,chatTitle:'CHATGPT G4 TEST',conversationUrl:url,
     completedAt:new Date().toISOString(),tabId:tab.id,windowId:tab.windowId,source:'chatgpt'};
  return await new Promise(resolve=>{
    const timer=setTimeout(()=>{pending.delete(id);resolve({ok:false,error:'ack-timeout'});},8000);
    pending.set(id,{timer,resolve});
    try{p.postMessage({version:2,type:'deliver',event,soundId:'female',soundVolume:85,audioOwner:'desktop'});}
    catch(_){pending.delete(id);clearTimeout(timer);resolve({ok:false,error:'send-failed'});}
  });
}
chrome.runtime.onMessage.addListener((m,sender,reply)=>{
 if(m?.type!=='G4_SEND_TEST')return;
 void sendTest().then(reply).catch(()=>reply({ok:false,error:'test-unavailable'}));
 return true;
});
