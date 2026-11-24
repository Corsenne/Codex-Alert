# Source-only Windows regression: check original extension validation is safe.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$source=Join-Path (Split-Path -Parent $PSScriptRoot) 'Manage-Release.ps1'
$tokens=$null;$errorsFound=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errorsFound)
if(@($errorsFound).Count -ne 0){throw 'G5_EXTENSION_VALIDATOR_PARSE_HOLD'}
$sourceCode=[IO.File]::ReadAllText($source)
foreach($expected in @(
 'G5_ORIGINAL_EXTENSION_FOLDER_NOT_FOUND',
 'G5_EXTENSION_PARENT_DIRECTORY_UNAVAILABLE',
 'G5_EXTENSION_SOURCE_DIRECTORY_VERIFIED',
 '[IO.DirectoryInfo]::new($dir)',
 'G5_EXTENSION_SYMLINK_HOLD'
)){
 if(-not $sourceCode.Contains($expected)){throw 'G5_EXTENSION_VALIDATOR_INCOMPLETE'}
}
if($sourceCode.Contains('Get-Item -LiteralPath $walk')){throw 'G5_OLD_PATH_WALK_REMAINS'}
Write-Host 'G5_EXTENSION_VALIDATOR_SOURCE_PASS'
