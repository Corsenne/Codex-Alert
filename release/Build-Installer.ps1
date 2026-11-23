# Build the real v1.2.0 NSIS Setup EXE locally with private voice assets.
# -CiSynthetic is ONLY for GitHub Actions; its output is NEVER a user release.
[CmdletBinding()]
param([switch]$CiSynthetic)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$work=if($CiSynthetic){Join-Path $env:RUNNER_TEMP 'G5SyntheticNSIS'}else{Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G5ReleaseBuild'}
$desktop=Join-Path $work 'desktop'
$lib=Join-Path $desktop 'src-tauri'
$bundle=Join-Path $lib 'target\release\bundle\nsis'
$g2b=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G2BTest\desktop\src-tauri'
$g2bVoice=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G2BTest\private\private-leo.wav'
$g4=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4Test'
function Needed([string]$command){if(-not(Get-Command $command -ErrorAction SilentlyContinue)){throw ('G5_BUILD_TOOL_MISSING_'+$command)}}
function Copy-Sources([string]$src,[string]$dst){
 if(-not(Test-Path -LiteralPath $src -PathType Container)){throw 'G5_SOURCE_MISSING'}
 foreach($f in (Get-ChildItem -LiteralPath $src -Recurse -File)){
  $rel=$f.FullName.Substring($src.Length).TrimStart('\','/')
  $to=Join-Path $dst $rel
  $parent=Split-Path -Parent $to
  if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
  Copy-Item -LiteralPath $f.FullName -Destination $to -Force
 }
}
function Replace-Code([string]$file,[string]$old,[string]$new){
 $body=[IO.File]::ReadAllText($file)
 if(-not $body.Contains($old)){throw 'G5_CODE_CONTRACT_CHANGED'}
 [IO.File]::WriteAllText($file,$body.Replace($old,$new),[Text.UTF8Encoding]::new($false))
}
function Silent-Wav([string]$dest){
 $out=[IO.File]::Create($dest);$writer=[IO.BinaryWriter]::new($out)
 try{
  $rate=16000;$bytes=3200;$enc=[Text.Encoding]::ASCII
  $writer.Write($enc.GetBytes('RIFF'));$writer.Write([uint32](36+$bytes))
  $writer.Write($enc.GetBytes('WAVEfmt '));$writer.Write([uint32]16)
  $writer.Write([uint16]1);$writer.Write([uint16]1)
  $writer.Write([uint32]$rate);$writer.Write([uint32]($rate*2))
  $writer.Write([uint16]2);$writer.Write([uint16]16)
  $writer.Write($enc.GetBytes('data'));$writer.Write([uint32]$bytes)
  $writer.Write((New-Object byte[] $bytes))
 }finally{$writer.Dispose()}
}
function Test-And-Build {
 Push-Location $desktop
 try{
  & npm.cmd install --no-audit --no-fund
  if($LASTEXITCODE -ne 0){throw 'G5_NPM_INSTALL_HOLD'}
  & npm.cmd test
  if($LASTEXITCODE -ne 0){throw 'G5_NODE_TEST_HOLD'}
  & cargo test --manifest-path (Join-Path $lib 'Cargo.toml')
  if($LASTEXITCODE -ne 0){throw 'G5_RUST_TEST_HOLD'}
  & npm.cmd run tauri -- build --bundles nsis
  if($LASTEXITCODE -ne 0){throw 'G5_NSIS_BUILD_HOLD'}
 }finally{Pop-Location}
}
try{
 foreach($tool in @('node','npm.cmd','cargo','git')){Needed $tool}
 if($CiSynthetic -and $env:GITHUB_ACTIONS -ne 'true'){throw 'G5_SYNTHETIC_ONLY_IN_GITHUB_ACTIONS'}
 if(-not $CiSynthetic){
  if(@(& git -C $repo status --porcelain --untracked-files=no).Count -gt 0){throw 'G5_SOURCE_DIRTY_HOLD'}
  $branch=(& git -C $repo branch --show-current).Trim()
  if($branch -cne 'feature/codex-finish-alert-g0-g2'){throw 'G5_WRONG_BRANCH'}
  if(-not(Test-Path -LiteralPath $g2bVoice -PathType Leaf)){
   $g2bVoice=Join-Path $g4 'private\private-leo.wav'
  }
  if(-not(Test-Path -LiteralPath $g2bVoice -PathType Leaf)){throw 'G5_PRIVATE_LEO_WAV_NOT_FOUND'}
 }
 if(Test-Path -LiteralPath $desktop){throw 'G5_WORKSPACE_ALREADY_EXISTS_NO_OVERWRITE'}
 foreach($overlay in @('candidate-g2a\desktop','candidate-g2b\desktop','candidate-g4\desktop')){
  Copy-Sources (Join-Path $repo $overlay) $desktop
 }
 $releaseConfig=Get-Content -LiteralPath (Join-Path $repo 'release\tauri-release.conf.json') -Raw -Encoding UTF8|ConvertFrom-Json
 if($releaseConfig.identifier -cne 'com.corsenne.finishalertdesktop.unified' -or
     $releaseConfig.bundle.windows.nsis.installMode -cne 'currentUser'){throw 'G5_RELEASE_IDENTITY_MISMATCH'}
 Copy-Item -LiteralPath (Join-Path $repo 'release\tauri-release.conf.json') -Destination (Join-Path $lib 'tauri.conf.json') -Force
 $hookDir=Join-Path $lib 'windows'
 New-Item -ItemType Directory -Path $hookDir -Force|Out-Null
 Copy-Item -LiteralPath (Join-Path $repo 'release\windows\release-hooks.nsh') -Destination (Join-Path $hookDir 'release-hooks.nsh') -Force
 foreach($file in @('src\ipc.rs','src\g4_callback.rs','src\g4_thread.rs','src\lib.rs')){
  $path=Join-Path $lib $file
  if($file -eq 'src\ipc.rs'){
   Replace-Code $path 'corsenne_finish_alert_g4_test_' 'corsenne_finish_alert_v12_'
  }elseif($file -eq 'src\g4_callback.rs'){
   Replace-Code $path 'corsenne_finish_alert_g4_cb_' 'corsenne_finish_alert_v12_cb_'
  }elseif($file -eq 'src\lib.rs'){
   Replace-Code $path 'FinishAlertG4Test' 'FinishAlertUnified'
  }
 }
 # Release namespace differs intentionally from the isolated G4 test identity.
 # Adapt only the test expectations in the disposable staging workspace.
 $g4Contracts=Join-Path $desktop 'tests\g4-contract.test.mjs'
 Replace-Code $g4Contracts 'com.corsenne.finishalertdesktop.g4test' 'com.corsenne.finishalertdesktop.unified'
 Replace-Code $g4Contracts 'corsenne_finish_alert_g4_test_' 'corsenne_finish_alert_v12_'
 Replace-Code $g4Contracts 'corsenne_finish_alert_g4_cb_' 'corsenne_finish_alert_v12_cb_'
 $assets=Join-Path $lib 'src\assets'
 $icons=Join-Path $lib 'icons'
 foreach($dir in @($assets,$icons)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
 if($CiSynthetic){
  foreach($name in @('female','holo','soft','pulse')){Silent-Wav (Join-Path $assets ($name+'.wav'))}
  Add-Type -AssemblyName System.Drawing
  $bmp=[Drawing.Bitmap]::new(128,128)
  try{
   $bmp.Save((Join-Path $icons '128x128.png'),[Drawing.Imaging.ImageFormat]::Png)
   $ico=[Drawing.Icon]::FromHandle($bmp.GetHicon())
   try{$file=[IO.File]::Create((Join-Path $icons 'icon.ico'));try{$ico.Save($file)}finally{$file.Dispose()}}
   finally{$ico.Dispose()}
  }finally{$bmp.Dispose()}
 }else{
  foreach($file in @('src\assets\female.wav','src\assets\holo.wav','src\assets\soft.wav','src\assets\pulse.wav','icons\icon.ico','icons\128x128.png')){
   $src=Join-Path $g2b $file
   if(-not(Test-Path -LiteralPath $src -PathType Leaf)){throw 'G5_PRIVATE_ASSET_MISSING'}
   $dst=Join-Path $lib $file
   Copy-Item -LiteralPath $src -Destination $dst -Force
  }
 }
 Write-Host 'G5_DESKTOP_RELEASE_SOURCES_STAGED'
 $hostDir=Join-Path $work 'native-host'
 Copy-Sources (Join-Path $repo 'candidate-g4\native-host') $hostDir
 Replace-Code (Join-Path $hostDir 'src\main.rs') 'corsenne_finish_alert_g4_test_' 'corsenne_finish_alert_v12_'
 Replace-Code (Join-Path $hostDir 'src\main.rs') 'corsenne_finish_alert_g4_cb_' 'corsenne_finish_alert_v12_cb_'
 & cargo test --manifest-path (Join-Path $hostDir 'Cargo.toml')
 if($LASTEXITCODE -ne 0){throw 'G5_NATIVE_BRIDGE_TEST_HOLD'}
 & cargo build --manifest-path (Join-Path $hostDir 'Cargo.toml') --release
 if($LASTEXITCODE -ne 0){throw 'G5_NATIVE_BRIDGE_BUILD_HOLD'}
 $resources=Join-Path $lib 'resources\release'
 New-Item -ItemType Directory -Path $resources -Force|Out-Null
 Copy-Item -LiteralPath (Join-Path $hostDir 'target\release\finish-alert-g4-bridge.exe') -Destination (Join-Path $resources 'finish-alert-bridge.exe') -Force
 Copy-Item -LiteralPath (Join-Path $repo 'release\Manage-Release.ps1') -Destination (Join-Path $resources 'Manage-Release.ps1') -Force
 $adapter=Join-Path $resources 'Codex-Stop-to-v12.ps1'
 Copy-Item -LiteralPath (Join-Path $repo 'candidate-g4\Codex-Stop-to-G4.ps1') -Destination $adapter -Force
 Replace-Code $adapter 'corsenne_finish_alert_g4_test_' 'corsenne_finish_alert_v12_'
 Copy-Item -LiteralPath (Join-Path $repo 'release\extension') -Destination (Join-Path $resources 'extension') -Recurse -Force
 Copy-Item -LiteralPath (Join-Path $repo 'candidate-g4c2\chrome-extension\background.js') -Destination (Join-Path $resources 'extension\background.js') -Force
 Copy-Item -LiteralPath (Join-Path $repo 'candidate-g4c2\chrome-extension\content.js') -Destination (Join-Path $resources 'extension\content.js') -Force
 $bg=Join-Path $resources 'extension\background.js'
 Replace-Code $bg "const HOST='com.corsenne.finish_alert_g4c2_test';" "const HOST='com.corsenne.finish_alert';"
 Replace-Code $bg ' if(!(await claimCycle(route.cycleKey)))return {ok:true,suppressed:'duplicate'};' @'
 const settings=await chrome.storage.local.get({enabled:true,soundId:'female',soundVolume:85});
 if(settings.enabled===false)return {ok:true,suppressed:'disabled'};
 const soundId=['holo','soft','pulse','female'].includes(settings.soundId)?settings.soundId:'female';
 const soundVolume=Number.isFinite(Number(settings.soundVolume))?
     Math.max(0,Math.min(100,Math.round(Number(settings.soundVolume)))):85;
 if(!(await claimCycle(route.cycleKey)))return {ok:true,suppressed:'duplicate'};
'@
 Replace-Code $bg "soundId:'female',soundVolume:85,audioOwner:'desktop'" "soundId,soundVolume,audioOwner:'desktop'"
 $version=[string]$releaseConfig.version
 [IO.File]::WriteAllText((Join-Path $resources 'release-version.txt'),$version,[Text.UTF8Encoding]::new($false))
 if($CiSynthetic){Silent-Wav (Join-Path $resources 'private-leo.wav')}
 else{Copy-Item -LiteralPath $g2bVoice -Destination (Join-Path $resources 'private-leo.wav') -Force}
 Write-Host 'G5_NSIS_RESOURCE_PAYLOAD_STAGED'
 Test-And-Build
 $files=@(Get-ChildItem -LiteralPath $bundle -File -Filter '*setup.exe')
 if($files.Count -ne 1){throw 'G5_NSIS_SETUP_NOT_UNIQUE'}
 if($CiSynthetic){
  Write-Host 'G5_SYNTHETIC_NSIS_COMPILE_PASS_NOT_FOR_DISTRIBUTION'
  exit 0
 }
 $out=Join-Path $env:USERPROFILE 'Downloads'
 if(-not(Test-Path -LiteralPath $out -PathType Container)){throw 'G5_DOWNLOAD_FOLDER_MISSING'}
 $dest=Join-Path $out ('Finish-Alert-Unified-'+$version+'-Setup.exe')
 if(Test-Path -LiteralPath $dest -PathType Leaf){throw 'G5_SETUP_ALREADY_EXISTS_NO_OVERWRITE'}
 Copy-Item -LiteralPath $files[0].FullName -Destination $dest
 $sha=[Security.Cryptography.SHA256]::Create()
 try{
  $stream=[IO.File]::OpenRead($dest)
  try{$digest=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose()}
 }finally{$sha.Dispose()}
 Write-Host 'G5_V120_NSIS_READY'
 Write-Host ('G5_SETUP='+$dest)
 Write-Host ('G5_SHA256='+$digest)
 Write-Host 'G5_SETUP_NOT_EXECUTED'
}catch{
 Write-Host ('G5_BUILD_HOLD='+$_.Exception.Message)
 exit 2
}
