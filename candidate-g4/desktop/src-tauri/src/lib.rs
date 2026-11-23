#![cfg(windows)]
use serde::{Deserialize,Serialize};
use std::sync::{Arc,Mutex,atomic::{AtomicBool,AtomicU64,Ordering}};
use std::time::Duration;
use tauri::{Manager,Emitter};
use tauri::menu::{Menu,MenuItem};
use tauri::tray::TrayIconBuilder;

mod ipc;
mod delivery;
mod g4_callback;
mod g4_thread;

#[derive(Debug,Clone,Serialize,Deserialize)]
#[serde(rename_all="camelCase")]
pub struct AlertEvent {
    pub version:u32,
    pub event_id:String,
    pub chat_title:String,
    pub completed_at:String,
    #[serde(default)] pub source:Option<String>,
    #[serde(default)] pub open_target:Option<String>,
    // Codex provenance is local-only, not exposed to frontend or logs.
    #[serde(default,skip_serializing)] pub transcript_path:Option<String>,
    #[serde(default)] pub conversation_url:Option<String>,
    #[serde(default,skip_serializing)] pub bridge_callback_pipe:Option<String>,
    #[serde(default)] pub tab_id:i32,
    #[serde(default)] pub window_id:i32,
}
pub struct Shared{
    ui_ready:AtomicBool,
    queue:Mutex<delivery::Queue>,
    connections:Mutex<Vec<(u64,std::sync::mpsc::Sender<String>)>>,
    next_connection:AtomicU64,
}
impl Shared {fn new()->Self{Self{ui_ready:AtomicBool::new(false),queue:Mutex::new(delivery::Queue::new()),connections:Mutex::new(Vec::new()),next_connection:AtomicU64::new(1)}}}
fn valid_conversation_url(value:&str)->bool{
    // Never execute arbitrary URLs. We do not open this URL in Rust; this is defense-in-depth.
    if value.contains(&['?','#','\\',' ','\n','\r'][..]) {return false;}
    let path=value.strip_prefix("https://chatgpt.com/")
         .or_else(||value.strip_prefix("https://chat.openai.com/"));
    let Some(path)=path else{return false;};
    if path.len()>240{return false;}
    let parts:Vec<&str>=path.trim_end_matches('/').split('/').collect();
    let valid_id=|s:&str| s.len()>=8&&s.len()<=100&&s.chars().all(|c|c.is_ascii_alphanumeric()||c=='_'||c=='-');
    match parts.as_slice(){["c",id]=>valid_id(id),["g",g,"c",id]=>g.len()>=3&&valid_id(id)&&g.chars().all(|c|c.is_ascii_alphanumeric()||c=='_'||c=='-'),_=>false}
}
/// Make a copy of a PCM-16 RIFF/WAVE clip with per-notification amplitude scaling.
/// This changes the sound itself, never Windows global or application mixer volume.
fn scaled_pcm16_wav(source:&[u8],volume:u8)->Option<Vec<u8>>{
    if source.len()<44 || &source[0..4]!=b"RIFF" || &source[8..12]!=b"WAVE" || volume>100 {return None;}
    let mut out=source.to_vec();
    let mut pos=12_usize;
    let mut pcm16=false;
    let mut regions=Vec::new();
    while pos.checked_add(8)?<=source.len() {
        let size=u32::from_le_bytes(source[pos+4..pos+8].try_into().ok()?) as usize;
        let body=pos.checked_add(8)?;
        let end=body.checked_add(size)?;
        if end>source.len(){return None;}
        let chunk=&source[pos..pos+4];
        if chunk==b"fmt " && size>=16 {
            let format=u16::from_le_bytes(source[body..body+2].try_into().ok()?);
            let bits=u16::from_le_bytes(source[body+14..body+16].try_into().ok()?);
            pcm16=format==1 && bits==16;
        } else if chunk==b"data" {
            if size%2!=0{return None;}
            regions.push((body,end));
        }
        pos=end.checked_add(size&1)?;
    }
    if !pcm16 || regions.is_empty(){return None;}
    for (body,end) in regions {
        for i in (body..end).step_by(2) {
            let sample=i16::from_le_bytes([source[i],source[i+1]]);
            let adjusted=((sample as i32)*(volume as i32)/100) as i16;
            out[i..i+2].copy_from_slice(&adjusted.to_le_bytes());
        }
    }
    Some(out)
}
#[cfg(windows)]
fn play_chime(sound_id:&str,volume:u8){
    use std::os::windows::ffi::OsStrExt;
    use std::sync::OnceLock;
    use std::collections::VecDeque;
    use std::path::PathBuf;
    #[link(name="winmm")]
    extern "system" {fn PlaySoundW(sound:*const u16,module:*mut std::ffi::c_void,flags:u32)->i32;}
    if volume==0 {return;}
    let (id,bytes):(&'static str,&'static [u8])=match sound_id {
        "soft"=>("soft",include_bytes!("assets/soft.wav")),
        "pulse"=>("pulse",include_bytes!("assets/pulse.wav")),
        "female"=>("female",include_bytes!("assets/female.wav")),
        _=>("holo",include_bytes!("assets/holo.wav")),
    };
    struct AudioCache {dir:PathBuf,entries:VecDeque<(String,PathBuf)>}
    impl AudioCache {
        fn new()->Self {
            let base=std::env::var_os("LOCALAPPDATA").map(PathBuf::from).unwrap_or_else(std::env::temp_dir);
            let dir=base.join("FinishAlertG4Test").join("audio-cache");
            // Single-instance application: old per-volume cache can be discarded on start.
            let _=std::fs::remove_dir_all(&dir);
            let _=std::fs::create_dir_all(&dir);
            Self {dir,entries:VecDeque::new()}
        }
    }
    static CACHE:OnceLock<Mutex<AudioCache>>=OnceLock::new();
    let cache=CACHE.get_or_init(||Mutex::new(AudioCache::new()));
    let key=format!("{id}-{volume}");
    let path={
        let mut cache=cache.lock().unwrap();
        if let Some((_,file))=cache.entries.iter().find(|(k,_)|k==&key){file.clone()}
        else {
            let file=cache.dir.join(format!("{key}.wav"));
            let Some(wav)=scaled_pcm16_wav(bytes,volume) else {
                eprintln!("Audio decode failed for {id}");return;
            };
            if let Err(e)=std::fs::write(&file,wav){eprintln!("Audio cache write failed: {e}");return;}
            cache.entries.push_back((key,file.clone()));
            while cache.entries.len()>16 {
                if let Some((_,old))=cache.entries.pop_front(){let _=std::fs::remove_file(old);}
            }
            file
        }
    };
    let wide:Vec<u16>=path.as_os_str().encode_wide().chain(std::iter::once(0)).collect();
    const FLAGS:u32=0x0002_0000|0x0000_0001|0x0000_0002; // SND_FILENAME|SND_ASYNC|SND_NODEFAULT
    if unsafe{PlaySoundW(wide.as_ptr(),std::ptr::null_mut(),FLAGS)}==0 {eprintln!("PlaySoundW failed for {id}");}
}


