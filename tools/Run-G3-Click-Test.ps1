# G3 isolated click test. Never edits installed Finish Alert, Chrome or Codex hooks.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$branch='feature/codex-finish-alert-g0-g2'
$root=Join-Path $env:LOCALAPPDATA 'CodexAlertDev'
$work=Join-Path $root 'G3ClickTest'
$fromG2B=Join-Path $root 'G2BTest'
$desktop=Join-Path $work 'desktop'
$lib=Join-Path $desktop 'src-tauri'
$exe=Join-Path $lib 'target\debug\finish-alert-g3-click-test.exe'
$trace=Join-Path $work 'G3_IPC_TRACE.txt'
$launched=$null

function Need-Tool([string]$name){
    if(-not (Get-Command $name -ErrorAction SilentlyContinue)){throw ('G3_MISSING_TOOL_'+$name)}
}
function Copy-Source([string]$source,[string]$dest){
    if(-not (Test-Path -LiteralPath $source -PathType Container)){throw 'G3_SOURCE_DIR_MISSING'}
    foreach($f in (Get-ChildItem -LiteralPath $source -File -Recurse)){
        $rel=$f.FullName.Substring($source.Length).TrimStart([char[]]@([char]'\',[char]'/'))
        $out=Join-Path $dest $rel
        $parent=Split-Path -Parent $out
        if(-not (Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force | Out-Null}
        Copy-Item -LiteralPath $f.FullName -Destination $out -Force
    }
}
function Verify-Codex-Link([string]$inputUrl){
    $url=$inputUrl.Trim().ToLowerInvariant()
    $pattern='^codex://threads/([0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$'
    $m=[regex]::Match($url,$pattern)
    if(-not $m.Success){throw 'G3_INVALID_CODEX_LINK_FORMAT'}
    $uuid=$m.Groups[1].Value
    $codexHome=if($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $env:USERPROFILE '.codex'}
    $sessions=Join-Path $codexHome 'sessions'
    if(-not (Test-Path -LiteralPath $sessions -PathType Container)){throw 'G3_NO_CODEX_SESSIONS'}
    $files=@(Get-ChildItem -LiteralPath $sessions -Recurse -File -Filter ('rollout-*-'+$uuid+'.jsonl') -ErrorAction SilentlyContinue |
        Select-Object -First 5)
    $valid=$false
    foreach($f in $files){
        try{
            $line=Get-Content -LiteralPath $f.FullName -TotalCount 1 -Encoding UTF8
            $meta=$line|ConvertFrom-Json -ErrorAction Stop
            if($meta.type -eq 'session_meta' -and [string]$meta.payload.id -ieq $uuid){$valid=$true;break}
        }catch{}
    }
    if(-not $valid){throw 'G3_CODEX_SESSION_ID_MISMATCH'}
    $handler=Get-Item -LiteralPath 'Registry::HKEY_CLASSES_ROOT\codex' -ErrorAction SilentlyContinue
    if($null -eq $handler -or @($handler.GetValueNames()) -notcontains 'URL Protocol'){
        throw 'G3_CODEX_URI_HANDLER_UNAVAILABLE'
    }
    return $url
}
function Get-Trace {
    if(Test-Path -LiteralPath $trace -PathType Leaf){
        return @(Get-Content -LiteralPath $trace -ErrorAction SilentlyContinue)
    }
    return @()
}
try{
    foreach($name in @('git','node','npm.cmd','cargo')){Need-Tool $name}
    if(-not (Test-Path -LiteralPath (Join-Path $repo '.git') -PathType Container)){
        throw 'G3_REPO_CLONE_NOT_FOUND'
    }
    $branchNow=(& git -C $repo branch --show-current).Trim()
    if($branchNow -cne $branch){throw 'G3_WRONG_GIT_BRANCH'}
    if(@(& git -C $repo status --porcelain --untracked-files=no).Count -gt 0){
        throw 'G3_REPO_DIRTY_NO_MUTATION'
    }
    & git -C $repo fetch --quiet origin $branch
    if($LASTEXITCODE -ne 0){throw 'G3_GIT_FETCH_FAILED'}
    & git -C $repo merge --ff-only FETCH_HEAD
    if($LASTEXITCODE -ne 0){throw 'G3_GIT_FAST_FORWARD_FAILED'}
    Write-Host 'G3_GITHUB_SYNC_PASS'

    $link=Verify-Codex-Link ([string](Read-Host 'Paste a previously tested Codex Desktop Copy deeplink'))
    Write-Host 'G3_CODEX_EXACT_TARGET_VALIDATED_PASS'
    if(@(Get-Process 'finish-alert-g3-click-test' -ErrorAction SilentlyContinue).Count -gt 0){
        throw 'G3_TEST_INSTANCE_ALREADY_RUNNING'
    }
    # Prepare a completely isolated G3 test binary from G2A base and test-only overlays.
    Copy-Source (Join-Path $repo 'candidate-g2a\desktop') $desktop
    Copy-Source (Join-Path $repo 'candidate-g2b\desktop') $desktop
    Copy-Source (Join-Path $repo 'candidate-g3\isolated-desktop') $desktop

    $cargoPath=Join-Path $lib 'Cargo.toml'
    $cargo=[IO.File]::ReadAllText($cargoPath)
    if(-not $cargo.Contains('name = "finish-alert-desktop"')){throw 'G3_UNEXPECTED_BASE_MANIFEST'}
    $cargo=$cargo.Replace('name = "finish-alert-desktop"','name = "finish-alert-g3-click-test"')
    $cargo=$cargo.Replace('name = "finish_alert_desktop_lib"','name = "finish_alert_g3_click_test_lib"')
    [IO.File]::WriteAllText($cargoPath,$cargo,[Text.UTF8Encoding]::new($false))
    $mainPath=Join-Path $lib 'src\main.rs'
    $main=[IO.File]::ReadAllText($mainPath)
    if(-not $main.Contains('finish_alert_desktop_lib::run()')){throw 'G3_UNEXPECTED_BASE_ENTRYPOINT'}
    $main=$main.Replace('finish_alert_desktop_lib::run()','finish_alert_g3_click_test_lib::run()')
    [IO.File]::WriteAllText($mainPath,$main,[Text.UTF8Encoding]::new($false))
    $conf=Get-Content -LiteralPath (Join-Path $lib 'tauri.conf.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if($conf.identifier -ne 'com.corsenne.finishalertdesktop.g3clicktest'){throw 'G3_ISOLATED_APP_ID_MISMATCH'}
    $ipc=[IO.File]::ReadAllText((Join-Path $lib 'src\ipc.rs'))
    $native=[IO.File]::ReadAllText((Join-Path $lib 'src\lib.rs'))
    if(-not $ipc.Contains('corsenne_finish_alert_g3_click_test_') -or
       -not $native.Contains('G3_AUDIO_STOP_CALLED') -or
       -not $native.Contains('FINISH_ALERT_G3_ALLOWED_LINK')){throw 'G3_TEST_BINARY_SOURCE_GUARD_FAILED'}
    # Audio and icons originate from the prior G2B PRIVATE local workspace, never GitHub.
    $srcLib=Join-Path $fromG2B 'desktop\src-tauri'
    foreach($rel in @('src\assets\female.wav','src\assets\holo.wav','src\assets\soft.wav',
          'src\assets\pulse.wav','icons\icon.ico','icons\128x128.png')){
        $src=Join-Path $srcLib $rel
        if(-not (Test-Path -LiteralPath $src -PathType Leaf)){throw 'G3_PRIVATE_ASSET_UNAVAILABLE'}
        $target=Join-Path $lib $rel
        $dir=Split-Path -Parent $target
        if(-not (Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Force -Path $dir | Out-Null}
        Copy-Item -LiteralPath $src -Destination $target -Force
    }
    $voice=Join-Path $fromG2B 'private\private-leo.wav'
    if(-not (Test-Path -LiteralPath $voice -PathType Leaf)){throw 'G3_PRIVATE_LEO_WAV_MISSING'}
    Write-Host 'G3_PRIVATE_ASSETS_READY'

    & node --test (Join-Path $repo 'candidate-g3\routing.test.mjs')
    if($LASTEXITCODE -ne 0){throw 'G3_ROUTE_TEST_FAILED'}
    & node (Join-Path $repo 'candidate-g3\chrome-extension\tests\exact-route.cjs')
    if($LASTEXITCODE -ne 0){throw 'G3_CHROME_ROUTE_TEST_FAILED'}
    Write-Host 'G3_ROUTING_SOURCE_TESTS_PASS'

    Push-Location $desktop
    try{
        if(-not (Test-Path -LiteralPath 'node_modules' -PathType Container)){
            & npm.cmd install --no-audit --no-fund
            if($LASTEXITCODE -ne 0){throw 'G3_NPM_INSTALL_FAILED'}
        }
        & npm.cmd test
        if($LASTEXITCODE -ne 0){throw 'G3_NODE_TEST_FAILED'}
    }finally{Pop-Location}
    & cargo test --manifest-path (Join-Path $lib 'Cargo.toml')
    if($LASTEXITCODE -ne 0){throw 'G3_RUST_TEST_FAILED'}
    Push-Location $desktop
    try{
        & npm.cmd run tauri -- build --debug --no-bundle
        if($LASTEXITCODE -ne 0){throw 'G3_TAURI_BUILD_FAILED'}
    }finally{Pop-Location}
    if(-not (Test-Path -LiteralPath $exe -PathType Leaf)){throw 'G3_ISOLATED_EXE_MISSING'}
    Write-Host 'G3_ISOLATED_WINDOWS_BUILD_PASS'

    if(Test-Path -LiteralPath $trace -PathType Leaf){Remove-Item -LiteralPath $trace -Force}
    $env:FINISH_ALERT_G2B_TRACE=$trace
    $env:FINISH_ALERT_G2B_PRIVATE_WAV=$voice
    $env:FINISH_ALERT_G3_ALLOWED_LINK=$link
    $launched=Start-Process -FilePath $exe -PassThru

    $ready=$false
    $until=(Get-Date).AddSeconds(30)
    while((Get-Date) -lt $until){
        if($launched.HasExited){throw 'G3_TEST_APP_EXITED'}
        if(@(Get-Trace) -contains 'G2B_UI_READY_PASS'){$ready=$true;break}
        Start-Sleep -Milliseconds 250
    }
    if(-not $ready){throw 'G3_UI_BOOTSTRAP_HOLD'}
    Write-Host 'G3_UI_READY_PASS'
    Write-Host 'Keep Codex on ANOTHER chat (or close Codex) so the return is visible.'
    $null=Read-Host 'Press ENTER, then click the G3 banner while Leo is speaking'
    & (Join-Path $repo 'candidate-g3\scripts\Send-G3.ps1')
    if($LASTEXITCODE -ne 0){throw 'G3_TEST_EVENT_SEND_FAILED'}
    $click=$false;$opened=$false
    $until=(Get-Date).AddSeconds(20)
    while((Get-Date) -lt $until){
        $steps=@(Get-Trace)
        if($steps -contains 'G3_AUDIO_STOP_CALLED'){$click=$true}
        if($steps -contains 'G3_THREAD_OPEN_DISPATCHED'){$opened=$true;break}
        if($steps -contains 'G3_THREAD_OPEN_FAILED'){throw 'G3_SHELLEXECUTE_FAILED'}
        if($steps -contains 'G3_TARGET_NOT_AUTHORIZED'){throw 'G3_RUNTIME_TARGET_AUTHORIZATION_FAILED'}
        Start-Sleep -Milliseconds 150
    }
    if(-not $click){throw 'G3_CLICK_NOT_OBSERVED'}
    Write-Host 'G3_AUDIO_STOP_CALLED'
    if(-not $opened){throw 'G3_TARGET_NOT_DISPATCHED'}
    Write-Host 'G3_THREAD_OPEN_DISPATCHED'
    Write-Host 'G3_CLICK_SEQUENCE_ACCEPTED_VISUAL_CONFIRMATION_REQUIRED'
    Write-Host 'Did the EXACT thread open? Did Leo stop immediately? Please report both.'
}catch{
    Write-Host ('G3_TEST_HOLD: '+$_.Exception.Message)
    if(Test-Path -LiteralPath $trace -PathType Leaf){
        Write-Host 'Sanitized G3 stage trace (no chat content or link):'
        @(Get-Content -LiteralPath $trace -Tail 40 -ErrorAction SilentlyContinue) | ForEach-Object {Write-Host $_}
    }
    exit 2
}finally{
    # Stop only the known G3 test EXE created by this script; never Chrome or Codex.
    if($null -ne $launched){
        try{
            $p=Get-Process -Id $launched.Id -ErrorAction SilentlyContinue
            if($null -ne $p -and $p.Path -and
                [IO.Path]::GetFullPath($p.Path) -ieq [IO.Path]::GetFullPath($exe)){
                Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            }
        }catch{}
    }
    Remove-Item Env:\FINISH_ALERT_G2B_TRACE -ErrorAction SilentlyContinue
    Remove-Item Env:\FINISH_ALERT_G2B_PRIVATE_WAV -ErrorAction SilentlyContinue
    Remove-Item Env:\FINISH_ALERT_G3_ALLOWED_LINK -ErrorAction SilentlyContinue
}
