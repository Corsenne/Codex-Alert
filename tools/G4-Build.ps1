# Build the isolated G4 ChatGPT-click integration test.
# NO Chrome extension installation or registry mutation is done here.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$branch='feature/codex-finish-alert-g0-g2'
$work=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4Test'
$g2b=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G2BTest'
$desktop=Join-Path $work 'desktop'
$lib=Join-Path $desktop 'src-tauri'
$private=Join-Path $work 'private'
$bin=Join-Path $work 'bin'
function Need([string]$command) {
    if(-not (Get-Command $command -ErrorAction SilentlyContinue)) {throw ('G4_MISSING_TOOL_'+$command)}
}
function Copy-Sources([string]$src,[string]$dest) {
    if(-not(Test-Path -LiteralPath $src -PathType Container)){throw 'G4_SOURCE_FOLDER_MISSING'}
    foreach($file in (Get-ChildItem -LiteralPath $src -File -Recurse)){
        $rel=$file.FullName.Substring($src.Length).TrimStart([char[]]@([char]'\',[char]'/'))
        $out=Join-Path $dest $rel
        $dir=Split-Path -Parent $out
        if(-not(Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
        Copy-Item -LiteralPath $file.FullName -Destination $out -Force
    }
}
try{
    foreach($tool in @('git','npm.cmd','cargo','node')){Need $tool}
    if(-not (Test-Path (Join-Path $repo '.git') -PathType Container)){throw 'G4_NOT_GIT_REPOSITORY'}
    if((& git -C $repo branch --show-current).Trim() -cne $branch){throw 'G4_WRONG_BRANCH'}
    if(@(& git -C $repo status --porcelain --untracked-files=no).Count -gt 0){throw 'G4_WORKTREE_DIRTY'}
    & git -C $repo fetch --quiet origin $branch
    if($LASTEXITCODE -ne 0){throw 'G4_GIT_FETCH_FAILED'}
    & git -C $repo merge --ff-only FETCH_HEAD
    if($LASTEXITCODE -ne 0){throw 'G4_GIT_FF_ONLY_FAILED'}
    Write-Host 'G4_GITHUB_SYNC_PASS'
    if(@(Get-Process 'finish-alert-g4-test' -ErrorAction SilentlyContinue).Count -gt 0){
        throw 'G4_TEST_ALREADY_RUNNING'
    }

    Copy-Sources (Join-Path $repo 'candidate-g2a\desktop') $desktop
    Copy-Sources (Join-Path $repo 'candidate-g2b\desktop') $desktop
    Copy-Sources (Join-Path $repo 'candidate-g4\desktop') $desktop

    $cargoFile=Join-Path $lib 'Cargo.toml'
    $cargoText=[IO.File]::ReadAllText($cargoFile)
    if(-not $cargoText.Contains('name = "finish-alert-desktop"')){throw 'G4_CARGO_BASE_UNEXPECTED'}
    $cargoText=$cargoText.Replace('name = "finish-alert-desktop"','name = "finish-alert-g4-test"')
    $cargoText=$cargoText.Replace('name = "finish_alert_desktop_lib"','name = "finish_alert_g4_test_lib"')
    [IO.File]::WriteAllText($cargoFile,$cargoText,[Text.UTF8Encoding]::new($false))
    $main=Join-Path $lib 'src\main.rs'
    $mainText=[IO.File]::ReadAllText($main)
    if(-not $mainText.Contains('finish_alert_desktop_lib::run()')){throw 'G4_TAURI_MAIN_UNEXPECTED'}
    $mainText=$mainText.Replace('finish_alert_desktop_lib::run()','finish_alert_g4_test_lib::run()')
    [IO.File]::WriteAllText($main,$mainText,[Text.UTF8Encoding]::new($false))

    $config=Get-Content -LiteralPath (Join-Path $lib 'tauri.conf.json') -Raw -Encoding UTF8|ConvertFrom-Json
    if($config.identifier -cne 'com.corsenne.finishalertdesktop.g4test'){throw 'G4_ISOLATED_IDENTITY_MISMATCH'}
    $ipc=[IO.File]::ReadAllText((Join-Path $lib 'src\ipc.rs'))
    if(-not $ipc.Contains('corsenne_finish_alert_g4_test_') -or $ipc.Contains('corsenne_finish_alert_v2_')){
        throw 'G4_PIPE_IDENTITY_MISMATCH'
    }
    $srcLib=Join-Path $g2b 'desktop\src-tauri'
    foreach($file in @('src\assets\female.wav','src\assets\holo.wav','src\assets\soft.wav','src\assets\pulse.wav','icons\icon.ico','icons\128x128.png')){
        $source=Join-Path $srcLib $file
        if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw 'G4_PRIVATE_ASSET_MISSING'}
        $dest=Join-Path $lib $file
        $parent=Split-Path -Parent $dest
        if(-not(Test-Path $parent)){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
        Copy-Item -LiteralPath $source -Destination $dest -Force
    }
    if(-not(Test-Path -LiteralPath $private)){New-Item -ItemType Directory -Path $private -Force|Out-Null}
    $leo=Join-Path $g2b 'private\private-leo.wav'
    if(-not(Test-Path -LiteralPath $leo -PathType Leaf)){throw 'G4_PRIVATE_LEO_MISSING'}
    Copy-Item -LiteralPath $leo -Destination (Join-Path $private 'private-leo.wav') -Force
    Write-Host 'G4_PRIVATE_ASSETS_READY'

    & node --test (Join-Path $repo 'candidate-g4\chrome-extension\tests\source-contract.test.mjs')
    if($LASTEXITCODE -ne 0){throw 'G4_CHROME_SOURCE_CONTRACT_FAILED'}
    & node --test (Join-Path $repo 'candidate-g4\chrome-extension\tests\g4-safety.test.mjs')
    if($LASTEXITCODE -ne 0){throw 'G4_CHROME_NO_MONITORING_CONTRACT_FAILED'}
    & node (Join-Path $repo 'candidate-g4\chrome-extension\tests\callback-flow.cjs')
    if($LASTEXITCODE -ne 0){throw 'G4_CHROME_CALLBACK_MODEL_FAILED'}
    Push-Location $desktop
    try{
        if(-not(Test-Path -LiteralPath 'node_modules' -PathType Container)){
            & npm.cmd install --no-audit --no-fund
            if($LASTEXITCODE -ne 0){throw 'G4_NPM_INSTALL_FAILED'}
        }
        & npm.cmd test
        if($LASTEXITCODE -ne 0){throw 'G4_NODE_TEST_FAILED'}
    }finally{Pop-Location}
    & cargo test --manifest-path (Join-Path $lib 'Cargo.toml')
    if($LASTEXITCODE -ne 0){throw 'G4_TAURI_RUST_TEST_FAILED'}
    Push-Location $desktop
    try{
        & npm.cmd run tauri -- build --debug --no-bundle
        if($LASTEXITCODE -ne 0){throw 'G4_TAURI_BUILD_FAILED'}
    }finally{Pop-Location}
    $desktopExe=Join-Path $lib 'target\debug\finish-alert-g4-test.exe'
    if(-not(Test-Path -LiteralPath $desktopExe -PathType Leaf)){throw 'G4_DESKTOP_BINARY_MISSING'}
    Write-Host 'G4_ISOLATED_WINDOWS_DESKTOP_BUILD_PASS'
    & cargo test --manifest-path (Join-Path $repo 'candidate-g4\native-host\Cargo.toml')
    if($LASTEXITCODE -ne 0){throw 'G4_BRIDGE_TEST_FAILED'}
    & cargo build --manifest-path (Join-Path $repo 'candidate-g4\native-host\Cargo.toml')
    if($LASTEXITCODE -ne 0){throw 'G4_BRIDGE_BUILD_FAILED'}
    $bridgeExe=Join-Path $repo 'candidate-g4\native-host\target\debug\finish-alert-g4-bridge.exe'
    if(-not(Test-Path -LiteralPath $bridgeExe -PathType Leaf)){throw 'G4_BRIDGE_BINARY_MISSING'}
    if(-not(Test-Path -LiteralPath $bin)){New-Item -ItemType Directory -Path $bin -Force |Out-Null}
    Copy-Item -LiteralPath $bridgeExe -Destination (Join-Path $bin 'finish-alert-g4-bridge.exe') -Force
    Write-Host 'G4_ISOLATED_NATIVE_BRIDGE_BUILD_PASS'
    Write-Host 'G4_TEST_BUILD_COMPLETE'
    Write-Host 'For G4A: run G4-Synthetic-Test.cmd (NO Chrome test extension or registry setup).'
    Write-Host 'G4B live Chrome integration is a later gate; do not load the test extension yet.'
}catch{
    Write-Host ('G4_TEST_BUILD_HOLD: '+$_.Exception.Message)
    exit 2
}
