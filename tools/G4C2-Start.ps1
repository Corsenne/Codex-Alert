# Start or reuse only the G4 isolated Tauri desktop. No production action.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4Test'
$exe=Join-Path $root 'desktop\src-tauri\target\debug\finish-alert-g4-test.exe'
$voice=Join-Path $root 'private\private-leo.wav'
$trace=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4C2Test\G4C2_STAGE_TRACE.txt'
try {
    if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'G4C2_G4_DESKTOP_EXE_MISSING'}
    if(-not(Test-Path -LiteralPath $voice -PathType Leaf)){throw 'G4C2_PRIVATE_VOICE_MISSING'}
    if(@(Get-Process finish-alert-desktop,finish-alert-bridge -ErrorAction SilentlyContinue).Count -gt 0){
        throw 'G4C2_PRODUCTION_NATIVE_APP_STILL_RUNNING'
    }
    $running=@(Get-Process -Name 'finish-alert-g4-test' -ErrorAction SilentlyContinue)
    if($running.Count -gt 1){throw 'G4C2_MULTIPLE_G4_TEST_DESKTOP_PROCESSES'}
    if($running.Count -eq 1){
        if(-not $running[0].Path -or
          [IO.Path]::GetFullPath($running[0].Path) -ine [IO.Path]::GetFullPath($exe)){
            throw 'G4C2_UNEXPECTED_TEST_DESKTOP_IDENTITY'
        }
        Write-Host 'G4C2_G4_DESKTOP_REUSED_PASS'
        exit 0
    }
    $dir=Split-Path -Parent $trace
    if(-not(Test-Path -LiteralPath $dir -PathType Container)){
        New-Item -ItemType Directory -Path $dir -Force|Out-Null
    }
    if(Test-Path -LiteralPath $trace){Remove-Item -LiteralPath $trace -Force}
    $env:FINISH_ALERT_G2B_TRACE=$trace
    $env:FINISH_ALERT_G2B_PRIVATE_WAV=$voice
    $p=Start-Process -FilePath $exe -PassThru
    $deadline=(Get-Date).AddSeconds(30);$ready=$false
    while((Get-Date) -lt $deadline) {
        if($p.HasExited){throw 'G4C2_DESKTOP_EXITED_EARLY'}
        if(Test-Path -LiteralPath $trace){
            if(@(Get-Content -LiteralPath $trace -ErrorAction SilentlyContinue) -contains 'G2B_UI_READY_PASS'){
                $ready=$true;break
            }
        }
        Start-Sleep -Milliseconds 250
    }
    if(-not $ready){throw 'G4C2_DESKTOP_UI_NOT_READY'}
    Write-Host 'G4C2_G4_DESKTOP_READY_PASS'
}catch {
    Write-Host ('G4C2_START_HOLD='+$_.Exception.Message);exit 2
}finally {
    Remove-Item Env:\FINISH_ALERT_G2B_TRACE -ErrorAction SilentlyContinue
    Remove-Item Env:\FINISH_ALERT_G2B_PRIVATE_WAV -ErrorAction SilentlyContinue
}
