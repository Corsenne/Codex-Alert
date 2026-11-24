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
 ]),actions=[], windows=new Map([[1,'normal'],[2,'normal'],[3,'normal']]);
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
  windows:{WINDOW_ID_NONE:-1,onFocusChanged:{addListener:f=>handlers.focusChanged=f},
    get:async id=>({focused:false,state:windows.get(id)||'normal'}),
    update:async(id,o)=>{if(o.state){windows.set(id,o.state);actions.push(['window-restore',id]);}
      if(o.focused)actions.push(['window-focus',id]);}}
 };
 let n=0;
 const ctx={chrome,crypto:{randomUUID:()=> '00000000-0000-4000-8000-'+String(++n).padStart(12,'0')},
    URL,Map,Set,Date,Object,Promise,Number,String,console,setTimeout:(f,ms)=>{const h=setTimeout(f,ms);h.unref?.();return h;},clearTimeout};
 vm.runInNewContext(source,ctx);
 const send=(msg,sender)=>new Promise(resolve=>handlers.onMessage(msg,sender,resolve));
 return {local,session,handlers,tabs,windows,actions,send};
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
  // Original tab reused another conversation; restore the matching alternate tab.
  h.windows.set(3,'minimized');
  h.handlers.port.onMsg({type:'notification.open',eventId});
  await waits(30);
  assert.deepEqual(h.actions.slice(-3),[['window-restore',3],['window-focus',3],['tab-focus',8]]);
  assert.ok(h.session.g3_completedNotificationOpens[eventId],'clicked event becomes consumed');
  const clickedActionCount=h.actions.length;
  h.handlers.port.onMsg({type:'notification.open',eventId});
  await waits(30);
  assert.equal(h.actions.length,clickedActionCount,'duplicate callback must not focus again');

  // Exact unknown target must not switch to a wrong or generic homepage.
  const bad={eventId:'test-route-invalid-0000',at:Date.now(),tabId:5,conversationUrl:null};
  h.session.g3_activeNotificationRoutes[bad.eventId]=bad;
  h.handlers.port.onMsg({type:'notification.open',eventId:bad.eventId});
  await waits(30);
  assert.equal(h.actions.length,clickedActionCount,'unknown target must fail closed');

  // Simulate a second, valid event whose original and alternate tabs were closed.
  const sender2={tab:{id:5,windowId:1,url:'https://chatgpt.com/c/12345678',title:'Test',active:false},documentId:'doc5b'};
  const answer2=await h.send({type:'COMPLETE',cycleId:'cycle2',chatTitle:'Test'},sender2);
  assert.ok(answer2?.ok);
  const eventId2=Object.keys(h.session.g3_activeNotificationRoutes).find(id=>id!==eventId && id!==bad.eventId);
  assert.ok(eventId2);
  h.tabs.delete(5);h.tabs.delete(8);
  h.handlers.port.onMsg({type:'notification.open',eventId:eventId2});
  await waits(30);
  assert.deepEqual(h.actions.at(-1),['create','https://chatgpt.com/c/12345678']);
  const created=h.actions.length;
  h.handlers.port.onMsg({type:'notification.open',eventId:eventId2});
  await waits(30);
  assert.equal(h.actions.length,created,'second callback for closed tab must not create another tab');
  assert.equal(Object.keys(h.session.g3_completedNotificationOpens).length,2);
  console.log('G3_CHATGPT_EXACT_ROUTE_PASS');
})().catch(e=>{console.error(e);process.exitCode=1;});
