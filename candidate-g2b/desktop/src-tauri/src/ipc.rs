//! Windows-only, same-session named pipe server.
//! Explicit protected DACL: Windows object OWNER RIGHTS + LocalSystem; no Everyone/Anonymous ACL.
use crate::{AlertEvent, Shared};
use crate::delivery::{Delivery,Admission};
use serde_json::{json, Value};
use std::{ffi::c_void, fs::File, io::{self, BufRead, BufReader, Write},
    os::windows::io::FromRawHandle, sync::Arc, thread};
use tauri::{AppHandle, Emitter};

#[repr(C)] struct SecurityAttributes { length:u32, descriptor:*mut c_void, inherit:i32 }
#[link(name="kernel32")]
extern "system" {
    fn GetCurrentProcessId() -> u32;
    fn ProcessIdToSessionId(pid:u32,session:*mut u32)->i32;
    fn CreateNamedPipeW(name:*const u16,open_mode:u32,pipe_mode:u32,instances:u32,
      out_size:u32,in_size:u32,timeout:u32,attrs:*mut SecurityAttributes)->*mut c_void;
    fn ConnectNamedPipe(pipe:*mut c_void,overlapped:*mut c_void)->i32;
    fn CloseHandle(handle:*mut c_void)->i32;
    fn LocalFree(handle:*mut c_void)->*mut c_void;
}
#[link(name="advapi32")]
extern "system" {
    fn ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl:*const u16,version:u32,
       descriptor:*mut *mut c_void,size:*mut u32)->i32;
}
const PIPE_ACCESS_DUPLEX:u32=0x0000_0003;
const PIPE_REJECT_REMOTE_CLIENTS:u32=0x0000_0008;
const PIPE_UNLIMITED_INSTANCES:u32=255;
const ERROR_PIPE_CONNECTED:i32=535;

pub fn pipe_path() -> String {
    let mut session=0u32;
    unsafe {ProcessIdToSessionId(GetCurrentProcessId(),&mut session);}
    format!(r"\\.\pipe\corsenne_finish_alert_g2b_test_{session}")
}
fn wide(s:&str)->Vec<u16>{s.encode_utf16().chain(std::iter::once(0)).collect()}
fn create_pipe()->io::Result<File>{
    let sddl=wide("D:P(A;;GA;;;SY)(A;;GA;;;OW)");
    let mut sec:*mut c_void=std::ptr::null_mut();
    let converted=unsafe{ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl.as_ptr(),1,&mut sec,std::ptr::null_mut())};
    if converted==0 {return Err(io::Error::last_os_error());}
    let mut attrs=SecurityAttributes{length:std::mem::size_of::<SecurityAttributes>() as u32,
        descriptor:sec,inherit:0};
    let name=wide(&pipe_path());
    let handle=unsafe{CreateNamedPipeW(name.as_ptr(),PIPE_ACCESS_DUPLEX,
       PIPE_REJECT_REMOTE_CLIENTS,PIPE_UNLIMITED_INSTANCES,8192,8192,1000,&mut attrs)};
    let last=io::Error::last_os_error();
    unsafe{LocalFree(sec);}
    if handle as isize==-1 {return Err(last);}
    let connected=unsafe{ConnectNamedPipe(handle,std::ptr::null_mut())};
    if connected==0 {
        let e=io::Error::last_os_error();
        if e.raw_os_error()!=Some(ERROR_PIPE_CONNECTED){unsafe{CloseHandle(handle);}return Err(e);}
    }
    // SAFETY: Windows returned a distinct owned HANDLE from CreateNamedPipeW.
    Ok(unsafe{File::from_raw_handle(handle)})
}
fn check_request_v2(msg:&Value)->Option<(AlertEvent,String,u8,bool)> {
    if msg.get("version")?.as_u64()?!=2 || msg.get("type")?.as_str()? != "deliver" {return None;}
    let e:AlertEvent=serde_json::from_value(msg.get("event")?.clone()).ok()?;
    let sound=msg.get("soundId")?.as_str()?;
    if !matches!(sound,"holo"|"soft"|"pulse"|"female") {return None;}
    let volume=msg.get("soundVolume").map_or(Some(100_u8),|v|v.as_u64().filter(|x|*x<=100).map(|x|x as u8))?;
    let id=&e.event_id;
    // Preserve the legacy v2 contract; it must never be able to impersonate Codex.
    if e.source.as_deref().map_or(false,|source|source!="chatgpt") || e.open_target.is_some() {return None;}
    if e.version!=2 || id.len()<12 || id.len()>50 ||
      !id.chars().all(|c|c.is_ascii_alphanumeric()||c=='-') ||
      e.chat_title.is_empty() || e.chat_title.chars().count()>100 ||
      e.chat_title.chars().any(|c|c.is_control()) || e.completed_at.len()>64 ||
      e.conversation_url.as_deref().map_or(false,|url|!crate::valid_conversation_url(url)) {return None;}
    let native_audio=match msg.get("audioOwner") {None=>false,Some(v) if v.as_str()==Some("desktop")=>true,_=>return None};
    Some((e,sound.to_string(),volume,native_audio))
}

