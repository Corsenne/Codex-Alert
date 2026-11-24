# Synthetic Windows PowerShell 5.1 test; uses DryRun only and never connects.
$ErrorActionPreference='Stop'
$relay=Join-Path $PSScriptRoot '..\src\Codex-Stop-Relay.ps1'
$dir=Join-Path $env:TEMP ('codex-alert-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
try{
    $hook=@{hook_event_name='Stop';session_id='01a1d17b-189a-7aa3-b85f-2d9f310e040a';turn_id='turn-0001';cwd='C:\Work\TALOS';stop_hook_active=$false;last_assistant_message='PRIVATE TEST PHRASE'}
    $file=Join-Path $dir 'stop.json'
    $hook | ConvertTo-Json | Set-Content -LiteralPath $file -Encoding UTF8
    $outputs=@(& $relay -SyntheticInput $file -DryRun)
    if ($outputs.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$outputs[0])) {
        throw 'G1_DRYRUN_NO_PIPELINE_OUTPUT'
    }
    $raw=[string]$outputs[0]
    try { $msg=$raw | ConvertFrom-Json -ErrorAction Stop }
    catch { throw 'G1_DRYRUN_INVALID_JSON' }
    if($msg.version -ne 3 -or $msg.event.source -ne 'codex' -or $msg.event.chatTitle -ne 'TALOS' -or $msg.soundId -ne 'leo'){throw 'G1_EVENT_MAPPING_MISMATCH'}
    if($raw.Contains('PRIVATE TEST PHRASE') -or $raw.Contains('C:\Work\TALOS')){throw 'G1_PRIVATE_HOOK_CONTENT_ESCAPED'}
    $repeatOutput=@(& $relay -SyntheticInput $file -DryRun)
    if($repeatOutput.Count -ne 1){throw 'G1_REPLAY_DRYRUN_OUTPUT_COUNT_FAILED'}
    $again=$repeatOutput[0] | ConvertFrom-Json -ErrorAction Stop
    if($again.event.eventId -ne $msg.event.eventId){throw 'G1_EVENT_ID_NONDETERMINISTIC'}
    $hook.hook_event_name='PermissionRequest';$hook|ConvertTo-Json|Set-Content -LiteralPath $file -Encoding UTF8
    if(@(& $relay -SyntheticInput $file -DryRun).Count -ne 0){throw 'approval event emitted'}
    $hook.hook_event_name='Stop';$hook.stop_hook_active=$true;$hook|ConvertTo-Json|Set-Content -LiteralPath $file -Encoding UTF8
    if(@(& $relay -SyntheticInput $file -DryRun).Count -ne 0){throw 'reentrant event emitted'}
    Write-Host 'G1_RELAY_SYNTHETIC_PASS'
}finally{Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue}
