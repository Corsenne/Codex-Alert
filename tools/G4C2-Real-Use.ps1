# G4C2 isolated REAL completion operator gate; never accepts unchecked registration.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
try {
    $desktop=@(Get-Process -Name 'finish-alert-g4-test' -ErrorAction SilentlyContinue)
    if($desktop.Count -ne 1){throw 'G4C2_TEST_DESKTOP_NOT_UNIQUE'}
    if(@(Get-Process finish-alert-desktop,finish-alert-bridge -ErrorAction SilentlyContinue).Count -gt 0){
        throw 'G4C2_STABLE_NATIVE_APP_RUNNING'
    }
    # Preflight the isolated HKCU registration, NOT the stable production entry.
    $key='HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.corsenne.finish_alert_g4c2_test'
    $bin=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4C2Test\bin'
    $expectedManifest=Join-Path $bin 'com.corsenne.finish_alert_g4c2_test.json'
    $expectedExe=Join-Path $bin 'finish-alert-g4c2-bridge.exe'
    $expectedConfig=Join-Path $bin 'bridge-config.json'
    if(-not(Test-Path -LiteralPath $key)){throw 'G4C2_NATIVE_HOST_NOT_REGISTERED'}
    $actualManifest=[string](Get-Item -LiteralPath $key -ErrorAction Stop).GetValue('')
    if($actualManifest -ine $expectedManifest){throw 'G4C2_NATIVE_HOST_UNEXPECTED_MANIFEST'}
    if(-not(Test-Path -LiteralPath $expectedManifest -PathType Leaf) -or
       -not(Test-Path -LiteralPath $expectedExe -PathType Leaf) -or
       -not(Test-Path -LiteralPath $expectedConfig -PathType Leaf)){
        throw 'G4C2_NATIVE_HOST_FILES_MISSING'
    }
    $hostManifest=Get-Content -LiteralPath $expectedManifest -Raw -Encoding UTF8 | ConvertFrom-Json
    $bridgeConfig=Get-Content -LiteralPath $expectedConfig -Raw -Encoding UTF8 | ConvertFrom-Json
    $extensionId=[string]$bridgeConfig.extensionId
    if($extensionId -cnotmatch '^[a-p]{32}$' -or
       $hostManifest.name -cne 'com.corsenne.finish_alert_g4c2_test' -or
       $hostManifest.type -cne 'stdio' -or
       @($hostManifest.allowed_origins).Count -ne 1 -or
       $hostManifest.allowed_origins[0] -cne ('chrome-extension://'+$extensionId+'/') -or
       [string]$hostManifest.path -ine $expectedExe){
        throw 'G4C2_NATIVE_HOST_CONFIGURATION_MISMATCH'
    }
    Write-Host 'G4C2_NATIVE_HOST_PREFLIGHT_PASS'
    Write-Host 'G4C2_REAL_COMPLETION_VISUAL_GATE'
    Write-Host 'Requirement: stable v1.1.5 OFF; G4B OFF; G4C2 real observer ON.'
    Write-Host 'Create new REAL ChatGPT replies in a saved conversation (/c/...).'
    for($i=1;$i -le 3;$i++){
        $answer=([string](Read-Host ('G4C2 real reply '+$i+': one banner, one voice, click stops sound, exact chat restored? PASS/FAIL/STOP'))).Trim().ToUpperInvariant()
        if($answer -eq 'STOP'){Write-Host 'G4C2_USER_STOP_NO_MUTATION';exit 0}
        if($answer -ne 'PASS'){Write-Host ('G4C2_REAL_REPLY_'+$i+'_HOLD');exit 2}
        Write-Host ('G4C2_REAL_REPLY_'+$i+'_PASS')
    }
    Write-Host 'G4C2_REAL_COMPLETION_3_OF_3_USER_PASS'
    Write-Host 'G4C2_PRODUCT_RELEASE=HOLD'
}catch{
    # Only local operator diagnostics; does not alter any installation.
    Write-Host ('G4C2_VISUAL_GATE_HOLD='+$_.Exception.Message)
    exit 2
}
