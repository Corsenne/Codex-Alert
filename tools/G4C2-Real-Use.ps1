# G4C2 visual real-use acceptance; independent of installed stable observer.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
try{
  $desktop=@(Get-Process -Name 'finish-alert-g4-test' -ErrorAction SilentlyContinue)
  if($desktop.Count -ne 1){throw 'G4C2_TEST_DESKTOP_NOT_UNIQUE'}
  if(@(Get-Process finish-alert-desktop,finish-alert-bridge -ErrorAction SilentlyContinue).Count -gt 0){
    throw 'G4C2_STABLE_NATIVE_APP_RUNNING'
  }
  Write-Host 'G4C2_REAL_COMPLETION_VISUAL_GATE'
  Write-Host 'Stable Finish Alert v1.1.5 is OFF; G4B manual test OFF; G4C2 real observer ON.'
  Write-Host 'Only request a new REAL ChatGPT reply on a saved /c/ conversation.'
  for($i=1;$i -le 3;$i++){
    $answer=([string](Read-Host ('G4C2 real reply '+$i+': one banner, one voice, click stops sound, exact chat restored? PASS/FAIL/STOP'))).Trim().ToUpperInvariant()
    if($answer -eq 'STOP'){Write-Host 'G4C2_USER_STOP_NO_MUTATION';exit 0}
    if($answer -ne 'PASS'){Write-Host ('G4C2_REAL_REPLY_'+$i+'_HOLD');exit 2}
    Write-Host ('G4C2_REAL_REPLY_'+$i+'_PASS')
  }
  Write-Host 'G4C2_REAL_COMPLETION_3_OF_3_USER_PASS'
  Write-Host 'G4C2_PRODUCT_RELEASE=HOLD'
}catch{
  Write-Host ('G4C2_VISUAL_GATE_HOLD='+$_.Exception.Message)
  exit 2
}
