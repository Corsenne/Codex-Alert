[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$release=Split-Path -Parent $PSScriptRoot
$html=[IO.File]::ReadAllText((Join-Path $release 'extension\popup.html'),[Text.Encoding]::UTF8)
if($html -notmatch '<script src="popup\.js" defer></script>'){throw 'G5_POPUP_SCRIPT_LINK_HOLD'}
$js=[IO.File]::ReadAllText((Join-Path $release 'extension\popup.js'),[Text.Encoding]::UTF8)
foreach($name in @('enabled','soundId','soundVolume')){
 if($html -notmatch ('id="'+$name+'"') -or $js -notmatch ("'"+$name+"'")){throw 'G5_POPUP_CONTROL_BINDING_HOLD'}
}
$source=Join-Path $release 'Repair-Activated-Popup.ps1'
$tokens=$null;$errorsFound=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errorsFound)
if(@($errorsFound).Count){throw 'G5_POPUP_REPAIR_SCRIPT_PARSE_HOLD'}
Write-Host 'G5_POPUP_SCRIPT_LINK_AND_REPAIR_PARSE_PASS'
