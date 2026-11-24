'use strict';
// Keep legacy storage.local preference keys; do not migrate or clear them.
const $=id=>document.getElementById(id);
const SOUNDS=new Set(['holo','soft','pulse','female']);
function volume(v){const n=Number(v);return Number.isFinite(n)?Math.max(0,Math.min(100,Math.round(n/5)*5)):85;}
// The status button must always provide a visible result, including when
// the service worker is missing, throws or cannot complete the message.
async function status(){
 const target=$('status');
 target.textContent='接続状態を確認中...';
 $('refresh').disabled=true;
 let timer;
 try{
  const timeout=new Promise((_,reject)=>{
   timer=setTimeout(()=>reject(new Error('status-timeout')),3000);
  });
  const x=await Promise.race([chrome.runtime.sendMessage({type:'G4C2_STATUS'}),timeout]);
  if(!x?.ok){
   target.textContent='診断応答なし：バックグラウンド処理が応答しません';
   return;
  }
  target.textContent='完了検知 '+Number(x.received||0)+'件 / Native受理 '+Number(x.accepted||0)+
    '件\nBridge: '+(x.nativeConnected?'接続中':'待機中')+
    '\n最近の結果: '+String(x.lastResult||'none').slice(0,100);
 }catch(e){
  const why=e?.message==='status-timeout'?'応答タイムアウト':'バックグラウンド接続エラー';
  target.textContent=why+'。chrome://extensions で拡張機能のエラーを確認';
 }finally{
  clearTimeout(timer);
  $('refresh').disabled=false;
 }
}
async function save(key,value){
 try{await chrome.storage.local.set({[key]:value});$('feedback').textContent='保存しました';}
 catch(_){$('feedback').textContent='設定保存に失敗しました';}
}
async function init(){
 const stored=await chrome.storage.local.get({enabled:true,soundId:'female',soundVolume:85});
 $('enabled').checked=stored.enabled!==false;
 $('soundId').value=SOUNDS.has(stored.soundId)?stored.soundId:'female';
 $('soundVolume').value=String(volume(stored.soundVolume));
 $('volumeValue').textContent=$('soundVolume').value+'%';
 $('enabled').addEventListener('change',()=>void save('enabled',$('enabled').checked));
 $('soundId').addEventListener('change',()=>void save('soundId',$('soundId').value));
 $('soundVolume').addEventListener('input',()=>{$('volumeValue').textContent=$('soundVolume').value+'%';});
 $('soundVolume').addEventListener('change',()=>void save('soundVolume',volume($('soundVolume').value)));
 $('refresh').addEventListener('click',()=>void status());
 await status();
}
void init().catch(()=>{$('feedback').textContent='画面の初期化に失敗しました';});
