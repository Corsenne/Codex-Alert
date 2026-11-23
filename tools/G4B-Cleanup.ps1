# Roll back only G4B isolated test registry and processes.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$key='HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.corsenne.finish_alert_g4_test'
$work=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4Test'
$expected=Join-Path $work 'bin\com.corsenne.finish_alert_g4_test.json'
$testExe=Join-Path $work 'desktop\src-tauri\target\debug\finish-alert-g4-test.exe'
$bridgeExe=Join-Path $work 'bin\finish-alert-g4-bridge.exe'
try{
 if(Test-Path -LiteralPath $key){
     $actual=(Get-Item -LiteralPath $key).GetValue('')
     if([string]$actual -ine $expected){throw 'G4B_REGISTRATION_CHANGED_NO_MUTATION'}
 }
 $approval=Read-Host 'Type CLEANUP to remove ONLY G4B test registration/processes (anything else cancels)'
 if($approval -cne 'CLEANUP'){Write-Host 'G4B_CLEANUP_CANCELLED';exit 0}
 if(Test-Path -LiteralPath $key){Remove-Item -LiteralPath $key -Recurse -Force}
 $stopped=0
 foreach($name in @('finish-alert-g4-test','finish-alert-g4-bridge')){
     foreach($p in @(Get-Process -Name $name -ErrorAction SilentlyContinue)){
         $expectedExe=if($name -eq 'finish-alert-g4-test'){$testExe}else{$bridgeExe}
         try {
            if($p.Path -and [IO.Path]::GetFullPath($p.Path) -ieq [IO.Path]::GetFullPath($expectedExe)){
                Stop-Process -Id $p.Id -Force -ErrorAction Stop;$stopped++
            }
         }catch{}
     }
 }
 Write-Host ('G4B_TEST_CLEANUP_PASS stopped_test_processes='+$stopped)
 Write-Host 'Remove the G4B no-monitoring test extension manually from chrome://extensions/ when finished.'
 Write-Host 'Stable ChatGPT Finish Alert, Codex Alert, and their settings have not been modified.'
}catch{
 Write-Host ('G4B_CLEANUP_HOLD: '+$_.Exception.Message);exit 2
}
