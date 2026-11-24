# Repair only the active Chrome extension service worker; preserve extension ID,
# Chrome storage, Codex Hook, native host and original rollback backup.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
function Fail([string]$code){throw $code}
try{
 $repo=Split-Path -Parent $PSScriptRoot
 $stateRoot=Join-Path $env:LOCALAPPDATA 'FinishAlertUnified'
 $stateFile=Join-Path $stateRoot 'release-state.json'
 if(-not(Test-Path -LiteralPath $stateFile -PathType Leaf)){Fail 'G5_WORKER_NOT_ACTIVATED'}
 $state=Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8|ConvertFrom-Json
 if($state.schema -ne 1 -or [string]$state.extensionId -cnotmatch '^[a-p]{32}$'){Fail 'G5_WORKER_STATE_INVALID'}
 $dir=[IO.Path]::GetFullPath([string]$state.extensionDir)
 $root=[IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')+'\'
 if(-not $dir.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){Fail 'G5_WORKER_PATH_NOT_APPROVED'}
 $walk=[IO.DirectoryInfo]::new($dir)
 $user=[IO.DirectoryInfo]::new($env:USERPROFILE)
 while($null -ne $walk){
  if(-not $walk.Exists){Fail 'G5_WORKER_PATH_MISSING'}
  if(($walk.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){Fail 'G5_WORKER_REPARSE_POINT_HOLD'}
  if([string]::Equals($walk.FullName,$user.FullName,[StringComparison]::OrdinalIgnoreCase)){break}
  $walk=$walk.Parent
 }
 if($null -eq $walk){Fail 'G5_WORKER_PARENT_OUTSIDE_PROFILE'}
 $manifestFile=Join-Path $dir 'manifest.json'
 $target=Join-Path $dir 'background.js'
 $source=Join-Path $repo 'release\extension\background.js'
 foreach($file in @($manifestFile,$target,$source)){
  if(-not(Test-Path -LiteralPath $file -PathType Leaf)){Fail 'G5_WORKER_FILE_MISSING'}
 }
 $m=Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8|ConvertFrom-Json
 $expectedName='ChatGPT Finish Alert '+[char]0x2014+' Desktop Edition'
 if($m.manifest_version -ne 3 -or [string]$m.name -cne $expectedName -or
   [string]$m.version -cnotmatch '^1\.2\.\d+$' -or
   [string]$m.background.service_worker -cne 'background.js'){
  Fail 'G5_WORKER_MANIFEST_NOT_APPROVED'
 }
 if(-not(Get-Command node -ErrorAction SilentlyContinue)){Fail 'G5_NODE_REQUIRED_FOR_SYNTAX_CHECK'}
 & node --check $source
 if($LASTEXITCODE -ne 0){Fail 'G5_REPAIR_SOURCE_SYNTAX_HOLD'}
 $current=[IO.File]::ReadAllText($target,[Text.Encoding]::UTF8)
 $approved=[IO.File]::ReadAllText($source,[Text.Encoding]::UTF8)
 if($current -ceq $approved){Write-Host 'G5_WORKER_ALREADY_CURRENT';exit 0}
 $backupDir=Join-Path $stateRoot 'worker-repair-backup'
 if(-not(Test-Path -LiteralPath $backupDir -PathType Container)){New-Item -ItemType Directory -Path $backupDir -Force|Out-Null}
 $backup=Join-Path $backupDir 'background-before-worker-repair.js'
 if(-not(Test-Path -LiteralPath $backup -PathType Leaf)){
  [IO.File]::WriteAllText($backup,$current,[Text.UTF8Encoding]::new($false))
 }
 $temporary=Join-Path $dir 'background.js.g5-new'
 [IO.File]::WriteAllText($temporary,$approved,[Text.UTF8Encoding]::new($false))
 & node --check $temporary
 if($LASTEXITCODE -ne 0){Remove-Item -LiteralPath $temporary -Force;Fail 'G5_REPAIR_TEMP_SYNTAX_HOLD'}
 Move-Item -LiteralPath $temporary -Destination $target -Force
 Write-Host 'G5_WORKER_SYNTAX_REPAIR_PASS'
 Write-Host 'G5_RELOAD_ORIGINAL_EXTENSION_AND_CHATGPT_TAB'
 exit 0
}catch{
 Write-Host ('G5_WORKER_REPAIR_HOLD='+$_.Exception.Message)
 exit 2
}
