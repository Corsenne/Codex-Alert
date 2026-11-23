import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
test('G4C3R inspect mode prints safe process categories, never raw Chrome commands',()=>{
 const s=read('tools/G4C3-Resume.ps1');
 assert.match(s,/Mode='Inspect'/);
 assert.match(s,/G4C3R_PRODUCT_MUTATION=NONE/);
 assert.match(s,/Get-CimInstance Win32_Process/);
 assert.match(s,/G4C3R_BACKGROUND_INSPECT_PASS_NO_MUTATION/);
 assert.match(s,/G4C3R_BACKGROUND_CAUSE_NOT_PROVEN/);
 assert.match(s,/G4C3R_.*CHROME_PID_TYPE_PARENT/);
 assert.match(s,/--type=/);
 assert.doesNotMatch(s,/Write-Host\s*\$command|Write-Output\s*\$command/);
 assert.doesNotMatch(s,/^\s*(?:Stop-Process|Start-Process|Remove-Item|Set-Item|New-Item|Set-Content|Add-Content|Set-ItemProperty|Remove-ItemProperty)\b/gm);
 assert.doesNotMatch(s,/\.Kill\(|taskkill/i);
});
test('G4C3R resume only accepts Chrome zero and verifies retirement+reopen',()=>{
 const s=read('tools/G4C3-Resume.ps1');
 assert.match(s,/G4C3R_CHROME_ZERO_REQUIRED/);
 assert.match(s,/Start-Sleep -Seconds 120/);
 assert.match(s,/G4C3R_BRIDGE_RETIREMENT_PASS/);
 assert.match(s,/G4C3R_BRIDGE_DID_NOT_RETIRE_HOLD/);
 assert.match(s,/G4C3R_REOPENED_REAL_NOTIFICATION_PASS/);
 assert.match(s,/G4C3R_PREVIOUS_FIVE_REPLIES=USER_REPORTED_PASS_NOT_RETESTED/);
 assert.match(s,/G4C_PRODUCT_CUTOVER=HOLD/);
 assert.doesNotMatch(s,/for\(\$i=1;\$i -le 5/);
});
test('G4C3R isolated identities and stop action',()=>{
 const s=read('tools/G4C3-Resume.ps1');
 assert.match(s,/function Verify-G4C2Registration/);
 assert.match(s,/allowed_origins/);
 assert.match(s,/G4C3R_G4_DESKTOP_IDENTITY_HOLD/);
 assert.match(s,/G4C3R_ISOLATED_BRIDGE_IDENTITY_OR_GROWTH_HOLD/);
 assert.match(s,/G4C3R_OPERATOR_STOP_NO_MUTATION/);
});
test('G4C3R separate inspect/continue launchers',()=>{
 const a=read('G4C3-Background-Inspect.cmd');
 const b=read('G4C3-Resume.cmd');
 assert.match(a,/-Mode Inspect/);
 assert.match(b,/-Mode Resume/);
 assert.doesNotMatch(a,/G4C3-Lifecycle\.cmd|G4C2-Register/);
});
