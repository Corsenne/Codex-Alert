import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
test('G4C3 lifecycle does not change Chrome or native registration',()=>{
 const s=read('tools/G4C3-Lifecycle.ps1');
 assert.match(s,/G4C3_PRODUCT_MUTATION=NONE/);
 assert.match(s,/Mode='Guided'/);
 assert.match(s,/Get-CimInstance -ClassName Win32_Process/);
 assert.match(s,/com\.corsenne\.finish_alert_g4c2_test/);
 assert.match(s,/G4C3_NATIVE_HOST_REGISTRATION=/);
 assert.match(s,/G4C3_SNAPSHOT_PASS_NO_MUTATION/);
 assert.match(s,/G4C_PRODUCT_CUTOVER=HOLD/);
 assert.doesNotMatch(s,/^\s*(?:Stop-Process|Start-Process|Remove-Item|Set-Item|New-Item|Set-Content|Add-Content|Set-ItemProperty|Remove-ItemProperty|Start-Job|Register-ScheduledTask)\b/gm);
 assert.doesNotMatch(s,/\.Kill\(|chrome\.exe.*\/F|taskkill/i);
});
test('G4C3 guided gate checks five replies, Chrome-zero, retirement and reopened recovery',()=>{
 const s=read('tools/G4C3-Lifecycle.ps1');
 assert.match(s,/for\(\$i=1;\$i -le 5;\$i\+\+\)/);
 assert.match(s,/G4C3_MULTI_BRIDGE_BASELINE_HOLD/);
 assert.match(s,/G4C3_BRIDGE_GROWTH_HOLD_AT_REPLY_/);
 assert.match(s,/G4C3_CHROME_BACKGROUND_STILL_RUNNING_HOLD/);
 assert.match(s,/Start-Sleep -Seconds 120/);
 assert.match(s,/G4C3_BRIDGE_NOT_RETIRED_AFTER_CHROME_EXIT_HOLD/);
 assert.match(s,/G4C3_REOPENED_NOTIFICATION_PASS/);
 assert.match(s,/G4C3_LONG_SOAK=HOLD/);
});
test('G4C3 process identity and registration preflight are strict',()=>{
 const s=read('tools/G4C3-Lifecycle.ps1');
 assert.match(s,/function Verify-IsolatedHost/);
 assert.match(s,/allowed_origins/);
 assert.match(s,/G4C3_BRIDGE_IDENTITY_HOLD_AT_/);
 assert.match(s,/G4C3_G4_DESKTOP_IDENTITY_HOLD_AT_/);
 assert.match(s,/G4C3_STABLE_PRODUCT_ACTIVE_AT_/);
 assert.match(s,/Get-Item -LiteralPath \$key/);
 assert.match(s,/G4C3_CHROME_REOPENED_EARLY_HOLD/);
});
test('G4C3 launcher and read-only snapshot use the same code',()=>{
 const cmd=read('G4C3-Lifecycle.cmd');
 const snap=read('G4C3-Snapshot.cmd');
 assert.match(cmd,/-File "%~dp0tools\\G4C3-Lifecycle\.ps1"/);
 assert.match(snap,/G4C3-Lifecycle\.cmd" snapshot/);
 assert.doesNotMatch(cmd,/G4C1C-Cleanup|G4C2-Register|G4C2-Start/);
});
