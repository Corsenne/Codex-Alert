import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const root = new URL('../../',import.meta.url);
const read = path => readFileSync(new URL(path,root),'utf8');
test('G4B operator scripts register only isolated native host',()=>{
  const r=read('tools/G4B-Register.ps1');
  assert.match(r,/com\.corsenne\.finish_alert_g4_test/);
  assert.match(r,/G4B_TEST_REGISTRATION_ALREADY_EXISTS_NO_OVERWRITE/);
  assert.match(r,/Finish Alert G4 Manual Test \(NO MONITORING\)/);
  assert.match(r,/content_scripts/);
  assert.match(r,/allowed_origins/);
  assert.doesNotMatch(r,/finish_alert_v2|finish_alert_g3c_test/);
});
test('G4B start and cleanup touch G4 test paths only',()=>{
  const start=read('tools/G4B-Start.ps1');
  const cleanup=read('tools/G4B-Cleanup.ps1');
  assert.match(start,/CodexAlertDev\\G4Test/);
  assert.match(start,/finish-alert-g4-test\.exe/);
  assert.match(cleanup,/com\.corsenne\.finish_alert_g4_test/);
  assert.match(cleanup,/G4B_REGISTRATION_CHANGED_NO_MUTATION/);
  assert.match(cleanup,/Stop-Process/);
  assert.doesNotMatch(start+cleanup,/CodexAlertDev\\G3CTest|finish_alert_v2/);
});
test('G4B synthetic Codex runner cannot open real threads',()=>{
  const sender=read('tools/G4B-Codex-Test.ps1');
  assert.match(sender,/corsenne_finish_alert_g4_test_/);
  assert.match(sender,/openTarget=\$null/);
  assert.match(sender,/source='codex'/);
  assert.match(sender,/G4B_CODEX_SYNTHETIC_ACK_PASS/);
  assert.doesNotMatch(sender,/codex:\/\/threads\/|hooks\.json|Stop-Process/);
});
test('G4B command wrappers call dedicated scripts',()=>{
  for(const name of ['Register','Start','Cleanup','Codex-Test']){
    const script=read('G4B-'+name+'.cmd');
    assert.match(script,new RegExp('tools\\\\G4B-'+name+'\\.ps1','i'));
  }
});
