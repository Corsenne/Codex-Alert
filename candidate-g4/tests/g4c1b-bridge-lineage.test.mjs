import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const load = name => readFileSync(new URL('../../'+name,import.meta.url),'utf8');
test('G4C1B does not mutate product or process state',()=>{
  const ps=load('tools/G4C1B-Bridge-Lineage.ps1');
  assert.match(ps,/inspection='READ_ONLY'/);
  assert.match(ps,/mutation='NONE'/);
  assert.match(ps,/cutover='HOLD'/);
  assert.match(ps,/G4C1B_READONLY_BRIDGE_DIAGNOSTIC_PASS/);
  assert.doesNotMatch(ps,/^\s*(Stop-Process|Kill|Remove-Item|Set-Item|New-Item|Set-ItemProperty|Unregister-|Start-Process|Invoke-WebRequest|git\s+push)\b/gmi);
});
test('G4C1B redacts paths, extension IDs, and command lines',()=>{
  const ps=load('tools/G4C1B-Bridge-Lineage.ps1');
  assert.match(ps,/executable_class=\$exeClassification/);
  assert.match(ps,/chrome_port_connection='NOT_VERIFIED'/);
  assert.match(ps,/parent_state=\$parentState/);
  assert.match(ps,/registered_bridge_manifest=\$/);
  assert.doesNotMatch(ps,/command_line\s*=\s*\$child\.CommandLine/i);
  assert.doesNotMatch(ps,/executable_path\s*=\s*\$actualPath/i);
  assert.doesNotMatch(ps,/Write-Host\s+\$actualPath/);
});
test('G4C1B wrapper runs isolated inspection without mutating anything',()=>{
  const script=load('G4C1B-Bridge-Lineage.cmd');
  assert.match(script,/tools\\G4C1B-Bridge-Lineage\.ps1/);
  assert.match(script,/G4C1B_BRIDGE_LINEAGE_DRIVER_COMPLETE/);
});
