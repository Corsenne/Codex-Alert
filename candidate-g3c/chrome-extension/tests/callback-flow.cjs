'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'..','background.js'),'utf8');
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
function harness(){
 const store={},actions=[],windows=new Map([[2,'minimized']]),
 tabs=new Map([
   [7,{id:7,windowId:2,url:'https://chatgpt.com/c/12345678-abcd',active:true}],
   [9,{id:9,windowId:3,url:'https://chatgpt.com/c/22222222-ffff',active:false}]
 ]),handlers={};
 let next=0;
 const port={};
 port.onMessage={addListener:f=>{port.onMsg=f;}};
 port.onDisconnect={addListener:f=>{port.onDisconnectCallback=f;}};
 port.postMessage=msg=>{
   handlers.sent=msg;
   queueMicrotask(()=>port.onMsg({type:'delivery.ack',eventId:msg.event.eventId,ok:true,state:'active'}));
 };
 const chrome={
  runtime:{
    onMessage:{addListener:f=>handlers.message=f},
    connectNative:name=>{handlers.host=name;return port;}
  },
  storage:{session:{
    get:async d=>typeof d==='string'?{[d]:store[d]}:Object.assign({},d,store),
    set:async vals=>Object.assign(store,vals)
  }},
  tabs:{
    get:async id=>{if(!tabs.has(id))throw Error('closed');return tabs.get(id);},
    query:async opts=>opts.active?[...tabs.values()].filter(t=>t.active):[...tabs.values()],
    update:async(id,opts)=>{actions.push(['focusTab',id]);Object.assign(tabs.get(id),opts);},
    create:async({url})=>{actions.push(['createExact',url]);}
  },
  windows:{
    get:async id=>({state:windows.get(id)||'normal'}),
    update:async(id,opts)=>{
      if(opts.state){windows.set(id,opts.state);actions.push(['restoreWindow',id]);}
      if(opts.focused)actions.push(['focusWindow',id]);
    }
  }
 };
 const context={chrome,URL,Date,Map,Object,Number,String,Promise,console,crypto:{
   randomUUID:()=> '00000000-0000-4000-8000-'+String(++next).padStart(12,'0')},
   setTimeout:(fn,ms)=>{const h=setTimeout(fn,ms);h.unref?.();return h;},clearTimeout};
 vm.runInNewContext(source,context);
 const send=()=>new Promise(res=>handlers.message({type:'G3C_SEND_TEST'},{},res));
 return {send,port,store,tabs,windows,actions,handlers};
}
(async()=>{
 const h=harness();
 const ack=await h.send();
 assert.equal(ack.ok,true,'manual test event must be ACKed');
 assert.equal(ack.state,'active');
 assert.equal(h.handlers.host,'com.corsenne.finish_alert_g3c_test');
 assert.ok(h.handlers.sent);
 assert.equal(h.handlers.sent.audioOwner,'desktop');
 const id=h.handlers.sent.event.eventId;
 assert.equal(h.store.g3c_routes[id].tabId,7);
 assert.equal(h.handlers.sent.event.conversationUrl,'https://chatgpt.com/c/12345678-abcd');

 // Test user switches to a different thread before banner click.
 h.tabs.get(7).active=false;
 h.tabs.get(9).active=true;
 h.port.onMsg({type:'notification.open',eventId:id});
 await wait(30);
 assert.deepEqual(h.actions,[
   ['restoreWindow',2],['focusWindow',2],['focusTab',7]
 ]);
 assert.ok(h.store.g3c_opened[id],'clicked event must be consumed');
 const before=h.actions.length;
 h.port.onMsg({type:'notification.open',eventId:id});
 await wait(30);
 assert.equal(h.actions.length,before,'replayed callback must be ignored');

 // Unknown event must never navigate or open the ChatGPT homepage.
 h.port.onMsg({type:'notification.open',eventId:'not-a-real-event'});
 await wait(30);
 assert.equal(h.actions.length,before);

 // Closed original tab: never focus a tab with a different conversation.
 h.tabs.delete(7);
 h.tabs.get(9).active=false;
 h.tabs.set(10,{id:10,windowId:3,url:'https://chatgpt.com/c/12345678-abcd',active:true});
 const ack2=await h.send();assert.equal(ack2.ok,true);
 const eventId2=h.handlers.sent.event.eventId;
 h.tabs.delete(10);
 h.port.onMsg({type:'notification.open',eventId:eventId2});
 await wait(30);
 assert.deepEqual(h.actions.at(-1),['createExact','https://chatgpt.com/c/12345678-abcd']);
 console.log('G3C_CHROME_NATIVE_CALLBACK_MODEL_PASS');
})().catch(e=>{console.error(e);process.exitCode=1;});
