import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const root=new URL('../',import.meta.url);
const file=(path)=>readFileSync(new URL(path,root),'utf8');
test('G2B HTML fixed-stage bootstrap and JS error hooks',()=>{
  const html=file('index.html');
  assert.match(html,/G2B_HTML_INLINE_EXECUTED/);
  assert.match(html,/G2B_JS_UNHANDLED_REJECTION/);
  assert.match(html,/G2B_DOM_READY/);
  assert.match(html,/__TAURI_INTERNALS__/);
});
test('React startup and listener/invoke stages are distinguishable',()=>{
  const source=file('src/main.tsx');
  for(const stage of ['G2B_REACT_MODULE_EXECUTED','G2B_REACT_EFFECT_STARTED',
    'G2B_EVENT_LISTENER_REGISTERED','G2B_EVENT_LISTENER_REJECTED',
    'G2B_UI_READY_INVOKE_REJECTED']) {
    assert.ok(source.includes(stage),stage);
  }
  assert.match(source,/await invoke\('ui_ready'\)/);
});
test('Rust allows only static stage labels, no user strings',()=>{
  const source=file('src-tauri/src/lib.rs');
  assert.match(source,/fn g2b_diagnostic\(stage:String\)/);
  assert.match(source,/matches!\(stage\.as_str\(\)/);
  assert.match(source,/g2b_trace\(&stage\)/);
  assert.match(source,/G2B_PAGE_ORIGIN_DEV_SERVER/);
  assert.match(source,/G2B_PAGE_ORIGIN_EMBEDDED_APP/);
  assert.match(source,/generate_handler!\[g2b_diagnostic,ui_ready/);
});
