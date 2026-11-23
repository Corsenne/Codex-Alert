# G4C4 synthetic-only source test; never modifies real hooks or starts desktop.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$adapter=Join-Path $repo 'candidate-g4\Codex-Stop-to-G4.ps1'
$work=Join-Path $env:TEMP ('G4C4-Test-'+[guid]::NewGuid().ToString('N'))
$id='019d25ff-3701-75d1-b331-160b90f8a456'
try{
    $sessions=Join-Path $work 'codex\sessions\2026\11\23'
    New-Item -ItemType Directory -Path $sessions -Force|Out-Null
    $file=Join-Path $sessions ('rollout-2026-11-23T01-02-03-'+$id+'.jsonl')
    $meta=@{type='session_meta';payload=@{id=$id}}|ConvertTo-Json -Compress
    [IO.File]::WriteAllText($file,$meta+[Environment]::NewLine+'PRIVATE TRANSCRIPT NOT READ'+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
    $hookFile=Join-Path $work 'hook.json'
    $msg=@{hook_event_name='Stop';stop_hook_active=$false;session_id=$id;
        turn_id='turn-01';cwd='C:\Work\TALOS';transcript_path=$file}
    $msg|ConvertTo-Json -Compress|Set-Content -LiteralPath $hookFile -Encoding UTF8
    $codexRoot=Join-Path $work 'codex'
    $valid=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $adapter -DryRun -SyntheticInput $hookFile -CodexHome $codexRoot)
    if($LASTEXITCODE -ne 0 -or $valid.Count -ne 1){throw 'G4C4_DRYRUN_NOT_ONE_EVENT'}
    $event=$valid[0]|ConvertFrom-Json
    $checks=[ordered]@{
        version=($event.version -eq 3)
        type=($event.type -ceq 'deliver')
        source=($event.event.source -ceq 'codex')
        exact_thread=($event.event.openTarget -ceq ('codex://threads/'+$id))
        transcript_proof=($event.event.transcriptPath -ceq $file)
        title=($event.event.chatTitle -ceq 'TALOS')
        voice=($event.soundId -ceq 'leo')
    }
    foreach($c in $checks.Keys){Write-Host ('G4C4_CHECK_'+$c.ToUpperInvariant()+'='+$checks[$c])}
    if(-not $checks.transcript_proof){
        $from=[string]$event.event.transcriptPath
        Write-Host ('G4C4_DIAG_PATH_PRESENT='+(-not [string]::IsNullOrEmpty($from)))
        Write-Host ('G4C4_DIAG_PATH_LENGTH='+$from.Length)
        Write-Host ('G4C4_DIAG_EXPECTED_LENGTH='+$file.Length)
        Write-Host ('G4C4_DIAG_PATH_CASE_INSENSITIVE_MATCH='+[string]::Equals($from,$file,[StringComparison]::OrdinalIgnoreCase))
        Write-Host ('G4C4_DIAG_PATH_FILENAME_MATCH='+[string]::Equals([IO.Path]::GetFileName($from),[IO.Path]::GetFileName($file),[StringComparison]::OrdinalIgnoreCase))
        Write-Host ('G4C4_DIAG_ACTUAL_EXISTS='+(Test-Path -LiteralPath $from -PathType Leaf))
        $common=0
        while($common -lt [Math]::Min($from.Length,$file.Length) -and $from[$common] -ceq $file[$common]){$common++}
        Write-Host ('G4C4_DIAG_COMMON_PREFIX_LENGTH='+$common)
        $contextStart=[Math]::Max(0,$common-2)
        $aEnd=[Math]::Min($from.Length,$common+7)
        $eEnd=[Math]::Min($file.Length,$common+7)
        Write-Host ('G4C4_DIAG_ACTUAL_CHARCODES='+(($from.Substring($contextStart,$aEnd-$contextStart).ToCharArray()|ForEach-Object{[int]$_}) -join ','))
        Write-Host ('G4C4_DIAG_EXPECTED_CHARCODES='+(($file.Substring($contextStart,$eEnd-$contextStart).ToCharArray()|ForEach-Object{[int]$_}) -join ','))
        Write-Host ('G4C4_DIAG_PATH_PROPERTY_TYPE='+$(if($null -eq $event.event.transcriptPath){'NULL'}else{'SET'}))
    }
    if(@($checks.Values|Where-Object{$_ -eq $false}).Count -gt 0){throw 'G4C4_VALID_EVENT_MISMATCH'}
    Write-Host 'G4C4_VERIFIED_CODEX_SESSION_DRYRUN_PASS'
    $msg.stop_hook_active=$true
    $msg|ConvertTo-Json -Compress|Set-Content -LiteralPath $hookFile -Encoding UTF8
    $inactive=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $adapter -DryRun -SyntheticInput $hookFile -CodexHome $codexRoot)
    if($LASTEXITCODE -ne 0 -or $inactive.Count -ne 0){throw 'G4C4_REENTRANT_STOP_NOT_IGNORED'}
    Write-Host 'G4C4_STOP_REENTRY_DENIED_PASS'
    $msg.stop_hook_active=$false
    $meta=@{type='session_meta';payload=@{id='00000000-0000-7000-8000-000000000001'}}|ConvertTo-Json -Compress
    [IO.File]::WriteAllText($file,$meta+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
    $msg|ConvertTo-Json -Compress|Set-Content -LiteralPath $hookFile -Encoding UTF8
    $bad=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $adapter -DryRun -SyntheticInput $hookFile -CodexHome $codexRoot)
    if($LASTEXITCODE -ne 0 -or $bad.Count -ne 1){throw 'G4C4_UNVERIFIED_EVENT_MISSING'}
    $limited=$bad[0]|ConvertFrom-Json
    if($null -ne $limited.event.openTarget -or $null -ne $limited.event.transcriptPath){
       throw 'G4C4_UNVERIFIED_LINK_NOT_DROPPED'
    }
    Write-Host 'G4C4_UNVERIFIED_THREAD_NAVIGATION_DENIED_PASS'
    Write-Host 'G4C4_CODEX_STOP_SOURCE_PASS'
    Write-Host 'REAL_STOP_HOOK=UNCHANGED'
}finally{
    if(Test-Path -LiteralPath $work){Remove-Item -LiteralPath $work -Recurse -Force}
}
