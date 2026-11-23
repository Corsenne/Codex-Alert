import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
test('G4C2R only reads allowlisted stage names from known local trace files',()=>{
 const x=read('tools/G4C2R-Inspect.ps1');
 assert.match(x,/G4C2R_MODE=READ_ONLY_OFFLINE/);
 assert.match(x,/G4C2R_PRODUCT_MUTATION=NONE/);
 assert.match(x,/G4B_STAGE_TRACE\.txt/);
 assert.match(x,/G4C2_STAGE_TRACE\.txt/);
 assert.match(x,/Get-Content -LiteralPath \$file -Encoding UTF8 -Tail 512/);
 assert.match(x,/allowSet\.ContainsKey/);
 assert.match(x,/G4C2R_UNRECOGNIZED_LINES/);
 assert.match(x,/G4C2R_TIMING_NOT_VERIFIABLE_NO_STAGE_TIMESTAMPS/);
 assert.match(x,/G4C2R_ROOT_CAUSE=HOLD/);
 assert.doesNotMatch(x,/^\s*(?:Stop-Process|Start-Process|Remove-Item|Set-Item|New-Item|Set-Content|Add-Content)\b/gm);
});
test('G4C2R CMD runs only offline reader',()=>{
 const x=read('G4C2R-Inspect.cmd');
 assert.match(x,/G4C2R-Inspect\.ps1/);
 assert.doesNotMatch(x,/G4C2-Start|G4C2-Register|G4C2-Real-Use/);
});
