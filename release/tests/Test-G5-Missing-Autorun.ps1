# G5: a missing HKCU Run value MUST be treated as absent, not an error.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$src=Join-Path (Split-Path -Parent $PSScriptRoot) 'Manage-Release.ps1'
$code=[IO.File]::ReadAllText($src)
$tokens=$null;$errorsFound=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($src,[ref]$tokens,[ref]$errorsFound)
if(@($errorsFound).Count -gt 0){throw 'G5_AUTORUN_PARSE_HOLD'}
$fn=@($ast.FindAll({param($x)
 $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Current-AutorunValue'
},$true))
if($fn.Count -ne 1){throw 'G5_AUTORUN_HELPER_MISSING'}
if($code.Contains('Get-ItemPropertyValue -Path $runKey -Name $runName')){throw 'G5_UNSAFE_AUTORUN_QUERY_REMAINS'}
$runName='G5_Autorun_Probe_Nonexistent_97913012'
. ([scriptblock]::Create($fn[0].Extent.Text))
if($null -ne (Current-AutorunValue)){throw 'G5_AUTORUN_NONEXISTENT_VALUE_NOT_NULL'}
Write-Host 'G5_MISSING_AUTORUN_SAFE_PASS'
