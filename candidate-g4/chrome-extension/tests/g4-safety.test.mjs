import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const get=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
test('G4 test Chrome extension never monitors real replies',()=>{
 const m=JSON.parse(get('manifest.json'));
 assert.ok(m.name.includes('NO MONITORING'));
 assert.equal(m.content_scripts,undefined);
 const bg=get('background.js');
 assert.match(bg,/finish_alert_g4_test/);
 assert.match(bg,/notification.closed/);
 assert.match(bg,/notification.open/);
 assert.doesNotMatch(bg,/MutationObserver/);
 assert.doesNotMatch(bg,/type:'COMPLETE'/);
});
