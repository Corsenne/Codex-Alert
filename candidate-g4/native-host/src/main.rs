//! G4 test-only Chrome Native Messaging host.
//! A synchronous request/ACK pipe and a separate one-shot callback pipe avoid
//! concurrent ReadFile/WriteFile on one non-overlapped Windows handle.
//! Not a deployable/production host. Stdout is Native Messaging frames only.
#![cfg(windows)]
use serde_json::{json,Value};
use serde::Deserialize;
use std::{
    collections::HashSet,ffi::c_void,fs::{self,File},io::{self,BufRead,BufReader,Read,Write},
    os::windows::io::FromRawHandle,path::PathBuf,sync::{Arc,Mutex,mpsc},thread,
    time::{Duration,Instant},
};
#[derive(Deserialize)]
#[serde(rename_all="camelCase")]
struct Config{extension_id:String}
#[repr(C)]
struct SecurityAttributes{length:u32,descriptor:*mut c_void,inherit:i32}
#[link(name="kernel32")]
extern "system"{
    fn GetCurrentProcessId()->u32;
    fn ProcessIdToSessionId(pid:u32,session:*mut u32)->i32;
    fn CreateFileW(name:*const u16,access:u32,share:u32,attrs:*mut c_void,
                   disposition:u32,flags:u32,template:*mut c_void)->*mut c_void;
    fn CreateNamedPipeW(name:*const u16,open_mode:u32,pipe_mode:u32,instances:u32,
       out_size:u32,in_size:u32,timeout:u32,attrs:*mut SecurityAttributes)->*mut c_void;
    fn ConnectNamedPipe(handle:*mut c_void,overlapped:*mut c_void)->i32;
    fn CloseHandle(handle:*mut c_void)->i32;
    fn LocalFree(handle:*mut c_void)->*mut c_void;
}
#[link(name="advapi32")]
extern "system"{
    fn ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl:*const u16,revision:u32,
         out:*mut *mut c_void,size:*mut u32)->i32;
}
fn wide(s:&str)->Vec<u16>{s.encode_utf16().chain(std::iter::once(0)).collect()}
fn session()->u32 {
    let mut id=0_u32;
    unsafe{ProcessIdToSessionId(GetCurrentProcessId(),&mut id);}
    id
}
fn forward_pipe()->String{format!(r"\\.\pipe\corsenne_finish_alert_g4_test_{}",session())}
fn callback_pipe()->String{
    format!(r"\\.\pipe\corsenne_finish_alert_g4_cb_{}_{}",session(),unsafe{GetCurrentProcessId()})
}
fn open_forward_pipe()->io::Result<File>{
    const GENERIC_READ:u32=0x8000_0000;const GENERIC_WRITE:u32=0x4000_0000;
    let name=wide(&forward_pipe());
    let handle=unsafe{CreateFileW(name.as_ptr(),GENERIC_READ|GENERIC_WRITE,0,
        std::ptr::null_mut(),3,0,std::ptr::null_mut())};
    if handle as isize==-1{return Err(io::Error::last_os_error());}
    Ok(unsafe{File::from_raw_handle(handle)})
}
fn create_callback_server()->io::Result<File>{
    let mut descriptor:*mut c_void=std::ptr::null_mut();
    if unsafe{ConvertStringSecurityDescriptorToSecurityDescriptorW(
        wide("D:P(A;;GA;;;SY)(A;;GA;;;OW)").as_ptr(),1,&mut descriptor,std::ptr::null_mut())}==0 {
        return Err(io::Error::last_os_error());
    }
    let mut attrs=SecurityAttributes{length:std::mem::size_of::<SecurityAttributes>() as u32,
        descriptor,inherit:0};
    let path=wide(&callback_pipe());
    const PIPE_ACCESS_INBOUND:u32=1;
    const PIPE_REJECT_REMOTE_CLIENTS:u32=8;
    let handle=unsafe{CreateNamedPipeW(path.as_ptr(),PIPE_ACCESS_INBOUND,
        PIPE_REJECT_REMOTE_CLIENTS,1,2048,2048,0,&mut attrs)};
    let err=io::Error::last_os_error();
    unsafe{LocalFree(descriptor);}
    if handle as isize==-1{return Err(err);}
    Ok(unsafe{File::from_raw_handle(handle)})
}
fn accept_callback(file:File,origin_events:Arc<Mutex<HashSet<String>>>,
                    output:Arc<Mutex<io::Stdout>>) {
    use std::os::windows::io::AsRawHandle;
    const ERROR_PIPE_CONNECTED:i32=535;
    let handle=file.as_raw_handle();
    let connected=unsafe{ConnectNamedPipe(handle,std::ptr::null_mut())};
    if connected==0 && io::Error::last_os_error().raw_os_error()!=Some(ERROR_PIPE_CONNECTED){return;}
    let mut input=BufReader::new(file);
    let mut line=String::new();
    if input.read_line(&mut line).ok().filter(|n|*n>0&&*n<=2048).is_none(){return;}
    let Ok(message)=serde_json::from_str::<Value>(&line) else{return;};
    if !matches!(message.get("type").and_then(Value::as_str),
        Some("notification.open"|"notification.closed")){return;}
    let Some(id)=message.get("eventId").and_then(Value::as_str) else{return;};
    if id.len()<12 || id.len()>50 || !id.bytes().all(|b|b.is_ascii_alphanumeric()||b==b'-'){return;}
    if !origin_events.lock().unwrap().remove(id){return;}
    let _=send_chrome(&output,&json!({"type":message["type"],"eventId":id}));
}
fn send_chrome(stdout:&Arc<Mutex<io::Stdout>>,message:&Value)->io::Result<()> {
    let data=serde_json::to_vec(message)?;
    if data.len()>8192{return Err(io::Error::new(io::ErrorKind::InvalidData,"reply too long"));}
    let mut out=stdout.lock().unwrap();
    out.write_all(&(data.len() as u32).to_le_bytes())?;
    out.write_all(&data)?;
    out.flush()
}
fn read_chrome(input:&mut impl Read)->io::Result<Option<Value>> {
    let mut header=[0_u8;4];
    match input.read_exact(&mut header){
        Ok(())=>{},
        Err(e) if e.kind()==io::ErrorKind::UnexpectedEof=>return Ok(None),
        Err(e)=>return Err(e)
    }
    let size=u32::from_le_bytes(header) as usize;
    if size==0||size>8192{return Err(io::Error::new(io::ErrorKind::InvalidData,"request too long"));}
    let mut bytes=vec![0;size];
    input.read_exact(&mut bytes)?;
    Ok(Some(serde_json::from_slice::<Value>(&bytes)?))
}

