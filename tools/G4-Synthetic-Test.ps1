# Isolated G4A FIFO + audio test. No Chrome extension registration, no live Codex Hook.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4Test'
$exe=Join-Path $root 'desktop\src-tauri\target\debug\finish-alert-g4-test.exe'
$voice=Join-Path $root 'private\private-leo.wav'
$trace=Join-Path $root 'G4_STAGE_TRACE.txt'
$repo=Split-Path -Parent $PSScriptRoot
$launched=$null
try{
 if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'G4_TEST_BINARY_NOT_BUILT'}
 if(-not(Test-Path -LiteralPath $voice -PathType Leaf)){throw 'G4_PRIVATE_LEO_MISSING'}
 if(@(Get-Process 'finish-alert-g4-test' -ErrorAction SilentlyContinue).Count -gt 0){
    throw 'G4_TEST_APP_ALREADY_RUNNING_CLOSE_TEST_INSTANCE'
 }
 if(Test-Path -LiteralPath $trace){Remove-Item -LiteralPath $trace -Force}
 $env:FINISH_ALERT_G2B_TRACE=$trace
 $env:FINISH_ALERT_G2B_PRIVATE_WAV=$voice
 # No validated Codex deep link is supplied in this FIFO-only scenario.
 Remove-Item Env:\FINISH_ALERT_G4_ALLOWED_CODEX_LINK -ErrorAction SilentlyContinue
 $launched=Start-Process -FilePath $exe -PassThru
 $until=(Get-Date).AddSeconds(30);$ready=$false
 while((Get-Date) -lt $until){
   if($launched.HasExited){throw 'G4_TEST_APP_EXITED_EARLY'}
   if(Test-Path -LiteralPath $trace){
      if(@(Get-Content -LiteralPath $trace -ErrorAction SilentlyContinue) -contains 'G2B_UI_READY_PASS'){
        $ready=$true;break
      }
   }
   Start-Sleep -Milliseconds 250
 }
 if(-not $ready){throw 'G4_TEST_UI_BOOTSTRAP_HOLD'}
 Write-Host 'G4_TEST_UI_READY_PASS'
 Write-Host 'This is a synthetic mixed-source queue test. Click does NOT open real chats.'
 $null=Read-Host 'Press ENTER to send 3 mixed ChatGPT/Codex alerts'
 & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'candidate-g4\scripts\Send-G4-Mixed.ps1')
 if($LASTEXITCODE -ne 0){throw 'G4_TEST_SENDER_FAILED'}
 Write-Host 'Check one banner at a time: CODEX -> CHATGPT -> CODEX, no sound overlap.'
 Write-Host 'Click a banner while voice plays: current voice should stop and next event should appear.'
 Start-Sleep -Seconds 28
 Write-Host 'G4_SYNTHETIC_VISUAL_AUDIO_USER_CONFIRMATION_REQUIRED'
}catch{
 Write-Host ('G4_SYNTHETIC_TEST_HOLD: '+$_.Exception.Message)
 if(Test-Path -LiteralPath $trace){
   Write-Host 'Stage-only trace:'
   Get-Content -LiteralPath $trace -Tail 40
 }
 exit 2
}finally{
 if($null -ne $launched){
    try{
      $p=Get-Process -Id $launched.Id -ErrorAction SilentlyContinue
      if($p -and $p.Path -and [IO.Path]::GetFullPath($p.Path) -ieq [IO.Path]::GetFullPath($exe)){
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
      }
    }catch{}
 }
 Remove-Item Env:\FINISH_ALERT_G2B_TRACE -ErrorAction SilentlyContinue
 Remove-Item Env:\FINISH_ALERT_G2B_PRIVATE_WAV -ErrorAction SilentlyContinue
}
