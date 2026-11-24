'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../background.js'),'utf8');
const wait=ms=>new Promise(r=>setTimeout(r,ms));
function harness(legacy={}) {
  const store={...legacy},handlers={},notifications=[],posts=[],badgeText=[],iconPaths=[],removedKeys=[],soundMessages=[];
  const tabRecords=new Map([
    [1,{id:1,windowId:9,url:'https://chatgpt.com/c/abcdefghij',title:'Chat A',active:false}],
    [2,{id:2,windowId:9,url:'https://chatgpt.com/c/xyzxyzxyz1',title:'Chat B',active:false}],
    [3,{id:3,windowId:9,url:'https://chatgpt.com/c/aabbccddzz',title:'Chat C',active:false}]
  ]);
  let desktopOnline=true,port=null,focused=false,ackMode='success';
  function getStore(arg) {
    if(typeof arg==='string')return {[arg]:store[arg]};
    if(Array.isArray(arg))return Object.fromEntries(arg.map(k=>[k,store[k]]));
    return Object.assign({},arg,store);
  }
  const chrome={
    runtime:{onInstalled:{addListener:f=>handlers.installed=f},onStartup:{addListener:f=>handlers.startup=f},
      onMessage:{addListener:f=>handlers.message=f},getURL:p=>'chrome-extension://mock/'+p,
      getContexts:async()=>[{documentUrl:'chrome-extension://mock/offscreen.html'}],
      sendMessage:async msg=>{soundMessages.push(msg);return {ok:true};},
      connectNative:()=>{
        if(!desktopOnline)throw Error('Native host not found');
        const x={onMessage:{addListener:f=>x.message=f},onDisconnect:{addListener:f=>x.disconnected=f},
          postMessage:msg=>{posts.push(msg);if(ackMode!=='timeout')queueMicrotask(()=>x.message({type:'delivery.ack',eventId:msg.event.eventId,ok:ackMode==='success',error:ackMode==='success'?'':ackMode==='queue-full'?'queue-full':'desktop-unavailable'}));},
          disconnect:()=>{}};
        port=x;return x;
      }},
    storage:{local:{get:async arg=>getStore(arg),set:async data=>Object.assign(store,data),
      remove:async keys=>{removedKeys.push(...keys);for(const k of keys)delete store[k];}}},
    action:{setBadgeText:async v=>badgeText.push(v.text),setIcon:async v=>iconPaths.push(v.path),setTitle:async()=>{}},
    notifications:{create:async(id,opts)=>{notifications.push({id,opts});return id;},clear:async()=>{},
      getPermissionLevel:async()=> 'granted',onClicked:{addListener:f=>handlers.notificationClicked=f}},
    offscreen:{createDocument:async()=>{}},
    tabs:{onActivated:{addListener:f=>handlers.activated=f},onUpdated:{addListener:f=>handlers.updated=f},
      get:async id=>({...tabRecords.get(id)}),query:async({windowId})=>[...tabRecords.values()].filter(t=>t.windowId===windowId&&t.active),
      update:async(id,update)=>{for(const t of tabRecords.values())if(t.windowId===tabRecords.get(id).windowId&&update.active)t.active=false;
        Object.assign(tabRecords.get(id),update);},create:async opts=>{handlers.createdTab=opts;}},
    windows:{WINDOW_ID_NONE:-1,onFocusChanged:{addListener:f=>handlers.focusChanged=f},
      get:async()=>({focused,state:'normal'}),update:async()=>{focused=true;}}
  };
  let counter=0;
  const ctx={chrome,crypto:{randomUUID:()=>`00000000-0000-4000-8000-${String(++counter).padStart(12,'0')}`},
    URL,Map,Date,console,String,Number,Object,Promise,Set,setTimeout:(fn,ms,...args)=>{const t=setTimeout(fn,ms===10000?60:ms,...args);if(ms>=90000)t.unref();return t;},clearTimeout};
  vm.runInNewContext(source,ctx);
  const send=(msg,sender={})=>new Promise((resolve,reject)=>{
    if(handlers.message(msg,sender,resolve)!==true)reject(Error('async listener expected'));
  });
  const sender=(tabId,doc)=>({tab:{...tabRecords.get(tabId)},documentId:doc});
  const complete=(tabId,cycleId,docId,chatTitle)=>send({type:'COMPLETE',cycleId,chatTitle},sender(tabId,docId));
  const status=()=>send({type:'GET_STATUS'});
  const activate=(id,focus=true)=>{
    focused=focus;
    for(const x of tabRecords.values())if(x.windowId===9)x.active=false;
    tabRecords.get(id).active=true;
    handlers.activated({tabId:id,windowId:9});
  };
  return {store,handlers,notifications,posts,badgeText,iconPaths,removedKeys,soundMessages,tabRecords,
    send,complete,status,sender,activate,windowFocus:(focus)=>{focused=focus;handlers.focusChanged(focus?9:-1);},
    updateTab:(id,url)=>{tabRecords.get(id).url=url;handlers.updated(id,{url},{...tabRecords.get(id)});},
    offline:()=>{desktopOnline=false;if(port)port.disconnected();},
    nativeOpen:id=>port.message({type:'notification.open',eventId:id}),setAckMode:mode=>{ackMode=mode;}};
}
(async()=>{
  const h=harness({events:[{eventId:'00000000-0000-4000-8000-000000001234',tabId:3,
      conversationUrl:'https://chatgpt.com/c/aabbccddzz',read:false}],
    completedCount:999,lastEvent:{status:'old'},lastCompletion:{status:'old'},sound:true,onlyWhenAway:true});
  let s=await h.status();
  await wait(10); // on-startup icon projection runs asynchronously after storage migration.
  assert.equal(s.hasUnread,true,'legacy unread must migrate');
  assert.equal(h.store.events,undefined,'old history removed');
  assert.equal(h.store.completedCount,undefined,'old total removed');
  assert.equal(h.store.sound,undefined,'old sound toggle removed');
  assert.equal(h.badgeText.at(-1),'','legacy text badge must always be cleared');
  assert.equal(h.iconPaths.at(-1)[16],'assets/icon16-unread.png','unread icon has cyan dot');
  h.activate(3);await wait(20);
  assert.equal((await h.status()).hasUnread,false,'legacy unseen chat clears when opened');
  assert.equal(h.badgeText.at(-1),'');
  assert.equal(h.iconPaths.at(-1)[16],'assets/icon16.png','read icon has no dot');
  await h.complete(1,'cycleA','docA','JARVIS Stage 4 - ChatGPT');
  await h.complete(2,'cycleB','docB','IAMO audit');
  s=await h.status();
  assert.equal(s.hasUnread,true);assert.equal(h.store.pendingChats.length,2);
  assert.equal(h.badgeText.at(-1),'','no text badge for any pending count');
  assert.equal(h.iconPaths.at(-1)[48],'assets/icon48-unread.png','multiple chats still show just one cyan dot');
  assert.equal(h.posts.length,2);
  assert.equal(h.posts[0].soundId,'holo');assert.equal(h.posts[0].soundVolume,85,'desktop owns audio at configured volume');assert.equal(h.posts[0].audioOwner,'desktop');assert.equal(h.posts[0].event.chatTitle,'JARVIS Stage 4');
  assert.equal(h.soundMessages.length,0,'no Chrome sound when desktop owns the queue');
  assert.equal(h.notifications.length,0);
  await h.complete(2,'cycleB','docB','IAMO audit');
  assert.equal(h.posts.length,2,'same cycle suppressed');
  assert.equal(h.soundMessages.length,0,'duplicate must not trigger any Chrome sound');
  // Completing another response in the same chat replaces the pending marker.
  await h.complete(2,'cycleB2','docB','IAMO audit');
  assert.equal(h.store.pendingChats.length,2,'no history / count per repeated completion');
  h.activate(1);await wait(20);
  assert.equal(h.store.pendingChats.length,1,'opening Chat A clears only A');
  assert.equal(h.store.pendingChats[0].tabId,2,'Chat B remains unseen');
  h.windowFocus(false);
  h.activate(2,false);await wait(20);
  assert.equal(h.store.pendingChats.length,1,'activation in unfocused Chrome must not mark read');
  h.windowFocus(true);await wait(20);
  assert.equal(h.store.pendingChats.length,0,'returning focus to Chat B clears remaining unread');
  assert.equal(h.badgeText.at(-1),'');
  assert.equal(h.iconPaths.at(-1)[16],'assets/icon16.png','read icon has no dot');
  await h.complete(1,'cycleA2','docA','JARVIS Stage 4');
  const id=h.posts.at(-1).event.eventId;
  h.nativeOpen(id);await wait(20);
  assert.equal(h.handlers.createdTab,undefined,'native click focuses existing tab');
  assert.equal(h.store.pendingChats.length,0);
  await h.send({type:'PREVIEW_SOUND',soundId:'soft',volume:40});
  assert.equal(h.soundMessages.at(-1).soundId,'soft','audio preview follows choice');
  assert.equal(h.soundMessages.at(-1).volume,40,'preview volume passes to offscreen');
  await h.send({type:'PREVIEW_SOUND',soundId:'pulse',volume:100});
  assert.equal(h.soundMessages.at(-1).soundId,'pulse');
  assert.equal(h.soundMessages.at(-1).volume,100);
  await h.send({type:'PREVIEW_SOUND',soundId:'female',volume:35});
  assert.equal(h.soundMessages.at(-1).soundId,'female','female voice is selectable');
  assert.equal(h.soundMessages.at(-1).volume,35);
  h.store.soundId='female';h.store.soundVolume=35;
  await h.complete(1,'female-cycle','docF','女性通知');
  assert.equal(h.posts.at(-1).soundId,'female','female sound must cross native bridge');
  assert.equal(h.posts.at(-1).soundVolume,35,'native receives selected volume');
  assert.equal(h.soundMessages.at(-1).volume,35,'preview remains the last Chrome sound');
  h.store.soundVolume=0;
  await h.complete(1,'silent-cycle','docF','無音通知');
  assert.equal(h.posts.at(-1).soundVolume,0,'zero volume retains banner delivery');
  await h.complete(2,'cycleB3','docB','new sound');
  await h.send({type:'UNKNOWN_TEST'}).then(x=>assert.equal(x.ok,false));
  await h.send({type:'PREVIEW_SOUND',soundId:'invalid'});
  assert.equal(h.soundMessages.at(-1).soundId,'holo','unexpected sound uses safe default');
  // Native queue overflow must not start an overlapping Chrome voice/banner.
  h.setAckMode('queue-full');
  const noSoundBefore=h.soundMessages.length,noNoticeBefore=h.notifications.length;
  const queueOverflow=await h.complete(1,'overload-cycle','docL','Queue overflow');
  assert.equal(queueOverflow.ok,false,'queue-full must be visible as a failure result');
  assert.equal(queueOverflow.error,'queue-full');
  assert.equal(h.soundMessages.length,noSoundBefore,'queue-full cannot overlap native sound');
  assert.equal(h.notifications.length,noNoticeBefore,'queue-full cannot overlap native banner');
  h.setAckMode('success');
  // No native ACK: banner may have been displayed and Windows may later acknowledge.
  // Chrome fallback must not speak again on timeout.
  h.setAckMode('timeout');
  h.store.soundVolume=70;
  const soundsBeforeTimeout=h.soundMessages.length;
  const noticesBeforeTimeout=h.notifications.length;
  await h.complete(1,'timeout-cycle','docT','ACK timeout scenario');
  assert.equal(h.soundMessages.length,soundsBeforeTimeout,'unknown ACK must not start Chrome sound');
  assert.equal(h.notifications.length,noticesBeforeTimeout,'unknown ACK must not trigger duplicate Chrome notice');
  assert.equal(h.posts.at(-1).soundVolume,70,'native owns the queued voice even on late ACK');
  // Native host fully offline must still play via Chrome exactly once.
  h.offline();
  h.store.soundVolume=65;
  await h.complete(1,'cycleA3','docC','Fallback chat');
  assert.equal(h.notifications.length,noticesBeforeTimeout+1,'only known-not-sent events use Chrome fallback');
  assert.equal(h.soundMessages.at(-1).type,'PLAY_SOUND','fallback audio played');
  assert.equal(h.soundMessages.at(-1).volume,65,'Chrome fallback uses saved volume');
  assert.equal(h.soundMessages.at(-1).soundId,'female','Chrome fallback retains female voice');
  const soundCount=h.soundMessages.length;
  h.store.soundVolume=0;
  await h.complete(1,'zero-fallback','docC','Silent fallback');
  assert.equal(h.notifications.length,noticesBeforeTimeout+2,'zero-volume fallback still displays banner');
  assert.equal(h.soundMessages.length,soundCount,'zero volume suppresses audio without sound toggle');
  h.handlers.notificationClicked(h.notifications[0].id);await wait(30);
  assert.equal(h.store.pendingChats.some(p=>p.tabId===1),false,'Chrome notification click marks Chat A as read');
  const disabled=harness({enabled:false});
  await disabled.complete(1,'disabled','docD','Disabled');
  assert.equal(disabled.posts.length,0);assert.equal(disabled.store.pendingChats.length,0);
  assert.equal(Object.keys(h.store).includes('lastEvent'),false,'no diagnostic event storage');
  assert.equal(Object.keys(h.store).includes('completedCount'),false,'no cumulative count storage');
  assert.equal(h.soundMessages.at(-1).type,'STOP_SOUND','fallback notification click stops audio');
  console.log('PASS background v1.2 G2: native queued audio owner, unknown ACK no double notification, offline fallback, click stops audio, routing, volume, unread');
})().catch(e=>{console.error(e);process.exitCode=1;});
