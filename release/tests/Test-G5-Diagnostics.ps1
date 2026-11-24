[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$js=[IO.File]::ReadAllText((Join-Path $repo 'release\extension\popup.js'),[Text.Encoding]::UTF8)
foreach($part in @('G4C2_STATUS','status-timeout','Promise.race','clearTimeout(timer)','target.textContent')){
 if(-not $js.Contains($part)){throw 'G5_DIAG_STATUS_MISSING'}
}
$path=Join-Path $repo 'release\Repair-Activated-Diagnostics.ps1'
$t=$null;$errorsFound=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$t,[ref]$errorsFound)
if(@($errorsFound).Count){throw 'G5_DIAG_REPAIR_PARSE_ERROR'}
Write-Host 'G5_DIAG_STATUS_VISIBLE_AND_REPAIR_PARSE_PASS'