/// Codex audio is deliberately a PRIVATE LOCAL asset, not embedded in the public repository.
/// Validation and cache are bounded; no arbitrary path may arrive from the pipe request.
#[cfg(windows)]
fn play_codex_voice(volume:u8){
    use std::os::windows::ffi::OsStrExt;
    #[link(name="winmm")]
    extern "system" {fn PlaySoundW(sound:*const u16,module:*mut std::ffi::c_void,flags:u32)->i32;}
    if volume==0{return;}
    let Some(wav_path)=std::env::var_os("FINISH_ALERT_G2B_PRIVATE_WAV") else{return;};
    let path=std::path::PathBuf::from(wav_path);
    let Ok(meta)=std::fs::metadata(&path) else {return;};
    if !meta.is_file()||meta.len()>2_000_000 {return;}
    let Ok(original)=std::fs::read(&path) else{return;};
    let Some(scaled)=scaled_pcm16_wav(&original,volume) else{return;};
    let cache=std::env::temp_dir().join("finish-alert-g4-test-audio");
    if std::fs::create_dir_all(&cache).is_err(){return;}
    // Per-volume, per-source checksum in filename prevents stale audio after user replaces clip.
    let mut h:u64=0xcbf29ce484222325;
    for byte in &original {h=(h^(*byte as u64)).wrapping_mul(0x100000001b3);}
    let filename=cache.join(format!("leo-{h:016x}-{volume}.wav"));
    if !filename.is_file() && std::fs::write(&filename,scaled).is_err(){return;}
    let wide:Vec<u16>=filename.as_os_str().encode_wide().chain(std::iter::once(0)).collect();
    const FLAGS:u32=0x0002_0000|0x0000_0001|0x0000_0002;
    unsafe{PlaySoundW(wide.as_ptr(),std::ptr::null_mut(),FLAGS);}
}