// A Chrome Native Messaging port can outlive its browser window; do not leak idle hosts.
const QUIET_POLL:Duration=Duration::from_secs(90);
const MAX_PENDING_AGE:Duration=Duration::from_secs(12*60);
fn stdin_frames()->mpsc::Receiver<io::Result<Option<Value>>>{
    let (tx,rx)=mpsc::sync_channel(32);
    thread::spawn(move||{
        let stdin=io::stdin();let mut input=stdin.lock();
        loop {
            let frame=read_chrome(&mut input);
            let end=!matches!(frame,Ok(Some(_)));
            if tx.send(frame).is_err()||end{break;}
        }
    });
    rx
}
fn should_retire(idle:Duration,pending:usize)->bool{
    (pending==0 && idle>=QUIET_POLL) || idle>=MAX_PENDING_AGE
}
fn next_frame(rx:&mpsc::Receiver<io::Result<Option<Value>>>,
       pending:&Arc<Mutex<HashSet<String>>>, last_use:Instant)->io::Result<Option<Value>>{
    loop{
        match rx.recv_timeout(QUIET_POLL){
          Ok(msg)=>return msg,
          Err(mpsc::RecvTimeoutError::Disconnected)=>return Ok(None),
          Err(mpsc::RecvTimeoutError::Timeout)=>{
             let count=pending.lock().map(|x|x.len()).unwrap_or(0);
             if should_retire(last_use.elapsed(),count){return Ok(None);}
          }
        }
    }
}
fn valid_extension_id(s:&str)->bool {
    s.len()==32 && s.bytes().all(|b|(b'a'..=b'p').contains(&b))
}
// Mirror the strict ChatGPT path contract of the G4 extension (no query/fragment).
fn valid_chat_url(url:&str)->bool{
    if url.len()>250 || url.contains(&['?','#','\\','\n','\r'][..]){return false;}
    let path=url.strip_prefix("https://chatgpt.com/")
      .or_else(||url.strip_prefix("https://chat.openai.com/"));
    let Some(path)=path else{return false;};
    let parts:Vec<&str>=path.trim_end_matches('/').split('/').collect();
    let id=|s:&str|s.len()>=8&&s.len()<=100&&s.bytes()
        .all(|b|b.is_ascii_alphanumeric()||b==b'_'||b==b'-');
    match parts.as_slice(){
       ["c",chat]=>id(chat),
       ["g",project,"c",chat]=>project.len()>=3&&project.len()<=100&&
           project.bytes().all(|b|b.is_ascii_alphanumeric()||b==b'_'||b==b'-')&&id(chat),
       _=>false
    }
}
fn valid_event(msg:&Value)->bool {
    if msg.get("type").and_then(Value::as_str)!=Some("deliver")||msg.get("version").and_then(Value::as_u64)!=Some(2){return false;}
    let Some(e)=msg.get("event")else{return false;};
    let Some(id)=e.get("eventId").and_then(Value::as_str)else{return false;};
    let Some(url)=e.get("conversationUrl").and_then(Value::as_str)else{return false;};
    id.len()>=12&&id.len()<=50&&id.bytes().all(|b|b.is_ascii_alphanumeric()||b==b'-')&&
        valid_chat_url(url)&&
        msg.get("soundId").and_then(Value::as_str)==Some("female") &&
        msg.get("audioOwner").and_then(Value::as_str)==Some("desktop")
}
fn run()->io::Result<()> {
    let base=std::env::current_exe()?.parent().ok_or(io::Error::new(io::ErrorKind::NotFound,"base"))?.to_owned();
    let config:Config=serde_json::from_slice(&fs::read(base.join("bridge-config.json"))?)?;
    if !valid_extension_id(&config.extension_id){return Err(io::Error::new(io::ErrorKind::InvalidData,"bad extension id"));}
    if std::env::args().nth(1).unwrap_or_default()!=format!("chrome-extension://{}/",config.extension_id) {
        return Err(io::Error::new(io::ErrorKind::PermissionDenied,"unknown extension"));
    }
    let stdout=Arc::new(Mutex::new(io::stdout()));
    let pending=Arc::new(Mutex::new(HashSet::<String>::new()));
    // Bind callback endpoint before emitting bridge.ready.
    let cb_file=create_callback_server()?;
    let cb_pending=Arc::clone(&pending);
    let cb_out=Arc::clone(&stdout);
    thread::spawn(move||{
        // Each click uses one callback connection. Re-arm without polling
        // so a second manual test can use the same authenticated host.
        let mut next=Some(cb_file);
        while let Some(server)=next.take() {
            accept_callback(server,Arc::clone(&cb_pending),Arc::clone(&cb_out));
            next=create_callback_server().ok();
        }
    });
    let mut stream=match open_forward_pipe() {
        Ok(s)=>BufReader::new(s),
        Err(_)=>{
            send_chrome(&stdout,&json!({"type":"bridge.ready","ok":false,"error":"g3c-test-app-not-running"}))?;
            return Ok(());
        }
    };
    send_chrome(&stdout,&json!({"type":"bridge.ready","ok":true}))?;
    let incoming=stdin_frames();
    let mut last_use=Instant::now();
    while let Some(mut message)=next_frame(&incoming,&pending,last_use)? {
        last_use=Instant::now();
        if !valid_event(&message){
            let id=message.get("event").and_then(|x|x.get("eventId"))
                .and_then(Value::as_str).unwrap_or("");
            send_chrome(&stdout,&json!({"type":"delivery.ack","eventId":id,"ok":false,"error":"invalid-test-request"}))?;
            continue;
        }
        let id=message["event"]["eventId"].as_str().unwrap().to_string();
        {
            let mut events=pending.lock().unwrap();
            if events.len()>=32 {
                send_chrome(&stdout,&json!({"type":"delivery.ack","eventId":id,"ok":false,"error":"g3c-test-queue-limit"}))?;
                continue;
            }
            events.insert(id.clone());
        }
        message["event"]["bridgeCallbackPipe"]=Value::String(callback_pipe());
        let request=serde_json::to_string(&message)?;
        stream.get_mut().write_all(request.as_bytes())?;
        stream.get_mut().write_all(b"\n")?;
        stream.get_mut().flush()?;
        let mut response=String::new();
        let n=stream.read_line(&mut response)?;
        if n==0 || n>8192 {return Err(io::Error::new(io::ErrorKind::InvalidData,"bad ack"));}
        let ack=serde_json::from_str::<Value>(&response)?;
        if ack.get("type").and_then(Value::as_str)!=Some("delivery.ack") ||
            ack.get("eventId").and_then(Value::as_str)!=Some(id.as_str()){return Err(io::Error::new(io::ErrorKind::InvalidData,"bad ack event"));}
        if ack.get("ok").and_then(Value::as_bool)!=Some(true){pending.lock().unwrap().remove(&id);}
        send_chrome(&stdout,&ack)?;
    }
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("G4 test native bridge failed: {e}");}}
#[cfg(test)]
mod tests{
 use super::*;
 #[test] fn extension_id_rejects_injection(){
    assert!(valid_extension_id(&"a".repeat(32)));
    assert!(!valid_extension_id("test"));assert!(!valid_extension_id(&"z".repeat(32)));
 }
 #[test] fn bridge_lifetime_is_bounded(){
   assert!(should_retire(Duration::from_secs(90),0));
   assert!(!should_retire(Duration::from_secs(89),0));
   assert!(!should_retire(Duration::from_secs(200),1));
   assert!(should_retire(Duration::from_secs(721),1));
 }
 #[test] fn route_host_and_sound_are_strict(){
    let v=json!({"version":2,"type":"deliver","event":{"eventId":"abcde-1234567890","conversationUrl":"https://chatgpt.com/c/12345678"},"soundId":"female","audioOwner":"desktop"});
    assert!(valid_event(&v));
    let mut w=v.clone();w["event"]["conversationUrl"]=json!("https://evil.test/c/12345678");
    assert!(!valid_event(&w));
    assert!(valid_chat_url("https://chatgpt.com/g/g-project/c/12345678-abcd"));
    assert!(!valid_chat_url("https://chatgpt.com/c/12345678?x=1"));
    assert!(!valid_chat_url("https://chatgpt.com/c/12345678/../../evil"));
 }
}
