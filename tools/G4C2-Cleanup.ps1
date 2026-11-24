# G4C2 isolated registration cleanup. Never delete or re-enable stable products.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$name='com.corsenne.finish_alert_g4c2_test'
$key='HKCU:\Software\Google\Chrome\NativeMessagingHosts\'+$name
$root=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4C2Test\bin'
$expected=Join-Path $root ($name+'.json')
$exe=Join-Path $root 'finish-alert-g4c2-bridge.exe'
try{
    if(Test-Path -LiteralPath $key){
        $actual=[string](Get-Item -LiteralPath $key).GetValue('')
        if($actual -ine $expected){throw 'G4C2_REGISTRATION_CHANGED_HOLD'}
    }
    if(@(Get-Process -Name chrome -ErrorAction SilentlyContinue).Count -gt 0){
        throw 'G4C2_CHROME_MUST_BE_CLOSED_TO_CLEANUP'
    }
    $bridges=@(Get-Process -Name 'finish-alert-g4c2-bridge' -ErrorAction SilentlyContinue)
    if($bridges.Count -gt 0){
        throw 'G4C2_BRIDGE_STILL_RUNNING_NO_TERMINATION'
    }
    $ok=[string](Read-Host 'Type CLEANUP to remove ONLY the isolated G4C2 HKCU host registration')
    if($ok -cne 'CLEANUP'){Write-Host 'G4C2_CLEANUP_CANCELLED';exit 0}
    if(Test-Path -LiteralPath $key){Remove-Item -LiteralPath $key -Recurse -Force}
    Write-Host 'G4C2_TEST_HOST_CLEANUP_PASS'
    Write-Host 'Stable extension, Finish Alert Desktop, and Codex Hook unchanged.'
}catch{
    Write-Host ('G4C2_CLEANUP_HOLD='+$_.Exception.Message);exit 2
}
