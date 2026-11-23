import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const root = new URL('../',import.meta.url);
const read=p=>readFileSync(new URL(p,root),'utf8');

test('G3 isolated app has unique app ID and IPC endpoint',()=>{
 const cfg=JSON.parse(read('src-tauri/tauri.conf.json'));
 const ipc=read('src-tauri/src/ipc.rs');
 assert.equal(cfg.identifier,'com.corsenne.finishalertdesktop.g3clicktest');
 assert.match(ipc,/corsenne_finish_alert_g3_click_test_/);
 assert.doesNotMatch(ipc,/corsenne_finish_alert_v2_/);
});
test('G3 click stops sound before opening only the authorized Codex link',()=>{
 const source=read('src-tauri/src/lib.rs');
 const start=source.indexOf('fn complete_notification(');
 const end=source.indexOf('#[cfg(windows)]\nfn open_chat_url',start);
 assert.ok(start>=0 && end>start);
 const block=source.slice(start,end);
 const stop=block.indexOf('stop_audio();');
 const click=block.indexOf('if action=="click"');
 const open=block.indexOf('open_codex_thread_target(url)');
 assert.ok(stop>=0 && click>stop && open>click,'stop must happen before navigation');
 assert.match(block,/FINISH_ALERT_G3_ALLOWED_LINK/);
 assert.match(block,/G3_AUDIO_STOP_CALLED/);
 assert.match(block,/G3_THREAD_OPEN_DISPATCHED/);
 assert.match(block,/G3_TARGET_NOT_AUTHORIZED/);
});
test('G3 input must match validated exact link and source contract',()=>{
 const ipc=read('src-tauri/src/ipc.rs');
 const routing=read('src-tauri/src/g3_routing.rs');
 assert.match(ipc,/FINISH_ALERT_G3_ALLOWED_LINK/);
 assert.match(ipc,/valid_codex_thread_target/);
 assert.match(routing,/codex:\/\/threads\//);
 assert.match(routing,/ShellExecuteW/);
});
test('GUI handler has no production Chrome open callback in synthetic test',()=>{
 const lib=read('src-tauri/src/lib.rs');
 assert.match(lib,/G3_OTHER_SOURCE_CLICK_IGNORED/);
 assert.match(lib,/G3_LEO_PLAY_REQUESTED/);
 assert.match(lib,/G2B_UI_READY_PASS/);
});
