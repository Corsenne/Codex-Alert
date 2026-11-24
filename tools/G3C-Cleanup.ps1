# Roll back only G3C isolated test registry and processes.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$key='HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.corsenne.finish_alert_g3c_test'
$work=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G3CTest'
$expected=Join-Path $work 'bin\com.corsenne.finish_alert_g3c_test.json'
$testExe=Join-Path $work 'desktop\src-tauri\target\debug\finish-alert-g3c-test.exe'
$bridgeExe=Join-Path $work 'bin\finish-alert-g3c-bridge.exe'
try{
 if(Test-Path -LiteralPath $key){
     $actual=(Get-Item -LiteralPath $key).GetValue('')
     if([string]$actual -ine $expected){throw 'G3C_REGISTRATION_CHANGED_NO_MUTATION'}
 }
 $approval=Read-Host 'Type CLEANUP to remove ONLY G3C test registration/processes (anything else cancels)'
 if($approval -cne 'CLEANUP'){Write-Host 'G3C_CLEANUP_CANCELLED';exit 0}
 if(Test-Path -LiteralPath $key){Remove-Item -LiteralPath $key -Recurse -Force}
 $stopped=0
 foreach($name in @('finish-alert-g3c-test','finish-alert-g3c-bridge')){
     foreach($p in @(Get-Process -Name $name -ErrorAction SilentlyContinue)){
         $expectedExe=if($name -eq 'finish-alert-g3c-test'){$testExe}else{$bridgeExe}
         try {
            if($p.Path -and [IO.Path]::GetFullPath($p.Path) -ieq [IO.Path]::GetFullPath($expectedExe)){
                Stop-Process -Id $p.Id -Force -ErrorAction Stop;$stopped++
            }
         }catch{}
     }
 }
 Write-Host ('G3C_TEST_CLEANUP_PASS stopped_test_processes='+$stopped)
 Write-Host 'Remove the G3C no-monitoring test extension manually from chrome://extensions/ when finished.'
 Write-Host 'Stable ChatGPT Finish Alert, Codex Alert, and their settings have not been modified.'
}catch{
 Write-Host ('G3C_CLEANUP_HOLD: '+$_.Exception.Message);exit 2
}
