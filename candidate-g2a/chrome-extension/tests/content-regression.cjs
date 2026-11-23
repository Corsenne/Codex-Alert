'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

class FakeElement {
  constructor(text = '', tagName = 'DIV') {this.textContent = text; this.tagName = tagName; this.isConnected = true;}
  getClientRects() {return [{}];}
  getAttribute(k) {return k === 'data-testid' && this.tagName === 'BUTTON' ? 'stop-button' : null;}
  closest() {return this;}
}
function launch({assistant = false, main = false, title = ''} = {}) {
  let stop = false;
  let error = false;
  let observer;
  const handlers = {};
  const out = [];
  const button = new FakeElement('', 'BUTTON');
  const answer = new FakeElement('');
  const body = new FakeElement('Question from the user');
  const mainNode = main ? new FakeElement('Question from the user') : null;
  const alert = new FakeElement('Something went wrong');
  const document = {
    title, visibilityState:'visible', hasFocus:()=>true,
    body, documentElement: new FakeElement(''),
    querySelector(sel) { if (sel === 'main') return mainNode; return null; },
    querySelectorAll(sel) {
      if (sel.startsWith('button[')) return stop ? [button] : [];
      if (sel.startsWith('[data-message-author-role="assistant"]')) return assistant ? [answer] : [];
      if (sel.startsWith('main .markdown')) return [];
      if (sel.startsWith('[role="alert"]')) return error ? [alert] : [];
      return [];
    },
    addEventListener(type, cb) {handlers[type] = cb;}
  };
  const window={addEventListener(type, cb){handlers['window:'+type]=cb;}};
  const chrome = {runtime: {
    sendMessage: async msg => {out.push(msg);return {ok:true};},
    onMessage: {addListener: cb => handlers.message = cb}
  }};
  class MutationObserver {constructor(fn) {observer = fn;} observe() {}}
  vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, '../content.js'), 'utf8'), {
    document, window, chrome, MutationObserver, Element: FakeElement, performance, Date,
    location: {hostname: 'chatgpt.com', pathname: '/c/1234567890', href:'https://chatgpt.com/c/1234567890', origin:'https://chatgpt.com'},
    setTimeout, clearTimeout, setInterval: () => 1, clearInterval: () => {},
    console, Math
  });
  function update() {observer([{type:'characterData',target:body,addedNodes:[]}]);}
  return {
    out, answer, body, mainNode, button,
    start() {stop = true; update();},
    stop() {stop = false; update();},
    fail() {error = true; update();},
    change(text) {body.textContent = text; if (mainNode) mainNode.textContent = text; if (assistant) answer.textContent = text; update();},
    cancel() {handlers.pointerdown({target:button}); stop = false; update();},
    probe() {let result; handlers.message({type:'PROBE_CONTENT'}, {}, x=>{result=x;});return result;}
  };
}
const wait = ms => new Promise(resolve => setTimeout(resolve,ms));
const completions = app => app.out.filter(x => x.type === 'COMPLETE');
async function run(name, setup, shouldComplete, expectedEvidence) {
  const app = launch(setup);
  app.start();
  await wait(700); // enough Stop observation to count as a real cycle
  if (name === 'assistant DOM') app.change('Question from the user - Assistant has replied');
  if (name === 'generic page text fallback') app.change('Question from the user - streamed response with unrecognized markup');
  if (name === 'assistant DOM' || name === 'generic page text fallback') await wait(220);
  if (name === 'manual stop') app.cancel();
  else if (name === 'error suppresses') {app.fail(); app.stop();}
  else app.stop();
  await wait(1520);
  assert.equal(completions(app).length, shouldComplete ? 1 : 0, name);
  if (expectedEvidence) assert.match(completions(app)[0].evidence, expectedEvidence, name + ' evidence');
  if (name === 'assistant DOM') assert.equal(completions(app)[0].chatTitle, 'JARVIS Stage 4', 'chat title metadata');
  console.log(`PASS ${name}`);
}
(async () => {
  let app = launch();
  await wait(170);
  assert.equal(completions(app).length,0,'idle must not notify');
  assert.equal(app.probe().phase,'idle');
  console.log('PASS idle page must not notify');
  await run('assistant DOM',{assistant:true,title:'JARVIS Stage 4 - ChatGPT'},true,/回答要素の更新/);
  await run('generic page text fallback',{},true,/ページ本文の更新/);
  await run('Stop-only transition fallback',{},true,/停止ボタンの遷移/);
  await run('manual stop',{},false);
  await run('error suppresses',{},false);
  console.log('PASS v0.3 detection regression preserved in v1.1 Lite');
})().catch(e => {console.error(e);process.exitCode = 1;});
