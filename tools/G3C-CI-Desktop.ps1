# GitHub Actions Windows-only smoke: compile the isolated G3C Tauri application
# using generated SILENT sounds and temporary synthetic icons, NEVER user-provided audio.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$work=Join-Path $env:RUNNER_TEMP 'FinishAlertG3CTestBuild'
$desktop=Join-Path $work 'desktop'
$lib=Join-Path $desktop 'src-tauri'
function Copy-Sources([string]$source,[string]$destination){
 foreach($f in (Get-ChildItem -LiteralPath $source -File -Recurse)){
   $rel=$f.FullName.Substring($source.Length).TrimStart([char[]]@([char]'\',[char]'/'))
   $dest=Join-Path $destination $rel
   $dir=Split-Path -Parent $dest
   if(-not(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
   Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
 }
}
function Silent-Wav([string]$dest){
 $dir=Split-Path -Parent $dest
 if(-not(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
 $file=[IO.File]::Create($dest)
 $bw=[IO.BinaryWriter]::new($file)
 try{
    $rate=16000;$samples=1600;$bytes=$samples*2
    $ascii=[Text.Encoding]::ASCII
    $bw.Write($ascii.GetBytes('RIFF'))
    $bw.Write([uint32](36+$bytes))
    $bw.Write($ascii.GetBytes('WAVEfmt '))
    $bw.Write([uint32]16)
    $bw.Write([uint16]1)
    $bw.Write([uint16]1)
    $bw.Write([uint32]$rate)
    $bw.Write([uint32]($rate*2))
    $bw.Write([uint16]2)
    $bw.Write([uint16]16)
    $bw.Write($ascii.GetBytes('data'))
    $bw.Write([uint32]$bytes)
    $bw.Write((New-Object byte[] $bytes))
 }finally{$bw.Dispose()}
}
if(-not $env:RUNNER_TEMP){throw 'G3C_CI_ONLY_NO_RUNNER_TEMP'}
foreach($src in @('candidate-g2a\desktop','candidate-g2b\desktop','candidate-g3c\desktop')){
 Copy-Sources (Join-Path $repo $src) $desktop
}
$cargo=Join-Path $lib 'Cargo.toml'
$cargoText=[IO.File]::ReadAllText($cargo)
$cargoText=$cargoText.Replace('name = "finish-alert-desktop"','name = "finish-alert-g3c-test"')
$cargoText=$cargoText.Replace('name = "finish_alert_desktop_lib"','name = "finish_alert_g3c_test_lib"')
[IO.File]::WriteAllText($cargo,$cargoText,[Text.UTF8Encoding]::new($false))
$main=Join-Path $lib 'src\main.rs'
$s=[IO.File]::ReadAllText($main).Replace('finish_alert_desktop_lib::run()','finish_alert_g3c_test_lib::run()')
[IO.File]::WriteAllText($main,$s,[Text.UTF8Encoding]::new($false))
foreach($name in @('female','holo','soft','pulse')){
 Silent-Wav (Join-Path $lib ('src\assets\'+$name+'.wav'))
}
$icons=Join-Path $lib 'icons'
if(-not(Test-Path $icons)){New-Item -ItemType Directory -Path $icons -Force|Out-Null}
Add-Type -AssemblyName System.Drawing
$bitmap=[Drawing.Bitmap]::new(128,128)
try {
 $bitmap.Save((Join-Path $icons '128x128.png'),[Drawing.Imaging.ImageFormat]::Png)
 $icon=[Drawing.Icon]::FromHandle($bitmap.GetHicon())
 try{
   $file=[IO.File]::Create((Join-Path $icons 'icon.ico'))
   try{$icon.Save($file)}finally{$file.Dispose()}
 }finally{$icon.Dispose()}
}finally{$bitmap.Dispose()}
Push-Location $desktop
try{
 & npm.cmd install --no-audit --no-fund
 if($LASTEXITCODE -ne 0){throw 'G3C_CI_NPM_INSTALL_FAILED'}
 & npm.cmd test
 if($LASTEXITCODE -ne 0){throw 'G3C_CI_NODE_TEST_FAILED'}
 & cargo test --manifest-path (Join-Path $lib 'Cargo.toml')
 if($LASTEXITCODE -ne 0){throw 'G3C_CI_RUST_TEST_FAILED'}
 & npm.cmd run tauri -- build --debug --no-bundle
 if($LASTEXITCODE -ne 0){throw 'G3C_CI_TAURI_BUILD_FAILED'}
}finally{Pop-Location}
$exe=Join-Path $lib 'target\debug\finish-alert-g3c-test.exe'
if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'G3C_CI_BUILD_EXE_MISSING'}
Write-Host 'G3C_ISOLATED_WINDOWS_TAURI_BUILD_PASS'
