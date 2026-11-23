# Explicit, TEST-ONLY Native Messaging registration. This does not replace production host.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$nativeName='com.corsenne.finish_alert_g4_test'
$key='HKCU:\Software\Google\Chrome\NativeMessagingHosts\'+$nativeName
$work=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4Test'
$bin=Join-Path $work 'bin'
$exe=Join-Path $bin 'finish-alert-g4-bridge.exe'
$manifestPath=Join-Path $bin ($nativeName+'.json')
$configPath=Join-Path $bin 'bridge-config.json'
try{
    if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'G4B_TEST_BRIDGE_NOT_BUILT'}
    if(Test-Path -LiteralPath $key){throw 'G4B_TEST_REGISTRATION_ALREADY_EXISTS_NO_OVERWRITE'}
    $repo=Split-Path -Parent $PSScriptRoot
    $extensionPath=Join-Path $repo 'candidate-g4\chrome-extension\manifest.json'
    if(-not(Test-Path -LiteralPath $extensionPath -PathType Leaf)){throw 'G4B_TEST_EXTENSION_MANIFEST_MISSING'}
    $extensionManifest=Get-Content -LiteralPath $extensionPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if($extensionManifest.name -cne 'Finish Alert G4 Manual Test (NO MONITORING)' -or
       $extensionManifest.background.service_worker -cne 'background.js' -or
       $null -ne $extensionManifest.content_scripts) {
        throw 'G4B_TEST_EXTENSION_NOT_ISOLATED'
    }

    Write-Host 'Copy the extension ID of "Finish Alert G4 Manual Test (NO MONITORING)" from chrome://extensions/'
    $id=([string](Read-Host 'Enter G4B TEST extension ID')).Trim().ToLowerInvariant()
    if($id -cnotmatch '^[a-p]{32}$'){throw 'G4B_TEST_EXTENSION_ID_INVALID'}
    Write-Host 'This registers ONLY an isolated HKCU G4 test host. Stable Finish Alert registry entries are not modified.'
    $approval=Read-Host 'Type REGISTER to create the isolated test host (anything else cancels)'
    if($approval -cne 'REGISTER'){
        Write-Host 'G4B_REGISTRATION_CANCELLED'
        exit 0
    }
    $hostManifest=[ordered]@{
        name=$nativeName;description='Isolated manual-only G4B click integration test'
        path=$exe;type='stdio';allowed_origins=@('chrome-extension://'+$id+'/')
    }
    $bridgeConfig=[ordered]@{extensionId=$id}
    $utf8=[Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($manifestPath,($hostManifest|ConvertTo-Json -Depth 4 -Compress),$utf8)
    [IO.File]::WriteAllText($configPath,($bridgeConfig|ConvertTo-Json -Depth 3 -Compress),$utf8)
    New-Item -Path $key -Force | Out-Null
    Set-Item -Path $key -Value $manifestPath
    $actual=(Get-Item -LiteralPath $key).GetValue('')
    if([string]$actual -ine $manifestPath){throw 'G4B_TEST_REGISTRATION_VERIFICATION_FAILED'}
    Write-Host 'G4B_NATIVE_HOST_TEST_REGISTERED_PASS'
    Write-Host 'Next: run G4B-Start.cmd, then use the G4B test extension popup on a ChatGPT conversation.'
}catch{
    Write-Host ('G4B_REGISTRATION_HOLD: '+$_.Exception.Message)
    exit 2
}
