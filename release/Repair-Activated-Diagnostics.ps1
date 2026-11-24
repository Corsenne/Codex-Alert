# Repair only popup diagnostics of the already activated G5 Chrome extension.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
function Fail([string]$code){throw $code}
try{
 $repo=Split-Path -Parent $PSScriptRoot
 $stateFile=Join-Path $env:LOCALAPPDATA 'FinishAlertUnified\release-state.json'
 if(-not(Test-Path -LiteralPath $stateFile -PathType Leaf)){Fail 'G5_DIAG_NOT_ACTIVATED'}
 $state=Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8|ConvertFrom-Json
 if($state.schema -ne 1 -or [string]$state.extensionId -cnotmatch '^[a-p]{32}$'){Fail 'G5_DIAG_STATE_INVALID'}
 $dir=[IO.Path]::GetFullPath([string]$state.extensionDir)
 $root=[IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')+'\'
 if(-not $dir.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){Fail 'G5_DIAG_OUTSIDE_USER'}
 $walk=[IO.DirectoryInfo]::new($dir)
 $user=[IO.DirectoryInfo]::new($env:USERPROFILE)
 while($null -ne $walk){
  if(-not $walk.Exists){Fail 'G5_DIAG_DIRECTORY_MISSING'}
  if(($walk.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){Fail 'G5_DIAG_SYMLINK_HOLD'}
  if([string]::Equals($walk.FullName,$user.FullName,[StringComparison]::OrdinalIgnoreCase)){break}
  $walk=$walk.Parent
 }
 if($null -eq $walk){Fail 'G5_DIAG_PARENT_MISMATCH'}
 $manifest=Join-Path $dir 'manifest.json'
 $html=Join-Path $dir 'popup.html'
 $dest=Join-Path $dir 'popup.js'
 $src=Join-Path $repo 'release\extension\popup.js'
 foreach($p in @($manifest,$html,$dest,$src)){
  if(-not(Test-Path -LiteralPath $p -PathType Leaf)){Fail 'G5_DIAG_FILE_MISSING'}
 }
 $m=Get-Content -LiteralPath $manifest -Raw -Encoding UTF8|ConvertFrom-Json
 $name='ChatGPT Finish Alert '+[char]0x2014+' Desktop Edition'
 if($m.manifest_version -ne 3 -or [string]$m.name -cne $name -or [string]$m.version -cnotmatch '^1\.2\.\d+$' -or [string]$m.action.default_popup -cne 'popup.html'){Fail 'G5_DIAG_EXTENSION_IDENTITY_MISMATCH'}
 if(([IO.File]::ReadAllText($html)) -notmatch '<script\s+src="popup\.js"'){Fail 'G5_DIAG_POPUP_SCRIPT_NOT_LINKED'}
 $new=[IO.File]::ReadAllText($src,[Text.Encoding]::UTF8)
 if($new -notmatch 'status-timeout' -or $new -notmatch 'G4C2_STATUS'){Fail 'G5_DIAG_SOURCE_INVALID'}
 $old=[IO.File]::ReadAllText($dest,[Text.Encoding]::UTF8)
 if($old -ceq $new){Write-Host 'G5_DIAGNOSTICS_ALREADY_CURRENT';exit 0}
 $backupDir=Join-Path $env:LOCALAPPDATA 'FinishAlertUnified\popup-repair-backup'
 if(-not(Test-Path -LiteralPath $backupDir -PathType Container)){New-Item -ItemType Directory -Path $backupDir -Force|Out-Null}
 $backup=Join-Path $backupDir 'popup-before-diagnostics.js'
 if(-not(Test-Path -LiteralPath $backup -PathType Leaf)){[IO.File]::WriteAllText($backup,$old,[Text.UTF8Encoding]::new($false))}
 $tmp=Join-Path $dir 'popup.js.g5-new'
 [IO.File]::WriteAllText($tmp,$new,[Text.UTF8Encoding]::new($false))
 Move-Item -LiteralPath $tmp -Destination $dest -Force
 Write-Host 'G5_DIAGNOSTICS_POPUP_REPAIRED_PASS'
 Write-Host 'G5_RELOAD_ORIGINAL_EXTENSION_IN_CHROME'
 exit 0
}catch{
 Write-Host ('G5_DIAGNOSTICS_REPAIR_HOLD='+$_.Exception.Message)
 exit 2
}