/// Stops our asynchronous WAV immediately, before any click navigation or next alert.
#[cfg(windows)]
fn stop_audio(){
    #[link(name="winmm")]
    extern "system" { fn PlaySoundW(sound:*const u16,module:*mut std::ffi::c_void,flags:u32)->i32; }
    unsafe { PlaySoundW(std::ptr::null(),std::ptr::null_mut(),0); }
}

#[repr(C)]struct Point{x:i32,y:i32}
#[repr(C)]struct Rect{left:i32,top:i32,right:i32,bottom:i32}
#[repr(C)]struct MonitorInfo{size:u32,monitor:Rect,work:Rect,flags:u32}
#[link(name="user32")]
extern "system" {
    fn MonitorFromPoint(point:Point,flags:u32)->*mut std::ffi::c_void;
    fn GetMonitorInfoW(handle:*mut std::ffi::c_void,info:*mut MonitorInfo)->i32;
}
fn primary_work_area()->Option<(i32,i32,i32,i32)>{
    let h=unsafe{MonitorFromPoint(Point{x:0,y:0},1)}; // MONITOR_DEFAULTTOPRIMARY
    if h.is_null(){return None;}
    let mut info=MonitorInfo{size:std::mem::size_of::<MonitorInfo>() as u32,
       monitor:Rect{left:0,top:0,right:0,bottom:0},work:Rect{left:0,top:0,right:0,bottom:0},flags:0};
    if unsafe{GetMonitorInfoW(h,&mut info)}==0{return None;}
    Some((info.work.left,info.work.top,info.work.right,info.work.bottom))
}
// Fixed stage-only instrumentation. User content and unexpected strings are never logged.
#[tauri::command]
fn g2b_diagnostic(stage:String){
    if matches!(stage.as_str(),
        "G2B_HTML_INLINE_EXECUTED" | "G2B_DOM_READY" |
        "G2B_JS_ERROR" | "G2B_JS_UNHANDLED_REJECTION" |
        "G2B_REACT_MODULE_EXECUTED" | "G2B_REACT_EFFECT_STARTED" |
        "G2B_EVENT_LISTENER_REGISTERED" | "G2B_EVENT_LISTENER_REJECTED" |
        "G2B_UI_READY_INVOKE_RESOLVED" | "G2B_UI_READY_INVOKE_REJECTED") {
        ipc::g2b_trace(&stage);
    }
}
// G2B-only: visible transparent WebView boots, then hides after listener registration.
#[tauri::command]
fn ui_ready(window:tauri::WebviewWindow,shared:tauri::State<'_,Arc<Shared>>)->Result<bool,String>{
    ipc::g2b_trace("G2B_UI_READY_INVOKED");
    window.hide().map_err(|e|{
        ipc::g2b_trace("G2B_UI_INITIAL_HIDE_FAILED");
        e.to_string()
    })?;
    shared.ui_ready.store(true,Ordering::SeqCst);
    ipc::g2b_trace("G2B_UI_READY_PASS");
    Ok(true)
}
#[tauri::command]
fn set_visible_count(window:tauri::WebviewWindow,shared:tauri::State<'_,Arc<Shared>>,
                     count:u8,event_id:Option<String>)->Result<(),String>{
    // Ignore stale UI effects during transitions between two queued notifications.
    let current=shared.queue.lock().map_err(|_|"queue-lock-failed")?
        .active.as_ref().map(|d|d.event.event_id.clone());
    if current!=event_id{return Ok(());}
    if count==0 && !shared.ui_ready.load(Ordering::SeqCst){return Ok(());}
    if count==0{return window.hide().map_err(|e|e.to_string());}
    let scale=window.scale_factor().unwrap_or(1.0).max(0.5);
    let work=primary_work_area().ok_or("primary-monitor-not-found")?;
    let width=((work.2-work.0) as f64/scale-20.0).min(420.0).max(280.0);
    let height=124.0_f64.min((work.3-work.1) as f64/scale-16.0);
    window.set_size(tauri::Size::Logical(tauri::LogicalSize::new(width,height))).map_err(|e|e.to_string())?;
    let x=(work.2-(width*scale).ceil() as i32-(12.0*scale) as i32).max(work.0);
    let y=(work.3-(height*scale).ceil() as i32-(12.0*scale) as i32).max(work.1);
    window.set_position(tauri::Position::Physical(tauri::PhysicalPosition::new(x,y))).map_err(|e|e.to_string())?;
    window.set_focusable(false).map_err(|e|e.to_string())?;
    window.set_always_on_top(true).map_err(|e|e.to_string())?;
    window.show().map_err(|e|e.to_string())
}
#[tauri::command]
fn notification_visible(shared:tauri::State<'_,Arc<Shared>>,event_id:String)->Result<(),String>{
    // The front-end calls this only after successful window.show and a paint boundary.
    // Keep the actor lock until the audio call finishes. Otherwise a click
    // may stop playback BEFORE a concurrent visibility callback starts it.
    let mut queue=shared.queue.lock().map_err(|_|"queue-lock-failed")?;
    if let Some((sound,volume))=queue.mark_visible(&event_id) {
        if sound=="leo"{ipc::g2b_trace("G4_LEO_PLAY_REQUESTED");play_codex_voice(volume)}
        else {ipc::g2b_trace("G4_CHATGPT_VOICE_REQUESTED");play_chime(&sound,volume)}
    }
    Ok(())
}
/// Common completion pathway for clicks, dismissals and native watchdog.
fn finish_event(app:&tauri::AppHandle,shared:&Arc<Shared>,event_id:&str,action:&str)
    ->Result<bool,String>{
    let outcome={
        let mut q=shared.queue.lock().map_err(|_|"queue-lock-failed")?;
        if q.active.as_ref().map(|d|d.event.event_id.as_str())!=Some(event_id){
            ipc::g2b_trace("G4R_STALE_ACTION_IGNORED");
            return Ok(false);
        }
        // One audio owner, and always stop before a callback or next event.
        stop_audio();
        q.complete(event_id).ok_or("event-not-active")?
    };
    if let Some(age)=outcome.promoted_wait{
        ipc::g2b_trace(if age<=Duration::from_secs(5) {
            "G4R_PROMOTED_WAIT_LE_5S"
        }else{"G4R_PROMOTED_WAIT_GT_5S"});
    }
    for stale in &outcome.dropped{
        ipc::g2b_trace("G4R_STALE_QUEUED_DROPPED");
        if stale.event.source.as_deref()!=Some("codex"){
            if let Some(pipe)=stale.event.bridge_callback_pipe.as_deref(){
                let _=g4_callback::send_callback(pipe,&stale.event.event_id,"notification.closed");
            }
        }
    }
    let finished=&outcome.finished;
    if action=="click" {
        ipc::g2b_trace("G4_AUDIO_STOP_BEFORE_ROUTE");
        match finished.event.source.as_deref(){
            Some("codex")=>{
                let target=finished.event.open_target.as_deref();
                let approved=std::env::var("FINISH_ALERT_G4_ALLOWED_CODEX_LINK").ok();
                match target {
                    Some(uri) if g4_thread::valid_codex_thread_target(uri)
                        && match finished.event.transcript_path.as_deref(){
                            Some(path)=>g4_thread::verified_codex_session_link(uri,path),
                            None=>approved.as_deref()==Some(uri), // explicit G3 synthetic test only
                        } =>{
                        let dispatched=g4_thread::open_codex_thread_target(uri);
                        ipc::g2b_trace(if dispatched{"G4_CODEX_ROUTE_DISPATCHED"}else{"G4_CODEX_ROUTE_FAILED"});
                    },
                    _=>ipc::g2b_trace("G4_CODEX_ROUTE_REJECTED"),
                }
            }
            _=>{
                let ok=finished.event.bridge_callback_pipe.as_deref().map_or(false,|pipe|
                    g4_callback::send_callback(pipe,&finished.event.event_id,"notification.open"));
                ipc::g2b_trace(if ok{"G4_CHATGPT_CALLBACK_SENT"}else{"G4_CHATGPT_CALLBACK_FAILED"});
            }
        }
    }else if finished.event.source.as_deref()!=Some("codex"){
        if let Some(pipe)=finished.event.bridge_callback_pipe.as_deref(){
            let ok=g4_callback::send_callback(pipe,&finished.event.event_id,"notification.closed");
            ipc::g2b_trace(if ok{"G4_CHATGPT_CLOSE_SENT"}else{"G4_CHATGPT_CLOSE_FAILED"});
        }
    }
    // A watchdog completion must clear stale frontend state even if JS timers are frozen.
    // Correlate only by eventId; never clear a newer toast.
    let _=app.emit_to("main","finish-alert:cleared",&finished.event.event_id);
    if let Some(next)=outcome.next{
        ipc::g2b_trace("G4R_PROMOTED_NEXT");
        app.emit_to("main","finish-alert:active",&next.event).map_err(|e|e.to_string())?;
    }else if let Some(win)=app.get_webview_window("main"){
        // Safety net independent of WebView rendering/JS execution.
        if win.hide().is_err(){ipc::g2b_trace("G4R_NATIVE_HIDE_FAILED");}
        else{ipc::g2b_trace("G4R_NATIVE_HIDE_PASS");}
    }
    Ok(true)
}
#[tauri::command]
fn complete_notification(app:tauri::AppHandle,shared:tauri::State<'_,Arc<Shared>>,
                         event_id:String,action:String)->Result<(),String>{
    if !matches!(action.as_str(),"click"|"dismiss"|"timeout"){return Err("invalid-action".into());}
    let _=finish_event(&app,shared.inner(),&event_id,&action)?;
    Ok(())
}
/// Single lightweight native worker. An invisible WebView cannot hold FIFO forever.
fn launch_native_watchdog(app:tauri::AppHandle,shared:Arc<Shared>){
    std::thread::spawn(move||loop{
        std::thread::sleep(Duration::from_millis(125));
        let due=shared.queue.lock().ok().and_then(|q|q.timeout_due(std::time::Instant::now()));
        if let Some(due)=due{
            ipc::g2b_trace(if due.painted{"G4R_NATIVE_VISIBLE_TIMEOUT"}else{"G4R_NATIVE_UNPAINTED_TIMEOUT"});
            let _=finish_event(&app,&shared,&due.id,"timeout");
        }
    });
}
#[cfg(windows)]
fn open_chat_url(url:&str)->bool {
    use std::os::windows::ffi::OsStrExt;
    #[link(name="shell32")]
    extern "system" {fn ShellExecuteW(hwnd:*mut std::ffi::c_void,operation:*const u16,file:*const u16,
        params:*const u16,directory:*const u16,show:i32)->*mut std::ffi::c_void;}
    if !valid_conversation_url(url){return false;}
    let target:Vec<u16>=std::ffi::OsStr::new(url).encode_wide().chain(std::iter::once(0)).collect();
    let action:Vec<u16>="open".encode_utf16().chain(std::iter::once(0)).collect();
    (unsafe{ShellExecuteW(std::ptr::null_mut(),action.as_ptr(),target.as_ptr(),
        std::ptr::null(),std::ptr::null(),1)} as isize)>32
}

