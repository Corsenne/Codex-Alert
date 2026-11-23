# Start only G4B isolated test desktop; no production action.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4Test'
$exe=Join-Path $root 'desktop\src-tauri\target\debug\finish-alert-g4-test.exe'
$voice=Join-Path $root 'private\private-leo.wav'
$trace=Join-Path $root 'G4B_STAGE_TRACE.txt'
try{
 if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'G4B_TEST_DESKTOP_NOT_BUILT'}
 if(-not(Test-Path -LiteralPath $voice -PathType Leaf)){throw 'G4B_PRIVATE_VOICE_MISSING'}
 if(@(Get-Process 'finish-alert-g4-test' -ErrorAction SilentlyContinue).Count -gt 0){
     throw 'G4B_TEST_APP_ALREADY_RUNNING'
 }
 if(Test-Path -LiteralPath $trace){Remove-Item -LiteralPath $trace -Force}
 $env:FINISH_ALERT_G2B_TRACE=$trace
 $env:FINISH_ALERT_G2B_PRIVATE_WAV=$voice
 $process=Start-Process -FilePath $exe -PassThru
 $ready=$false;$until=(Get-Date).AddSeconds(30)
 while((Get-Date) -lt $until){
   if($process.HasExited){throw 'G4B_TEST_APP_EXITED_EARLY'}
   if(Test-Path -LiteralPath $trace){
      if(@(Get-Content -LiteralPath $trace -ErrorAction SilentlyContinue) -contains 'G2B_UI_READY_PASS'){
        $ready=$true;break
      }
   }
   Start-Sleep -Milliseconds 250
 }
 if(-not $ready){throw 'G4B_UI_BOOTSTRAP_HOLD'}
 Write-Host 'G4B_ISOLATED_UI_READY_PASS'
 Write-Host 'Open a saved ChatGPT conversation, use the separate G4 NO MONITORING test extension popup.'
 Write-Host 'For mixed FIFO, stage G4B-Codex-Test.cmd, send Chrome test event, then press ENTER to queue Codex.'
 Write-Host 'Run G4B-Cleanup.cmd after testing. It stops only G4B processes and removes only the G4B HKCU test host.'
}catch{
 Write-Host ('G4B_START_HOLD: '+$_.Exception.Message)
 if(Test-Path -LiteralPath $trace){
     Write-Host 'Stage-only trace:'
     Get-Content -LiteralPath $trace -Tail 30
 }
 exit 2
}finally{
 Remove-Item Env:\FINISH_ALERT_G2B_TRACE -ErrorAction SilentlyContinue
 Remove-Item Env:\FINISH_ALERT_G2B_PRIVATE_WAV -ErrorAction SilentlyContinue
}