/// Separate source contract. This does not broaden the existing v2 ChatGPT parser.
fn check_request_v3(msg:&Value)->Option<(AlertEvent,String,u8,bool)> {
    if msg.get("version")?.as_u64()?!=3 || msg.get("type")?.as_str()? != "deliver"{return None;}
    if msg.get("soundId")?.as_str()? != "leo"{return None;}
    let volume=msg.get("soundVolume")?.as_u64()?;
    if volume>100{return None;}
    let event=msg.get("event")?;
    if event.get("version")?.as_u64()?!=3 || event.get("source")?.as_str()? != "codex" {return None;}
    let parsed:AlertEvent=serde_json::from_value(event.clone()).ok()?;
    if parsed.version!=3 || parsed.source.as_deref()!=Some("codex") || parsed.open_target.is_some() ||
       parsed.conversation_url.is_some() || parsed.tab_id!=0 || parsed.window_id!=0 {return None;}
    if !parsed.event_id.starts_with("codex-") || parsed.event_id.len()!=38 ||
       !parsed.event_id[6..].bytes().all(|c|c.is_ascii_hexdigit()) ||
       parsed.chat_title.is_empty() || parsed.chat_title.chars().count()>100 ||
       parsed.chat_title.chars().any(|c|c.is_control()) ||
       parsed.completed_at.is_empty() || parsed.completed_at.len()>64 ||
       parsed.completed_at.chars().any(|c|c.is_control()){return None;}
    Some((parsed,"leo".to_owned(),volume as u8,true))
}
fn check_request(msg:&Value)->Option<(AlertEvent,String,u8,bool)> {
    match msg.get("version")?.as_u64()? {
       2 => check_request_v2(msg),
       3 => check_request_v3(msg),
       _ => None,
    }
}

// G2B ISOLATED TEST ONLY: synchronous read, then ACK write, then next read.
// The original writer thread and read loop shared a non-overlapped pipe handle.
// Cross-thread synchronous read/write may block each other on this handle.
// This is NOT the final production duplex/callback architecture.
pub(crate) fn g2b_trace(stage:&str){
    use std::{fs::OpenOptions,io::Write};
    let Some(path)=std::env::var_os("FINISH_ALERT_G2B_TRACE") else {return};
    let Ok(mut f)=OpenOptions::new().create(true).append(true).open(path) else{return};
    // Fixed labels only. Never store event contents, file paths or identifiers.
    let _=writeln!(f,"{}",stage);
}
fn write_ack(output:&mut File, response:Value)->io::Result<()>{
    output.write_all(response.to_string().as_bytes())?;
    output.write_all(b"\n")?;
    output.flush()
}
fn handle_connection(file:File,app:AppHandle,shared:Arc<Shared>){
    g2b_trace("G2B_PIPE_ACCEPTED");
    let mut input=BufReader::new(file);
    let mut line=String::new();
    loop {
        line.clear();
        match input.read_line(&mut line) {
            Ok(0)=>{g2b_trace("G2B_PIPE_EOF");break;},
            Ok(n) if n<=8192=>g2b_trace("G2B_REQUEST_LINE_READ"),
            _=>{g2b_trace("G2B_READ_ERROR_OR_OVERSIZE");break;},
        }
        let parsed=serde_json::from_str::<Value>(&line);
        let id=parsed.as_ref().ok().and_then(|x|x.get("event")).and_then(|x|x.get("eventId"))
            .and_then(Value::as_str).unwrap_or("").to_string();
        let Some((event,sound,volume,native_audio))=parsed.ok().as_ref().and_then(check_request) else{
            g2b_trace("G2B_REQUEST_INVALID");
            if write_ack(input.get_mut(),json!({"type":"delivery.ack","eventId":id,"ok":false,"error":"invalid-event"})).is_err(){
                g2b_trace("G2B_ACK_WRITE_FAILED");break;
            }
            g2b_trace("G2B_ACK_INVALID_SENT");
            continue;
        };
        for _ in 0..40 {
            if shared.ui_ready.load(std::sync::atomic::Ordering::SeqCst){break;}
            thread::sleep(std::time::Duration::from_millis(50));
        }
        if !shared.ui_ready.load(std::sync::atomic::Ordering::SeqCst){
            g2b_trace("G2B_WEBVIEW_NOT_READY");
            if write_ack(input.get_mut(),json!({"type":"delivery.ack","eventId":id,"ok":false,"error":"ui-not-ready"})).is_err(){
                g2b_trace("G2B_ACK_WRITE_FAILED");break;
            }
            g2b_trace("G2B_ACK_UI_NOT_READY_SENT");
            continue;
        }
        // Synthetic G2B clicks stop speech/dismiss; they NEVER route into real apps.
        let request=Delivery{event:event.clone(),sound_id:sound,volume,native_audio,connection_id:None};
        let (ok,position,error)={
            let mut q=shared.queue.lock().unwrap();
            match q.admit(request.clone()){
                Admission::Duplicate=>(true,"duplicate",""),
                Admission::Full=>(false,"rejected","queue-full"),
                Admission::Queued=>(true,"queued",""),
                Admission::Active=>{
                    if app.emit_to("main","finish-alert:active",&request.event).is_ok(){
                        (true,"active","")
                    }else{
                        q.rollback_active(&request.event.event_id);
                        (false,"rejected","emit-failed")
                    }
                }
            }
        };
        g2b_trace(match position {
            "active"=>"G2B_EVENT_ACTIVE",
            "queued"=>"G2B_EVENT_QUEUED",
            "duplicate"=>"G2B_EVENT_DUPLICATE",
            _=>"G2B_EVENT_REJECTED",
        });
        let ack=json!({"type":"delivery.ack","eventId":event.event_id,"ok":ok,
                       "state":position,"error":error});
        match write_ack(input.get_mut(),ack){
            Ok(())=>g2b_trace("G2B_ACK_SENT"),
            Err(_)=>{g2b_trace("G2B_ACK_WRITE_FAILED");break;},
        }
    }
}
pub fn launch(app:AppHandle,shared:Arc<Shared>){
    thread::spawn(move ||loop{
        match create_pipe(){
            Ok(file)=>{let app2=app.clone();let shared2=shared.clone();
                thread::spawn(move||handle_connection(file,app2,shared2));},
            Err(e)=>{eprintln!("Named pipe create/accept failed: {e}");
                thread::sleep(std::time::Duration::from_millis(500));}
        }
    });
}
/// Never broadcast clicks to every Native Messaging connection. Only the
/// exact bridge which originated the ChatGPT event receives the callback.
pub fn notify_open_to(shared:&Arc<Shared>,connection_id:u64,event_id:&str)->bool {
    let message=json!({"type":"notification.open","eventId":event_id}).to_string();
    let mut conns=shared.connections.lock().unwrap();
    conns.iter().find(|(id,_)|*id==connection_id)
        .map_or(false,|(_,tx)|tx.send(message).is_ok())
}