pub fn run(){
    tauri::Builder::default()
      .plugin(tauri_plugin_single_instance::init(|_,_,_|{}))
      .on_page_load(|webview,payload|{
          if webview.label()=="main" {
              // Log only a fixed origin class; never log complete URLs or filesystem paths.
              let target=payload.url().as_str();
              let stage=if target.starts_with("http://127.0.0.1:1420") ||
                           target.starts_with("http://localhost:1420") {
                  "G2B_PAGE_ORIGIN_DEV_SERVER"
              } else if target.starts_with("http://tauri.localhost") ||
                        target.starts_with("https://tauri.localhost") ||
                        target.starts_with("tauri://localhost") {
                  "G2B_PAGE_ORIGIN_EMBEDDED_APP"
              } else if target.starts_with("about:") {
                  "G2B_PAGE_ORIGIN_ABOUT"
              } else {
                  "G2B_PAGE_ORIGIN_OTHER"
              };
              ipc::g2b_trace(stage);
              match payload.event(){
                  tauri::webview::PageLoadEvent::Started=>ipc::g2b_trace("G2B_PAGE_LOAD_STARTED"),
                  tauri::webview::PageLoadEvent::Finished=>ipc::g2b_trace("G2B_PAGE_LOAD_FINISHED"),
              }
          }
      })
      .setup(|app|{
          let shared=Arc::new(Shared::new());
          app.manage(shared.clone());
          ipc::launch(app.handle().clone(),shared.clone());
          launch_native_watchdog(app.handle().clone(),shared);
          let quit=MenuItem::with_id(app,"quit","終了",true,None::<&str>)?;
          let menu=Menu::with_items(app,&[&quit])?;
          TrayIconBuilder::new().icon(app.default_window_icon().ok_or("missing application icon")?.clone())
            .tooltip("Finish Alert G4 TEST (not installed)")
            .menu(&menu)
            .on_menu_event(|app,event|match event.id().as_ref(){
                "quit"=>app.exit(0),
                _=>{}
            }).build(app)?;
          if let Some(win)=app.get_webview_window("main") {let _=win.set_focusable(false);}
          Ok(())
      })
      .invoke_handler(tauri::generate_handler![g2b_diagnostic,ui_ready,set_visible_count,notification_visible,complete_notification])
      .on_window_event(|win,event|{
        if let tauri::WindowEvent::CloseRequested{api,..}=event{
          api.prevent_close();let _=win.hide();
        }
      })
      .run(tauri::generate_context!()).expect("Finish Alert Tauri runtime failed");
}

#[cfg(test)]mod tests{
    use super::*;
    #[test]fn volume_scaling_keeps_wav_structure(){
        for sound in [include_bytes!("assets/holo.wav").as_slice(),include_bytes!("assets/female.wav").as_slice()] {
            let full=scaled_pcm16_wav(sound,100).unwrap();
            assert_eq!(full,sound);
            let half=scaled_pcm16_wav(sound,50).unwrap();
            assert_eq!(half.len(),sound.len());
            assert_eq!(&half[0..12],&sound[0..12]);
            let silent=scaled_pcm16_wav(sound,0).unwrap();
            assert_eq!(silent.len(),sound.len());
            assert!(scaled_pcm16_wav(sound,101).is_none());
        }
    }
    #[test]fn exact_chatgpt_urls_only(){
        assert!(valid_conversation_url("https://chatgpt.com/c/12345678-1234"));
        assert!(valid_conversation_url("https://chatgpt.com/g/g-12345678/c/abcdefg123456"));
        assert!(!valid_conversation_url("https://evil.example/c/12345678"));
        assert!(!valid_conversation_url("https://chatgpt.com/c/12345678?x=1"));
    }
}
