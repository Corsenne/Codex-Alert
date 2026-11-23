$ErrorActionPreference='Stop'
$relay=Join-Path $PSScriptRoot '..\candidate-g3\Codex-Stop-Relay.ps1'
$root=Join-Path $env:TEMP ('codex-g3-test-'+[guid]::NewGuid().ToString('N'))
$id='019d25ff-3701-75d1-b331-160b90f8a456'
$rollout=Join-Path $root ('sessions\2026\11\23\rollout-2026-11-23T12-40-12-'+$id+'.jsonl')
$inputFile=Join-Path $root 'synthetic-hook.json'
try{
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $rollout)|Out-Null
    $line=@{type='session_meta';payload=@{id=$id}}|ConvertTo-Json -Compress -Depth 4
    [IO.File]::WriteAllText($rollout,$line+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
    $hook=@{hook_event_name='Stop';session_id=$id;turn_id='turn-0001';cwd='C:\Dev\TALOS';transcript_path=$rollout;stop_hook_active=$false;last_assistant_message='SECRET CONTENT'}
    $hook|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $inputFile -Encoding UTF8
    $out=@(& $relay -SyntheticInput $inputFile -CodexHome $root -DryRun)
    if($out.Count -ne 1){throw 'G3_NO_DRYRUN_OUTPUT'}
    $msg=$out[0]|ConvertFrom-Json
    if($msg.event.openTarget -ne ('codex://threads/'+$id)){throw 'G3_VERIFIED_LINK_NOT_EMITTED'}
    if($msg.soundId -ne 'leo' -or $msg.event.source -ne 'codex'){throw 'G3_MAPPING_INVALID'}
    if($out[0].Contains('SECRET CONTENT') -or $out[0].Contains('C:\Dev\TALOS')){throw 'G3_PRIVACY_LEAK'}
    $hook.transcript_path=$null
    $hook|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $inputFile -Encoding UTF8
    $miss=@(& $relay -SyntheticInput $inputFile -CodexHome $root -DryRun|ConvertFrom-Json)
    if($miss.Count -ne 1 -or $null -ne $miss[0].event.openTarget){throw 'G3_UNVERIFIED_LINK_NOT_REJECTED'}
    Write-Host 'G3_STOP_LINK_SYNTHETIC_PASS'
}catch{
    Write-Host ('G3_STOP_LINK_SYNTHETIC_HOLD: '+$_.Exception.Message)
    exit 2
}finally{Remove-Item -LiteralPath $root -Force -Recurse -ErrorAction SilentlyContinue}
