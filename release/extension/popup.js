'use strict';
// Keep legacy storage.local preference keys; do not migrate or clear them.
const $=id=>document.getElementById(id);
const SOUNDS=new Set(['holo','soft','pulse','female']);
function volume(v){const n=Number(v);return Number.isFinite(n)?Math.max(0,Math.min(100,Math.round(n/5)*5)):85;}
async function status(){
 const x=await chrome.runtime.sendMessage({type:'G4C2_STATUS'});
 if(!x?.ok){$('status').textContent='Native接続状態を取得できません';return;}
 $('status').textContent='完了検知 '+x.received+'件 / Native受理 '+x.accepted+
   '件\nBridge: '+(x.nativeConnected?'接続中':'待機中')+
   '\n最近の結果: '+x.lastResult;
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
