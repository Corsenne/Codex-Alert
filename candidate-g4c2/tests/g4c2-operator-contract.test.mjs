import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
test('G4C2 native host installation is isolated, gated and uses accepted G4 bridge bytes',()=>{
 const x=read('tools/G4C2-Register.ps1');
 assert.match(x,/com\.corsenne\.finish_alert_g4c2_test/);
 assert.match(x,/G4C2_REGISTRATION_ALREADY_EXISTS_NO_OVERWRITE/);
 assert.match(x,/G4C2_STABLE_NATIVE_PROCESSES_STILL_RUNNING/);
 assert.match(x,/STABLE_OFF/);
 assert.match(x,/G4B_OFF/);
 assert.match(x,/Copy-Item -LiteralPath \$source -Destination \$exe/);
 assert.match(x,/Get-Sha256Hex/);
 assert.match(x,/System\.Security\.Cryptography\.SHA256/);
 assert.match(x,/System\.IO\.File\]::OpenRead/);
 assert.match(x,/G4C2_EXISTING_IDENTICAL_TEST_BRIDGE_REUSED/);
 assert.match(x,/G4C2_TEST_BRIDGE_SHA256_VERIFIED/);
 assert.doesNotMatch(x,/^\s*(?!#).*Get-FileHash\s+-LiteralPath/m);
 assert.match(x,/allowed_origins/);
 assert.doesNotMatch(x,/finish_alert_v2_|hooks\.json|codex-alert\.ps1/);
});
test('G4C2 start reuses only exact approved isolated G4 executable',()=>{
 const x=read('tools/G4C2-Start.ps1');
 assert.match(x,/finish-alert-g4-test\.exe/);
 assert.match(x,/G4C2_G4_DESKTOP_REUSED_PASS/);
 assert.match(x,/G4C2_G4_DESKTOP_READY_PASS/);
 assert.match(x,/G4C2_PRODUCTION_NATIVE_APP_STILL_RUNNING/);
});
test('G4C2 cleanup does not kill or overwrite product',()=>{
 const x=read('tools/G4C2-Cleanup.ps1');
 assert.match(x,/G4C2_CHROME_MUST_BE_CLOSED_TO_CLEANUP/);
 assert.match(x,/G4C2_BRIDGE_STILL_RUNNING_NO_TERMINATION/);
 assert.match(x,/G4C2_TEST_HOST_CLEANUP_PASS/);
 assert.doesNotMatch(x,/Stop-Process|\.Kill\(|finish_alert_v2_/);
});
test('G4C2 real-use gate requires all three user PASS checks',()=>{
 const x=read('tools/G4C2-Real-Use.ps1');
 assert.match(x,/for\(\$i=1;\$i -le 3;\$i\+\+\)/);
 assert.match(x,/G4C2_REAL_COMPLETION_3_OF_3_USER_PASS/);
 assert.match(x,/G4C2_PRODUCT_RELEASE=HOLD/);
 assert.match(x,/G4C2_NATIVE_HOST_NOT_REGISTERED/);
 assert.match(x,/G4C2_NATIVE_HOST_PREFLIGHT_PASS/);
 assert.match(x,/G4C2_NATIVE_HOST_CONFIGURATION_MISMATCH/);
 assert.match(x,/expectedManifest/);
});
