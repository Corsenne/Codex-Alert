import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
test('G4C2 diagnostic popup is read-only and exposes both detection and native delivery',()=>{
 const bg=read('candidate-g4c2/chrome-extension/background.js');
 const popup=read('candidate-g4c2/chrome-extension/popup.js');
 const page=read('candidate-g4c2/chrome-extension/popup.html');
 assert.match(bg,/const DIAG='g4c2_metadata_diagnostic'/);
 assert.match(bg,/received:Math\.min\(1000/);
 assert.match(bg,/accepted:Math\.min\(1000/);
 assert.match(bg,/lastResult:result/);
 assert.match(bg,/m\?\.type==='G4C2_STATUS'/);
 assert.match(popup,/G4C2_STATUS/);
 assert.match(popup,/PROBE_CONTENT/);
 assert.match(popup,/chrome\.tabs\.sendMessage/);
 assert.match(page,/再取得（読み取り専用）/);
 assert.doesNotMatch(popup,/chrome\.storage\.session\.set|chrome\.runtime\.connectNative|chrome\.tabs\.create/);
});
