# Codex Finish Alert / G1 development candidate.
# Stop Hook input: JSON on stdin. No logs, network, or changes to Codex settings.
# This script becomes active ONLY after G0 inspection and an explicit cutover.
[CmdletBinding()]
param(
    [string]$SyntheticInput = '',
    [switch]$DryRun,
    [switch]$DoNotStartDesktop
)
$ErrorActionPreference = 'Stop'

function ConvertTo-Delivery {
    param([object]$Hook)
    if ($null -eq $Hook -or [string]$Hook.hook_event_name -cne 'Stop') { return $null }
    if ($Hook.stop_hook_active -eq $true) { return $null }
    $session = [string]$Hook.session_id
    $turn = [string]$Hook.turn_id
    if ($session -cnotmatch '^[A-Za-z0-9_-]{6,128}$' -or $turn -cnotmatch '^[A-Za-z0-9_-]{4,128}$') { return $null }
    $cwd = [string]$Hook.cwd
    $name = if ($cwd) { [IO.Path]::GetFileName($cwd.TrimEnd([char[]]@([char]'\',[char]'/'))) } else { '' }
    $name = [regex]::Replace([string]$name, '[\x00-\x1f\x7f]', '').Trim()
    if ($name.Length -gt 100) { $name = $name.Substring(0, 100) }
    if (-not $name) { $name = 'Codex' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $idBytes = [Text.Encoding]::UTF8.GetBytes($session + [char]0 + $turn)
        $hash = [BitConverter]::ToString($sha.ComputeHash($idBytes)).Replace('-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
    $eventId = 'codex-' + $hash.Substring(0, 32)
    # Thread deep link is NOT inferred from session_id; this requires G3 validation.
    return [ordered]@{
        version = 3
        type = 'deliver'
        event = [ordered]@{
            version = 3
            source = 'codex'
            eventId = $eventId
            chatTitle = $name
            completedAt = [DateTime]::UtcNow.ToString('o')
            openTarget = $null
        }
        soundId = 'leo'
        soundVolume = 85
    }
}

try {
    $raw = if ($SyntheticInput) {
        [IO.File]::ReadAllText((Resolve-Path -LiteralPath $SyntheticInput).Path, [Text.Encoding]::UTF8)
    } else {
        [Console]::In.ReadToEnd()
    }
    if ($raw.Length -gt 65536 -or [string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $hook = $raw | ConvertFrom-Json -ErrorAction Stop
    $delivery = ConvertTo-Delivery -Hook $hook
    if ($null -eq $delivery) { exit 0 }
    $json = ConvertTo-Json -InputObject $delivery -Depth 8 -Compress
    if ($DryRun) { Write-Output $json; exit 0 }

    $sessionId = [Diagnostics.Process]::GetCurrentProcess().SessionId
    $pipeName = 'corsenne_finish_alert_v2_' + $sessionId
    $pipe = New-Object IO.Pipes.NamedPipeClientStream('.', $pipeName, [IO.Pipes.PipeDirection]::InOut)
    try {
        try { $pipe.Connect(400) }
        catch {
            if ($DoNotStartDesktop) { exit 0 }
            $exe = Join-Path $env:LOCALAPPDATA 'FinishAlertDesktop\bin\finish-alert-desktop.exe'
            if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { exit 0 }
            Start-Process -FilePath $exe -WindowStyle Hidden | Out-Null
            $pipe.Connect(1400)
        }
        $pipe.ReadTimeout = 1400
        $pipe.WriteTimeout = 1400
        $utf8 = New-Object Text.UTF8Encoding($false)
        $writer = New-Object IO.StreamWriter($pipe, $utf8, 1024, $true)
        $reader = New-Object IO.StreamReader($pipe, $utf8, $false, 1024, $true)
        try {
            $writer.WriteLine($json)
            $writer.Flush()
            # A failed/late ACK never launches a second notification renderer.
            $ack = $reader.ReadLine()
            if ($ack -and $ack.Length -le 8192) {
                $reply = $ack | ConvertFrom-Json
                if ($reply.type -eq 'delivery.ack' -and $reply.eventId -eq $delivery.event.eventId) { exit 0 }
            }
        } finally { $reader.Dispose(); $writer.Dispose() }
    } finally { $pipe.Dispose() }
} catch {
    # A hook must never block Codex completion or expose private data in stderr.
    exit 0
}
exit 0
