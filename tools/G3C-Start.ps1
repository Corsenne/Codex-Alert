# Start only G3C isolated test desktop; no production action.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G3CTest'
$exe=Join-Path $root 'desktop\src-tauri\target\debug\finish-alert-g3c-test.exe'
$voice=Join-Path $root 'private\private-leo.wav'
$trace=Join-Path $root 'G3C_STAGE_TRACE.txt'
try{
 if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'G3C_TEST_DESKTOP_NOT_BUILT'}
 if(-not(Test-Path -LiteralPath $voice -PathType Leaf)){throw 'G3C_PRIVATE_VOICE_MISSING'}
 if(@(Get-Process 'finish-alert-g3c-test' -ErrorAction SilentlyContinue).Count -gt 0){
     throw 'G3C_TEST_APP_ALREADY_RUNNING'
 }
 if(Test-Path -LiteralPath $trace){Remove-Item -LiteralPath $trace -Force}
 $env:FINISH_ALERT_G2B_TRACE=$trace
 $env:FINISH_ALERT_G2B_PRIVATE_WAV=$voice
 $process=Start-Process -FilePath $exe -PassThru
 $ready=$false;$until=(Get-Date).AddSeconds(30)
 while((Get-Date) -lt $until){
   if($process.HasExited){throw 'G3C_TEST_APP_EXITED_EARLY'}
   if(Test-Path -LiteralPath $trace){
      if(@(Get-Content -LiteralPath $trace -ErrorAction SilentlyContinue) -contains 'G2B_UI_READY_PASS'){
        $ready=$true;break
      }
   }
   Start-Sleep -Milliseconds 250
 }
 if(-not $ready){throw 'G3C_UI_BOOTSTRAP_HOLD'}
 Write-Host 'G3C_ISOLATED_UI_READY_PASS'
 Write-Host 'Open a ChatGPT conversation, use the G3C TEST extension button to send 1 manual banner.'
 Write-Host 'Click the banner while the female voice is playing, and confirm the exact chat tab is focused.'
 Write-Host 'Run G3C-Cleanup.cmd after testing. It stops only G3C processes and removes only the G3C HKCU test host.'
}catch{
 Write-Host ('G3C_START_HOLD: '+$_.Exception.Message)
 if(Test-Path -LiteralPath $trace){
     Write-Host 'Stage-only trace:'
     Get-Content -LiteralPath $trace -Tail 30
 }
 exit 2
}finally{
 Remove-Item Env:\FINISH_ALERT_G2B_TRACE -ErrorAction SilentlyContinue
 Remove-Item Env:\FINISH_ALERT_G2B_PRIVATE_WAV -ErrorAction SilentlyContinue
}
