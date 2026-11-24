import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
test('G4C1C preview is default, mutation only in explicit cleanup gate',()=>{
 const s=read('tools/G4C1C-Bridge-Cleanup.ps1');
 assert.match(s,/Mode='Preview'/);
 assert.match(s,/if\(\$Mode -eq 'Preview'\)/);
 assert.match(s,/G4C1C_PREVIEW_PASS_NO_MUTATION/);
 assert.match(s,/Read-Host.*CLEANUP/);
 assert.match(s,/if\(\$snap\.chrome -ne 0\)/);
 assert.match(s,/G4C1C_NOT_ALL_BRIDGES_SAFE_ABORT/);
 assert.match(s,/G4C1C_CHROME_RESTARTED_ABORT/);
 assert.match(s,/G4C1C_NATIVE_HOST_CHANGED_ABORT/);
 assert.match(s,/G4C1C_PROCESS_IDENTITY_CHANGED_ABORT/);
 assert.match(s,/G4C1C_OPEN_HANDLE_MISMATCH_ABORT/);
 assert.match(s,/\.MainModule\.FileName/);
 assert.match(s,/\.StartTime\.ToUniversalTime\(\)/);
 assert.match(s,/\.Kill\(\)/);
 assert.doesNotMatch(s,/Stop-Process|taskkill|chrome\.exe.*Kill\(/i);
});
test('G4C1C requires matching registered executable and local user ownership',()=>{
 const s=read('tools/G4C1C-Bridge-Cleanup.ps1');
 assert.match(s,/com\.corsenne\.finish_alert/);
 assert.match(s,/LOCALAPPDATA/);
 assert.match(s,/finish-alert-bridge\.exe/);
 assert.match(s,/GetOwner/);
 assert.match(s,/sameSession/);
 assert.match(s,/parentState -in @\('missing','pid-reused'\)/);
});
test('G4C1C scripts are separate explicit modes',()=>{
 const p=read('G4C1C-Preview.cmd'), c=read('G4C1C-Cleanup.cmd');
 assert.match(p,/-Mode Preview/);
 assert.match(c,/-Mode Cleanup/);
 assert.match(p,/tools\\G4C1C-Bridge-Cleanup\.ps1/);
 assert.match(c,/tools\\G4C1C-Bridge-Cleanup\.ps1/);
});
