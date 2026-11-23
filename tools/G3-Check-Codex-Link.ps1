# G3 read-only check: exact local Codex thread link on Windows.
# This script never edits Codex settings, the transcript, or Finish Alert.
# Only an explicit OPEN response launches a vetted codex://threads/<UUID> link.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
try {
    $inputLink = [string](Read-Host 'Paste Copy deeplink from the selected Codex Desktop local conversation')
    $inputLink = $inputLink.Trim()
    $pattern = '^codex://threads/([0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$'
    $match = [regex]::Match($inputLink, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) {
        Write-Host 'G3_CODEX_DEEPLINK_FORMAT_HOLD'
        exit 2
    }
    $threadId = $match.Groups[1].Value.ToLowerInvariant()
    Write-Host 'G3_CODEX_DEEPLINK_FORMAT_PASS'

    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
    $sessionRoot = Join-Path $codexHome 'sessions'
    if (-not (Test-Path -LiteralPath $sessionRoot -PathType Container)) {
        Write-Host 'G3_CODEX_SESSION_FOLDER_NOT_FOUND'
        exit 2
    }
    $filenameFilter = 'rollout-*-' + $threadId + '.jsonl'
    $candidates = @(Get-ChildItem -LiteralPath $sessionRoot -Recurse -File -Filter $filenameFilter -ErrorAction SilentlyContinue |
        Select-Object -First 5)
    if ($candidates.Count -eq 0) {
        Write-Host 'G3_CODEX_SESSION_FILENAME_NOT_FOUND'
        exit 2
    }
    $found = $false
    foreach ($candidate in $candidates) {
        try {
            # The first metadata line only; no transcript body is read or printed.
            $firstLine = Get-Content -LiteralPath $candidate.FullName -TotalCount 1 -Encoding UTF8 -ErrorAction Stop
            $metadata = $firstLine | ConvertFrom-Json -ErrorAction Stop
            if ($metadata.type -eq 'session_meta' -and
                [string]$metadata.payload.id -ieq $threadId) {
                $found = $true
                break
            }
        } catch {
            # A mismatched or unreadable candidate cannot authorize navigation.
        }
    }
    if (-not $found) {
        Write-Host 'G3_CODEX_SESSION_META_ID_HOLD'
        exit 2
    }
    Write-Host 'G3_CODEX_SESSION_META_ID_PASS'

    $registration = Get-Item -LiteralPath 'Registry::HKEY_CLASSES_ROOT\codex' -ErrorAction SilentlyContinue
    $registered = $false
    if ($null -ne $registration) {
        $registered = @($registration.GetValueNames()) -contains 'URL Protocol'
    }
    if (-not $registered) {
        Write-Host 'G3_CODEX_URL_HANDLER_NOT_REGISTERED'
        Write-Host 'HOLD: codex:// handler is unavailable; nothing was opened.'
        exit 2
    }
    Write-Host 'G3_CODEX_URL_HANDLER_REGISTERED'

    $answer = Read-Host 'Type OPEN to test this exact Codex thread; press Enter to cancel'
    if ($answer -cne 'OPEN') {
        Write-Host 'G3_CODEX_LINK_OPEN_CANCELLED_NO_CHANGES'
        exit 0
    }
    Start-Process -FilePath ('codex://threads/' + $threadId) -ErrorAction Stop
    Write-Host 'G3_CODEX_LINK_DISPATCHED_USER_VISUAL_CONFIRMATION_REQUIRED'
} catch {
    # Do not print paths, links or exception content.
    Write-Host 'G3_CODEX_LINK_CHECK_HOLD'
    exit 2
}
