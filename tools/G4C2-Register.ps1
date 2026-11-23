# Register ONLY a new G4C2 isolated Native Messaging host. Never replace production.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$name='com.corsenne.finish_alert_g4c2_test'
$key='HKCU:\Software\Google\Chrome\NativeMessagingHosts\'+$name
$work=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4C2Test'
$bin=Join-Path $work 'bin'
$source=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4Test\bin\finish-alert-g4-bridge.exe'
$exe=Join-Path $bin 'finish-alert-g4c2-bridge.exe'
$manifestPath=Join-Path $bin ($name+'.json')
$configPath=Join-Path $bin 'bridge-config.json'
try {
    if(Test-Path -LiteralPath $key){throw 'G4C2_REGISTRATION_ALREADY_EXISTS_NO_OVERWRITE'}
    if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw 'G4C2_ACCEPTED_G4_BRIDGE_MISSING'}
    if(@(Get-Process finish-alert-desktop,finish-alert-bridge -ErrorAction SilentlyContinue).Count -gt 0){
        throw 'G4C2_STABLE_NATIVE_PROCESSES_STILL_RUNNING'
    }
    $mFile=Join-Path $repo 'candidate-g4c2\chrome-extension\manifest.json'
    if(-not(Test-Path -LiteralPath $mFile -PathType Leaf)){throw 'G4C2_EXTENSION_MISSING'}
    $manifest=Get-Content -LiteralPath $mFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if($manifest.name -cne 'Finish Alert G4C2 Real Completion TEST (ISOLATED)' -or
       $manifest.background.service_worker -cne 'background.js' -or
       @($manifest.content_scripts).Count -ne 1 -or
       @($manifest.content_scripts[0].js).Count -ne 1 -or
       $manifest.content_scripts[0].js[0] -cne 'content.js') {
        throw 'G4C2_EXTENSION_IDENTITY_MISMATCH'
    }
    Write-Host 'Select the extension named Finish Alert G4C2 Real Completion TEST (ISOLATED) in chrome://extensions/.'
    $id=([string](Read-Host 'Paste ONLY its 32-character extension ID')).Trim().ToLowerInvariant()
    if($id -cnotmatch '^[a-p]{32}$'){throw 'G4C2_EXTENSION_ID_INVALID'}
    Write-Host 'Stable v1.1.5 must remain OFF; G4B manual test extension must be OFF; only ONE completion observer.'
    if(([string](Read-Host 'Type STABLE_OFF to attest installed v1.1.5 is disabled')) -cne 'STABLE_OFF'){
        Write-Host 'G4C2_CANCELLED_STABLE_NOT_CONFIRMED';exit 0
    }
    if(([string](Read-Host 'Type G4B_OFF to attest previous G4B manual extension is disabled')) -cne 'G4B_OFF'){
        Write-Host 'G4C2_CANCELLED_G4B_NOT_CONFIRMED';exit 0
    }
    Write-Host 'This installs an ISOLATED test Native Messaging key under HKCU only.'
    if(([string](Read-Host 'Type REGISTER to proceed')) -cne 'REGISTER'){
        Write-Host 'G4C2_REGISTRATION_CANCELLED';exit 0
    }
    if(-not(Test-Path -LiteralPath $bin -PathType Container)){
        New-Item -ItemType Directory -Path $bin -Force|Out-Null
    }
    if(Test-Path -LiteralPath $exe -PathType Leaf){
        $oldHash=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
        $newHash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        if($oldHash -ne $newHash){throw 'G4C2_EXISTING_TEST_BRIDGE_DIFFERENT_NO_OVERWRITE'}
    }else{
        Copy-Item -LiteralPath $source -Destination $exe -ErrorAction Stop
    }
    if((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash -ne
       (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash){
        throw 'G4C2_BRIDGE_COPY_HASH_MISMATCH'
    }
    $u8=[Text.UTF8Encoding]::new($false)
    $hostManifest=[ordered]@{
        name=$name
        description='Isolated G4C2 real completion Windows test'
        path=$exe
        type='stdio'
        allowed_origins=@('chrome-extension://'+$id+'/')
    }
    $config=[ordered]@{extensionId=$id}
    [IO.File]::WriteAllText($manifestPath,($hostManifest|ConvertTo-Json -Depth 4 -Compress),$u8)
    [IO.File]::WriteAllText($configPath,($config|ConvertTo-Json -Depth 3 -Compress),$u8)
    New-Item -Path $key -Force|Out-Null
    Set-Item -Path $key -Value $manifestPath
    if([string](Get-Item -LiteralPath $key).GetValue('') -ine $manifestPath){
        throw 'G4C2_REGISTRATION_VERIFICATION_FAILED'
    }
    Write-Host 'G4C2_ISOLATED_NATIVE_HOST_REGISTERED_PASS'
    Write-Host 'Production v1.1.5 registry, extension, and Codex Stop Hook UNCHANGED.'
}catch {
    Write-Host ('G4C2_REGISTER_HOLD='+$_.Exception.Message)
    exit 2
}
