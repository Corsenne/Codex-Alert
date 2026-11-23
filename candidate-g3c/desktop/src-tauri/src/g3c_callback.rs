//! G3C ISOLATED TEST callback channel; NOT the production native duplex protocol.
use std::io::{self,Write};
use std::fs::OpenOptions;
#[cfg(windows)]
pub(crate) fn valid_callback_pipe(input:&str)->bool{
    const BASE:&str=r"\\.\pipe\corsenne_finish_alert_g3c_cb_";
    let Some(tail)=input.strip_prefix(BASE) else {return false;};
    let mut parts=tail.split('_');
    let Some(session)=parts.next() else{return false};
    let Some(pid)=parts.next() else{return false};
    if parts.next().is_some(){return false;}
    if session.is_empty()||session.len()>8||pid.is_empty()||pid.len()>10 {return false;}
    if !session.bytes().all(|b|b.is_ascii_digit())||!pid.bytes().all(|b|b.is_ascii_digit()){return false;}
    true
}
#[cfg(windows)]
pub(crate) fn send_chrome_open(pipe:&str,event_id:&str)->bool{
    if !valid_callback_pipe(pipe)||event_id.len()<12||event_id.len()>50||
       !event_id.bytes().all(|b|b.is_ascii_alphanumeric()||b==b'-'){return false;}
    let msg=serde_json::json!({"type":"notification.open","eventId":event_id});
    let result=(||->io::Result<()> {
        let mut f=OpenOptions::new().write(true).open(pipe)?;
        f.write_all(msg.to_string().as_bytes())?;
        f.write_all(b"\n")?;
        f.flush()
    })();
    result.is_ok()
}
#[cfg(all(test,windows))]
mod tests{
 use super::*;
 #[test]fn strict_test_pipe(){
  assert!(valid_callback_pipe(r"\\.\pipe\corsenne_finish_alert_g3c_cb_2_12345"));
  assert!(!valid_callback_pipe(r"\\.\pipe\corsenne_finish_alert_v2_2"));
  assert!(!valid_callback_pipe(r"\\.\pipe\corsenne_finish_alert_g3c_cb_2_12345\evil"));
  assert!(!valid_callback_pipe(r"\\.\pipe\corsenne_finish_alert_g3c_cb_2_x"));
 }
}