#[cfg(test)]
mod tests{
  use super::*;
  #[test]fn valid_event_accepts_test_and_denies_control_chars(){
    let m=json!({"version":2,"type":"deliver","soundId":"holo","event":{
      "version":2,"eventId":"test-00000000-0000","chatTitle":"JARVIS", "completedAt":"2026-11-03T09:00:00Z", "conversationUrl":null}});
    assert!(check_request(&m).is_some());
    let mut bad=m.clone();bad["event"]["chatTitle"]=json!("line\nnewline");assert!(check_request(&bad).is_none());
    let mut voice=m.clone();voice["soundId"]=json!("female");voice["soundVolume"]=json!(35);
    assert_eq!(check_request(&voice).unwrap().2,35);
    voice["soundVolume"]=json!(0);assert_eq!(check_request(&voice).unwrap().2,0);
    voice["soundVolume"]=json!(101);assert!(check_request(&voice).is_none());
    let mut spoof=m.clone();spoof["event"]["source"]=json!("codex");assert!(check_request(&spoof).is_none());
    let codex=json!({"version":3,"type":"deliver","soundId":"leo","soundVolume":85,"event":{
       "version":3,"source":"codex","eventId":"codex-00112233445566778899aabbccddeeff",
       "chatTitle":"TALOS","completedAt":"2026-11-23T01:00:00Z","openTarget":null}});
    assert!(check_request(&codex).is_some());
    let mut bad=codex.clone();bad["event"]["source"]=json!("chatgpt");assert!(check_request(&bad).is_none());
    let mut bad=codex.clone();bad["event"]["openTarget"]=json!("https://bad.invalid/");assert!(check_request(&bad).is_none());
    let mut bad=codex.clone();bad["event"]["chatTitle"]=json!("line\nnewline");assert!(check_request(&bad).is_none());
    let mut bad=codex.clone();bad["soundVolume"]=json!(101);assert!(check_request(&bad).is_none());
    let mut bad=codex.clone();bad["version"]=json!(2);assert!(check_request(&bad).is_none());

  }
}

/// Release per-event browser click routing so its Native Messaging bridge can
/// enter idle shutdown after the full cross-source queue was displayed.
pub fn notify_closed_to(shared:&Arc<Shared>,connection_id:u64,event_id:&str)->bool {
    let message=json!({"type":"notification.closed","eventId":event_id}).to_string();
    shared.connections.lock().unwrap().iter().find(|(id,_)|*id==connection_id)
        .map_or(false,|(_,tx)|tx.send(message).is_ok())
}
