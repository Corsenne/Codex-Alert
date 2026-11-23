# Read-only stage labels for isolated G3C Chrome click testing.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
try {
 $root=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G3CTest'
 $trace=Join-Path $root 'G3C_STAGE_TRACE.txt'
 $statuses=if(Test-Path -LiteralPath $trace -PathType Leaf) {
    @(Get-Content -LiteralPath $trace -ErrorAction Stop | Where-Object {
      $_ -match '^(?:G2B|G3C)_[A-Z0-9_]{3,70}$'
    } | Select-Object -Last 50)
 }else{@('G3C_TRACE_NOT_FOUND')}
 Write-Host '=== G3C isolated runtime status (read only) ==='
 Write-Host ('desktop_test_processes='+@(Get-Process 'finish-alert-g3c-test' -ErrorAction SilentlyContinue).Count)
 Write-Host ('bridge_test_processes='+@(Get-Process 'finish-alert-g3c-bridge' -ErrorAction SilentlyContinue).Count)
 $key='HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.corsenne.finish_alert_g3c_test'
 Write-Host ('test_host_registered='+[bool](Test-Path -LiteralPath $key))
 Write-Host 'stage_only_trace:'
 foreach($stage in $statuses){Write-Host $stage}
 Write-Host 'G3C_READONLY_AUDIT_COMPLETE'
}catch{
 Write-Host 'G3C_READONLY_AUDIT_HOLD'
 exit 2
}
