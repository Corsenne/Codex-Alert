import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const files=(name)=>readFileSync(new URL('../'+name,import.meta.url),'utf8');
test('test extension has no ChatGPT completion monitor or content scripts',()=>{
 const manifest=JSON.parse(files('manifest.json'));
 assert.ok(manifest.name.includes('NO MONITORING'));
 assert.equal(manifest.content_scripts,undefined);
 assert.deepEqual(manifest.permissions.sort(),['nativeMessaging','tabs','windows','storage'].sort());
});
test('test worker can only restore exactly identified ChatGPT conversations',()=>{
 const code=files('background.js');
 assert.match(code,/const HOST='com\.corsenne\.finish_alert_g4_test'/);
 assert.match(code,/const url=exactUrl\(record.url\)/);
 assert.match(code,/exactUrl\(candidate.url\)===url/);
 assert.match(code,/chrome\.windows\.update\(tab.windowId,\{focused:true\}\)/);
 assert.match(code,/chrome\.tabs\.update\(tab.id,\{active:true\}\)/);
 assert.match(code,/chrome\.tabs\.create\(\{url\}\)/);
 assert.doesNotMatch(code,/chrome\.tabs\.create\(\{url:'https:\/\/chatgpt.com\/'\}\)/);
});
