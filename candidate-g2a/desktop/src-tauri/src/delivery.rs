//! Bounded, source-neutral alert queue. Native owns visibility and sound ordering.
//! No transcript text, history, or external I/O is persisted.
use crate::AlertEvent;
use std::collections::VecDeque;

pub const MAX_WAITING: usize = 64;
pub const MAX_RECENT: usize = 256;

#[derive(Clone, Debug)]
pub struct Delivery {
    pub event: AlertEvent,
    pub sound_id: String,
    pub volume: u8,
    pub native_audio: bool,
    pub connection_id: Option<u64>,
}

impl Delivery {
    pub fn key(&self) -> String {
        format!("{}:{}", self.event.source.as_deref().unwrap_or("chatgpt"), self.event.event_id)
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum Admission { Active, Queued, Duplicate, Full }

pub struct Queue {
    pub active: Option<Delivery>,
    pub waiting: VecDeque<Delivery>,
    recent: VecDeque<String>,
    audio_started: bool,
}
impl Queue {
    pub fn new() -> Self { Self { active: None, waiting: VecDeque::new(), recent: VecDeque::new(), audio_started: false } }
    pub fn admit(&mut self, item: Delivery) -> Admission {
        let key = item.key();
        if self.recent.contains(&key) { return Admission::Duplicate; }
        if self.active.is_some() && self.waiting.len() >= MAX_WAITING { return Admission::Full; }
        self.recent.push_back(key);
        while self.recent.len() > MAX_RECENT { self.recent.pop_front(); }
        if self.active.is_none() {
            self.active=Some(item);
            self.audio_started=false;
            Admission::Active
        } else {
            self.waiting.push_back(item);
            Admission::Queued
        }
    }
    pub fn rollback_active(&mut self,id:&str) {
        if self.active.as_ref().map(|d|d.event.event_id.as_str())==Some(id){
            if let Some(old)=self.active.take(){
                let key=old.key();self.recent.retain(|k|k!=&key);
                self.audio_started=false;
            }
        }
    }
    /// The UI calls this only after the banner has been shown successfully.
    pub fn mark_visible(&mut self, id: &str) -> Option<(String,u8)> {
        let item = self.active.as_ref()?;
        if item.event.event_id != id || self.audio_started { return None; }
        self.audio_started=true;
        if !item.native_audio { return None; } // stable v1.1.5 Chrome is the legacy audio owner
        Some((item.sound_id.clone(),item.volume))
    }
    /// Caller must synchronously stop Windows sound BEFORE handling the returned next event.
    pub fn complete(&mut self, id: &str) -> Option<(Delivery, Option<Delivery>)> {
        if self.active.as_ref()?.event.event_id != id { return None; }
        let old=self.active.take()?;
        self.active=self.waiting.pop_front();
        self.audio_started=false;
        Some((old, self.active.clone()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn event(i:usize,s:&str)->Delivery {
        Delivery { event:AlertEvent { version:3,event_id:format!("codex-{i:032x}"),chat_title:"TALOS".into(),completed_at:"2026-11-23T00:00:00Z".into(),source:Some(s.into()),open_target:None,conversation_url:None,tab_id:0,window_id:0}, sound_id:"leo".into(),volume:80,native_audio:true,connection_id:None }
    }
    #[test] fn cross_source_is_one_at_a_time_and_waiting_is_silent(){
        let mut q=Queue::new();
        assert_eq!(q.admit(event(1,"chatgpt")),Admission::Active);
        assert_eq!(q.admit(event(2,"codex")),Admission::Queued);
        assert_eq!(q.waiting.len(),1);
        assert_eq!(q.mark_visible("codex-00000000000000000000000000000002"),None);
        assert!(q.mark_visible("codex-00000000000000000000000000000001").is_some());
        assert_eq!(q.mark_visible("codex-00000000000000000000000000000001"),None);
        let (_,next)=q.complete("codex-00000000000000000000000000000001").unwrap();
        assert_eq!(next.unwrap().event.source.as_deref(),Some("codex"));
    }
    #[test] fn bounded_and_duplicate(){
        let mut q=Queue::new();assert_eq!(q.admit(event(0,"codex")),Admission::Active);
        for n in 1..=MAX_WAITING {assert_eq!(q.admit(event(n,"codex")),Admission::Queued);}
        assert_eq!(q.admit(event(70,"codex")),Admission::Full);
        assert_eq!(q.admit(event(2,"codex")),Admission::Duplicate);
        assert!(q.complete("wrong").is_none());
    }
}
