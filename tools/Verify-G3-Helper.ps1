# Strict Windows PowerShell 5.1 parser preflight before interactive G3 deep-link check.
# This must not execute the inspected script and must not output user paths.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
try {
    $target = Join-Path $PSScriptRoot 'G3-Check-Codex-Link.ps1'
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        Write-Host 'G3_HELPER_PARSER_HOLD'
        exit 2
    }
    $tokens = $null
    $errorsFound = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $target, [ref]$tokens, [ref]$errorsFound)
    if (@($errorsFound).Count -gt 0) {
        Write-Host 'G3_HELPER_PARSER_HOLD'
        exit 2
    }
    # Defend against the previous duplicated-content regression even if
    # individual copied chunks happen to be parseable.
    $source = [IO.File]::ReadAllText($target)
    if (([regex]::Matches($source, 'G3_CODEX_SESSION_META_ID_PASS').Count) -ne 1) {
        Write-Host 'G3_HELPER_DUPLICATE_BLOCK_HOLD'
        exit 2
    }
    Write-Host 'G3_HELPER_PARSER_PASS'
} catch {
    Write-Host 'G3_HELPER_PARSER_HOLD'
    exit 2
}
