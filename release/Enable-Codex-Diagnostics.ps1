[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
function Fail([string]$code){throw $code}
try{
 $repo=Split-Path -Parent $PSScriptRoot
 $base=Join-Path $env:LOCALAPPDATA 'FinishAlertUnified'
 $stateFile=Join-Path $base 'release-state.json'
 $location=Join-Path $base 'install-location.txt'
 if(-not(Test-Path -LiteralPath $stateFile -PathType Leaf)){Fail 'G5_NOT_ACTIVATED'}
 if(-not(Test-Path -LiteralPath $location -PathType Leaf)){Fail 'G5_INSTALL_LOCATION_MISSING'}
 $state=Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8|ConvertFrom-Json
 if($state.schema -ne 1){Fail 'G5_STATE_INVALID'}
 $root=[IO.File]::ReadAllText($location).Trim()
 $dest=Join-Path $root 'resources\release\Codex-Stop-to-v12.ps1'
 $src=Join-Path $repo 'release\diagnostic\Codex-Stop-to-v12.diagnostic.ps1'
 $source=Join-Path $repo 'candidate-g4\Codex-Stop-to-G4.ps1'
 foreach($path in @($dest,$src,$source)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){Fail 'G5_DIAGNOSTIC_FILE_MISSING'}}
 $old=[IO.File]::ReadAllText($dest,[Text.Encoding]::UTF8)
 $expected=[IO.File]::ReadAllText($source,[Text.Encoding]::UTF8).Replace('corsenne_finish_alert_g4_test_','corsenne_finish_alert_v12_')
 $new=[IO.File]::ReadAllText($src,[Text.Encoding]::UTF8)
 if($old -cne $expected -and $old -cne $new){Fail 'G5_ADAPTER_CHANGED_EXTERNALLY'}
 $hookRoot=if($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $env:USERPROFILE '.codex'}
 $hooks=Join-Path $hookRoot 'hooks.json'
 if(-not(Test-Path -LiteralPath $hooks -PathType Leaf)){Fail 'G5_STOP_HOOK_MISSING'}
 $h=Get-Content -LiteralPath $hooks -Raw -Encoding UTF8|ConvertFrom-Json
 $command=[string]$h.hooks.Stop[0].hooks[0].commandWindows
 if(-not $command.Contains($dest)){Fail 'G5_HOOK_TARGET_MISMATCH'}
 $tok=$null;$errorsFound=$null
 [void][System.Management.Automation.Language.Parser]::ParseFile($src,[ref]$tok,[ref]$errorsFound)
 if(@($errorsFound).Count){Fail 'G5_DIAGNOSTIC_PARSE_HOLD'}
 $back=Join-Path $base 'codex-diagnostic-backup'
 if(-not(Test-Path -LiteralPath $back -PathType Container)){New-Item -ItemType Directory -Path $back -Force|Out-Null}
 $backup=Join-Path $back 'Codex-Stop-to-v12.ps1'
 if(-not(Test-Path -LiteralPath $backup -PathType Leaf)){[IO.File]::WriteAllText($backup,$old,[Text.UTF8Encoding]::new($false))}
 if($old -cne $new){[IO.File]::WriteAllText($dest,$new,[Text.UTF8Encoding]::new($false))}
 [IO.File]::WriteAllText((Join-Path $base 'codex-diagnostics.enabled'),'1',[Text.Encoding]::ASCII)
 $log=Join-Path $base 'codex-hook-stages.log'
 if(Test-Path -LiteralPath $log -PathType Leaf){Remove-Item -LiteralPath $log -Force}
 Write-Host 'G5_CODEX_DIAGNOSTICS_ENABLED_PASS'
 Write-Host 'G5_HOOK_CONFIGURATION_AND_CHROME_UNCHANGED'
}catch{
 Write-Host ('G5_CODEX_DIAG_HOLD='+$_.Exception.Message)
 exit 2
}
