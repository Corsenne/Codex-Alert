# G4C-1 — Read-only production-environment inventory. No registry, hook or
# Chrome setting mutation; no installer, process termination or network calls.
# Do not print hook command text, extension IDs, URL paths or prompt contents.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

function Count-HookEvent($document,[string]$eventName) {
    $groups=0; $handlers=0; $legacy=0; $candidate=0
    if($null -eq $document -or $null -eq $document.hooks) {
        return [ordered]@{groups=0;handlers=0;legacy_codex_alert=0;new_relay_references=0}
    }
    if($document.hooks.PSObject.Properties.Name -notcontains $eventName) {
        return [ordered]@{groups=0;handlers=0;legacy_codex_alert=0;new_relay_references=0}
    }
    foreach($group in @($document.hooks.$eventName)) {
        if($null -eq $group){continue}
        $groups++
        foreach($handler in @($group.hooks)) {
            if($null -eq $handler){continue}
            $handlers++
            $commands=([string]$handler.command)+' '+([string]$handler.commandWindows)
            if($commands -match '(?i)codex[-_]?alert\.ps1'){$legacy++}
            if($commands -match '(?i)Codex-Stop-Relay\.ps1'){$candidate++}
        }
    }
    return [ordered]@{groups=$groups;handlers=$handlers;legacy_codex_alert=$legacy;new_relay_references=$candidate}
}

function Inspect-Codex {
    $codexHomeDir=if($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $env:USERPROFILE '.codex'}
    $hooks=Join-Path $codexHomeDir 'hooks.json'
    $toml=Join-Path $codexHomeDir 'config.toml'
    $parse='absent'; $doc=$null; $digest=$null
    if(Test-Path -LiteralPath $hooks -PathType Leaf){
        try {
            $doc=Get-Content -LiteralPath $hooks -Raw -Encoding UTF8 | ConvertFrom-Json
            $parse='ok'
            $digest=(Get-FileHash -LiteralPath $hooks -Algorithm SHA256).Hash
        }catch{$parse='error'}
    }
    $mode='unknown'; $permissions='unknown'; $inlineStop=0; $inlinePermission=0
    $configStatus='absent'
    if(Test-Path -LiteralPath $toml -PathType Leaf){
        $configStatus='present'
        try {
            $inDesktop=$false
            foreach($line in (Get-Content -LiteralPath $toml -Encoding UTF8)){
                if($line -match '^\s*\[\[hooks\.Stop'){$inlineStop++}
                if($line -match '^\s*\[\[hooks\.PermissionRequest'){$inlinePermission++}
                if($line -match '^\s*\[([^\]]+)\]\s*(?:#.*)?$'){
                    $inDesktop=($Matches[1] -eq 'desktop')
                    continue
                }
                if(-not $inDesktop){continue}
                if($line -match '^\s*notifications-turn-mode\s*=\s*"([^"]+)"'){$mode=$Matches[1]}
                if($line -match '^\s*notifications-permissions-enabled\s*=\s*(true|false)'){$permissions=$Matches[1]}
            }
        }catch{$configStatus='read-error'; $mode='unknown';$permissions='unknown'}
    }
    return [ordered]@{
        hooks_json=$parse
        hooks_sha256=$digest
        stop=(Count-HookEvent $doc 'Stop')
        permission_request=(Count-HookEvent $doc 'PermissionRequest')
        config_toml=$configStatus
        desktop_turn_mode=$mode
        desktop_permission_notifications=$permissions
        inline_stop_groups=$inlineStop
        inline_permission_groups=$inlinePermission
        coverage='user_config_only_not_system_project_plugin_hooks'
    }
}

function Inspect-ChromeNativeHosts {
    $roots=@(
        @{label='HKCU';path='Registry::HKEY_CURRENT_USER\Software\Google\Chrome\NativeMessagingHosts'},
        @{label='HKLM';path='Registry::HKEY_LOCAL_MACHINE\Software\Google\Chrome\NativeMessagingHosts'},
        @{label='HKCU32';path='Registry::HKEY_CURRENT_USER\Software\WOW6432Node\Google\Chrome\NativeMessagingHosts'},
        @{label='HKLM32';path='Registry::HKEY_LOCAL_MACHINE\Software\WOW6432Node\Google\Chrome\NativeMessagingHosts'}
    )
    $rows=New-Object 'System.Collections.Generic.List[object]'
    foreach($root in $roots){
        if(-not(Test-Path -LiteralPath $root.path)){continue}
        try {$keys=@(Get-ChildItem -LiteralPath $root.path -ErrorAction Stop)}
        catch {
            $rows.Add([ordered]@{scope=$root.label;host='enumeration-denied';manifest='unknown';executable='unknown';allowed_origins='unknown'})
            continue
        }
        foreach($key in $keys){
            $name=[string]$key.PSChildName
            if($name -notmatch '(?i)(finish[_-]?alert|codex[_-]?alert|corsenne)'){continue}
            $manifest='unreadable';$binary='unknown';$originCount='unknown'
            try {
                $manifestPath=[string]$key.GetValue('')
                # Only inspect a local absolute drive path; never follow UNC/network paths.
                if($manifestPath -notmatch '^[A-Za-z]:\\'){
                    $manifest='nonlocal-or-invalid-path'
                }elseif(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){
                    $manifest='missing'
                }else{
                    $file=Get-Item -LiteralPath $manifestPath -ErrorAction Stop
                    if($file.Length -gt 65536){$manifest='oversize'}
                    else{
                        $m=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
                        $manifest='ok'
                        $originCount=@($m.allowed_origins).Count
                        $exe=[string]$m.path
                        if($exe -notmatch '^[A-Za-z]:\\'){$binary='nonlocal-or-invalid-path'}
                        elseif(Test-Path -LiteralPath $exe -PathType Leaf){$binary='present'}
                        else{$binary='missing'}
                    }
                }
            }catch{$manifest='parse-or-access-error'}
            $rows.Add([ordered]@{
                scope=$root.label;host=$name;manifest=$manifest
                executable=$binary;allowed_origins=$originCount
            })
        }
    }
    return @($rows.ToArray())
}

