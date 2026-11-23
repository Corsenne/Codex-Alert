# G4C-1C — Optional, gated stale native bridge cleanup.
# Preview is read-only. Cleanup requires Chrome fully closed, exact executable,
# same user/session, process age & parent state, explicit human confirmation.
# Never terminate Chrome, Codex, Finish Alert Desktop, or modify configuration.
[CmdletBinding()]
param([ValidateSet('Preview','Cleanup')][string]$Mode='Preview')
$ErrorActionPreference='Stop'

function Get-RegisteredBridgePath {
    $key='Registry::HKEY_CURRENT_USER\Software\Google\Chrome\NativeMessagingHosts\com.corsenne.finish_alert'
    if(-not(Test-Path -LiteralPath $key)){return $null}
    $manifest=[string](Get-Item -LiteralPath $key -ErrorAction Stop).GetValue('')
    if($manifest -cnotmatch '^[A-Za-z]:\\'){return $null}
    if(-not(Test-Path -LiteralPath $manifest -PathType Leaf)){return $null}
    $file=Get-Item -LiteralPath $manifest -ErrorAction Stop
    if($file.Length -gt 65536){return $null}
    $m=Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    if($m.name -cne 'com.corsenne.finish_alert'){return $null}
    $exe=[string]$m.path
    if($exe -cnotmatch '^[A-Za-z]:\\'){return $null}
    $expected=[IO.Path]::GetFullPath($exe)
    if(([IO.Path]::GetFileName($expected)) -ine 'finish-alert-bridge.exe'){return $null}
    if(-not(Test-Path -LiteralPath $expected -PathType Leaf)){return $null}
    # Installation must be in user's local appdata, not system or arbitrary folder.
    $local=[IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\')+'\'
    if(-not $expected.StartsWith($local,[StringComparison]::OrdinalIgnoreCase)){return $null}
    return $expected
}

function New-Snapshot([string]$expected) {
    $all=@(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
    $byId=@{}
    foreach($p in $all){$byId[[int]$p.ProcessId]=$p}
    $chrome=@($all|Where-Object {$_.Name -ieq 'chrome.exe'}).Count
    $session=[Diagnostics.Process]::GetCurrentProcess().SessionId
    $user=[Security.Principal.WindowsIdentity]::GetCurrent().Name
    $rows=New-Object 'System.Collections.Generic.List[object]'
    foreach($p in $all){
        if($p.Name -ine 'finish-alert-bridge.exe'){continue}
        $created=$null
        try{$created=([DateTime]$p.CreationDate).ToUniversalTime()}catch{}
        $parent=[int]$p.ParentProcessId
        $parentState='missing'
        if($byId.ContainsKey($parent)){
            $parentState='alive'
            try {
                if($null -ne $created -and ([DateTime]$byId[$parent].CreationDate).ToUniversalTime() -gt $created){
                    $parentState='pid-reused'
                }
            }catch{$parentState='unverified'}
        }
        $exeMatch=$false
        try {
            $actual=[IO.Path]::GetFullPath([string]$p.ExecutablePath)
            if($null -ne $expected){
                $exeMatch=[string]::Equals($actual,$expected,[StringComparison]::OrdinalIgnoreCase)
            }
        }catch{}
        $sameUser=$false
        try {
            $own=Invoke-CimMethod -InputObject $p -MethodName GetOwner -ErrorAction Stop
            $sameUser=($own.ReturnValue -eq 0 -and
                 [string]::Equals(([string]$own.Domain)+'\'+([string]$own.User),
                      $user,[StringComparison]::OrdinalIgnoreCase))
        }catch{}
        $sameSession=([int]$p.SessionId -eq $session)
        $age=$null
        if($null -ne $created){$age=[Math]::Max(0,[int][Math]::Floor(([DateTime]::UtcNow-$created).TotalMinutes))}
        $eligible=($null -ne $created -and $exeMatch -and $sameUser -and $sameSession -and
                    $parentState -in @('missing','pid-reused'))
        $rows.Add([pscustomobject]@{
            pid=[int]$p.ProcessId; age_minutes=$age; parent_state=$parentState
            executable_match=$exeMatch; user_match=$sameUser; session_match=$sameSession
            eligible=$eligible; created_ticks=$(if($null -eq $created){0L}else{$created.Ticks})
        })
    }
    return [pscustomobject]@{chrome=$chrome;bridge_count=$rows.Count;
       eligible_count=@($rows|Where-Object {$_.eligible}).Count;
       rows=@($rows.ToArray())}
}

try {
    $expected=Get-RegisteredBridgePath
    $snap=New-Snapshot $expected
    Write-Host ('G4C1C_MODE='+$Mode)
    Write-Host ('G4C1C_CHROME_PROCESSES='+$snap.chrome)
    Write-Host ('G4C1C_BRIDGES='+$snap.bridge_count)
    Write-Host ('G4C1C_ELIGIBLE='+$snap.eligible_count)
    Write-Host ('G4C1C_REGISTERED_EXECUTABLE='+$(if($expected){'VERIFIED'}else{'UNVERIFIED'}))
    foreach($p in $snap.rows){
        Write-Host ('G4C1C_BRIDGE PID='+$p.pid+' AGE_MIN='+$p.age_minutes+
            ' PARENT='+$p.parent_state+' EXE_MATCH='+$p.executable_match+
            ' SAME_USER='+$p.user_match+' SAME_SESSION='+$p.session_match+
            ' ELIGIBLE='+$p.eligible)
    }
    if($Mode -eq 'Preview'){
        Write-Host 'G4C1C_PREVIEW_PASS_NO_MUTATION'
        exit 0
    }
    # User must close Chrome manually. This script must NEVER terminate Chrome.
    if($snap.chrome -ne 0){throw 'G4C1C_CHROME_MUST_BE_FULLY_CLOSED'}
    if($null -eq $expected){throw 'G4C1C_REGISTERED_EXE_UNVERIFIED'}
    if($snap.bridge_count -ne $snap.eligible_count){throw 'G4C1C_NOT_ALL_BRIDGES_SAFE_ABORT'}
    if($snap.eligible_count -eq 0){Write-Host 'G4C1C_NOTHING_TO_CLEAN';exit 0}
    $answer=[string](Read-Host ('Type CLEANUP '+$snap.eligible_count+' to stop ONLY these verified stale bridge processes'))
    if($answer -cne ('CLEANUP '+$snap.eligible_count)){
        Write-Host 'G4C1C_CLEANUP_CANCELLED_NO_MUTATION'
        exit 0
    }
    $stopped=0
    foreach($entry in @($snap.rows|Where-Object {$_.eligible})){
        $latest=New-Snapshot (Get-RegisteredBridgePath)
        if($latest.chrome -ne 0){throw 'G4C1C_CHROME_RESTARTED_ABORT'}
        if((Get-RegisteredBridgePath) -cne $expected){throw 'G4C1C_NATIVE_HOST_CHANGED_ABORT'}
        $current=@($latest.rows|Where-Object {$_.pid -eq $entry.pid})
        if($current.Count -eq 0){continue}
        if($current.Count -ne 1 -or -not $current[0].eligible -or
           $current[0].created_ticks -ne $entry.created_ticks){
            throw 'G4C1C_PROCESS_IDENTITY_CHANGED_ABORT'
        }
        $live=$null
        try{
            $live=[Diagnostics.Process]::GetProcessById($entry.pid)
            $livePath=$live.MainModule.FileName
            $liveStarted=$live.StartTime.ToUniversalTime()
            $expectedStarted=[DateTime]::new([long]$entry.created_ticks,[DateTimeKind]::Utc)
            if(-not [string]::Equals([IO.Path]::GetFullPath($livePath),$expected,
                       [StringComparison]::OrdinalIgnoreCase) -or
               [Math]::Abs(($liveStarted-$expectedStarted).TotalSeconds) -gt 1){
                throw 'G4C1C_OPEN_HANDLE_MISMATCH_ABORT'
            }
            $live.Kill()
            [void]$live.WaitForExit(5000)
            if(-not $live.HasExited){throw 'G4C1C_PROCESS_STILL_RUNNING_HOLD'}
            $stopped++
        }finally{if($null -ne $live){$live.Dispose()}}
    }
    Write-Host ('G4C1C_VERIFIED_BRIDGES_STOPPED='+$stopped)
    Write-Host 'G4C1C_CLEANUP_COMPLETE'
    Write-Host 'G4C_PRODUCT_RELEASE=HOLD'
}catch{
    # Emit only a fixed diagnostic class, never local paths or command lines.
    $known=@(
      'G4C1C_CHROME_MUST_BE_FULLY_CLOSED',
      'G4C1C_REGISTERED_EXE_UNVERIFIED',
      'G4C1C_NOT_ALL_BRIDGES_SAFE_ABORT',
      'G4C1C_CHROME_RESTARTED_ABORT',
      'G4C1C_NATIVE_HOST_CHANGED_ABORT',
      'G4C1C_PROCESS_IDENTITY_CHANGED_ABORT',
      'G4C1C_OPEN_HANDLE_MISMATCH_ABORT',
      'G4C1C_PROCESS_STILL_RUNNING_HOLD'
    )
    $message=[string]$_.Exception.Message
    $safe=if($known -ccontains $message){$message}else{'G4C1C_UNEXPECTED_ERROR'}
    Write-Host ('G4C1C_HOLD_REASON='+$safe)
    Write-Host 'G4C1C_CLEANUP_HOLD'
    exit 2
}
