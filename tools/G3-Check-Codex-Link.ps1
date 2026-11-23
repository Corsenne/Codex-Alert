# G3 read-only Codex exact-thread deep-link check.
# No logging of transcript contents, names, paths, clipboard or credentials.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
try {
    $inputLink = (Read-Host 'Paste the copied deep link from the currently selected Codex Desktop local thread').Trim()
    $uuidPattern='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}'
    $matcher=[regex]::new(('^codex://threads/('+$uuidPattern+')
    Write-Host 'G3_CODEX_DEEPLINK_FORMAT_PASS'
    $homeDir=if($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $env:USERPROFILE '.codex'}
    $sessionRoot=Join-Path $homeDir 'sessions'
    if(-not (Test-Path -LiteralPath $sessionRoot -PathType Container)){
        Write-Host 'G3_CODEX_SESSION_FOLDER_NOT_FOUND'
        exit 2
    }
    $candidates=@(Get-ChildItem -LiteralPath $sessionRoot -Recurse -File -Filter ('rollout-*-'+$threadId+'.jsonl') -ErrorAction SilentlyContinue | Select-Object -First 3)
    if($candidates.Count -eq 0){Write-Host 'G3_CODEX_SESSION_FILENAME_NOT_FOUND';exit 2}
    $found=$false
    foreach($f in $candidates){
        try {
            # Only read and parse the very first metadata line. Never print transcript contents.
            $first=Get-Content -LiteralPath $f.FullName -TotalCount 1 -Encoding UTF8 -ErrorAction Stop
            $meta=$first|ConvertFrom-Json -ErrorAction Stop
            if($meta.type -eq 'session_meta' -and [string]$meta.payload.id -ieq $threadId){$found=$true;break}
        } catch {}
    }
    if(-not $found){Write-Host 'G3_CODEX_SESSION_META_ID_HOLD';exit 2}
    Write-Host 'G3_CODEX_SESSION_META_ID_PASS'
    $handler=Get-ItemProperty -Path 'Registry::HKEY_CLASSES_ROOT\codex' -ErrorAction SilentlyContinue
    $installed=($null -ne $handler -and $null -ne $handler.'URL Protocol')
    if(-not $installed){
        Write-Host 'G3_CODEX_URL_HANDLER_NOT_REGISTERED'
        Write-Host 'HOLD: No automatic open attempt. This PC may lack a registered codex:// handler.'
        exit 2
    }
    Write-Host 'G3_CODEX_URL_HANDLER_REGISTERED'
    $answer=Read-Host 'Type OPEN to test opening this exact chat in the Codex Desktop app (or Enter to cancel)'
    if($answer -cne 'OPEN'){
        Write-Host 'G3_CODEX_LINK_OPEN_CANCELLED_NO_CHANGES'
        exit 0
    }
    Start-Process -FilePath ('codex://threads/'+$threadId) -ErrorAction Stop
    Write-Host 'G3_CODEX_LINK_DISPATCHED_USER_VISUAL_CONFIRMATION_REQUIRED'
}catch {
    Write-Host 'G3_CODEX_LINK_CHECK_HOLD'
    exit 2
}
),[Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $matched=$matcher.Match($inputLink)
    if(-not $matched.Success) {
        Write-Host 'G3_CODEX_DEEPLINK_FORMAT_HOLD'
        exit 2
    }
    $threadId=$matched.Groups[1].Value.ToLowerInvariant()
    Write-Host 'G3_CODEX_DEEPLINK_FORMAT_PASS'
    $homeDir=if($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $env:USERPROFILE '.codex'}
    $sessionRoot=Join-Path $homeDir 'sessions'
    if(-not (Test-Path -LiteralPath $sessionRoot -PathType Container)){
        Write-Host 'G3_CODEX_SESSION_FOLDER_NOT_FOUND'
        exit 2
    }
    $candidates=@(Get-ChildItem -LiteralPath $sessionRoot -Recurse -File -Filter ('rollout-*-'+$threadId+'.jsonl') -ErrorAction SilentlyContinue | Select-Object -First 3)
    if($candidates.Count -eq 0){Write-Host 'G3_CODEX_SESSION_FILENAME_NOT_FOUND';exit 2}
    $found=$false
    foreach($f in $candidates){
        try {
            # Only read and parse the very first metadata line. Never print transcript contents.
            $first=Get-Content -LiteralPath $f.FullName -TotalCount 1 -Encoding UTF8 -ErrorAction Stop
            $meta=$first|ConvertFrom-Json -ErrorAction Stop
            if($meta.type -eq 'session_meta' -and [string]$meta.payload.id -ieq $threadId){$found=$true;break}
        } catch {}
    }
    if(-not $found){Write-Host 'G3_CODEX_SESSION_META_ID_HOLD';exit 2}
    Write-Host 'G3_CODEX_SESSION_META_ID_PASS'
    $handler=Get-ItemProperty -Path 'Registry::HKEY_CLASSES_ROOT\codex' -ErrorAction SilentlyContinue
    $installed=($null -ne $handler -and $null -ne $handler.'URL Protocol')
    if(-not $installed){
        Write-Host 'G3_CODEX_URL_HANDLER_NOT_REGISTERED'
        Write-Host 'HOLD: No automatic open attempt. This PC may lack a registered codex:// handler.'
        exit 2
    }
    Write-Host 'G3_CODEX_URL_HANDLER_REGISTERED'
    $answer=Read-Host 'Type OPEN to test opening this exact chat in the Codex Desktop app (or Enter to cancel)'
    if($answer -cne 'OPEN'){
        Write-Host 'G3_CODEX_LINK_OPEN_CANCELLED_NO_CHANGES'
        exit 0
    }
    Start-Process -FilePath ('codex://threads/'+$threadId) -ErrorAction Stop
    Write-Host 'G3_CODEX_LINK_DISPATCHED_USER_VISUAL_CONFIRMATION_REQUIRED'
}catch {
    Write-Host 'G3_CODEX_LINK_CHECK_HOLD'
    exit 2
}
