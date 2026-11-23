# G5 Windows Hook selector regression for two command keys.
# Extract only pure functions (not the top-level release mutation code).
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$file=Join-Path (Split-Path -Parent $PSScriptRoot) 'release\Manage-Release.ps1'
$tokens=$null;$errs=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errs)
if(@($errs).Count){foreach($err in $errs){Write-Host ('G5_PARSER_ERROR='+$err.ToString())};throw 'G5_HOOK_SCRIPT_PARSE_HOLD'}
$names=@('Fail','WindowsField','LegacyField','Command','CheckNewHook')
$found=@($ast.FindAll({
  param($node)
  $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
  $names -contains [string]$node.Name
},$true))
if($found.Count -ne $names.Count){throw 'G5_HOOK_HELPER_NOT_UNIQUE'}
$isolated=($found|ForEach-Object{$_.Extent.Text}) -join [Environment]::NewLine
$scenario=@'
$old='powershell.exe -File "C:\stable\codex-alert.ps1"'
$neutral='powershell.exe -File "C:\other\codex-alert.ps1"'
function Expect([bool]$actual,[string]$label){if(-not $actual){throw ('G5_FIELD_TEST_HOLD_'+$label)}}
$dual=[pscustomobject]@{handler=[pscustomobject]@{command=$neutral;commandWindows=$old}}
Expect ((LegacyField $dual) -ceq 'commandWindows') 'DUAL_OLD'
$dual.handler.commandWindows=Command 'C:\Installed'
CheckNewHook $dual 'C:\Installed'
Expect ($dual.handler.command -ceq $neutral) 'NEUTRAL_UNCHANGED'
$default=[pscustomobject]@{handler=[pscustomobject]@{command=$old}}
Expect ((LegacyField $default) -ceq 'command') 'SINGLE_DEFAULT'
$default.handler.command=Command 'C:\Installed'
CheckNewHook $default 'C:\Installed'
$win=[pscustomobject]@{handler=[pscustomobject]@{commandWindows=$old}}
Expect ((LegacyField $win) -ceq 'commandWindows') 'SINGLE_WINDOWS'
$win.handler.commandWindows=Command 'C:\Installed'
CheckNewHook $win 'C:\Installed'
$bad=[pscustomobject]@{handler=[pscustomobject]@{command=$old;commandWindows='other-script.exe'}}
try{[void](LegacyField $bad);throw 'G5_BAD_WINDOWS_FIELD_ACCEPTED'}
catch{if($_.Exception.Message -ceq 'G5_BAD_WINDOWS_FIELD_ACCEPTED'){throw}}
$changed=[pscustomobject]@{handler=[pscustomobject]@{commandWindows='different script.exe'}}
try{CheckNewHook $changed 'C:\Installed';throw 'G5_WRONG_HOOK_ACCEPTED'}
catch{if($_.Exception.Message -ceq 'G5_WRONG_HOOK_ACCEPTED'){throw}}
Write-Host 'G5_HOOK_SINGLE_AND_DUAL_WINDOWS_FIELDS_PASS'
'@
& ([scriptblock]::Create($isolated+[Environment]::NewLine+$scenario))
if(-not $?){throw 'G5_HOOK_SYNTHETIC_FAILED'}
