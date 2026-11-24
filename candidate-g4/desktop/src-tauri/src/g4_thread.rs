//! G4 exact-thread target: no project-folder fallback or arbitrary URI execution.
#[cfg(windows)]
pub(crate) fn valid_codex_thread_target(url:&str)->bool{
    const PREFIX:&str="codex://threads/";
    let Some(id)=url.strip_prefix(PREFIX) else{return false;};
    if id.len()!=36 || !id.is_ascii(){return false;}
    let b=id.as_bytes();
    for (i,x) in b.iter().enumerate(){
        if [8,13,18,23].contains(&i){if *x!=b'-'{return false;}}
        else if !x.is_ascii_hexdigit(){return false;}
    }
    // Canonical 36-char UUID format; restrict version and variant.
    if !matches!(b[14],b'1'..=b'8'){return false;}
    if !matches!(b[19],b'8'|b'9'|b'a'|b'b'){return false;}
    true
}

/// Accept a dynamic Codex target only when the local session_meta first line
/// matches the exact verified Codex UUID. No transcript body is read or logged.
#[cfg(windows)]
pub(crate) fn verified_codex_session_link(uri:&str,transcript:&str)->bool{
    use std::path::PathBuf;
    let home=std::env::var_os("CODEX_HOME").map(PathBuf::from)
        .or_else(||std::env::var_os("USERPROFILE").map(|p|PathBuf::from(p).join(".codex")));
    let Some(home)=home else{return false};
    verified_codex_session_link_in_root(uri,transcript,&home.join("sessions"))
}
#[cfg(windows)]
fn verified_codex_session_link_in_root(
    uri:&str,transcript:&str,session_root:&std::path::Path
)->bool{
    use std::{fs::File,io::{BufRead,BufReader,Read},path::Path};
    const MAX_FIRST_LINE:u64=65_536;
    if !valid_codex_thread_target(uri)||transcript.len()>2048{return false;}
    let Some(id)=uri.strip_prefix("codex://threads/") else{return false;};
    if id!=id.to_ascii_lowercase(){return false;}
    let proposed=Path::new(transcript);
    if !proposed.is_absolute(){return false;}
    let Ok(root)=std::fs::canonicalize(session_root) else{return false;};
    let Ok(path)=std::fs::canonicalize(proposed) else{return false;};
    if !path.starts_with(&root)||path==root{return false;}
    let Some(name)=path.file_name().and_then(|x|x.to_str()) else{return false;};
    if !name.starts_with("rollout-")||!name.ends_with(&format!("-{id}.jsonl")){return false;}
    let Some(prefix)=name.strip_prefix("rollout-")
        .and_then(|n|n.strip_suffix(&format!("-{id}.jsonl"))) else{return false;};
    if prefix.is_empty()||!prefix.bytes().all(|b|b.is_ascii_digit()||b==b'-'||b==b'T'||b==b'.'||b==b'Z'){return false;}
    let Ok(file)=File::open(path) else{return false;};
    let mut first=String::new();
    let Ok(count)=BufReader::new(file).take(MAX_FIRST_LINE).read_line(&mut first) else{return false;};
    if count==0||count as u64>=MAX_FIRST_LINE{return false;}
    let Ok(meta)=serde_json::from_str::<serde_json::Value>(&first) else{return false;};
    meta.get("type").and_then(|v|v.as_str())==Some("session_meta")&&
      meta.get("payload").and_then(|p|p.get("id")).and_then(|v|v.as_str())==Some(id)
}

#[cfg(windows)]
pub(crate) fn open_codex_thread_target(url:&str)->bool {
    use std::os::windows::ffi::OsStrExt;
    if !valid_codex_thread_target(url){return false;}
    #[link(name="shell32")]
    extern "system" {
        fn ShellExecuteW(hwnd:*mut std::ffi::c_void,operation:*const u16,file:*const u16,
                         params:*const u16,directory:*const u16,show:i32)->*mut std::ffi::c_void;
    }
    let target:Vec<u16>=std::ffi::OsStr::new(url).encode_wide().chain(std::iter::once(0)).collect();
    let open:Vec<u16>="open".encode_utf16().chain(std::iter::once(0)).collect();
    // ShellExecute success only confirms dispatch; real thread focus must be tested.
    (unsafe{ShellExecuteW(std::ptr::null_mut(),open.as_ptr(),target.as_ptr(),
       std::ptr::null(),std::ptr::null(),1)} as isize)>32
}
#[cfg(all(test,windows))]
mod tests {
 use super::*;
 const ID:&str="019d25ff-3701-75d1-b331-160b90f8a456";
 #[test]fn exact_codex_link_allowed(){
    assert!(valid_codex_thread_target(&format!("codex://threads/{ID}")));
 }

 #[test]fn verified_codex_rollout_metadata_exact_session(){
    use std::{fs,io::Write,time::{SystemTime,UNIX_EPOCH}};
    let stamp=SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_nanos();
    let base=std::env::temp_dir().join(format!("g4_codex_verify_{}_{}",std::process::id(),stamp));
    let sessions=base.join("sessions");
    let folder=sessions.join("2026").join("11").join("23");
    fs::create_dir_all(&folder).unwrap();
    let uri=format!("codex://threads/{ID}");
    let file=folder.join(format!("rollout-2026-11-23T01-02-03-{ID}.jsonl"));
    let mut output=fs::File::create(&file).unwrap();
    writeln!(output,"{{\"type\":\"session_meta\",\"payload\":{{\"id\":\"{ID}\"}}}}").unwrap();
    writeln!(output,"{{\"type\":\"private_transcript\",\"payload\":\"not-read\"}}").unwrap();
    drop(output);
    assert!(verified_codex_session_link_in_root(&uri,file.to_str().unwrap(),&sessions));
    let outside=base.join(format!("rollout-2026-11-23T01-02-03-{ID}.jsonl"));
    fs::copy(&file,&outside).unwrap();
    assert!(!verified_codex_session_link_in_root(&uri,outside.to_str().unwrap(),&sessions));
    assert!(!verified_codex_session_link_in_root("codex://threads/new",file.to_str().unwrap(),&sessions));
    fs::write(&file,format!("{{\"type\":\"session_meta\",\"payload\":{{\"id\":\"019d25ff-3701-75d1-b331-160b90f8a457\"}}}}\n")).unwrap();
    assert!(!verified_codex_session_link_in_root(&uri,file.to_str().unwrap(),&sessions));
    let _=fs::remove_dir_all(&base);
 }
 #[test]fn no_forged_or_generic_links(){
    for s in [
      "codex://threads/new", "codex://settings",
      "https://example.com", "codex://threads/../../a",
      "codex://threads/019d25ff-3701-75d1-b331-160b90f8a456?x=1",
      "codex://threads/019d25ff-3701-75d1-b331-160b90f8a456#fragment",
      "codex://threads/019d25ff-3701-75d1-b331-160b90f8a456/extra",
      "codex://threads/019d25ff-3701-05d1-b331-160b90f8a456"
    ]{assert!(!valid_codex_thread_target(s),"{s}");}
 }
}
