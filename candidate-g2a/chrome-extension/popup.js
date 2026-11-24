'use strict';
const $=id=>document.getElementById(id);
const SOUNDS=new Set(['holo','soft','pulse','female']);
const volumeChoice=v=>Number.isFinite(Number(v))?Math.max(0,Math.min(100,Math.round(Number(v)/5)*5)):85;
async function request(type,extras={}){
  const result=await chrome.runtime.sendMessage({type,...extras});
  if(!result?.ok)throw new Error(result?.error||'操作に失敗');
  return result;
}
function feedback(message){
  const element=$('feedback');
  element.textContent=message;
  element.hidden=!message;
}
async function refresh(){
  const state=await request('GET_STATUS');
  $('unreadStatus').classList.toggle('has-unread',state.hasUnread);
  $('unreadLabel').textContent=state.hasUnread?'未確認あり':'確認済み';
}
async function init(){
  const stored=await chrome.storage.local.get({enabled:true,soundId:'holo',soundVolume:85});
  $('enabled').checked=!!stored.enabled;
  $('soundId').value=SOUNDS.has(stored.soundId)?stored.soundId:'holo';
  $('soundVolume').value=String(volumeChoice(stored.soundVolume));
  $('volumeValue').textContent=$('soundVolume').value+'%';
  $('enabled').addEventListener('change',async()=>{
    try{await chrome.storage.local.set({enabled:$('enabled').checked});feedback('');}
    catch(e){feedback('設定保存エラー: '+e.message);}
  });
  $('soundId').addEventListener('change',async()=>{
    try{await chrome.storage.local.set({soundId:$('soundId').value});feedback('');}
    catch(e){feedback('設定保存エラー: '+e.message);}
  });
  $('soundVolume').addEventListener('input',()=>{
    $('volumeValue').textContent=$('soundVolume').value+'%';
  });
  $('soundVolume').addEventListener('change',async()=>{
    try{await chrome.storage.local.set({soundVolume:volumeChoice($('soundVolume').value)});feedback('');}
    catch(e){feedback('音量保存エラー: '+e.message);}
  });
  $('previewSound').addEventListener('click',async()=>{
    try{await request('PREVIEW_SOUND',{soundId:$('soundId').value,volume:volumeChoice($('soundVolume').value)});feedback('試聴しました');}
    catch(e){feedback('試聴エラー: '+e.message);}
  });
  chrome.storage.onChanged.addListener((changes,area)=>{
    if(area==='local' && changes.pendingChats)void refresh().catch(e=>feedback('状態取得エラー: '+e.message));
  });
  await refresh();
}
init().catch(e=>feedback('初期化エラー: '+e.message));
