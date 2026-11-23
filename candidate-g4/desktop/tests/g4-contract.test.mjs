import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const root=new URL('../',import.meta.url);
const read=(p)=>readFileSync(new URL(p,root),'utf8');
test('G4 isolated identity and common pipe',()=>{
 const cfg=JSON.parse(read('src-tauri/tauri.conf.json'));
 assert.equal(cfg.identifier,'com.corsenne.finishalertdesktop.g4test');
 const ipc=read('src-tauri/src/ipc.rs');
 assert.match(ipc,/corsenne_finish_alert_g4_test_/);
 assert.doesNotMatch(ipc,/corsenne_finish_alert_g3c_test_/);
});
test('G4 click stops sound before source-specific routing',()=>{
 const code=read('src-tauri/src/lib.rs').replace(/\r\n/g,'\n');
 const start=code.indexOf('fn complete_notification(');
 const end=code.indexOf('#[cfg(windows)]\nfn open_chat_url',start);
 assert.ok(start>=0&&end>start);
 const section=code.slice(start,end);
 const stop=section.indexOf('stop_audio();');
 const cb=section.indexOf('g4_callback::send_callback');
 const open=section.indexOf('g4_thread::open_codex_thread_target');
 assert.ok(stop>=0&&cb>stop&&open>stop);
 assert.match(section,/G4_CHATGPT_CALLBACK_SENT/);
 assert.match(section,/G4_CODEX_ROUTE_DISPATCHED/);
 assert.match(section,/G4_CHATGPT_CLOSE_SENT/);
});
test('G4 Codex link requires independent exact local consent',()=>{
 const s=read('src-tauri/src/ipc.rs');
 assert.match(s,/FINISH_ALERT_G4_ALLOWED_CODEX_LINK/);
 assert.match(s,/g4_thread::valid_codex_thread_target/);
 assert.match(s,/bridge_callback_pipe\.is_some\(\)/);
});
test('G4 callback cannot access general native pipes',()=>{
 const s=read('src-tauri/src/g4_callback.rs');
 assert.match(s,/corsenne_finish_alert_g4_cb_/);
 assert.match(s,/notification.open/);
 assert.match(s,/notification.closed/);
 // The negative Rust unit test deliberately mentions the old pipe by name.
 // Only the production prefix declaration and callback implementation must be isolated.
 const implementation=s.split('#[cfg(all(test,windows))]')[0];
 assert.doesNotMatch(implementation,/corsenne_finish_alert_v2_/);
});
test('G4 queue remains one-visible and no sound while waiting',()=>{
 const code=read('src-tauri/src/delivery.rs');
 assert.match(code,/pub const MAX_WAITING: usize = 64/);
 assert.match(code,/Admission::Queued/);
 assert.match(code,/if item.event.event_id != id \|\| self.audio_started/);
 assert.match(code,/self.audio_started=false/);
});
