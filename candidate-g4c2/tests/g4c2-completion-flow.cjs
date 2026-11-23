'use strict';
const assert=require('node:assert/strict');
const {readFileSync}=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const source=readFileSync(path.join(__dirname,'..','chrome-extension','background.js'),'utf8');
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
function harness(){
 const store={},actions=[],sent=[],handlers={},tabs=new Map([
  [7,{id:7,windowId:2,url:'https://chatgpt.com/c/12345678-abcd?model=auto',title:'Conversation A',active:true}],
  [9,{id:9,windowId:3,url:'https://chatgpt.com/c/22222222-ffff',title:'Conversation B',active:false}]
 ]);
 const ports=[];
 let seq=0;
 const p={
  onMessage:{addListener:f=>{p.onMsg=f}},
  onDisconnect:{addListener:f=>{p.onDisconnectCall=f}},
  disconnect:()=>{p.onDisconnectCall?.()},
  postMessage:(msg)=>{
   sent.push(msg);
   queueMicrotask(()=>p.onMsg({type:'delivery.ack',eventId:msg.event.eventId,ok:true,state:'active'}));
  }
 };
 const chrome={
  runtime:{
   id:'abcdefghijklmnopabcdefghijklmnop',
   onMessage:{addListener:f=>{handlers.message=f}},
   connectNative:name=>{ports.push(name);return p}
  },
  storage:{session:{
   get:async defaults=>Object.assign({},defaults,store),
   set:async update=>Object.assign(store,update)
  }},
  tabs:{
   get:async id=>{if(!tabs.has(id))throw Error('tab-closed');return tabs.get(id)},
   query:async()=>[...tabs.values()],
   update:async(id,options)=>{actions.push(['tab',id]);Object.assign(tabs.get(id),options)},
   create:async({url})=>{actions.push(['create',url])}
  },
  windows:{
   get:async()=>({state:'minimized'}),
   update:async(id,opts)=>{actions.push(['window',id,Object.keys(opts)[0]])}
  }
 };
 const ctx={
  chrome,URL,Promise,Date,Number,Object,Map,Set,String,console,
  crypto:{randomUUID:()=> '00000000-0000-4000-8000-'+String(++seq).padStart(12,'0')},
  setTimeout:(fn,ms)=>{const t=setTimeout(fn,ms);t.unref?.();return t;},
  clearTimeout
 };
 vm.runInNewContext(source,ctx);
 const send=(type,props={},sender={})=>
   new Promise(resolve=>handlers.message({type,...props},sender,resolve));
 const sender=(tabId=7)=>({id:chrome.runtime.id,documentId:'document-alpha',
   tab:tabs.get(tabId)});
 return {store,actions,sent,handlers,tabs,ports,p,send,sender};
}
(async()=>{
 const h=harness(),good={cycleId:'1795420000000-1',chatTitle:'Real Chat A\nClick'};
 const r=await h.send('COMPLETE',good,h.sender());
 assert.equal(r.ok,true,'native delivery must ACK');
 assert.equal(r.state,'active');
 assert.equal(h.ports[0],'com.corsenne.finish_alert_g4c2_test');
 assert.equal(h.sent.length,1);
 const event=h.sent[0].event;
 assert.equal(h.sent[0].audioOwner,'desktop');
 assert.equal(h.sent[0].soundId,'female');
 assert.equal(event.source,'chatgpt');
 assert.equal(event.version,2);
 assert.equal(event.conversationUrl,'https://chatgpt.com/c/12345678-abcd');
 assert.equal(event.chatTitle,'Real Chat A Click');
 assert.equal(h.store.g4c2_routes[event.eventId].tabId,7);
 const duplicate=await h.send('COMPLETE',good,h.sender());
 assert.equal(duplicate.suppressed,'duplicate');
 assert.equal(h.sent.length,1,'same cycle delivered once');
 const spoof=await h.send('COMPLETE',{cycleId:'1795420000000-2'},
   {id:'wrongid',documentId:'document-beta',tab:h.tabs.get(7)});
 assert.equal(spoof.ok,false);
 const noChat=await h.send('COMPLETE',{cycleId:'1795420000000-3'},
   {id:h.sender().id,documentId:'document-beta',
    tab:{id:21,windowId:3,url:'https://example.com/c/12345678'}});
 assert.equal(noChat.ok,false);
 assert.equal(h.sent.length,1);
 // Navigate elsewhere before click; click must restore the exact original chat.
 h.tabs.get(7).active=false;
 h.tabs.get(9).active=true;
 h.p.onMsg({type:'notification.open',eventId:event.eventId});
 await wait(30);
 assert.deepEqual(h.actions,[['window',2,'state'],['window',2,'focused'],['tab',7]]);
 const before=h.actions.length;
 h.p.onMsg({type:'notification.open',eventId:event.eventId});
 await wait(30);
 assert.equal(h.actions.length,before,'callback replay must not navigate');
 h.p.onMsg({type:'notification.open',eventId:'fake-1234567890'});
 await wait(20);
 assert.equal(h.actions.length,before,'unknown event cannot navigate');
 // New completion with a different cycle is permitted.
 const next=await h.send('COMPLETE',{cycleId:'1795420000000-4'},h.sender());
 assert.equal(next.ok,true);
 assert.equal(h.sent.length,2);
 h.p.onMsg({type:'notification.closed',eventId:h.sent[1].event.eventId});
 const status=await h.send('G4C2_STATUS');
 assert.equal(status.ok,true);
 assert.equal(status.mode,'G4C2_REAL_OBSERVER_ISOLATED');
 console.log('G4C2_REAL_COMPLETION_NATIVE_CALLBACK_MODEL_PASS');
})().catch(e=>{console.error(e);process.exitCode=1});
