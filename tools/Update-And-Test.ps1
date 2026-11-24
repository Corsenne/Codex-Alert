# GitHub-first G2B development updater. Never installs over the stable Finish Alert.
[CmdletBinding()]
param([string]$AssetFolder='')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$branch='feature/codex-finish-alert-g0-g2'
$work=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G2BTest'
$desktop=Join-Path $work 'desktop'
$lib=Join-Path $desktop 'src-tauri'
$exe=Join-Path $lib 'target\debug\finish-alert-g2b-test.exe'
$private=Join-Path $work 'private'
$trace=Join-Path $work 'G2B_IPC_TRACE.txt'
$launched=$null

function Require-External([string]$name){
    if(-not (Get-Command $name -ErrorAction SilentlyContinue)){throw ('G2B_MISSING_TOOL_'+$name)}
}
function Invoke-Git([string[]]$CommandArguments){
    & git -C $repo @CommandArguments
    if($LASTEXITCODE -ne 0){throw 'G2B_GIT_COMMAND_FAILED'}
}
function Copy-Source([string]$source,[string]$dest){
    if(-not (Test-Path -LiteralPath $source -PathType Container)){throw 'G2B_REPO_SOURCE_MISSING'}
    foreach($f in (Get-ChildItem -LiteralPath $source -File -Recurse)){
        $relative=$f.FullName.Substring($source.Length).TrimStart([char[]]@([char]'\',[char]'/'))
        $out=Join-Path $dest $relative
        $parent=Split-Path -Parent $out
        if(-not (Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force | Out-Null}
        Copy-Item -LiteralPath $f.FullName -Destination $out -Force
    }
}
function Is-Asset-Root([string]$candidate){
    return (Test-Path -LiteralPath (Join-Path $candidate 'private-leo.wav') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $candidate 'desktop\src-tauri\icons\icon.ico') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $candidate 'desktop\src-tauri\src\assets\female.wav') -PathType Leaf)
}
function Resolve-Asset-Root {
    if($AssetFolder){
        if(-not (Is-Asset-Root $AssetFolder)){throw 'G2B_ASSET_FOLDER_INVALID'}
        return $AssetFolder
    }
    # Try prior extracted G2B test folders; user audio is NEVER placed in GitHub.
    $downloads=Join-Path $env:USERPROFILE 'Downloads'
    $preferred=@('FinishAlert_Codex_G2B_UI_READY_FIXED','FinishAlert_Codex_G2B_IPC_ACK_FIXED','FinishAlert_Codex_G2B_Isolated_GUI_Test')
    foreach($name in $preferred){
        $p=Join-Path $downloads $name
        if(Is-Asset-Root $p){return $p}
        $nested=Join-Path $p $name
        if(Is-Asset-Root $nested){return $nested}
    }
    if(Test-Path $downloads){
        foreach($dir in (Get-ChildItem -LiteralPath $downloads -Directory -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'FinishAlert_Codex_G2B*' })){
            if(Is-Asset-Root $dir.FullName){return $dir.FullName}
        }
    }
    throw 'G2B_PRIVATE_ASSET_FOLDER_NOT_FOUND'
}
function Ensure-Private-Assets {
    $names=@('private-leo.wav','female.wav','holo.wav','soft.wav','pulse.wav','icon.ico','128x128.png')
    $targets=@(
        (Join-Path $private 'private-leo.wav'),
        (Join-Path $lib 'src\assets\female.wav'),
        (Join-Path $lib 'src\assets\holo.wav'),
        (Join-Path $lib 'src\assets\soft.wav'),
        (Join-Path $lib 'src\assets\pulse.wav'),
        (Join-Path $lib 'icons\icon.ico'),
        (Join-Path $lib 'icons\128x128.png')
    )
    $allPresent=$true
    foreach($t in $targets){if(-not (Test-Path -LiteralPath $t -PathType Leaf)){$allPresent=$false;break}}
    if($allPresent){return}
    $assetRoot=Resolve-Asset-Root
    $sources=@(
        (Join-Path $assetRoot 'private-leo.wav'),
        (Join-Path $assetRoot 'desktop\src-tauri\src\assets\female.wav'),
        (Join-Path $assetRoot 'desktop\src-tauri\src\assets\holo.wav'),
        (Join-Path $assetRoot 'desktop\src-tauri\src\assets\soft.wav'),
        (Join-Path $assetRoot 'desktop\src-tauri\src\assets\pulse.wav'),
        (Join-Path $assetRoot 'desktop\src-tauri\icons\icon.ico'),
        (Join-Path $assetRoot 'desktop\src-tauri\icons\128x128.png')
    )
    for($i=0;$i -lt $sources.Count;$i++){
        $dir=Split-Path -Parent $targets[$i]
        if(-not (Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
        Copy-Item -LiteralPath $sources[$i] -Destination $targets[$i] -Force
    }
}
try {
    Require-External 'git'
    Require-External 'node'
    Require-External 'npm.cmd'
    Require-External 'cargo'
    if(-not (Test-Path -LiteralPath (Join-Path $repo '.git'))){throw 'G2B_NOT_A_GIT_CLONE'}
    $current=(& git -C $repo branch --show-current)
    if($current -ne $branch){throw 'G2B_WRONG_BRANCH_NO_CHANGES_MADE'}
    $tracked=@(& git -C $repo status --porcelain --untracked-files=no)
    if($tracked.Count -gt 0){throw 'G2B_WORKTREE_DIRTY_NO_CHANGES_MADE'}
    Write-Host 'Updating development branch from GitHub (fast-forward only)...'
    Invoke-Git -CommandArguments @('fetch','--quiet','origin',$branch)
    Invoke-Git -CommandArguments @('merge','--ff-only','FETCH_HEAD')
    Write-Host 'G2B_GITHUB_SYNC_PASS'
    $revision=(& git -C $repo rev-parse --short=12 HEAD)
    Write-Host ('G2B_TEST_SOURCE_COMMIT='+$revision)
    # Stop here if G3 helper was corrupted in Git, before any G2B rebuild.
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $repo 'tools\Verify-G3-Helper.ps1')
    if($LASTEXITCODE -ne 0){throw 'G3_HELPER_SYNTAX_PRECHECK_HOLD'}

    # G3 exact-routing tests are source-only and cannot change installed alerts.
    & node --test (Join-Path $repo 'candidate-g3\routing.test.mjs')
    if($LASTEXITCODE -ne 0){throw 'G3_CODEX_AND_CHATGPT_ROUTING_TEST_FAILED'}
    & node (Join-Path $repo 'candidate-g3\chrome-extension\tests\exact-route.cjs')
    if($LASTEXITCODE -ne 0){throw 'G3_CHROME_EXACT_ROUTE_TEST_FAILED'}
    Write-Host 'G3_ROUTING_SOURCE_TESTS_PASS'
    if(@(Get-Process 'finish-alert-g2b-test' -ErrorAction SilentlyContinue).Count -gt 0){
        throw 'G2B_TEST_ALREADY_RUNNING_CLOSE_ONLY_TEST_APP'
    }
    # Build in isolated LOCALAPPDATA workspace. No writes to installed Finish Alert.
    Copy-Source (Join-Path $repo 'candidate-g2a\desktop') $desktop
    Copy-Source (Join-Path $repo 'candidate-g2b\desktop') $desktop
    # Ensure G2B test-only identity. The earlier G2A Cargo package is not safe to run here.
    $cargoPath=Join-Path $lib 'Cargo.toml'
    $cargo=[IO.File]::ReadAllText($cargoPath)
    $cargo=$cargo.Replace('name = "finish-alert-desktop"','name = "finish-alert-g2b-test"')
    $cargo=$cargo.Replace('name = "finish_alert_desktop_lib"','name = "finish_alert_g2b_test_lib"')
    [IO.File]::WriteAllText($cargoPath,$cargo,[Text.UTF8Encoding]::new($false))
    $mainPath=Join-Path $lib 'src\main.rs'
    $main=[IO.File]::ReadAllText($mainPath).Replace('finish_alert_desktop_lib::run()','finish_alert_g2b_test_lib::run()')
    [IO.File]::WriteAllText($mainPath,$main,[Text.UTF8Encoding]::new($false))
    $uiPath=Join-Path $desktop 'src\main.tsx'
    $ui=[IO.File]::ReadAllText($uiPath).Replace("CODEX ALERT':'FINISH ALERT'","CODEX ALERT · TEST':'FINISH ALERT · TEST'")
    [IO.File]::WriteAllText($uiPath,$ui,[Text.UTF8Encoding]::new($false))
    $config=Get-Content -LiteralPath (Join-Path $lib 'tauri.conf.json') -Raw -Encoding UTF8|ConvertFrom-Json
    if($config.identifier -ne 'com.corsenne.finishalertdesktop.g2btest'){throw 'G2B_ISOLATED_IDENTITY_MISMATCH'}
    $pipeSource=Get-Content -LiteralPath (Join-Path $lib 'src\ipc.rs') -Raw -Encoding UTF8
    if(-not $pipeSource.Contains('corsenne_finish_alert_g2b_test_')){throw 'G2B_TEST_PIPE_MISMATCH'}
    Ensure-Private-Assets
    Write-Host 'G2B_PRIVATE_ASSETS_READY'
    if(-not (Test-Path -LiteralPath (Join-Path $work 'scripts'))){New-Item -ItemType Directory -Path (Join-Path $work 'scripts') -Force|Out-Null}
    Copy-Item -LiteralPath (Join-Path $repo 'candidate-g2b\scripts\Send-G2B.ps1') -Destination (Join-Path $work 'scripts\Send-G2B.ps1') -Force

    Push-Location $desktop
    try{
        if(-not (Test-Path -LiteralPath 'node_modules' -PathType Container)){
            & npm.cmd install --no-audit --no-fund
            if($LASTEXITCODE -ne 0){throw 'G2B_NPM_INSTALL_FAILED'}
        }
        & npm.cmd test
        if($LASTEXITCODE -ne 0){throw 'G2B_NODE_TESTS_FAILED'}
        # npm run build alone does not embed React into a debug Cargo executable.
        # The Tauri CLI build below invokes build.beforeBuildCommand and frontendDist.
    } finally { Pop-Location }

    & cargo test --manifest-path (Join-Path $lib 'Cargo.toml')
    if($LASTEXITCODE -ne 0){throw 'G2B_CARGO_TEST_FAILED'}

    Push-Location $desktop
    try {
        # This MUST be a Tauri CLI build, not a plain 'cargo build':
        # cargo debug may load devUrl (127.0.0.1:1420) without a running Vite server.
        # CLI build packages frontendDist into the isolated debug EXE without an installer.
        & npm.cmd run tauri -- build --debug --no-bundle
        if($LASTEXITCODE -ne 0){throw 'G2B_TAURI_ASSET_BUILD_FAILED'}
    } finally { Pop-Location }
    if(-not (Test-Path -LiteralPath (Join-Path $desktop 'dist\index.html') -PathType Leaf)){
        throw 'G2B_FRONTEND_DIST_MISSING'
    }
    # Confirm that the diagnostic HTML and compiled React module actually exist.
    $htmlOutput=[IO.File]::ReadAllText((Join-Path $desktop 'dist\index.html'))
    if(-not $htmlOutput.Contains('G2B_HTML_INLINE_EXECUTED')) {
        throw 'G2B_DIAGNOSTIC_HTML_NOT_INCLUDED'
    }
    $builtJS=@(Get-ChildItem -LiteralPath (Join-Path $desktop 'dist\assets') -Filter '*.js' -File -ErrorAction Stop)
    $reactMarkerFound=$false
    foreach($builtAsset in $builtJS) {
        $assetText=[IO.File]::ReadAllText($builtAsset.FullName)
        if($assetText.Contains('G2B_REACT_MODULE_EXECUTED')){$reactMarkerFound=$true;break}
    }
    if(-not $reactMarkerFound){throw 'G2B_DIAGNOSTIC_REACT_NOT_INCLUDED'}
    Write-Host 'G2B_FRONTEND_DIAGNOSTIC_ASSETS_PASS'
    if(-not (Test-Path -LiteralPath $exe -PathType Leaf)){throw 'G2B_TEST_EXE_MISSING'}
    Write-Host 'G2B_TAURI_FRONTEND_EMBED_BUILD_PASS'
    Write-Host 'G2B_ISOLATED_WINDOWS_BUILD_PASS'
    if(Test-Path -LiteralPath $trace -PathType Leaf){Remove-Item -LiteralPath $trace -Force}
    $env:FINISH_ALERT_G2B_TRACE=$trace
    $env:FINISH_ALERT_G2B_PRIVATE_WAV=Join-Path $private 'private-leo.wav'
    $launched=Start-Process -FilePath $exe -PassThru
    $deadline=(Get-Date).AddSeconds(30);$ready=$false
    while((Get-Date) -lt $deadline){
        if($launched.HasExited){throw 'G2B_TEST_APP_EXITED_EARLY'}
        if(Test-Path -LiteralPath $trace -PathType Leaf){
            $steps=@(Get-Content -LiteralPath $trace -ErrorAction SilentlyContinue)
            if($steps -contains 'G2B_UI_READY_PASS'){$ready=$true;break}
        }
        Start-Sleep -Milliseconds 250
    }
    if(-not $ready){throw 'G2B_UI_BOOTSTRAP_HOLD'}
    Write-Host 'G2B_UI_READY_PASS'
    $null=Read-Host 'Press ENTER to start isolated 3-notification test'
    & (Join-Path $work 'scripts\Send-G2B.ps1')
    if($LASTEXITCODE -ne 0){throw 'G2B_SYNTHETIC_SEND_FAIL'}
    Write-Host 'Watching FIFO and audio? Test window closes automatically after 27 seconds.'
    Start-Sleep -Seconds 27
    Write-Host 'G2B_GITHUB_TEST_COMPLETE_VISUAL_AUDIO_USER_CONFIRMATION_REQUIRED'
} catch {
    Write-Host ('HOLD: '+$_.Exception.Message)
    if(Test-Path -LiteralPath $trace -PathType Leaf){
        Write-Host 'G2B sanitized IPC trace:'
        Get-Content -LiteralPath $trace -Tail 35
    }
    exit 1
} finally {
    if($null -ne $launched){
        try {
            $proc=Get-Process -Id $launched.Id -ErrorAction SilentlyContinue
            if($proc -and $proc.Path -and ([IO.Path]::GetFullPath($proc.Path) -ieq [IO.Path]::GetFullPath($exe))){
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }
    Remove-Item Env:\FINISH_ALERT_G2B_TRACE -ErrorAction SilentlyContinue
    Remove-Item Env:\FINISH_ALERT_G2B_PRIVATE_WAV -ErrorAction SilentlyContinue
}
