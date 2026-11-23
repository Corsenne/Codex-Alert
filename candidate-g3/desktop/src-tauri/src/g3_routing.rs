//! G3 exact-thread target: no project-folder fallback or arbitrary URI execution.
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
