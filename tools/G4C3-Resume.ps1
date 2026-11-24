# G4C3 continuation after 5/5 real replies: no repeated first phase.
# Read-only: never closes Chrome, kills processes, or changes settings.
[CmdletBinding()]
param([ValidateSet('Inspect','Resume')][string]$Mode='Inspect')
$ErrorActionPreference='Stop'
$hostName='com.corsenne.finish_alert_g4c2_test'
$reg='HKCU:\Software\Google\Chrome\NativeMessagingHosts\'+$hostName
$bin=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4C2Test\bin'
$manifestPath=Join-Path $bin ($hostName+'.json')
$configPath=Join-Path $bin 'bridge-config.json'
$bridgeExe=Join-Path $bin 'finish-alert-g4c2-bridge.exe'
$desktopExe=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4Test\desktop\src-tauri\target\debug\finish-alert-g4-test.exe'

function Verify-G4C2Registration {
    if(-not(Test-Path -LiteralPath $reg)){return $false}
    $registered=[string](Get-Item -LiteralPath $reg -ErrorAction Stop).GetValue('')
    if($registered -ine $manifestPath){return $false}
    foreach($file in @($manifestPath,$configPath,$bridgeExe)){
        if(-not(Test-Path -LiteralPath $file -PathType Leaf)){return $false}
        $info=Get-Item -LiteralPath $file -ErrorAction Stop
        if(($info.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){return $false}
    }
    $hostManifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8|ConvertFrom-Json
    $config=Get-Content -LiteralPath $configPath -Raw -Encoding UTF8|ConvertFrom-Json
    $extensionId=[string]$config.extensionId
    return ($extensionId -cmatch '^[a-p]{32}$' -and
       $hostManifest.name -ceq $hostName -and
       $hostManifest.type -ceq 'stdio' -and
       [string]$hostManifest.path -ieq $bridgeExe -and
       @($hostManifest.allowed_origins).Count -eq 1 -and
       $hostManifest.allowed_origins[0] -ceq ('chrome-extension://'+$extensionId+'/'))
}
function Get-Snapshot([string]$label){
    $all=@(Get-CimInstance Win32_Process -ErrorAction Stop)
    $byPid=@{}
    foreach($p in $all){$byPid[[int]$p.ProcessId]=$p}
    $chrome=@($all|Where-Object{$_.Name -ieq 'chrome.exe'})
    $bridges=@($all|Where-Object{$_.Name -ieq 'finish-alert-g4c2-bridge.exe'})
    $g4=@($all|Where-Object{$_.Name -ieq 'finish-alert-g4-test.exe'})
    $legacy=@($all|Where-Object{$_.Name -in @('finish-alert-desktop.exe','finish-alert-bridge.exe')})
    $session=[Diagnostics.Process]::GetCurrentProcess().SessionId
    $types=@{}
    $chromeDetails=New-Object 'System.Collections.Generic.List[string]'
    foreach($p in $chrome){
        $command=[string]$p.CommandLine
        $type='browser-root'
        if($command -match '(?:^|\s)--type=([A-Za-z0-9_-]+)'){
            $type=$Matches[1].ToLowerInvariant()
            if($type -eq 'renderer' -and $command -match '(?:^|\s)--extension-process(?:\s|$)'){
                $type='renderer-extension'
            }
        }
        if(-not $types.ContainsKey($type)){$types[$type]=0}
        $types[$type]++
        $parent=[int]$p.ParentProcessId
        $parentClass=if($byPid.ContainsKey($parent)){
            ([string]$byPid[$parent].Name).ToLowerInvariant()
        }else{'parent-not-running'}
        # Do not print process command lines, file paths, profile data, tabs or URLs.
        $chromeDetails.Add(('{0}/{1}/{2}' -f [int]$p.ProcessId,$type,$parentClass))
    }
    $bridgesBad=0
    foreach($p in $bridges){
        try{
            $actual=[IO.Path]::GetFullPath([string]$p.ExecutablePath)
            if(-not [string]::Equals($actual,$bridgeExe,[StringComparison]::OrdinalIgnoreCase) -or
               [int]$p.SessionId -ne $session){$bridgesBad++}
        }catch{$bridgesBad++}
    }
    $desktopGood=0
    foreach($p in $g4){
        try{
            $actual=[IO.Path]::GetFullPath([string]$p.ExecutablePath)
            if([string]::Equals($actual,$desktopExe,[StringComparison]::OrdinalIgnoreCase) -and
               [int]$p.SessionId -eq $session){$desktopGood++}
        }catch{}
    }
    $typeText=@($types.Keys|Sort-Object|ForEach-Object{$_+':'+$types[$_]}) -join ','
    Write-Host ('G4C3R_'+$label+'_CHROME='+$chrome.Count)
    Write-Host ('G4C3R_'+$label+'_CHROME_TYPES='+$typeText)
    Write-Host ('G4C3R_'+$label+'_G4_DESKTOP='+$g4.Count)
    Write-Host ('G4C3R_'+$label+'_G4_DESKTOP_VERIFIED='+$desktopGood)
    Write-Host ('G4C3R_'+$label+'_G4C2_BRIDGES='+$bridges.Count)
    Write-Host ('G4C3R_'+$label+'_BRIDGE_IDENTITY_MISMATCH='+$bridgesBad)
    Write-Host ('G4C3R_'+$label+'_LEGACY_PROCESSES='+$legacy.Count)
    Write-Host ('G4C3R_'+$label+'_CHROME_PID_TYPE_PARENT='+($chromeDetails.ToArray() -join ','))
    return [pscustomobject]@{
       chrome=$chrome.Count;bridge=$bridges.Count;desktop=$g4.Count
       desktopVerified=$desktopGood;bridgeBad=$bridgesBad;legacy=$legacy.Count
    }
}
function Require-Safe([object]$s,[string]$label){
    if($s.legacy -ne 0){throw ('G4C3R_LEGACY_NATIVE_RUNNING_'+$label)}
    if($s.desktop -ne 1 -or $s.desktopVerified -ne 1){
        throw ('G4C3R_G4_DESKTOP_IDENTITY_HOLD_'+$label)
    }
    if($s.bridgeBad -ne 0 -or $s.bridge -gt 1){
        throw ('G4C3R_ISOLATED_BRIDGE_IDENTITY_OR_GROWTH_HOLD_'+$label)
    }
}
function Ask([string]$prompt,[string]$expected){
    $answer=([string](Read-Host $prompt)).Trim().ToUpperInvariant()
    if($answer -eq 'STOP'){
        Write-Host 'G4C3R_OPERATOR_STOP_NO_MUTATION'
        exit 0
    }
    if($answer -cne $expected){throw 'G4C3R_OPERATOR_CONFIRMATION_HOLD'}
}
try{
    Write-Host ('G4C3R_MODE='+$Mode)
    Write-Host 'G4C3R_PRODUCT_MUTATION=NONE'
    $registered=Verify-G4C2Registration
    Write-Host ('G4C3R_G4C2_REGISTRATION='+$(if($registered){'VERIFIED'}else{'UNVERIFIED'}))
    $baseline=Get-Snapshot 'BASELINE'
    if($Mode -eq 'Inspect'){
        Write-Host 'G4C3R_BACKGROUND_INSPECT_PASS_NO_MUTATION'
        Write-Host 'G4C3R_BACKGROUND_CAUSE_NOT_PROVEN'
        exit 0
    }
    if(-not $registered){throw 'G4C3R_G4C2_REGISTRATION_HOLD'}
    Require-Safe $baseline 'BASELINE'
    if($baseline.chrome -ne 0){
        Write-Host 'G4C3R_CHROME_STILL_RUNNING_NO_IDLE_TEST'
        throw 'G4C3R_CHROME_ZERO_REQUIRED'
    }
    Write-Host 'G4C3R_CHROME_ZERO_VERIFIED'
    Write-Host 'G4C3R_OBSERVE_NATIVE_RETIREMENT=120_SECONDS'
    Start-Sleep -Seconds 120
    $after=Get-Snapshot 'AFTER_120S'
    Require-Safe $after 'AFTER_120S'
    if($after.chrome -ne 0){throw 'G4C3R_CHROME_REOPENED_DURING_IDLE_HOLD'}
    if($after.bridge -ne 0){throw 'G4C3R_BRIDGE_DID_NOT_RETIRE_HOLD'}
    Write-Host 'G4C3R_BRIDGE_RETIREMENT_PASS'
    Write-Host 'Reopen Chrome manually, keep stable v1.1.5 OFF and G4C2 ON; reload a saved chat.'
    Ask 'After reopening Chrome, type REOPENED or STOP' 'REOPENED'
    $reopen=Get-Snapshot 'REOPENED'
    Require-Safe $reopen 'REOPENED'
    if($reopen.chrome -eq 0){throw 'G4C3R_CHROME_NOT_REOPENED'}
    Ask 'After ONE new real ChatGPT reply with one banner/voice and exact click/stop, type PASS or STOP' 'PASS'
    $final=Get-Snapshot 'REOPENED_REAL_REPLY'
    Require-Safe $final 'REOPENED_REAL_REPLY'
    Write-Host 'G4C3R_REOPENED_REAL_NOTIFICATION_PASS'
    Write-Host 'G4C3R_PHASE_B_SHORT_LIFECYCLE_PASS'
    Write-Host 'G4C3R_PREVIOUS_FIVE_REPLIES=USER_REPORTED_PASS_NOT_RETESTED'
    Write-Host 'G4C3_LONG_SOAK=HOLD'
    Write-Host 'G4C_PRODUCT_CUTOVER=HOLD'
}catch{
    Write-Host ('G4C3R_RESUME_HOLD='+$_.Exception.Message)
    Write-Host 'G4C_PRODUCT_CUTOVER=HOLD'
    exit 2
}
