# G4C-1B — Read-only bridge process lineage / resource inventory.
# No process kill, no Chrome/Hook changes, no command lines, URL, user folder
# paths or extension IDs emitted. Not an orphan or leak determination by itself.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

function Read-RegisteredBridgePath {
    $keyPath='Registry::HKEY_CURRENT_USER\Software\Google\Chrome\NativeMessagingHosts\com.corsenne.finish_alert'
    try {
        if(-not(Test-Path -LiteralPath $keyPath)){return $null}
        $manifestPath=[string](Get-Item -LiteralPath $keyPath -ErrorAction Stop).GetValue('')
        if($manifestPath -cnotmatch '^[A-Za-z]:\\'){return $null}
        if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){return $null}
        $info=Get-Item -LiteralPath $manifestPath -ErrorAction Stop
        if($info.Length -gt 65536){return $null}
        $parsed=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $exePath=[string]$parsed.path
        if($exePath -cnotmatch '^[A-Za-z]:\\'){return $null}
        return [IO.Path]::GetFullPath($exePath)
    }catch{
        return $null
    }
}

function Safe-ProcessState($raw,$expectedExe) {
    $rows=New-Object 'System.Collections.Generic.List[object]'
    $byId=@{}
    foreach($item in $raw){
        $byId[[int]$item.ProcessId]=$item
    }
    $chrome=@($raw | Where-Object {$_.Name -ieq 'chrome.exe'})
    $bridges=@($raw | Where-Object {$_.Name -ieq 'finish-alert-bridge.exe'})
    $desktop=@($raw | Where-Object {$_.Name -ieq 'finish-alert-desktop.exe'})
    $now=[DateTime]::UtcNow
    foreach($child in $bridges){
        $childId=[int]$child.ProcessId
        $parentId=[int]$child.ParentProcessId
        $started=$null; $age=$null
        try {
            $started=([DateTime]$child.CreationDate).ToUniversalTime()
            $age=[Math]::Max(0,[int][Math]::Floor(($now-$started).TotalMinutes))
        }catch{}
        $parentName='unknown'
        $parentState='not-running'
        if($byId.ContainsKey($parentId)){
            $parent=$byId[$parentId]
            $parentName=([string]$parent.Name).ToLowerInvariant()
            $parentState='alive'
            try {
                if($started -ne $null -and ([DateTime]$parent.CreationDate).ToUniversalTime() -gt $started){
                    $parentState='pid-reused'
                }
            }catch{
                $parentState='timestamp-unverified'
            }
        }
        $exeClassification='unverified'
        try {
            $actualPath=[string]$child.ExecutablePath
            if([string]::IsNullOrWhiteSpace($actualPath)){
                $exeClassification='inaccessible'
            }elseif([string]::IsNullOrWhiteSpace($expectedExe)){
                $exeClassification='registered-manifest-unavailable'
            }elseif([string]::Equals([IO.Path]::GetFullPath($actualPath),$expectedExe,
                   [StringComparison]::OrdinalIgnoreCase)){
                $exeClassification='registered-executable'
            }else{
                $exeClassification='different-executable'
            }
        }catch{
            $exeClassification='inaccessible'
        }
        $workingMB=$null
        try{
            if($null -ne $child.WorkingSetSize){
                $workingMB=[Math]::Round([double]$child.WorkingSetSize/1MB,1)
            }
        }catch{}
        $rows.Add([ordered]@{
            pid=$childId
            session_id=[int]$child.SessionId
            age_minutes=$age
            parent_pid=$parentId
            parent_name=$parentName
            parent_state=$parentState
            executable_class=$exeClassification
            working_set_mb=$workingMB
            chrome_port_connection='NOT_VERIFIED'
        })
    }
    $oldest=$null
    $knownAges=@($rows.ToArray()|Where-Object {$null -ne $_.age_minutes}|ForEach-Object {$_.age_minutes})
    if($knownAges.Count -gt 0){$oldest=($knownAges|Measure-Object -Maximum).Maximum}
    $parentMissing=@($rows.ToArray()|Where-Object {$_.parent_state -eq 'not-running'}).Count
    $parentReused=@($rows.ToArray()|Where-Object {$_.parent_state -eq 'pid-reused'}).Count
    $differentExe=@($rows.ToArray()|Where-Object {$_.executable_class -eq 'different-executable'}).Count
    return [ordered]@{
        bridge_count=$bridges.Count
        desktop_count=$desktop.Count
        chrome_process_count=$chrome.Count
        oldest_bridge_minutes=$oldest
        bridge_parent_not_running=$parentMissing
        bridge_parent_pid_reused=$parentReused
        bridge_different_executable=$differentExe
        bridges=@($rows.ToArray())
        interpretation='Parent alive does not prove Chrome Native Messaging port alive; parent missing does not prove leaked process.'
    }
}

try {
    $registered=Read-RegisteredBridgePath
    $processes=@(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
    $report=[ordered]@{
        gate='G4C-1B'
        inspection='READ_ONLY'
        mutation='NONE'
        cutover='HOLD'
        timestamp_utc=[DateTime]::UtcNow.ToString('o')
        registered_bridge_manifest=$(if($null -eq $registered){'UNVERIFIED'}else{'READABLE'})
        process_lineage=(Safe-ProcessState $processes $registered)
        source_notes='No raw command lines, executable paths, extension IDs, browser URLs or user conversations captured.'
        next_gate='G4C-2/HOLD until lifecycle attribution and rollback plan'
    }
    $report | ConvertTo-Json -Depth 8
    Write-Host 'G4C1B_READONLY_BRIDGE_DIAGNOSTIC_PASS'
    Write-Host 'G4C_PRODUCT_RELEASE=HOLD'
}catch{
    Write-Host ('G4C1B_DIAGNOSTIC_HOLD_CLASS='+$_.Exception.GetType().Name)
    Write-Host 'G4C1B_DIAGNOSTIC_HOLD'
    exit 2
}