function Inspect-AlertProcesses {
    $rows=New-Object 'System.Collections.Generic.List[object]'
    $state='ok'
    try {$processes=@(Get-Process -ErrorAction Stop)}
    catch {$processes=@();$state='unknown-access-error'}
    foreach($p in $processes) {
        if($p.ProcessName -notmatch '(?i)(finish[-_]?alert|finishalert|codex[-_]?alert|codexalert)'){continue}
        $age=$null
        try {$age=[int][Math]::Floor(([datetime]::UtcNow-$p.StartTime.ToUniversalTime()).TotalMinutes)}
        catch{}
        $role=if($p.ProcessName -match '(?i)(bridge|native[-_]?host)'){'bridge'}else{'alert-app-or-helper'}
        $rows.Add([ordered]@{name=$p.ProcessName;pid=$p.Id;age_minutes=$age;role=$role})
    }
    $oldest=$null
    $ages=@($rows.ToArray() | Where-Object {$null -ne $_.age_minutes} | ForEach-Object {$_.age_minutes})
    if($ages.Count -gt 0){$oldest=($ages|Measure-Object -Maximum).Maximum}
    return [ordered]@{
        inspection=$state;count=$rows.Count;oldest_minutes=$oldest;items=@($rows.ToArray())
    }
}

function Inspect-Repo {
    $repo=Split-Path -Parent $PSScriptRoot
    $status='unknown';$head='unknown';$branch='unknown';$changed='unknown'
    if(Get-Command git -ErrorAction SilentlyContinue){
        try {
            $head=(& git -C $repo rev-parse --short HEAD 2>$null | Select-Object -First 1)
            $branch=(& git -C $repo branch --show-current 2>$null | Select-Object -First 1)
            $dirty=@(& git -C $repo status --porcelain --untracked-files=no 2>$null)
            $changed=($dirty.Count -gt 0)
            $status='ok'
        }catch{$status='unavailable'}
    }else{$status='git-not-installed'}
    return [ordered]@{inspection=$status;branch=$branch;head=$head;tracked_changes=$changed}
}

$phase='init'
try {
    $phase='codex'
    $codex=Inspect-Codex
    $phase='chrome-hosts'
    $hosts=@(Inspect-ChromeNativeHosts)
    $phase='processes'
    $processes=Inspect-AlertProcesses
    $phase='report'
    $g4TestHosts=@($hosts|Where-Object {$_.host -eq 'com.corsenne.finish_alert_g4_test'})
    $g3cTestHosts=@($hosts|Where-Object {$_.host -eq 'com.corsenne.finish_alert_g3c_test'})
    $report=[ordered]@{
        gate='G4C-1'
        mode='READ_ONLY'
        product_mutation='NONE'
        production_cutover='HOLD'
        timestamp_utc=[DateTime]::UtcNow.ToString('o')
        repository=(Inspect-Repo)
        codex=$codex
        chrome_native_hosts=$hosts
        g4_test_host_registration_count=$g4TestHosts.Count
        g3c_test_host_registration_count=$g3cTestHosts.Count
        alert_processes=$processes
        chrome_extension_active_state='NOT_VERIFIED_BY_READONLY_AUDIT'
        native_bridge_soak='NOT_YET_TESTED'
        limitation='No actual Chrome extension activity, all Codex hook layers, or real completion event is inferred.'
    }
    $report | ConvertTo-Json -Depth 9
    Write-Host 'G4C1_READONLY_INSPECTION_COMPLETE'
    Write-Host 'G4C1_PRODUCT_RELEASE=HOLD'
}catch{
    # Avoid emitting raw paths, hook text or errors containing local data.
    Write-Host ('G4C1_HOLD_PHASE='+$phase)
    Write-Host ('G4C1_HOLD_CLASS='+$_.Exception.GetType().Name)
    Write-Host 'G4C1_READONLY_INSPECTION_HOLD'
    exit 2
}
