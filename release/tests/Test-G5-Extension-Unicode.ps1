# Regression: PowerShell 5.1 UTF-8 source encoding must not corrupt the exact
# official Chrome extension name (em dash).
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$source=Join-Path (Split-Path -Parent $PSScriptRoot) 'Manage-Release.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
if(@($parseErrors).Count){throw 'G5_EXTENSION_NAME_SOURCE_PARSE_HOLD'}
$selected=@($ast.FindAll({param($node)
 $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
 @('Extension','Fail') -contains [string]$node.Name
},$true))
if($selected.Count -ne 2){throw 'G5_EXTENSION_NAME_HELPERS_HOLD'}
$functions=($selected|ForEach-Object{$_.Extent.Text}) -join [Environment]::NewLine
. ([scriptblock]::Create($functions))
$base=Join-Path $env:USERPROFILE ('g5_extension_name_ci_'+[guid]::NewGuid().ToString('N'))
$ext=Join-Path $base 'chrome-extension'
try{
 New-Item -ItemType Directory -Path $ext -Force | Out-Null
 $name='ChatGPT Finish Alert '+[char]0x2014+' Desktop Edition'
 $manifest=[ordered]@{name=$name;version='1.1.5';manifest_version=3}
 [IO.File]::WriteAllText((Join-Path $ext 'manifest.json'),($manifest|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
 if((Extension $ext) -cne $ext){throw 'G5_EXTENSION_115_REJECTED'}
 $manifest.name='ChatGPT Finish Alert - Desktop Edition'
 [IO.File]::WriteAllText((Join-Path $ext 'manifest.json'),($manifest|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
 $rejected=$false
 try{[void](Extension $ext)}catch{if($_.Exception.Message -ceq 'G5_EXTENSION_NOT_APPROVED'){$rejected=$true}else{throw}}
 if(-not $rejected){throw 'G5_EXTENSION_WRONG_NAME_ACCEPTED'}
 Write-Host 'G5_EXTENSION_EXACT_NAME_PS51_PASS'
}finally{
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
