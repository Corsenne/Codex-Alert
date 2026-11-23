[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
function Fail([string]$code){throw $code}
try{
 $stateRoot=Join-Path $env:LOCALAPPDATA 'FinishAlertUnified'
 $stateFile=Join-Path $stateRoot 'release-state.json'
 if(-not(Test-Path -LiteralPath $stateFile -PathType Leaf)){Fail 'G5_POPUP_REPAIR_NOT_ACTIVATED'}
 $state=Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8|ConvertFrom-Json
 if($state.schema -ne 1 -or [string]$state.extensionId -cnotmatch '^[a-p]{32}$'){Fail 'G5_POPUP_REPAIR_STATE_INVALID'}
 $dir=[IO.Path]::GetFullPath([string]$state.extensionDir)
 $root=[IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')+'\'
 if(-not $dir.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){Fail 'G5_POPUP_REPAIR_OUTSIDE_PROFILE'}
 if(-not(Test-Path -LiteralPath $dir -PathType Container)){Fail 'G5_POPUP_REPAIR_EXTENSION_MISSING'}
 $walk=[IO.DirectoryInfo]::new($dir)
 $user=[IO.DirectoryInfo]::new($env:USERPROFILE)
 while($null -ne $walk){
  if(-not $walk.Exists){Fail 'G5_POPUP_REPAIR_PARENT_MISSING'}
  if(($walk.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){Fail 'G5_POPUP_REPAIR_SYMLINK_HOLD'}
  if([string]::Equals($walk.FullName,$user.FullName,[StringComparison]::OrdinalIgnoreCase)){break}
  $walk=$walk.Parent
 }
 if($null -eq $walk){Fail 'G5_POPUP_REPAIR_OUTSIDE_PROFILE'}
 $manifestFile=Join-Path $dir 'manifest.json'
 $popup=Join-Path $dir 'popup.html'
 $js=Join-Path $dir 'popup.js'
 foreach($path in @($manifestFile,$popup,$js)){
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){Fail 'G5_POPUP_REPAIR_FILE_MISSING'}
 }
 $m=Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8|ConvertFrom-Json
 $expectedName='ChatGPT Finish Alert '+[char]0x2014+' Desktop Edition'
 if($m.manifest_version -ne 3 -or [string]$m.name -cne $expectedName -or [string]$m.version -cnotmatch '^1\.2\.\d+$' -or [string]$m.action.default_popup -cne 'popup.html'){Fail 'G5_POPUP_REPAIR_MANIFEST_INVALID'}
 $original=[IO.File]::ReadAllText($popup,[Text.Encoding]::UTF8)
 if($original -match '<script\s+src="popup\.js"'){Write-Host 'G5_POPUP_ALREADY_FIXED';exit 0}
 if($original -notmatch 'id="enabled"' -or $original -notmatch 'id="soundId"' -or $original -notmatch 'id="soundVolume"'){Fail 'G5_POPUP_REPAIR_LAYOUT_UNEXPECTED'}
 $marker='</body></html>'
 if(-not $original.Contains($marker)){Fail 'G5_POPUP_REPAIR_LAYOUT_END_MISSING'}
 $fixed=$original.Replace($marker,'<script src="popup.js" defer></script>'+[Environment]::NewLine+$marker)
 $backupDir=Join-Path $stateRoot 'popup-repair-backup'
 if(-not(Test-Path -LiteralPath $backupDir -PathType Container)){New-Item -ItemType Directory -Path $backupDir -Force|Out-Null}
 $backup=Join-Path $backupDir 'popup-before-script-fix.html'
 if(-not(Test-Path -LiteralPath $backup -PathType Leaf)){[IO.File]::WriteAllText($backup,$original,[Text.UTF8Encoding]::new($false))}
 $tmp=Join-Path $dir 'popup.html.g5-new'
 [IO.File]::WriteAllText($tmp,$fixed,[Text.UTF8Encoding]::new($false))
 Move-Item -LiteralPath $tmp -Destination $popup -Force
 Write-Host 'G5_POPUP_SCRIPT_REPAIRED_PASS'
 Write-Host 'G5_RELOAD_ORIGINAL_EXTENSION_IN_CHROME'
 exit 0
}catch{
 Write-Host ('G5_POPUP_REPAIR_HOLD='+$_.Exception.Message)
 exit 2
}
