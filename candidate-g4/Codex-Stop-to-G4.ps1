# G4C4 source: Codex Stop hook to the existing isolated G4 native FIFO.
# This script is not registered in Codex settings. It reads first-line metadata
# only, never transcript content, and never starts an extra notification app.
[CmdletBinding()]
param([switch]$DryRun,[string]$SyntheticInput='',[string]$CodexHome='')
$ErrorActionPreference='Stop'
function Resolve-Session([object]$hook,[string]$codexRoot){
    $id=([string]$hook.session_id).ToLowerInvariant()
    if($id -cnotmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'){return $null}
    $provided=[string]$hook.transcript_path
    if([string]::IsNullOrEmpty($provided) -or -not [IO.Path]::IsPathRooted($provided)){return $null}
    try{
        $root=[IO.Path]::GetFullPath((Join-Path $codexRoot 'sessions')).TrimEnd('\','/')+'\'
        $file=[IO.Path]::GetFullPath($provided)
        if(-not $file.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){return $null}
        $name=[IO.Path]::GetFileName($file)
        if(-not $name.ToLowerInvariant().EndsWith('-'+$id+'.jsonl')){return $null}
        if($name -cnotmatch '^rollout-[0-9T.Z-]+-[0-9a-f-]{36}\.jsonl$'){return $null}
        if(-not(Test-Path -LiteralPath $file -PathType Leaf)){return $null}
        $info=Get-Item -LiteralPath $file -ErrorAction Stop
        if($info.Attributes -band [IO.FileAttributes]::ReparsePoint){return $null}
        $line=Get-Content -LiteralPath $file -TotalCount 1 -Encoding UTF8 -ErrorAction Stop
        if([string]::IsNullOrEmpty($line) -or $line.Length -ge 65536){return $null}
        $meta=$line|ConvertFrom-Json -ErrorAction Stop
        if($meta.type -cne 'session_meta' -or ([string]$meta.payload.id).ToLowerInvariant() -cne $id){return $null}
        return [pscustomobject]@{uri=('codex://threads/'+$id);file=$file}
    }catch{return $null}
}
function Make-Message([object]$hook,[string]$codexRoot){
    if($null -eq $hook -or [string]$hook.hook_event_name -cne 'Stop' -or $hook.stop_hook_active -eq $true){return $null}
    $session=[string]$hook.session_id
    $turn=[string]$hook.turn_id
    if($session -cnotmatch '^[A-Za-z0-9_-]{6,128}$' -or $turn -cnotmatch '^[A-Za-z0-9_-]{4,128}$'){return $null}
    $cwd=[string]$hook.cwd
    $name=if([string]::IsNullOrWhiteSpace($cwd)){'Codex'}else{[IO.Path]::GetFileName($cwd.TrimEnd('\','/'))}
    $name=[regex]::Replace([string]$name,'[\x00-\x1f\x7f]','').Trim()
    if(-not $name){$name='Codex'}
    if($name.Length -gt 100){$name=$name.Substring(0,100)}
    $sha=[Security.Cryptography.SHA256]::Create()
    try{
        $bytes=[Text.Encoding]::UTF8.GetBytes($session+[char]0+$turn)
        $hex=[BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant()
    }finally{$sha.Dispose()}
    $record=Resolve-Session $hook $codexRoot
    $event=[ordered]@{
        version=3;source='codex';eventId=('codex-'+$hex.Substring(0,32))
        chatTitle=$name;completedAt=[DateTime]::UtcNow.ToString('o')
        openTarget=$(if($record){$record.uri}else{$null})
    }
    if($record){$event['transcriptPath']=$record.file}
    return [ordered]@{version=3;type='deliver';event=$event;soundId='leo';soundVolume=85}
}
$pipe=$null;$writer=$null;$reader=$null
try{
    if($SyntheticInput -and -not $DryRun){throw 'SYNTHETIC_INPUT_DRY_RUN_ONLY'}
    $raw=if($SyntheticInput){
        [IO.File]::ReadAllText((Resolve-Path -LiteralPath $SyntheticInput -ErrorAction Stop).Path,[Text.Encoding]::UTF8)
    }else{[Console]::In.ReadToEnd()}
    if([string]::IsNullOrWhiteSpace($raw) -or $raw.Length -gt 65536){throw 'INVALID_INPUT'}
    $hook=$raw|ConvertFrom-Json -ErrorAction Stop
    $codexRoot=if($CodexHome){$CodexHome}elseif($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $env:USERPROFILE '.codex'}
    $msg=Make-Message $hook $codexRoot
    if($null -eq $msg){exit 0}
    if($DryRun){Write-Output ($msg|ConvertTo-Json -Depth 8 -Compress);exit 0}
    $sessionId=[Diagnostics.Process]::GetCurrentProcess().SessionId
    $pipeName='corsenne_finish_alert_g4_test_'+$sessionId
    $pipe=[IO.Pipes.NamedPipeClientStream]::new('.', $pipeName,[IO.Pipes.PipeDirection]::InOut)
    $pipe.Connect(800)
    $pipe.ReadTimeout=1500
    $pipe.WriteTimeout=1500
    $utf8=[Text.UTF8Encoding]::new($false)
    $writer=[IO.StreamWriter]::new($pipe,$utf8,1024,$true)
    $reader=[IO.StreamReader]::new($pipe,$utf8,$false,1024,$true)
    $writer.WriteLine(($msg|ConvertTo-Json -Depth 8 -Compress))
    $writer.Flush()
    $line=$reader.ReadLine()
    if(-not $line -or $line.Length -gt 8192){throw 'ACK_TIMEOUT_OR_INVALID'}
    $ack=$line|ConvertFrom-Json -ErrorAction Stop
    if($ack.type -cne 'delivery.ack' -or $ack.ok -ne $true -or
       $ack.eventId -cne $msg.event.eventId -or
       @('active','queued','duplicate') -cnotcontains [string]$ack.state){throw 'ACK_MISMATCH'}
}catch{
    # Never block Codex on a notification failure; no private paths in output.
    if($DryRun){exit 2}
}finally{
    if($null -ne $reader){$reader.Dispose()}
    if($null -ne $writer){$writer.Dispose()}
    if($null -ne $pipe){$pipe.Dispose()}
}
exit 0
