import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
test('G4C2 observer matches the pinned G2A detection candidate byte-for-byte',()=>{
 const a=read('candidate-g4c2/chrome-extension/content.js');
 const b=read('candidate-g2a/chrome-extension/content.js');
 assert.equal(a,b);
 assert.match(a,/send\('COMPLETE', \{cycleId: id, evidence, chatTitle: getChatTitle\(\)\}\)/);
 assert.match(a,/manualStopLock/);
 assert.match(a,/ERROR_WORDS/);
});
test('Only isolated G4C2 extension receives real content COMPLETE',()=>{
 const m=JSON.parse(read('candidate-g4c2/chrome-extension/manifest.json'));
 assert.equal(m.manifest_version,3);
 assert.equal(m.background.service_worker,'background.js');
 assert.deepEqual(m.content_scripts[0].matches,['https://chatgpt.com/*','https://chat.openai.com/*']);
 assert.equal(m.content_scripts[0].run_at,'document_idle');
 assert.match(m.name,/ISOLATED/);
 const bg=read('candidate-g4c2/chrome-extension/background.js');
 assert.match(bg,/const HOST='com\.corsenne\.finish_alert_g4c2_test'/);
 assert.match(bg,/m\?\.type!=='COMPLETE'/);
 assert.match(bg,/sender\?\.id!==chrome\.runtime\.id/);
 assert.match(bg,/sender\.documentId/);
 assert.match(bg,/claimCycle/);
 assert.match(bg,/scheduleIdleClose/);
 assert.match(bg,/audioOwner:'desktop'/);
 assert.doesNotMatch(bg,/chrome\.notifications\.create|offscreen\.html|PLAY_SOUND|chrome\.tabs\.create\(\{url:'https:\/\/chatgpt\.com\/'\}\)/);
});
