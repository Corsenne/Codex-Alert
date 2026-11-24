//! Chrome Native Messaging host. stdout is reserved for little-endian length-framed JSON.
//! Does not interpret URLs, launch shell commands, or read ChatGPT page content.
#![cfg(windows)]
use serde::Deserialize;
use serde_json::{json, Value};
use std::{
    fs::{self, File},
    io::{self, BufRead, BufReader, Read, Write},
    path::PathBuf,
    os::windows::io::FromRawHandle,
    ffi::c_void,
    process::{Command, Stdio},
    sync::{Arc, Mutex, mpsc},
    thread,
    time::{Duration, Instant},
};

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct BridgeConfig { extension_id: String }

#[link(name = "kernel32")]
extern "system" {
    fn GetCurrentProcessId() -> u32;
    fn ProcessIdToSessionId(process_id: u32, session_id: *mut u32) -> i32;
    fn CreateFileW(name:*const u16,desired_access:u32,share_mode:u32,attributes:*mut c_void,
       creation_disposition:u32,flags:u32,template:*mut c_void)->*mut c_void;
}
fn pipe_path() -> String {
    let mut session = 0_u32;
    unsafe { ProcessIdToSessionId(GetCurrentProcessId(), &mut session); }
    format!(r"\\.\pipe\corsenne_finish_alert_v2_{session}")
}
fn host_send(out: &Arc<Mutex<io::Stdout>>, msg: &Value) -> io::Result<()> {
    let bytes = serde_json::to_vec(msg)?;
    if bytes.len() > 8192 { return Err(io::Error::new(io::ErrorKind::InvalidData,"reply too long")); }
    let mut output = out.lock().expect("stdout mutex poisoned");
    output.write_all(&(bytes.len() as u32).to_le_bytes())?;
    output.write_all(&bytes)?;
    output.flush()
}
fn read_host_message(input: &mut impl Read) -> io::Result<Option<Value>> {
    let mut prefix = [0u8;4];
    match input.read_exact(&mut prefix) {
        Ok(()) => {},
        Err(e) if e.kind() == io::ErrorKind::UnexpectedEof => return Ok(None),
        Err(e) => return Err(e),
    }
    let n = u32::from_le_bytes(prefix) as usize;
    if n == 0 || n > 64 * 1024 { return Err(io::Error::new(io::ErrorKind::InvalidData,"message over limit")); }
    let mut buf=vec![0u8;n];input.read_exact(&mut buf)?;
    let value=serde_json::from_slice::<Value>(&buf)?;
    Ok(Some(value))
}
fn read_config(base:&PathBuf) -> io::Result<BridgeConfig> {
    let cfg = fs::read_to_string(base.join("bridge-config.json"))?;
    let parsed: BridgeConfig=serde_json::from_str(&cfg)?;
    if parsed.extension_id.len()!=32 || !parsed.extension_id.chars().all(|c| ('a'..='p').contains(&c)) {
        return Err(io::Error::new(io::ErrorKind::InvalidData,"invalid extension id"));
    }
    Ok(parsed)
}
fn open_pipe(path:&str)->io::Result<File>{
    const GENERIC_READ:u32=0x8000_0000;
    const GENERIC_WRITE:u32=0x4000_0000;
    const OPEN_EXISTING:u32=3;
    let wide:Vec<u16>=path.encode_utf16().chain(std::iter::once(0)).collect();
    let handle=unsafe{CreateFileW(wide.as_ptr(),GENERIC_READ|GENERIC_WRITE,0,
       std::ptr::null_mut(),OPEN_EXISTING,0,std::ptr::null_mut())};
    if handle as isize==-1 {return Err(io::Error::last_os_error());}
    // SAFETY: CreateFileW returned an owned Windows HANDLE.
    Ok(unsafe{File::from_raw_handle(handle)})
}
fn pipe_connect(base:&PathBuf)-> io::Result<File> {
    let path=pipe_path();
    let deadline=Instant::now()+Duration::from_secs(6);
    let mut launched=false;
    loop {
        match open_pipe(&path) {
            Ok(file)=>return Ok(file),
            Err(e)=>{
                if !launched {
                    launched=true;
                    let app=base.join("finish-alert-desktop.exe");
                    if !app.is_file() { return Err(io::Error::new(io::ErrorKind::NotFound,"desktop EXE missing")); }
                    // This is a fixed, same-folder executable; there are no user-supplied arguments.
                    // Native Messaging stdin/stdout are owned exclusively by this host.
                    // Do not inherit their handles into Tauri; this can delay EOF and
                    // leave a bridge process alive after Chrome closes its native port.
                    let _=Command::new(app)
                        .stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null())
                        .spawn();
                }
                if Instant::now()>=deadline { return Err(e); }
                thread::sleep(Duration::from_millis(150));
            }
        }
    }
}
fn validated_delivery(message:&Value)->bool{
    if message.get("version").and_then(Value::as_u64)!=Some(2) || message.get("type").and_then(Value::as_str)!=Some("deliver") {return false;}
    let Some(event)=message.get("event") else{return false;};
    let event_id=event.get("eventId").and_then(Value::as_str).unwrap_or("");
    let title=event.get("chatTitle").and_then(Value::as_str).unwrap_or("");
    event_id.len()<=50 && event_id.len()>=12 && event_id.chars().all(|c|c.is_ascii_alphanumeric()||c=='-') &&
      !title.is_empty() && title.chars().count()<=100 && !title.chars().any(|c|c.is_control()) &&
      event.get("completedAt").and_then(Value::as_str).map_or(false,|s|s.len()<=64) &&
      matches!(message.get("soundId").and_then(Value::as_str),Some("holo"|"soft"|"pulse"|"female")) &&
      message.get("soundVolume").map_or(true,|v|v.as_u64().map_or(false,|n|n<=100))
}
// A blocking stdin reader alone can remain stuck when a handle leaks after
// Chrome disconnects. An independent, bounded idle watchdog ensures a bridge
// does not accumulate for days. The background read thread dies on host exit.
const IDLE_LIMIT: Duration=Duration::from_secs(180);
fn stdin_frames() -> mpsc::Receiver<io::Result<Option<Value>>> {
    let (tx,rx)=mpsc::sync_channel(32);
    thread::spawn(move || {
        let stdin=io::stdin();
        let mut input=stdin.lock();
        loop {
            let frame=read_host_message(&mut input);
            let done=!matches!(&frame,Ok(Some(_)));
            if tx.send(frame).is_err() || done {break;}
        }
    });
    rx
}
fn next_frame(rx:&mpsc::Receiver<io::Result<Option<Value>>>) -> io::Result<Option<Value>> {
    match rx.recv_timeout(IDLE_LIMIT) {
        Ok(msg)=>msg,
        Err(mpsc::RecvTimeoutError::Timeout)=>Ok(None), // intentionally retire idle bridge
        Err(mpsc::RecvTimeoutError::Disconnected)=>Ok(None),
    }
}
fn run() -> io::Result<()> {
    let exe=std::env::current_exe()?;
    let base=exe.parent().ok_or_else(||io::Error::new(io::ErrorKind::NotFound,"app directory"))?.to_path_buf();
    let config=read_config(&base)?;
    let origin=std::env::args().nth(1).unwrap_or_default();
    if origin!=format!("chrome-extension://{}/",config.extension_id) {
        return Err(io::Error::new(io::ErrorKind::PermissionDenied,"unapproved chrome origin"));
    }
    let stdout=Arc::new(Mutex::new(io::stdout()));
    let incoming=stdin_frames();
    let stream=match pipe_connect(&base){
        Ok(s)=>{host_send(&stdout,&json!({"type":"bridge.ready","ok":true}))?;s}
        Err(e)=>{
            host_send(&stdout,&json!({"type":"bridge.ready","ok":false,"error":format!("desktop-unavailable: {e}")}))?;
            // Keep reading Chrome messages to return a failure ACK rather than dropping them.
            while let Some(msg)=next_frame(&incoming)? {
                let id=msg.get("event").and_then(|v|v.get("eventId")).and_then(Value::as_str).unwrap_or("");
                host_send(&stdout,&json!({"type":"delivery.ack","eventId":id,"ok":false,"error":"desktop-unavailable"}))?;
            }
            return Ok(());
        }
    };
    let output=Arc::clone(&stdout);
    let reader=stream.try_clone()?;
    let writer=Arc::new(Mutex::new(stream));
    let receiver=thread::spawn(move || {
        let mut input=BufReader::new(reader);
        let mut line=String::new();
        loop {
            line.clear();
            match input.read_line(&mut line) {
                Ok(0)=>break,
                Ok(n) if n<=8192=> {
                    if let Ok(msg)=serde_json::from_str::<Value>(&line) {
                        let kind=msg.get("type").and_then(Value::as_str).unwrap_or("");
                        if ["delivery.ack","notification.open","notification.closed"].contains(&kind) {
                            let _=host_send(&output,&msg);
                        }
                    }
                },
                _=>break
            }
        }
        let _=host_send(&output,&json!({"type":"bridge.disconnected"}));
    });
    while let Some(msg)=next_frame(&incoming)? {
        if msg.get("version").and_then(Value::as_u64)==Some(2)
            && msg.get("type").and_then(Value::as_str)==Some("bridge.ping") {
            host_send(&stdout,&json!({"type":"bridge.pong"}))?;
            continue;
        }
        let id=msg.get("event").and_then(|v|v.get("eventId")).and_then(Value::as_str).unwrap_or("");
        if !validated_delivery(&msg){
            host_send(&stdout,&json!({"type":"delivery.ack","eventId":id,"ok":false,"error":"invalid-request"}))?;
            continue;
        }
        let serialized=serde_json::to_string(&msg)?;
        let result=(||->io::Result<()> {
            let mut p=writer.lock().expect("pipe mutex poisoned");
            p.write_all(serialized.as_bytes())?;p.write_all(b"\n")?;p.flush()
        })();
        if let Err(e)=result {
            host_send(&stdout,&json!({"type":"delivery.ack","eventId":id,"ok":false,"error":format!("pipe-write-failed: {e}")}))?;
            break;
        }
    }
    drop(writer);
    // Process exit closes pipe/stdout and terminates any stalled reader threads.
    let _=receiver.thread().id();
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("Finish Alert native host: {e}");}}

