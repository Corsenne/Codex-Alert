# Synthetic Windows PowerShell 5.1 test; uses DryRun only and never connects.
$ErrorActionPreference='Stop'
$relay=Join-Path $PSScriptRoot '..\src\Codex-Stop-Relay.ps1'
$dir=Join-Path $env:TEMP ('codex-alert-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
try{
    $hook=@{hook_event_name='Stop';session_id='01a1d17b-189a-7aa3-b85f-2d9f310e040a';turn_id='turn-0001';cwd='C:\Work\TALOS';stop_hook_active=$false;last_assistant_message='PRIVATE TEST PHRASE'}
    $file=Join-Path $dir 'stop.json'
    $hook | ConvertTo-Json | Set-Content -LiteralPath $file -Encoding UTF8
    $raw=& $relay -SyntheticInput $file -DryRun
    $msg=$raw|ConvertFrom-Json
    if($msg.version -ne 3 -or $msg.event.source -ne 'codex' -or $msg.event.chatTitle -ne 'TALOS' -or $msg.soundId -ne 'leo'){throw 'mapping failed'}
    if($raw -match 'PRIVATE TEST PHRASE' -or $raw -match 'C:\\Work\\TALOS'){throw 'sensitive payload leaked'}
    $again=& $relay -SyntheticInput $file -DryRun | ConvertFrom-Json
    if($again.event.eventId -ne $msg.event.eventId){throw 'nondeterministic event ID'}
    $hook.hook_event_name='PermissionRequest';$hook|ConvertTo-Json|Set-Content -LiteralPath $file -Encoding UTF8
    if(@(& $relay -SyntheticInput $file -DryRun).Count -ne 0){throw 'approval event emitted'}
    $hook.hook_event_name='Stop';$hook.stop_hook_active=$true;$hook|ConvertTo-Json|Set-Content -LiteralPath $file -Encoding UTF8
    if(@(& $relay -SyntheticInput $file -DryRun).Count -ne 0){throw 'reentrant event emitted'}
    Write-Host 'G1_RELAY_SYNTHETIC_PASS'
}finally{Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue}
