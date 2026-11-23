//! Isolated G4 FIFO: native-owned lifetime, bounded queue and stale-item drop.
//! No event payload, URL, transcript, IDs or titles are written to telemetry.
use crate::AlertEvent;
use std::{collections::VecDeque,time::{Duration,Instant}};

pub const MAX_WAITING:usize=64;
pub const MAX_RECENT:usize=256;
pub const VISIBLE_TIMEOUT:Duration=Duration::from_secs(8);
pub const UNPAINTED_TIMEOUT:Duration=Duration::from_secs(12);
pub const MAX_QUEUE_AGE:Duration=Duration::from_secs(20);

#[derive(Clone,Debug)]
pub struct Delivery{
    pub event:AlertEvent,
    pub sound_id:String,
    pub volume:u8,
    pub native_audio:bool,
    pub connection_id:Option<u64>,
}
impl Delivery{
    pub fn key(&self)->String {
        format!("{}:{}",self.event.source.as_deref().unwrap_or("chatgpt"),self.event.event_id)
    }
}
#[derive(Debug,PartialEq,Eq)]
pub enum Admission{Active,Queued,Duplicate,Full}
#[derive(Clone,Debug)]
pub struct Waiting{
    pub item:Delivery,
    queued_at:Instant,
}
pub struct Advance{
    pub finished:Delivery,
    pub dropped:Vec<Delivery>,
    pub next:Option<Delivery>,
    pub promoted_wait:Option<Duration>,
}
#[derive(Debug,Clone,PartialEq,Eq)]
pub struct TimeoutDue {
    pub id:String,
    pub painted:bool,
}
pub struct Queue{
    pub active:Option<Delivery>,
    pub waiting:VecDeque<Waiting>,
    recent:VecDeque<String>,
    audio_started:bool,
    active_since:Option<Instant>,
    visible_since:Option<Instant>,
}
impl Queue {
    pub fn new()->Self{
        Self{active:None,waiting:VecDeque::new(),recent:VecDeque::new(),
            audio_started:false,active_since:None,visible_since:None}
    }
    pub fn admit(&mut self,item:Delivery)->Admission{self.admit_at(item,Instant::now())}
    fn admit_at(&mut self,item:Delivery,now:Instant)->Admission{
        let key=item.key();
        if self.recent.contains(&key){return Admission::Duplicate;}
        if self.active.is_some()&&self.waiting.len()>=MAX_WAITING{return Admission::Full;}
        self.recent.push_back(key);
        while self.recent.len()>MAX_RECENT{self.recent.pop_front();}
        if self.active.is_none(){
            self.active=Some(item);
            self.active_since=Some(now);
            self.visible_since=None;
            self.audio_started=false;
            Admission::Active
        }else{
            self.waiting.push_back(Waiting{item,queued_at:now});
            Admission::Queued
        }
    }
    pub fn rollback_active(&mut self,id:&str){
        if self.active.as_ref().map(|d|d.event.event_id.as_str())==Some(id){
            if let Some(old)=self.active.take(){
                let key=old.key();self.recent.retain(|k|k!=&key);
                self.audio_started=false;
                self.active_since=None;
                self.visible_since=None;
            }
        }
    }
    /// Called only after successful WebView show + paint boundary.
    pub fn mark_visible(&mut self,id:&str)->Option<(String,u8)>{
        self.mark_visible_at(id,Instant::now())
    }
    fn mark_visible_at(&mut self,id:&str,now:Instant)->Option<(String,u8)>{
        let item=self.active.as_ref()?;
        if item.event.event_id!=id||self.audio_started{return None;}
        // Independent native timeout starts now, even if the clip is disabled.
        self.visible_since=Some(now);
        self.audio_started=true;
        if !item.native_audio{return None;}
        Some((item.sound_id.clone(),item.volume))
    }
    /// Native watchdog may expire a shown banner or recover an unpainted one.
    /// No WebView JavaScript timer is required to make forward progress.
    pub fn timeout_due(&self,now:Instant)->Option<TimeoutDue>{
        let item=self.active.as_ref()?;
        let (start,limit,painted)=match self.visible_since{
            Some(start)=>(start,VISIBLE_TIMEOUT,true),
            None=>(self.active_since?,UNPAINTED_TIMEOUT,false),
        };
        if now.saturating_duration_since(start)<limit{return None;}
        Some(TimeoutDue{id:item.event.event_id.clone(),painted})
    }
    pub fn complete(&mut self,id:&str)->Option<Advance>{self.complete_at(id,Instant::now())}
    fn complete_at(&mut self,id:&str,now:Instant)->Option<Advance>{
        if self.active.as_ref()?.event.event_id!=id{return None;}
        let finished=self.active.take()?;
        self.active_since=None;self.visible_since=None;self.audio_started=false;
        let mut dropped=Vec::new();
        let mut promoted_wait=None;
        while let Some(wait)=self.waiting.pop_front(){
            let age=now.saturating_duration_since(wait.queued_at);
            if age>=MAX_QUEUE_AGE{
                dropped.push(wait.item);
                continue;
            }
            promoted_wait=Some(age);
            self.active=Some(wait.item);
            self.active_since=Some(now);
            break;
        }
        Some(Advance{finished,dropped,next:self.active.clone(),promoted_wait})
    }
}
#[cfg(test)]
mod tests{
 use super::*;
 fn event(i:usize,s:&str)->Delivery {
    Delivery{event:AlertEvent{version:3,event_id:format!("codex-{i:032x}"),
      chat_title:"TALOS".into(),completed_at:"2026-11-23T00:00:00Z".into(),
      source:Some(s.into()),open_target:None,transcript_path:None,conversation_url:None,
      bridge_callback_pipe:None,tab_id:0,window_id:0},
      sound_id:"leo".into(),volume:80,native_audio:true,connection_id:None}
 }
 #[test] fn cross_source_one_at_a_time_waiting_silent(){
    let t=Instant::now();let mut q=Queue::new();
    assert_eq!(q.admit_at(event(1,"chatgpt"),t),Admission::Active);
    assert_eq!(q.admit_at(event(2,"codex"),t+Duration::from_secs(1)),Admission::Queued);
    assert_eq!(q.waiting.len(),1);
    assert_eq!(q.mark_visible_at("codex-00000000000000000000000000000002",t),None);
    assert!(q.mark_visible_at("codex-00000000000000000000000000000001",t).is_some());
    assert_eq!(q.mark_visible_at("codex-00000000000000000000000000000001",t),None);
    let result=q.complete_at("codex-00000000000000000000000000000001",t+Duration::from_secs(8)).unwrap();
    assert_eq!(result.next.unwrap().event.source.as_deref(),Some("codex"));
    assert_eq!(result.promoted_wait,Some(Duration::from_secs(7)));
    assert!(result.dropped.is_empty());
 }
 #[test] fn bounded_and_duplicate(){
    let mut q=Queue::new();assert_eq!(q.admit(event(0,"codex")),Admission::Active);
    for n in 1..=MAX_WAITING{assert_eq!(q.admit(event(n,"codex")),Admission::Queued);}
    assert_eq!(q.admit(event(70,"codex")),Admission::Full);
    assert_eq!(q.admit(event(2,"codex")),Admission::Duplicate);
    assert!(q.complete("wrong").is_none());
 }
 #[test] fn native_timeout_independent_of_webview_timer(){
    let t=Instant::now();let mut q=Queue::new();
    assert_eq!(q.admit_at(event(1,"chatgpt"),t),Admission::Active);
    assert_eq!(q.timeout_due(t+Duration::from_secs(11)),None);
    assert_eq!(q.timeout_due(t+Duration::from_secs(12)).unwrap().painted,false);
    q.mark_visible_at("codex-00000000000000000000000000000001",t+Duration::from_secs(1));
    assert_eq!(q.timeout_due(t+Duration::from_secs(8)),None);
    assert_eq!(q.timeout_due(t+Duration::from_secs(9)).unwrap().painted,true);
    let old=q.complete_at("codex-00000000000000000000000000000001",t+Duration::from_secs(9)).unwrap();
    assert!(old.next.is_none());
    assert!(q.timeout_due(t+Duration::from_secs(60)).is_none());
 }
 #[test] fn late_queued_events_dropped_without_new_voice(){
    let t=Instant::now();let mut q=Queue::new();
    q.admit_at(event(1,"chatgpt"),t);
    q.admit_at(event(2,"chatgpt"),t+Duration::from_secs(1));
    q.admit_at(event(3,"codex"),t+Duration::from_secs(2));
    let a=q.complete_at("codex-00000000000000000000000000000001",t+Duration::from_secs(22)).unwrap();
    assert_eq!(a.dropped.len(),2);
    assert!(a.next.is_none());
    assert!(q.active.is_none());
    assert!(q.waiting.is_empty());
 }
 #[test] fn stale_actions_are_idempotent(){
    let t=Instant::now();let mut q=Queue::new();
    q.admit_at(event(1,"chatgpt"),t);
    q.admit_at(event(2,"chatgpt"),t);
    let a=q.complete_at("codex-00000000000000000000000000000001",t+Duration::from_secs(1)).unwrap();
    assert!(a.next.is_some());
    assert!(q.complete_at("codex-00000000000000000000000000000001",t+Duration::from_secs(1)).is_none());
    assert_eq!(q.active.as_ref().unwrap().event.event_id,"codex-00000000000000000000000000000002");
 }
 #[test] fn enqueue_delay_never_resets_old_waiting_timestamp(){
    let t=Instant::now();let mut q=Queue::new();
    q.admit_at(event(1,"chatgpt"),t);
    q.admit_at(event(2,"chatgpt"),t);
    q.admit_at(event(3,"chatgpt"),t+Duration::from_secs(19));
    let a=q.complete_at("codex-00000000000000000000000000000001",t+Duration::from_secs(20)).unwrap();
    assert_eq!(a.dropped.len(),1);
    assert_eq!(a.next.unwrap().event.event_id,"codex-00000000000000000000000000000003");
    assert_eq!(a.promoted_wait,Some(Duration::from_secs(1)));
 }
}
