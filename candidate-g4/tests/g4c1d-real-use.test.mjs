import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
test('G4C1D is manual real-reply instrumentation, never auto-generates a reply',()=>{
 const source=read('tools/G4C1D-Real-Use.ps1');
 assert.match(source,/Mode='Manual'/);
 assert.match(source,/G4C1D_PRODUCT_MUTATION=NONE/);
 assert.match(source,/Get-CimInstance -ClassName Win32_Process/);
 assert.match(source,/G4C1D_SAMPLES_COLLECTED_PASS/);
 assert.match(source,/G4C1D_IDLE_RETIREMENT_NOT_TESTED/);
 assert.match(source,/Read-Host.*REAL ChatGPT reply/);
 assert.doesNotMatch(source,/^\s*(?:Stop-Process|New-Item|Set-Item|Remove-Item|Start-Process|Invoke-WebRequest|curl|git\s+push)\b/gm);
});
test('G4C1D separates snapshot only from manual run',()=>{
 const source=read('tools/G4C1D-Real-Use.ps1');
 const snap=read('G4C1D-Snapshot.cmd');
 const manual=read('G4C1D-Real-Use.cmd');
 assert.match(source,/if\(\$Mode -eq 'Snapshot'\)/);
 assert.match(snap,/-Mode Snapshot/);
 assert.match(manual,/-Mode Manual/);
 assert.match(source,/bridge_processes/);
 assert.match(source,/identity=/);
});
