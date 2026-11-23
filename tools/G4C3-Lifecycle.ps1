# G4C-3 — isolated G4C2 real-completion bridge lifecycle acceptance.
# This tool only reads process/registration metadata and asks for visual observations.
# It NEVER sends completions, stops processes, edits settings or changes registry.
[CmdletBinding()]
param([ValidateSet('Snapshot','Guided')][string]$Mode='Guided')
$ErrorActionPreference='Stop'

$hostName='com.corsenne.finish_alert_g4c2_test'
$key='HKCU:\Software\Google\Chrome\NativeMessagingHosts\'+$hostName
$testBin=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4C2Test\bin'
$testManifest=Join-Path $testBin ($hostName+'.json')
$testExe=Join-Path $testBin 'finish-alert-g4c2-bridge.exe'
$testCfg=Join-Path $testBin 'bridge-config.json'
$desktopExe=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4Test\desktop\src-tauri\target\debug\finish-alert-g4-test.exe'

function Verify-IsolatedHost {
    if(-not(Test-Path -LiteralPath $key)){return $false}
    $actual=[string](Get-Item -LiteralPath $key -ErrorAction Stop).GetValue('')
    if($actual -ine $testManifest){return $false}
    foreach($f in @($testManifest,$testExe,$testCfg)){
        if(-not(Test-Path -LiteralPath $f -PathType Leaf)){return $false}
        if((Get-Item -LiteralPath $f).Attributes -band [IO.FileAttributes]::ReparsePoint){return $false}
    }
    $manifest=Get-Content -LiteralPath $testManifest -Raw -Encoding UTF8|ConvertFrom-Json
    $cfg=Get-Content -LiteralPath $testCfg -Raw -Encoding UTF8|ConvertFrom-Json
    $ext=[string]$cfg.extensionId
    return ($ext -cmatch '^[a-p]{32}$' -and
        $manifest.name -ceq $hostName -and $manifest.type -ceq 'stdio' -and
        @($manifest.allowed_origins).Count -eq 1 -and
        $manifest.allowed_origins[0] -ceq ('chrome-extension://'+$ext+'/') -and
        [string]$manifest.path -ieq $testExe)
}
function Snapshot([string]$label) {
    $all=@(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
    $chrome=@($all|Where-Object {$_.Name -ieq 'chrome.exe'})
    $native=@($all|Where-Object {$_.Name -ieq 'finish-alert-g4c2-bridge.exe'})
    $g4=@($all|Where-Object {$_.Name -ieq 'finish-alert-g4-test.exe'})
    $legacyBridge=@($all|Where-Object {$_.Name -ieq 'finish-alert-bridge.exe'})
    $legacyDesktop=@($all|Where-Object {$_.Name -ieq 'finish-alert-desktop.exe'})
    $sameSession=[Diagnostics.Process]::GetCurrentProcess().SessionId
    $otherExe=0;$unknown=0;$otherSession=0
    $now=[DateTime]::UtcNow
    $ageMax=0;$mb=0.0
    $states=New-Object 'System.Collections.Generic.List[string]'
    foreach($p in $native){
        $path=''
        try{$path=[IO.Path]::GetFullPath([string]$p.ExecutablePath)}catch{}
        if([string]::IsNullOrWhiteSpace($path)){$unknown++}
        elseif(-not [string]::Equals($path,$testExe,[StringComparison]::OrdinalIgnoreCase)){$otherExe++}
        if([int]$p.SessionId -ne $sameSession){$otherSession++}
        $start=$null;$age=$null
        try{
            $start=([DateTime]$p.CreationDate).ToUniversalTime()
            $age=[int][Math]::Max(0,[Math]::Floor(($now-$start).TotalMinutes))
            $ageMax=[Math]::Max($ageMax,$age)
        }catch{}
        try{$mb+=[double]$p.WorkingSetSize/1MB}catch{}
        $states.Add(('{0}/{1}m' -f [int]$p.ProcessId,$(if($null -eq $age){'unknown'}else{$age})))
    }
    $desktopMatch=0;$desktopUnknown=0
    foreach($p in $g4){
        try {
            if([string]::Equals([IO.Path]::GetFullPath([string]$p.ExecutablePath),
                $desktopExe,[StringComparison]::OrdinalIgnoreCase) -and
                [int]$p.SessionId -eq $sameSession){$desktopMatch++}
            else{$desktopUnknown++}
        }catch{$desktopUnknown++}
    }
    $s=[pscustomobject]@{
        chrome=$chrome.Count; bridge=$native.Count; g4=$g4.Count
        legacy_bridge=$legacyBridge.Count;legacy_desktop=$legacyDesktop.Count
        bridge_other_exe=$otherExe;bridge_unknown_exe=$unknown
        bridge_other_session=$otherSession;g4_verified=$desktopMatch
        g4_unverified=$desktopUnknown
        oldest_minutes=$ageMax;working_set_mb=[Math]::Round($mb,1)
        bridge_states=@($states.ToArray())
    }
    Write-Host ('G4C3_'+$label+'_CHROME='+$s.chrome)
    Write-Host ('G4C3_'+$label+'_G4_DESKTOP='+$s.g4)
    Write-Host ('G4C3_'+$label+'_G4_DESKTOP_VERIFIED='+$s.g4_verified)
    Write-Host ('G4C3_'+$label+'_G4C2_BRIDGES='+$s.bridge)
    Write-Host ('G4C3_'+$label+'_BRIDGE_OLDEST_MIN='+$s.oldest_minutes)
    Write-Host ('G4C3_'+$label+'_BRIDGE_WORKINGSET_MB='+$s.working_set_mb)
    Write-Host ('G4C3_'+$label+'_BRIDGE_EXE_MISMATCH='+$s.bridge_other_exe)
    Write-Host ('G4C3_'+$label+'_BRIDGE_EXE_UNKNOWN='+$s.bridge_unknown_exe)
    Write-Host ('G4C3_'+$label+'_BRIDGE_OTHER_SESSION='+$s.bridge_other_session)
    Write-Host ('G4C3_'+$label+'_LEGACY_NATIVE_PROCESSES='+($s.legacy_bridge+$s.legacy_desktop))
    if($states.Count){Write-Host ('G4C3_'+$label+'_BRIDGE_PID_AGE='+($states.ToArray() -join ','))}
    return $s
}
function Assert-Safe([object]$s,[string]$label) {
    if($s.legacy_bridge+$s.legacy_desktop -ne 0){throw ('G4C3_STABLE_PRODUCT_ACTIVE_AT_'+$label)}
    if($s.bridge_other_exe -ne 0 -or $s.bridge_unknown_exe -ne 0 -or
       $s.bridge_other_session -ne 0){throw ('G4C3_BRIDGE_IDENTITY_HOLD_AT_'+$label)}
    if($s.g4 -ne 1 -or $s.g4_verified -ne 1 -or $s.g4_unverified -ne 0){
        throw ('G4C3_G4_DESKTOP_IDENTITY_HOLD_AT_'+$label)
    }
}
function Require-Answer([string]$message,[string[]]$accepted) {
    $value=([string](Read-Host $message)).Trim().ToUpperInvariant()
    if($value -eq 'STOP'){Write-Host 'G4C3_OPERATOR_STOP_NO_MUTATION';exit 0}
    if($accepted -cnotcontains $value){throw ('G4C3_OPERATOR_INPUT_HOLD_'+$value)}
    return $value
}
try{
    Write-Host ('G4C3_MODE='+$Mode)
    Write-Host 'G4C3_PRODUCT_MUTATION=NONE'
    $verified=Verify-IsolatedHost
    Write-Host ('G4C3_NATIVE_HOST_REGISTRATION='+$(if($verified){'VERIFIED'}else{'UNVERIFIED'}))
    $baseline=Snapshot 'BASELINE'
    if($Mode -eq 'Snapshot'){
        Write-Host 'G4C3_SNAPSHOT_PASS_NO_MUTATION'
        exit 0
    }
    if(-not $verified){throw 'G4C3_NATIVE_HOST_UNVERIFIED'}
    Assert-Safe $baseline 'BASELINE'
    if($baseline.chrome -eq 0){throw 'G4C3_CHROME_NOT_RUNNING'}
    if($baseline.bridge -gt 1){throw 'G4C3_MULTI_BRIDGE_BASELINE_HOLD'}
    Write-Host 'G4C3_GUIDED_REAL_COMPLETIONS=5'
    Write-Host 'Stable v1.1.5 OFF; G4B OFF; G4C2 ON. No automatic ChatGPT sends.'
    $maxBridges=$baseline.bridge;$total=0
    for($i=1;$i -le 5;$i++){
        $a=Require-Answer ('After REAL reply '+$i+': 1 banner, 1 voice, click stops, exact tab restored; PASS/FAIL/STOP') @('PASS','FAIL')
        if($a -eq 'FAIL'){throw ('G4C3_REPLY_'+$i+'_FAIL')}
        $s=Snapshot ('REPLY_'+$i)
        Assert-Safe $s ('REPLY_'+$i)
        $maxBridges=[Math]::Max($maxBridges,$s.bridge)
        if($s.bridge -gt 1){throw ('G4C3_BRIDGE_GROWTH_HOLD_AT_REPLY_'+$i)}
        $total++
        Write-Host ('G4C3_REPLY_'+$i+'_PASS')
    }
    Write-Host ('G4C3_MAX_BRIDGES_DURING_REPLIES='+$maxBridges)
    Write-Host 'Now EXIT Chrome completely using Chrome menu (save work). Do not terminate processes via script.'
    $ack=Require-Answer 'After Chrome has fully exited, type EXITED (or STOP)' @('EXITED')
    $closed=Snapshot 'AFTER_CHROME_EXIT'
    Assert-Safe $closed 'AFTER_CHROME_EXIT'
    if($closed.chrome -ne 0){throw 'G4C3_CHROME_BACKGROUND_STILL_RUNNING_HOLD'}
    Write-Host 'G4C3_CHROME_ZERO_CONFIRMED'
    Write-Host 'Read-only Native bridge retirement observation: 120 seconds from Chrome-zero confirmation.'
    Start-Sleep -Seconds 120
    $idle=Snapshot 'AFTER_CHROME_120S'
    Assert-Safe $idle 'AFTER_CHROME_120S'
    if($idle.chrome -ne 0){throw 'G4C3_CHROME_REOPENED_EARLY_HOLD'}
    if($idle.bridge -ne 0){throw 'G4C3_BRIDGE_NOT_RETIRED_AFTER_CHROME_EXIT_HOLD'}
    Write-Host 'G4C3_BRIDGE_RETIREMENT_AFTER_CHROME_EXIT_PASS'
    Write-Host 'Reopen Chrome manually. Ensure G4C2 is ON; refresh a saved ChatGPT chat.'
    $again=Require-Answer 'After Chrome reopens, type REOPENED (or STOP)' @('REOPENED')
    $reopen=Snapshot 'REOPENED'
    Assert-Safe $reopen 'REOPENED'
    if($reopen.chrome -eq 0){throw 'G4C3_REOPEN_CHROME_NOT_RUNNING_HOLD'}
    if($reopen.bridge -gt 1){throw 'G4C3_REOPEN_MULTI_BRIDGE_HOLD'}
    $check=Require-Answer 'After ONE REAL reply on reopened Chrome, banner/voice/click PASS/FAIL/STOP' @('PASS','FAIL')
    if($check -ne 'PASS'){throw 'G4C3_REOPENED_REAL_REPLY_FAIL'}
    $last=Snapshot 'REOPENED_REPLY'
    Assert-Safe $last 'REOPENED_REPLY'
    if($last.bridge -gt 1){throw 'G4C3_REOPEN_BRIDGE_GROWTH_HOLD'}
    Write-Host 'G4C3_REOPENED_NOTIFICATION_PASS'
    Write-Host 'G4C3_FIVE_PLUS_ONE_VISUAL_PASS'
    Write-Host 'G4C3_ISOLATED_SHORT_LIFECYCLE_PASS'
    Write-Host 'G4C3_LONG_SOAK=HOLD'
    Write-Host 'G4C_PRODUCT_CUTOVER=HOLD'
}catch{
    Write-Host ('G4C3_GUIDED_HOLD='+$_.Exception.Message)
    Write-Host 'G4C_PRODUCT_CUTOVER=HOLD'
    exit 2
}
