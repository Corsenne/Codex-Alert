# G3 candidate, DRY-RUN ONLY. Never register as active Codex Stop hook.
[CmdletBinding()]
param([string]$SyntheticInput='', [switch]$DryRun, [string]$CodexHome='')
$ErrorActionPreference='Stop'
function Resolve-Link([object]$Hook,[string]$HomeDir){
    $id=([string]$Hook.session_id).ToLowerInvariant()
    $regex='^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    if($id -cnotmatch $regex){return $null}
    $original=[string]$Hook.transcript_path
    if(-not $original -or -not [IO.Path]::IsPathRooted($original)){return $null}
    try{
        $root=([IO.Path]::GetFullPath((Join-Path $HomeDir 'sessions'))).TrimEnd('\','/')+'\'
        $path=[IO.Path]::GetFullPath($original)
        if(-not $path.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){return $null}
        $filename=[IO.Path]::GetFileName($path)
        if(-not $filename.ToLowerInvariant().EndsWith('-'+$id+'.jsonl')){return $null}
        if($filename -notmatch '^rollout-[0-9T-]+-[0-9a-f-]{36}\.jsonl$'){return $null}
        if(-not (Test-Path -LiteralPath $path -PathType Leaf)){return $null}
        $line=Get-Content -LiteralPath $path -TotalCount 1 -Encoding UTF8
        $meta=$line | ConvertFrom-Json -ErrorAction Stop
        if($meta.type -cne 'session_meta' -or [string]$meta.payload.id -ine $id){return $null}
        return 'codex://threads/'+$id
    }catch{return $null}
}
function Map-Stop([object]$Hook,[string]$HomeDir){
    if($null -eq $Hook -or [string]$Hook.hook_event_name -cne 'Stop' -or $Hook.stop_hook_active -eq $true){return $null}
    $session=[string]$Hook.session_id
    $turn=[string]$Hook.turn_id
    if($session -cnotmatch '^[A-Za-z0-9_-]{6,128}$' -or $turn -cnotmatch '^[A-Za-z0-9_-]{4,128}$'){return $null}
    $name=([IO.Path]::GetFileName(([string]$Hook.cwd).TrimEnd('\','/'))).Trim()
    $name=[regex]::Replace($name,'[\x00-\x1f\x7f]','')
    if($name.Length -gt 100){$name=$name.Substring(0,100)}
    if(-not $name){$name='Codex'}
    $sha=[Security.Cryptography.SHA256]::Create()
    try{$bytes=[Text.Encoding]::UTF8.GetBytes($session+[char]0+$turn)
        $hash=[BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant()
    }finally{$sha.Dispose()}
    [ordered]@{version=3;type='deliver';event=[ordered]@{
        version=3;source='codex';eventId=('codex-'+$hash.Substring(0,32))
        chatTitle=$name;completedAt=[DateTime]::UtcNow.ToString('o')
        openTarget=(Resolve-Link $Hook $HomeDir)
    };soundId='leo';soundVolume=85}
}
try{
    if(-not $DryRun){throw 'G3_NOT_A_LIVE_HOOK'}
    $raw=if($SyntheticInput){[IO.File]::ReadAllText((Resolve-Path -LiteralPath $SyntheticInput).Path,[Text.Encoding]::UTF8)}else{[Console]::In.ReadToEnd()}
    if([string]::IsNullOrWhiteSpace($raw) -or $raw.Length -gt 65536){throw 'G3_INPUT_INVALID'}
    $hook=$raw|ConvertFrom-Json -ErrorAction Stop
    $homeDir=if($CodexHome){$CodexHome}else{if($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $env:USERPROFILE '.codex'}}
    $msg=Map-Stop $hook $homeDir
    if($null -ne $msg){Write-Output (ConvertTo-Json -InputObject $msg -Depth 8 -Compress)}
}catch{
    # No secret output or hook mutation. Synthetic tests inspect output.
    exit 2
}
