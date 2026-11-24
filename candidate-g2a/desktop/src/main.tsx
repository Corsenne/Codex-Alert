import React,{useEffect,useRef,useState} from 'react';
import {createRoot} from 'react-dom/client';
import {listen} from '@tauri-apps/api/event';
import {invoke} from '@tauri-apps/api/core';
import type {ToastEvent} from './queue';
import './style.css';

type FinishAction='click'|'dismiss'|'timeout';
function useClock(iso:string){
  const date=new Date(iso);return (Number.isFinite(date.getTime())?date:new Date()).toLocaleTimeString('ja-JP',{hour:'2-digit',minute:'2-digit'});
}
function Toast({event,onFinish}:{event:ToastEvent;onFinish:(id:string,action:FinishAction)=>void}){
  const time=useClock(event.completedAt);
  useEffect(()=>{
    const timer=window.setTimeout(()=>onFinish(event.eventId,'timeout'),8000);
    return ()=>window.clearTimeout(timer);
  },[event.eventId,onFinish]);
  const codex=event.source==='codex';
  // Codex deep-link dispatch is gated by real thread-ID verification in G3.
  // Clicking still stops current voice and dismisses the banner at G2.
  return <article className={`toast${codex?' codex-toast':''}`}
    onClick={()=>onFinish(event.eventId,'click')}
    tabIndex={0} role="button"
    aria-label={codex?`${event.chatTitle} のCodex処理が完了`:`${event.chatTitle}の回答を表示`}
    onKeyDown={e=>{if(e.target===e.currentTarget && (e.key==='Enter'||e.key===' ')){e.preventDefault();onFinish(event.eventId,'click');}}}>
    <div className="line-top"><span className="status-emblem" aria-hidden="true">!</span><span className="brand">{codex?'CODEX ALERT':'FINISH ALERT'}</span><span className="complete">COMPLETE</span><time>{time}</time>
      <button className="close" aria-label="通知を閉じる" title="閉じる"
        onClick={e=>{e.stopPropagation();onFinish(event.eventId,'dismiss');}}>×</button></div>
    <div className="content"><span className="star">✦</span><div className="message">
      <strong title={event.chatTitle}>{event.chatTitle}</strong>
      <span>{codex?'Codexの作業が終了しました':'ChatGPTの回答が完了しました'}</span>
    </div></div>
    <div className="timer"><div/></div>
  </article>;
}
function App(){
  const [active,setActive]=useState<ToastEvent|null>(null);
  const finishing=useRef<Set<string>>(new Set());
  const onFinish=React.useCallback((id:string,action:FinishAction)=>{
    if(finishing.current.has(id))return;
    finishing.current.add(id);
    void invoke('complete_notification',{eventId:id,action}).then(()=>{
      setActive(current=>current?.eventId===id?null:current);
    }).catch(err=>{
      finishing.current.delete(id);
      console.error('Could not finish notification',err);
    });
  },[]);
  useEffect(()=>{
    let cancelled=false;let unlisten:(()=>void)|undefined;
    (async()=>{
      unlisten=await listen<ToastEvent>('finish-alert:active',ev=>{
        if(!cancelled && ev.payload?.eventId){finishing.current.delete(ev.payload.eventId);setActive(ev.payload);}
      });
      if(!cancelled)await invoke('ui_ready');
    })().catch(err=>console.error('UI listener error',err));
    return()=>{cancelled=true;unlisten?.();};
  },[]);
  useEffect(()=>{
    let cancelled=false;
    (async()=>{
      await invoke('set_visible_count',{count:active?1:0,eventId:active?.eventId??null});
      if(!active || cancelled)return;
      await new Promise<void>(resolve=>requestAnimationFrame(()=>resolve()));
      if(!cancelled)await invoke('notification_visible',{eventId:active.eventId});
    })().catch(err=>console.error('Banner visibility error',err));
    return()=>{cancelled=true;};
  },[active?.eventId]);
  return <div className="stack" aria-live="polite">{active&&<Toast key={active.eventId} event={active} onFinish={onFinish}/>}</div>;
}
createRoot(document.getElementById('root')!).render(<App/>);
