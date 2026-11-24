# Explicit, TEST-ONLY Native Messaging registration. This does not replace production host.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$nativeName='com.corsenne.finish_alert_g3c_test'
$key='HKCU:\Software\Google\Chrome\NativeMessagingHosts\'+$nativeName
$work=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G3CTest'
$bin=Join-Path $work 'bin'
$exe=Join-Path $bin 'finish-alert-g3c-bridge.exe'
$manifestPath=Join-Path $bin ($nativeName+'.json')
$configPath=Join-Path $bin 'bridge-config.json'
try{
    if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'G3C_TEST_BRIDGE_NOT_BUILT'}
    if(Test-Path -LiteralPath $key){throw 'G3C_TEST_REGISTRATION_ALREADY_EXISTS_NO_OVERWRITE'}
    Write-Host 'Copy the extension ID of "Finish Alert G3C Click Test (NO MONITORING)" from chrome://extensions/'
    $id=([string](Read-Host 'Enter G3C TEST extension ID')).Trim().ToLowerInvariant()
    if($id -cnotmatch '^[a-p]{32}$'){throw 'G3C_TEST_EXTENSION_ID_INVALID'}
    Write-Host 'This registers ONLY an isolated HKCU G3C test host. Stable Finish Alert registry entries are not modified.'
    $approval=Read-Host 'Type REGISTER to create the isolated test host (anything else cancels)'
    if($approval -cne 'REGISTER'){
        Write-Host 'G3C_REGISTRATION_CANCELLED'
        exit 0
    }
    $hostManifest=[ordered]@{
        name=$nativeName;description='Isolated manual-only G3C click integration test'
        path=$exe;type='stdio';allowed_origins=@('chrome-extension://'+$id+'/')
    }
    $bridgeConfig=[ordered]@{extensionId=$id}
    $utf8=[Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($manifestPath,($hostManifest|ConvertTo-Json -Depth 4 -Compress),$utf8)
    [IO.File]::WriteAllText($configPath,($bridgeConfig|ConvertTo-Json -Depth 3 -Compress),$utf8)
    New-Item -Path $key -Force | Out-Null
    Set-Item -Path $key -Value $manifestPath
    $actual=(Get-Item -LiteralPath $key).GetValue('')
    if([string]$actual -ine $manifestPath){throw 'G3C_TEST_REGISTRATION_VERIFICATION_FAILED'}
    Write-Host 'G3C_NATIVE_HOST_TEST_REGISTERED_PASS'
    Write-Host 'Next: run G3C-Start.cmd, then use the G3C test extension popup on a ChatGPT conversation.'
}catch{
    Write-Host ('G3C_REGISTRATION_HOLD: '+$_.Exception.Message)
    exit 2
}
