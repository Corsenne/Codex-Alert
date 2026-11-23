import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const read = file => readFileSync(new URL('../../'+file,import.meta.url),'utf8');
test('G4C1 is an inventory and never mutates product settings or processes',()=>{
  const s=read('tools/G4C1-Inspect.ps1');
  assert.match(s,/G4C1_READONLY_INSPECTION_COMPLETE/);
  assert.match(s,/product_mutation='NONE'/);
  assert.match(s,/production_cutover='HOLD'/);
  assert.match(s,/Inspect-Codex/);
  assert.match(s,/Inspect-ChromeNativeHosts/);
  assert.match(s,/Inspect-AlertProcesses/);
  assert.doesNotMatch(s,/^\s*(?:Set-Item|New-Item|Remove-Item|Stop-Process|Start-Process|Set-ItemProperty|Remove-ItemProperty|Copy-Item|Move-Item|git\s+(?:merge|pull|push))\b/gm);
});
test('G4C1 never prints raw Chrome origins, hook commands, or conversation content',()=>{
  const s=read('tools/G4C1-Inspect.ps1');
  assert.match(s,/allowed_origins=\$originCount/);
  assert.match(s,/coverage='user_config_only_not_system_project_plugin_hooks'/);
  assert.match(s,/chrome_extension_active_state='NOT_VERIFIED_BY_READONLY_AUDIT'/);
  assert.match(s,/native_bridge_soak='NOT_YET_TESTED'/);
  assert.doesNotMatch(s,/\$m\.allowed_origins\s*\|\s*ConvertTo-Json/);
  assert.doesNotMatch(s,/(?<!\$)\$commands\s*\|\s*Write-Host/);
});
test('G4C1 script has a non-mutating double-click wrapper',()=>{
  const s=read('G4C1-Inspect.cmd');
  assert.match(s,/tools\\G4C1-Inspect\.ps1/);
  assert.match(s,/G4C1_INSPECTION_DRIVER_COMPLETE/);
});
