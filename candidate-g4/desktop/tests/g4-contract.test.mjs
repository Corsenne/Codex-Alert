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
test('G4 click stops sound before source-specific routing (shared native exit)',()=>{
 const code=read('src-tauri/src/lib.rs').replace(/\r\n/g,'\n');
 const start=code.indexOf('fn finish_event(');
 const end=code.indexOf('#[tauri::command]\nfn complete_notification(',start);
 assert.ok(start>=0&&end>start);
 const section=code.slice(start,end);
 const stop=section.indexOf('stop_audio();');
 const cb=section.indexOf('g4_callback::send_callback');
 const open=section.indexOf('g4_thread::open_codex_thread_target');
 assert.ok(stop>=0&&cb>stop&&open>stop,'stop before callback and external routing');
 assert.match(section,/G4_CHATGPT_CALLBACK_SENT/);
 assert.match(section,/G4_CODEX_ROUTE_DISPATCHED/);
 assert.match(section,/G4_CHATGPT_CLOSE_SENT/);
 assert.match(section,/G4R_STALE_ACTION_IGNORED/);
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
test('G4 queue remains single-active, silent waiting and FIFO-bounded',()=>{
 const q=read('src-tauri/src/delivery.rs');
 assert.match(q,/pub const MAX_WAITING:usize=64/);
 assert.match(q,/Admission::Queued/);
 assert.match(q,/self\.audio_started=false/);
 assert.match(q,/if item\.event\.event_id!=id\|\|self\.audio_started/);
 assert.match(q,/pub const MAX_QUEUE_AGE:Duration=Duration::from_secs\(20\)/);
 assert.match(q,/self\.waiting\.push_back\(Waiting\{item,queued_at:now\}\)/);
 assert.match(q,/while let Some\(wait\)=self\.waiting\.pop_front\(\)/);
});
test('Native G4R timeout independent of JS timer and no stale navigation',()=>{
 const native=read('src-tauri/src/lib.rs');
 const q=read('src-tauri/src/delivery.rs');
 const view=read('src/main.tsx');
 assert.match(native,/fn launch_native_watchdog\(/);
 assert.match(native,/Duration::from_millis\(125\)/);
 assert.match(native,/finish_event\(&app,&shared,&due\.id,"timeout"\)/);
 assert.match(native,/finish-alert:cleared/);
 assert.match(native,/G4R_NATIVE_VISIBLE_TIMEOUT/);
 assert.match(native,/G4R_NATIVE_UNPAINTED_TIMEOUT/);
 assert.match(q,/pub const VISIBLE_TIMEOUT:Duration=Duration::from_secs\(8\)/);
 assert.match(q,/pub const UNPAINTED_TIMEOUT:Duration=Duration::from_secs\(12\)/);
 assert.match(q,/fn timeout_due\(/);
 assert.match(q,/fn stale_actions_are_idempotent\(/);
 assert.match(q,/fn late_queued_events_dropped_without_new_voice\(/);
 assert.match(view,/finish-alert:cleared/);
 assert.doesNotMatch(view,/setTimeout\(\(\)=>onFinish\(event\.eventId,'timeout'\)/);
});
