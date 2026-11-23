'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../background.js'),'utf8');
const waits=(ms)=>new Promise(r=>setTimeout(r,ms));
function harness(){
 const local={pendingChats:[]}, session={}, handlers={},tabs=new Map([
  [5,{id:5,windowId:1,url:'https://chatgpt.com/c/12345678',title:'Test',active:false}],
  [6,{id:6,windowId:2,url:'https://chatgpt.com/c/87654321',title:'Other',active:false}]
 ]),actions=[];
 const get=(store,key)=>typeof key==='string'?{[key]:store[key]}:
  (Array.isArray(key)?Object.fromEntries(key.map(k=>[k,store[k]])):Object.assign({},key,store));
 const chrome={
  runtime:{onInstalled:{addListener:f=>handlers.installed=f},onStartup:{addListener:f=>handlers.startup=f},onMessage:{addListener:f=>handlers.onMessage=f},
    getURL:v=>'chrome-extension://mock/'+v,getContexts:async()=>[{documentUrl:'chrome-extension://mock/offscreen.html'}],
    sendMessage:async()=>({ok:true}),connectNative:()=>{const p={onMessage:{addListener:f=>p.onMsg=f},onDisconnect:{addListener:f=>p.onDisc=f},
      postMessage:o=>queueMicrotask(()=>p.onMsg({type:'delivery.ack',eventId:o.event.eventId,ok:true,state:'active'})),disconnect:()=>{}};handlers.port=p;return p;}},
  storage:{local:{get:async k=>get(local,k),set:async v=>Object.assign(local,v),remove:async()=>{}},
    session:{get:async k=>get(session,k),set:async v=>Object.assign(session,v)}},
  action:{setBadgeText:async()=>{},setIcon:async()=>{},setTitle:async()=>{}},
  notifications:{getPermissionLevel:async()=> 'granted',create:async()=>{},clear:async()=>{},onClicked:{addListener:f=>handlers.noticeClicked=f}},
  offscreen:{createDocument:async()=>{}},
  tabs:{onActivated:{addListener:f=>handlers.tabActivated=f},onUpdated:{addListener:f=>handlers.tabUpdated=f},get:async id=>{if(!tabs.has(id))throw Error('gone');return tabs.get(id);},
    query:async()=>[...tabs.values()],update:async(id,o)=>{actions.push(['tab-focus',id]);Object.assign(tabs.get(id),o);},
    create:async o=>{actions.push(['create',o.url]);}},
  windows:{WINDOW_ID_NONE:-1,onFocusChanged:{addListener:f=>handlers.focusChanged=f},get:async()=>({focused:false,state:'normal'}),
    update:async(id)=>{actions.push(['window-focus',id]);}}
 };
 let n=0;
 const ctx={chrome,crypto:{randomUUID:()=> '00000000-0000-4000-8000-'+String(++n).padStart(12,'0')},
    URL,Map,Set,Date,Object,Promise,Number,String,console,setTimeout:(f,ms)=>{const h=setTimeout(f,ms);h.unref?.();return h;},clearTimeout};
 vm.runInNewContext(source,ctx);
 const send=(msg,sender)=>new Promise(resolve=>handlers.onMessage(msg,sender,resolve));
 return {local,session,handlers,tabs,actions,send};
}
(async()=>{
  let h=harness();
  await waits(10);
  const sender={tab:{...h.tabs.get(5)},documentId:'doc5'};
  await h.send({type:'COMPLETE',cycleId:'cycle1',chatTitle:'Test'},sender);
  const eventId=Object.keys(h.session.g3_activeNotificationRoutes)[0];
  assert.ok(eventId,'route saved to session storage');
  h.tabs.get(5).url='https://chatgpt.com/c/87654321';
  h.tabs.set(8,{id:8,windowId:3,url:'https://chatgpt.com/c/12345678',title:'Moved',active:false});
  h.handlers.port.onMsg({type:'notification.open',eventId});
  await waits(25);
  assert.deepEqual(h.actions.slice(-2).map(a=>a[0]),['window-focus','tab-focus']);
  assert.deepEqual(h.actions.at(-1),['tab-focus',8],'must focus exact alternate chat not the reused tab');
  const oldActions=h.actions.length;
  const bad={eventId:'test-route-invalid-0000',at:Date.now(),tabId:5,conversationUrl:null};
  h.session.g3_activeNotificationRoutes[bad.eventId]=bad;
  h.handlers.port.onMsg({type:'notification.open',eventId:bad.eventId});
  await waits(25);
  assert.equal(h.actions.length,oldActions,'unknown conversation must not open a random chat');
  h.tabs.delete(8);
  h.handlers.port.onMsg({type:'notification.open',eventId});
  await waits(25);
  assert.deepEqual(h.actions.at(-1),['create','https://chatgpt.com/c/12345678']);
  console.log('G3_CHATGPT_EXACT_ROUTE_PASS');
})().catch(e=>{console.error(e);process.exitCode=1;});