#[cfg(test)]
mod tests{
    use super::*;
    #[test] fn validate_payload(){
        let valid=json!({"type":"deliver","version":2,"event":{"eventId":"test-00000000-0000","chatTitle":"JARVIS監査","completedAt":"2026-11-03T11:00:00+09:00"},"soundId":"holo"});
        assert!(validated_delivery(&valid));
        let mut invalid=valid.clone();invalid["event"]["chatTitle"]=json!("evil\nlog");
        assert!(!validated_delivery(&invalid));
        let mut invalid_sound=valid.clone();invalid_sound["soundId"]=json!("silent");
        assert!(!validated_delivery(&invalid_sound));
        let mut voice=valid.clone();voice["soundId"]=json!("female");voice["soundVolume"]=json!(0);
        assert!(validated_delivery(&voice));
        voice["soundVolume"]=json!(100);assert!(validated_delivery(&voice));
        voice["soundVolume"]=json!(101);assert!(!validated_delivery(&voice));
        voice["soundVolume"]=json!(-1);assert!(!validated_delivery(&voice));
    }
    #[test] fn chrome_protocol_roundtrip(){
        let value=json!({"version":2,"type":"deliver"});
        let bytes=serde_json::to_vec(&value).unwrap();
        let mut wire=Vec::new();wire.extend_from_slice(&(bytes.len() as u32).to_le_bytes());wire.extend_from_slice(&bytes);
        assert_eq!(read_host_message(&mut wire.as_slice()).unwrap(),Some(value));
    }
}
