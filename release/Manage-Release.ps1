# Finish Alert Unified v1.2 release migration. Local, reversible, per-user.
# RegisterInstall does not modify installed stable extension, Chrome settings or Hook.
[CmdletBinding()]
param(
 [ValidateSet('RegisterInstall','Preview','Activate','Update','Rollback')]
 [string]$Mode='Preview',
 [string]$InstallDir='',
 [string]$ExtensionDir=''
)
$ErrorActionPreference='Stop'
$stateRoot=Join-Path $env:LOCALAPPDATA 'FinishAlertUnified'
$locFile=Join-Path $stateRoot 'install-location.txt'
$stateFile=Join-Path $stateRoot 'release-state.json'
$hostName='com.corsenne.finish_alert'
$key='Registry::HKEY_CURRENT_USER\Software\Google\Chrome\NativeMessagingHosts\'+$hostName
$runKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runName='FinishAlertUnified'
# A missing Run value is normal before first activation. Get-ItemPropertyValue
# throws on a missing name even with SilentlyContinue in some PS5 installations.
function Current-AutorunValue(){
 $reg=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run',$false)
 if($null -eq $reg){return $null}
 try{return $reg.GetValue($runName,$null)}finally{$reg.Dispose()}
}
function Fail([string]$code){throw $code}
function Directory([string]$p){if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Path $p -Force|Out-Null}}
function Utf8([string]$path,[string]$value){[IO.File]::WriteAllText($path,$value,[Text.UTF8Encoding]::new($false))}
function JsonSave([string]$path,$value){$tmp=$path+'.new';Utf8 $tmp ($value|ConvertTo-Json -Depth 48);Move-Item -LiteralPath $tmp -Destination $path -Force}
function Require-Resources(){
 $dir=if($InstallDir){$InstallDir}elseif(Test-Path -LiteralPath $locFile -PathType Leaf){[IO.File]::ReadAllText($locFile).Trim()}else{''}
 if(-not $dir -or -not [IO.Path]::IsPathRooted($dir)){Fail 'G5_INSTALL_LOCATION_UNKNOWN'}
 $res=Join-Path ([IO.Path]::GetFullPath($dir)) 'resources\release'
 foreach($name in @('Manage-Release.ps1','Codex-Stop-to-v12.ps1','finish-alert-bridge.exe','private-leo.wav','release-version.txt','extension\manifest.json','extension\background.js','extension\content.js','extension\popup.html','extension\popup.css','extension\popup.js')){
  if(-not(Test-Path -LiteralPath (Join-Path $res $name) -PathType Leaf)){Fail 'G5_INSTALL_PAYLOAD_MISSING'}
 }
 return $res
}
function Version([string]$res){
 $v=[IO.File]::ReadAllText((Join-Path $res 'release-version.txt')).Trim()
 if($v -cnotmatch '^1\.[2-9]\.\d{1,3}$'){Fail 'G5_INVALID_VERSION'}
 return $v
}
function State(){
 if(-not(Test-Path -LiteralPath $stateFile -PathType Leaf)){return $null}
 $o=Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8|ConvertFrom-Json
 if($o.schema -ne 1 -or $o.extensionId -cnotmatch '^[a-p]{32}$' -or -not [IO.Path]::IsPathRooted([string]$o.originalBackup)){Fail 'G5_STATE_INVALID'}
 $base=[IO.Path]::GetFullPath($stateRoot).TrimEnd('\')+'\'
 if(-not [IO.Path]::GetFullPath([string]$o.originalBackup).StartsWith($base,[StringComparison]::OrdinalIgnoreCase)){Fail 'G5_BACKUP_LOCATION_UNTRUSTED'}
 return $o
}
function NativeHost(){
 if(-not(Test-Path -LiteralPath $key)){Fail 'G5_LEGACY_NATIVE_HOST_MISSING'}
 $file=[string](Get-Item -LiteralPath $key).GetValue('')
 if(-not [IO.Path]::IsPathRooted($file) -or -not(Test-Path -LiteralPath $file -PathType Leaf)){Fail 'G5_NATIVE_MANIFEST_MISSING'}
 $m=Get-Content -LiteralPath $file -Raw -Encoding UTF8|ConvertFrom-Json
 if($m.name -cne $hostName -or $m.type -cne 'stdio' -or @($m.allowed_origins).Count -ne 1){Fail 'G5_NATIVE_MANIFEST_UNRECOGNIZED'}
 $origin=[string]$m.allowed_origins[0]
 if($origin -cnotmatch '^chrome-extension://([a-p]{32})/$'){Fail 'G5_EXTENSION_ID_UNVERIFIED'}
 return [pscustomobject]@{file=$file;id=$Matches[1]}
}
function Extension([string]$dir){
 $dir=$dir.Trim().Trim('"')
 if(-not $dir -or -not [IO.Path]::IsPathRooted($dir)){Fail 'G5_EXTENSION_PATH_NOT_ABSOLUTE'}
 $dir=[IO.Path]::GetFullPath($dir)
 $root=[IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')+'\'
 if(-not $dir.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){Fail 'G5_EXTENSION_OUTSIDE_USER_PROFILE'}
 # Validate leaf first. Do not assume the provided directory exists.
 if(-not(Test-Path -LiteralPath $dir -PathType Container)){
  Write-Host 'G5_EXTENSION_DIRECTORY_EXISTS=False'
  Fail 'G5_ORIGINAL_EXTENSION_FOLDER_NOT_FOUND'
 }
 # Walk the real parent chain via DirectoryInfo rather than Split-Path and
 # Get-Item on newly constructed string paths. Never ignore reparse points.
 $rootDir=[IO.DirectoryInfo]::new($root.TrimEnd('\'))
 $walk=[IO.DirectoryInfo]::new($dir)
 while($null -ne $walk){
  if(-not $walk.Exists){Fail 'G5_EXTENSION_PARENT_DIRECTORY_UNAVAILABLE'}
  if(($walk.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){Fail 'G5_EXTENSION_SYMLINK_HOLD'}
  if([string]::Equals($walk.FullName,$rootDir.FullName,[StringComparison]::OrdinalIgnoreCase)){break}
  $walk=$walk.Parent
 }
 if($null -eq $walk){Fail 'G5_EXTENSION_PARENT_CHAIN_OUTSIDE_PROFILE'}
 $file=Join-Path $dir 'manifest.json'
 if(-not(Test-Path -LiteralPath $file -PathType Leaf)){Fail 'G5_EXTENSION_MANIFEST_MISSING'}
 $m=Get-Content -LiteralPath $file -Raw -Encoding UTF8|ConvertFrom-Json
 if($m.manifest_version -ne 3 -or $m.name -cne 'ChatGPT Finish Alert — Desktop Edition' -or [string]$m.version -cnotmatch '^1\.(1|2)\.\d+'){Fail 'G5_EXTENSION_NOT_APPROVED'}
 Write-Host 'G5_EXTENSION_SOURCE_DIRECTORY_VERIFIED'
 return $dir
}
function Hook(){
 $root=if($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $env:USERPROFILE '.codex'}
 $file=Join-Path $root 'hooks.json'
 if(-not(Test-Path -LiteralPath $file -PathType Leaf)){Fail 'G5_HOOKS_JSON_MISSING'}
 $doc=Get-Content -LiteralPath $file -Raw -Encoding UTF8|ConvertFrom-Json
 if(@($doc.hooks.Stop).Count -ne 1 -or @($doc.hooks.Stop[0].hooks).Count -ne 1){Fail 'G5_STOP_HOOK_NOT_UNIQUE'}
 $h=$doc.hooks.Stop[0].hooks[0]
 if(-not $h){Fail 'G5_EMPTY_STOP_HANDLER'}
 return [pscustomobject]@{file=$file;document=$doc;handler=$h}
}
# A valid Codex Stop handler may define BOTH platform-neutral command and
# Windows-specific commandWindows. Only the command actually used by Windows
# is replaced, leaving the other field and PermissionRequest hooks untouched.
function WindowsField($hook){
 $props=@($hook.handler.PSObject.Properties.Name)
 if($props -contains 'commandWindows' -and
    -not [string]::IsNullOrWhiteSpace([string]$hook.handler.commandWindows)){
    return 'commandWindows'
 }
 if($props -contains 'command' -and
    -not [string]::IsNullOrWhiteSpace([string]$hook.handler.command)){
    return 'command'
 }
 Fail 'G5_STOP_COMMAND_MISSING'
}
function LegacyField($hook){
 $field=WindowsField $hook
 if([string]$hook.handler.$field -notmatch '(?i)codex-alert\.ps1'){
    Write-Host ('G5_WINDOWS_STOP_FIELD='+$field)
    Write-Host 'G5_WINDOWS_STOP_LEGACY_MATCH=False'
    Fail 'G5_UNEXPECTED_STOP_HOOK'
 }
 Write-Host ('G5_WINDOWS_STOP_FIELD='+$field)
 Write-Host 'G5_WINDOWS_STOP_LEGACY_MATCH=True'
 return $field
}
function Command([string]$root){
 $exe=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $script=Join-Path $root 'resources\release\Codex-Stop-to-v12.ps1'
 return ('"'+$exe+'" -NoProfile -ExecutionPolicy Bypass -File "'+$script+'"')
}
function CheckNewHook($hook,[string]$root){
 $field=WindowsField $hook
 if([string]$hook.handler.$field -cne (Command $root)){
    Fail 'G5_HOOK_MODIFIED_EXTERNALLY'
 }
}
function Files(){return @('manifest.json','background.js','content.js','popup.html','popup.css','popup.js')}
function SaveExt([string]$dir,[string]$backup){
 Directory $backup
 $present=@()
 foreach($n in (Files)){
  if(Test-Path -LiteralPath (Join-Path $dir $n) -PathType Leaf){
   Copy-Item -LiteralPath (Join-Path $dir $n) -Destination (Join-Path $backup $n) -Force
   $present+=,$n
  }
 }
 return ,$present
}
function RestoreExt([string]$dir,[string]$backup,$present){
 foreach($n in (Files)){
  $dst=Join-Path $dir $n
  if(@($present) -ccontains $n){
   $src=Join-Path $backup $n
   if(-not(Test-Path -LiteralPath $src -PathType Leaf)){Fail 'G5_BACKUP_INCOMPLETE'}
   Copy-Item -LiteralPath $src -Destination $dst -Force
  }elseif(Test-Path -LiteralPath $dst -PathType Leaf){Remove-Item -LiteralPath $dst -Force}
 }
}
function DeployExt([string]$resources,[string]$dir){
 foreach($n in (Files)){Copy-Item -LiteralPath (Join-Path $resources ('extension\'+$n)) -Destination (Join-Path $dir $n) -Force}
}
function Bridge([string]$resources,[string]$version,[string]$extId){
 $dir=Join-Path $stateRoot ('bridge\v'+$version)
 Directory $dir
 $exe=Join-Path $dir 'finish-alert-bridge.exe'
 Copy-Item -LiteralPath (Join-Path $resources 'finish-alert-bridge.exe') -Destination $exe -Force
 JsonSave (Join-Path $dir 'bridge-config.json') ([ordered]@{extensionId=$extId})
 $manifest=Join-Path $dir 'com.corsenne.finish_alert.json'
 JsonSave $manifest ([ordered]@{name=$hostName;type='stdio';description='Finish Alert Unified';path=$exe;allowed_origins=@('chrome-extension://'+$extId+'/')})
 return $manifest
}
function Confirm([string]$message,[string]$expected){
 if(([string](Read-Host $message)).Trim() -cne $expected){Fail 'G5_OPERATOR_CANCELLED'}
}
try{
 Write-Host ('G5_MODE='+$Mode)
 if($Mode -eq 'RegisterInstall'){
  $resources=Require-Resources
  Directory $stateRoot
  Utf8 $locFile ([IO.Path]::GetFullPath($InstallDir))
  Write-Host 'G5_NSIS_INSTALLED_PASS'
  if(Test-Path -LiteralPath $stateFile -PathType Leaf){$Mode='Update'}
  else{Write-Host 'G5_FIRST_ACTIVATION_REQUIRED';exit 0}
 }
 $resources=Require-Resources
 $version=Version $resources
 $installRoot=Split-Path -Parent (Split-Path -Parent $resources)
 if($Mode -eq 'Preview'){
  $s=State
  Write-Host ('G5_VERSION='+$version)
  Write-Host ('G5_ACTIVATED='+[bool]($null -ne $s))
  if($null -eq $s){
   $h=Hook;$f=LegacyField $h;$n=NativeHost
   Write-Host 'G5_LEGACY_ONE_STOP_AND_NATIVE_HOST_VERIFIED'
   Write-Host 'G5_ORIGINAL_UNPACKED_EXTENSION_FOLDER_REQUIRED'
  }
  Write-Host 'G5_PREVIEW_PASS_NO_MUTATION';exit 0
 }
 if($Mode -eq 'Activate'){
  if(Test-Path -LiteralPath $stateFile){Fail 'G5_ALREADY_ACTIVATED'}
  $h=Hook;$field=LegacyField $h;$n=NativeHost
  $desktopExe=Join-Path $installRoot 'finish-alert-desktop.exe'
  if(-not(Test-Path -LiteralPath $desktopExe -PathType Leaf)){Fail 'G5_INSTALLED_DESKTOP_EXE_MISSING'}
  $legacyApps=@(Get-Process -Name 'finish-alert-desktop' -ErrorAction SilentlyContinue | Where-Object { -not $_.Path -or $_.Path -ine $desktopExe })
  if($legacyApps.Count -gt 0){Fail 'G5_CLOSE_LEGACY_DESKTOP_BEFORE_ACTIVATE'}
  $oldRun=Current-AutorunValue
  if($oldRun){Fail 'G5_AUTORUN_NAME_ALREADY_IN_USE'}
  if(-not $ExtensionDir){$ExtensionDir=[string](Read-Host 'Original unpacked Finish Alert Chrome extension folder')}
  $ext=Extension $ExtensionDir
  Write-Host 'G5_ONE_STOP_HOOK_ONE_SAME_ID_EXTENSION'
  Write-Host 'G5_DISABLE_BOTH_OLD_OBSERVER_AND_G4C2_BEFORE_ACTIVATING'
  Confirm ('Type ACTIVATE '+$n.id+' to confirm SAME original unpacked folder and extension ID') ('ACTIVATE '+$n.id)
  $backup=Join-Path $stateRoot ('backups\original-'+[guid]::NewGuid().ToString('N'))
  Directory $backup
  Copy-Item -LiteralPath $h.file -Destination (Join-Path $backup 'hooks.json') -Force
  Copy-Item -LiteralPath $n.file -Destination (Join-Path $backup 'native-manifest.json') -Force
  $present=SaveExt $ext (Join-Path $backup 'extension')
  JsonSave (Join-Path $backup 'rollback-info.json') ([ordered]@{extensionId=$n.id;extensionDir=$ext;files=$present;hookPath=$h.file;hostManifest=$n.file;autoRunOriginal=$oldRun})
  try{
   $manifest=Bridge $resources $version $n.id
   $h.handler.$field=Command $installRoot
   JsonSave $h.file $h.document
   DeployExt $resources $ext
   Set-Item -LiteralPath $key -Value $manifest
   Set-ItemProperty -Path $runKey -Name $runName -Value ('"'+$desktopExe+'"')
   JsonSave $stateFile ([ordered]@{schema=1;version=$version;extensionId=$n.id;extensionDir=$ext;originalBackup=$backup;activeManifest=$manifest})
  }catch{
   try{Copy-Item -LiteralPath (Join-Path $backup 'hooks.json') -Destination $h.file -Force}catch{}
   try{RestoreExt $ext (Join-Path $backup 'extension') $present}catch{}
   try{Set-Item -LiteralPath $key -Value $n.file}catch{}
   try{Remove-ItemProperty -Path $runKey -Name $runName -ErrorAction SilentlyContinue}catch{}
   throw
  }
  $alreadyRunning=@(Get-Process -Name 'finish-alert-desktop' -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path -ieq $desktopExe })
  if($alreadyRunning.Count -eq 0){try{Start-Process -FilePath $desktopExe -ErrorAction Stop}catch{Write-Host 'G5_DESKTOP_MANUAL_START_REQUIRED'}}
  Write-Host 'G5_ACTIVATED_PASS'
  Write-Host 'G5_ENABLE_ORIGINAL_EXTENSION_AND_RELOAD_CHROME'
  exit 0
 }
 $s=State
 if($null -eq $s){Fail 'G5_NOT_ACTIVATED'}
 $h=Hook;CheckNewHook $h $installRoot
 if($Mode -eq 'Update'){
  if([string]$s.version -ceq $version){Write-Host 'G5_SAME_VERSION_NO_CHANGE';exit 0}
  $ext=Extension ([string]$s.extensionDir)
  $old=[string](Get-Item -LiteralPath $key).GetValue('')
  if($old -ine [string]$s.activeManifest){Fail 'G5_HOST_WAS_CHANGED'}
  $backup=Join-Path $stateRoot ('backups\update-'+[guid]::NewGuid().ToString('N'))
  $present=SaveExt $ext (Join-Path $backup 'extension')
  $new=Bridge $resources $version $s.extensionId
  try{
   DeployExt $resources $ext
   Set-Item -LiteralPath $key -Value $new
   $s.version=$version;$s.activeManifest=$new
   JsonSave $stateFile $s
  }catch{
   try{RestoreExt $ext (Join-Path $backup 'extension') $present}catch{}
   try{Set-Item -LiteralPath $key -Value $old}catch{}
   throw
  }
  Write-Host 'G5_ONE_CLICK_UPDATE_PASS'
  Write-Host 'G5_CHROME_RELOAD_MAY_BE_REQUIRED';exit 0
 }
 if($Mode -eq 'Rollback'){
  $backup=[string]$s.originalBackup
  $info=Get-Content -LiteralPath (Join-Path $backup 'rollback-info.json') -Raw -Encoding UTF8|ConvertFrom-Json
  if([string]$info.extensionId -cne [string]$s.extensionId){Fail 'G5_ROLLBACK_ID_MISMATCH'}
  Confirm 'Type ROLLBACK to restore original Finish Alert and Codex Stop Hook' 'ROLLBACK'
  Copy-Item -LiteralPath (Join-Path $backup 'hooks.json') -Destination ([string]$info.hookPath) -Force
  RestoreExt ([string]$info.extensionDir) (Join-Path $backup 'extension') $info.files
  Copy-Item -LiteralPath (Join-Path $backup 'native-manifest.json') -Destination ([string]$info.hostManifest) -Force
  Set-Item -LiteralPath $key -Value ([string]$info.hostManifest)
  $registeredRun=Current-AutorunValue
  if($registeredRun -eq ('"'+(Join-Path $installRoot 'finish-alert-desktop.exe')+'"')){Remove-ItemProperty -Path $runKey -Name $runName -ErrorAction SilentlyContinue}
  Move-Item -LiteralPath $stateFile -Destination (Join-Path $stateRoot 'rolled-back-state.json') -Force
  Write-Host 'G5_ORIGINAL_STABLE_ROLLBACK_PASS'
  Write-Host 'G5_REENABLE_STABLE_EXTENSION_AND_CLOSE_UNIFIED_DESKTOP';exit 0
 }
}catch{
 Write-Host ('G5_HOLD='+$_.Exception.Message)
 exit 2
}
