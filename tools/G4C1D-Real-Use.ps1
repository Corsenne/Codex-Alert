# G4C-1D — read-only real-use Chrome notification repetition / bridge-process samples.
# No hook/registry/file mutation, no Chrome process termination, no synthesized completion.
[CmdletBinding()]
param([ValidateSet('Manual','Snapshot')][string]$Mode='Manual')
$ErrorActionPreference = 'Stop'

function Get-AlertSnapshot {
    $all=@(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
    $chrome=@($all|Where-Object {$_.Name -ieq 'chrome.exe'})
    $bridges=@($all|Where-Object {$_.Name -ieq 'finish-alert-bridge.exe'})
    $desktop=@($all|Where-Object {$_.Name -ieq 'finish-alert-desktop.exe'})
    $rows=New-Object 'System.Collections.Generic.List[object]'
    foreach($b in $bridges){
        $started=$null
        try{$started=([DateTime]$b.CreationDate).ToUniversalTime()}catch{}
        $age=$null
        if($null -ne $started){$age=[int][Math]::Max(0,[Math]::Floor(([DateTime]::UtcNow-$started).TotalMinutes))}
        $mem=$null
        if($null -ne $b.WorkingSetSize){$mem=[Math]::Round(([double]$b.WorkingSetSize/1MB),1)}
        $rows.Add([pscustomobject]@{
            process_id=[int]$b.ProcessId
            age_minutes=$age
            working_set_mb=$mem
            # PID+creation timestamp prevents a reused PID from looking identical.
            identity=('{0}:{1}' -f [int]$b.ProcessId,$(if($started){$started.Ticks}else{'unknown'}))
        })
    }
    return [pscustomobject]@{
        chrome_processes=$chrome.Count
        bridge_processes=$bridges.Count
        desktop_processes=$desktop.Count
        bridge_details=@($rows.ToArray())
    }
}
function Show-Snapshot([string]$label,$sample){
    $details=@($sample.bridge_details|Sort-Object process_id)
    Write-Host ('G4C1D_'+$label+'_CHROME='+$sample.chrome_processes)
    Write-Host ('G4C1D_'+$label+'_BRIDGES='+$sample.bridge_processes)
    Write-Host ('G4C1D_'+$label+'_DESKTOP='+$sample.desktop_processes)
    if($details.Count -gt 0){
        Write-Host ('G4C1D_'+$label+'_PID_AGE_MEM='+(
            ($details|ForEach-Object{
                '{0}/{1}m/{2}MB' -f $_.process_id,$_.age_minutes,$_.working_set_mb
            }) -join ','
        ))
    }
}
try{
    Write-Host ('G4C1D_MODE='+$Mode)
    Write-Host 'G4C1D_PRODUCT_MUTATION=NONE'
    $baseline=Get-AlertSnapshot
    Show-Snapshot 'BASELINE' $baseline
    if($Mode -eq 'Snapshot'){
        Write-Host 'G4C1D_SNAPSHOT_PASS_NO_MUTATION'
        exit 0
    }
    if($baseline.chrome_processes -eq 0){
        Write-Host 'G4C1D_HOLD_CHROME_NOT_RUNNING'
        exit 2
    }
    $responses=New-Object 'System.Collections.Generic.List[string]'
    $snapshots=New-Object 'System.Collections.Generic.List[object]'
    $snapshots.Add($baseline)
    Write-Host 'Use the INSTALLED STABLE Finish Alert v1.1.5. Do NOT load a second completion observer.'
    Write-Host 'For each of 3 real ChatGPT replies: observe one banner, one voice, and exact-chat click return.'
    Write-Host 'Return to this PowerShell window after checking the notification. Nothing is auto-sent to ChatGPT.'
    for($i=1;$i -le 3;$i++){
        $mark=[string](Read-Host ('After REAL ChatGPT reply '+$i+' and checking banner/voice/click, type PASS, FAIL, or STOP'))
        $mark=$mark.Trim().ToUpperInvariant()
        if($mark -eq 'STOP'){
            Write-Host 'G4C1D_OPERATOR_STOP_NO_MUTATION'
            exit 0
        }
        if($mark -cnotin @('PASS','FAIL')){
            Write-Host 'G4C1D_HOLD_INVALID_OPERATOR_RESULT'
            exit 2
        }
        $snap=Get-AlertSnapshot
        $responses.Add($mark)
        $snapshots.Add($snap)
        Show-Snapshot ('AFTER_'+$i) $snap
        Write-Host ('G4C1D_AFTER_'+$i+'_VISUAL='+$mark)
    }
    $identitySets=@($snapshots|ForEach-Object {
        @($_.bridge_details|ForEach-Object{$_.identity})
    })
    $baselineKeys=@($baseline.bridge_details|ForEach-Object{$_.identity})
    $last=$snapshots[$snapshots.Count-1]
    $newKeys=@($last.bridge_details|Where-Object{
        $baselineKeys -cnotcontains $_.identity
    }).Count
    $maxCount=($snapshots.ToArray()|Measure-Object -Property bridge_processes -Maximum).Maximum
    $visualPassed=(@($responses|Where-Object{$_ -eq 'PASS'}).Count -eq 3)
    Write-Host ('G4C1D_MAX_BRIDGES_OBSERVED='+$maxCount)
    Write-Host ('G4C1D_FINAL_NEW_BRIDGE_IDENTITIES='+$newKeys)
    Write-Host ('G4C1D_VISUAL_3_OF_3_PASS='+$visualPassed)
    Write-Host 'G4C1D_SAMPLES_COLLECTED_PASS'
    Write-Host 'G4C1D_IDLE_RETIREMENT_NOT_TESTED'
    Write-Host 'G4C1D_PRODUCT_CUTOVER=HOLD'
    if(-not $visualPassed){Write-Host 'G4C1D_VISUAL_REGRESSION_HOLD'}
}catch{
    Write-Host ('G4C1D_RUNTIME_HOLD_CLASS='+$_.Exception.GetType().Name)
    Write-Host 'G4C1D_RUNTIME_HOLD'
    exit 2
}
