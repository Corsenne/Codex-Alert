# Read-only G0 inspection. Do not print hook commands, file paths or transcript data.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
function Count-Event($document,[string]$name){
    $groups=0;$handlers=0;$legacy=0
    if ($document -and $document.hooks -and $document.hooks.PSObject.Properties.Name -contains $name){
        foreach($group in @($document.hooks.$name)){
            if($null -eq $group){continue}
            $groups++
            foreach($handler in @($group.hooks)){
                if($null -eq $handler){continue}
                $handlers++
                if(([string]$handler.command+' '+[string]$handler.commandWindows) -match '(?i)codex-alert\.ps1'){$legacy++}
            }
        }
    }
    return [ordered]@{groups=$groups;handlers=$handlers;legacy_references=$legacy}
}
try{
    $homeDir=if($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $env:USERPROFILE '.codex'}
    $hooks=Join-Path $homeDir 'hooks.json'
    $toml=Join-Path $homeDir 'config.toml'
    $doc=$null;$parse='absent'
    if(Test-Path -LiteralPath $hooks -PathType Leaf){
        try{$doc=Get-Content -LiteralPath $hooks -Raw -Encoding UTF8 | ConvertFrom-Json;$parse='ok'}
        catch{$parse='error'}
    }
    $mode='unknown';$approval='unknown';$inlineStop=0;$inlinePermission=0
    if(Test-Path -LiteralPath $toml -PathType Leaf){
        $desktop=$false
        foreach($line in (Get-Content -LiteralPath $toml -Encoding UTF8)){
            if($line -match '^\s*\[\[hooks\.Stop'){$inlineStop++}
            if($line -match '^\s*\[\[hooks\.PermissionRequest'){$inlinePermission++}
            if($line -match '^\s*\[([^\]]+)\]\s*(?:#.*)?$'){$desktop=($Matches[1] -eq 'desktop');continue}
            if(-not $desktop){continue}
            if($line -match '^\s*notifications-turn-mode\s*=\s*"([^"]+)"'){$mode=$Matches[1]}
            if($line -match '^\s*notifications-permissions-enabled\s*=\s*(true|false)'){$approval=$Matches[1]}
        }
    }
    $report=[ordered]@{
        audit='G0_READONLY';mutation='NONE';hooks_json=$parse
        config_toml=$(if(Test-Path -LiteralPath $toml){'present'}else{'absent'})
        stop=(Count-Event $doc 'Stop')
        permission_request=(Count-Event $doc 'PermissionRequest')
        desktop=[ordered]@{turn_mode=$mode;permissions_enabled=$approval;inline_stop=$inlineStop;inline_permission=$inlinePermission}
        note='System, project and plugin hook layers are not included in this report.'
    }
    $report | ConvertTo-Json -Depth 9
    Write-Host 'No local files or Codex settings were changed.'
}catch{
    Write-Host 'G0 inspection failed; no changes were made.'
    exit 1
}
