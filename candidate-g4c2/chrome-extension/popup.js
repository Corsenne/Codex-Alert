'use strict';
const el=id=>document.getElementById(id);
async function refresh(){
 el('state').textContent='確認中...';el('probe').textContent='確認中...';
 try{
   const x=await chrome.runtime.sendMessage({type:'G4C2_STATUS'});
   el('state').textContent=x?.ok?[
     'COMPLETE受信: '+x.received,
     'Native受理: '+x.accepted,
     '最近の結果: '+x.lastResult,
     'Bridge: '+(x.nativeConnected?'接続中':'未接続'),
     'Native待機中: '+x.pendingNative,
     'バナー経路保持: '+x.activeNative
   ].join('\n'):'背景処理の状態取得失敗';
 }catch(_){el('state').textContent='背景処理に接続できない';}
 try{
   const tabs=await chrome.tabs.query({active:true,lastFocusedWindow:true});
   const tab=tabs.find(t=>/^https:\/\/(chatgpt\.com|chat\.openai\.com)\//.test(t.url||''));
   if(!tab){el('probe').textContent='現在のアクティブタブはChatGPTではない';return;}
   const x=await chrome.tabs.sendMessage(tab.id,{type:'PROBE_CONTENT'});
   el('probe').textContent=x?.ok?[
     '監視状態: '+x.phase,
     '直近の検知結果: '+x.lastOutcome,
     '最終判断: '+x.lastEvidence,
     '停止ボタン表示: '+(x.stopVisible?'あり':'なし'),
     '生成中経過ms: '+x.activeMs
   ].join('\n'):'完了検知スクリプトの状態取得失敗';
 }catch(_){el('probe').textContent='完了検知スクリプトに接続できない（タブ再読み込みを確認）';}
}
el('refresh').addEventListener('click',()=>{void refresh();});
void refresh();
