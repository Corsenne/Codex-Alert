# G4C2R: offline stage-trace reader. No browser/native process modification.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$allowed=@(
 'G2B_UI_READY_PASS','G2B_PIPE_ACCEPTED','G2B_PIPE_EOF',
 'G2B_EVENT_ACTIVE','G2B_EVENT_QUEUED','G2B_EVENT_DUPLICATE',
 'G2B_EVENT_REJECTED','G2B_ACK_SENT','G2B_ACK_WRITE_FAILED',
 'G4_CHATGPT_VOICE_REQUESTED','G4_LEO_PLAY_REQUESTED',
 'G4_AUDIO_STOP_BEFORE_ROUTE','G4_CHATGPT_CALLBACK_SENT',
 'G4_CHATGPT_CALLBACK_FAILED','G4_CHATGPT_CLOSE_SENT',
 'G4_CHATGPT_CLOSE_FAILED','G2B_REQUEST_LINE_READ',
 'G2B_REQUEST_INVALID','G2B_WEBVIEW_NOT_READY',
 'G2B_PAGE_LOAD_STARTED','G2B_PAGE_LOAD_FINISHED',
 'G2B_UI_READY_INVOKED','G2B_EVENT_LISTENER_REGISTERED',
 'G4R_STALE_ACTION_IGNORED','G4R_PROMOTED_WAIT_LE_5S',
 'G4R_PROMOTED_WAIT_GT_5S','G4R_STALE_QUEUED_DROPPED',
 'G4R_PROMOTED_NEXT','G4R_NATIVE_HIDE_FAILED',
 'G4R_NATIVE_HIDE_PASS','G4R_NATIVE_VISIBLE_TIMEOUT',
 'G4R_NATIVE_UNPAINTED_TIMEOUT'
)
$allowSet=@{};foreach($name in $allowed){$allowSet[$name]=$true}
function Inspect-Trace([string]$name,[string]$file){
 Write-Host ('G4C2R_TRACE_NAME='+$name)
 if(-not(Test-Path -LiteralPath $file -PathType Leaf)){
   Write-Host 'G4C2R_TRACE_STATE=NOT_FOUND';return $false
 }
 $info=Get-Item -LiteralPath $file -ErrorAction Stop
 if(($info.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
   Write-Host 'G4C2R_TRACE_STATE=REPARSE_POINT_HOLD';return $false
 }
 if($info.Length -gt 5242880){
   Write-Host 'G4C2R_TRACE_STATE=OVERSIZE_HOLD';return $false
 }
 $age=[Math]::Max(0,[int][Math]::Floor(((Get-Date)-$info.LastWriteTime).TotalMinutes))
 $lines=@(Get-Content -LiteralPath $file -Encoding UTF8 -Tail 512 -ErrorAction Stop)
 $valid=New-Object 'System.Collections.Generic.List[string]';$ignored=0
 foreach($line in $lines){
   $entry=([string]$line).Trim()
   if($allowSet.ContainsKey($entry)){$valid.Add($entry)}else{$ignored++}
 }
 Write-Host 'G4C2R_TRACE_STATE=FOUND'
 Write-Host ('G4C2R_TRACE_AGE_MINUTES='+$age)
 Write-Host ('G4C2R_LINES_ANALYZED='+$lines.Count)
 Write-Host ('G4C2R_KNOWN_STAGES='+$valid.Count)
 Write-Host ('G4C2R_UNRECOGNIZED_LINES='+$ignored)
 foreach($stage in @('G2B_EVENT_ACTIVE','G2B_EVENT_QUEUED',
                     'G2B_EVENT_DUPLICATE','G2B_EVENT_REJECTED',
                     'G4_CHATGPT_VOICE_REQUESTED','G4_CHATGPT_CLOSE_SENT',
                     'G4_AUDIO_STOP_BEFORE_ROUTE','G4_CHATGPT_CALLBACK_SENT',
                     'G2B_ACK_SENT','G4R_NATIVE_VISIBLE_TIMEOUT',
                     'G4R_NATIVE_UNPAINTED_TIMEOUT','G4R_STALE_QUEUED_DROPPED',
                     'G4R_PROMOTED_NEXT','G4R_PROMOTED_WAIT_GT_5S',
                     'G4R_STALE_ACTION_IGNORED')){
   $count=@($valid|Where-Object{$_ -ceq $stage}).Count
   Write-Host ('G4C2R_COUNT_'+$stage+'='+$count)
 }
 $tail=@($valid|Select-Object -Last 48)
 Write-Host ('G4C2R_RECENT_STAGE_COUNT='+$tail.Count)
 for($i=0;$i -lt $tail.Count;$i++){
   Write-Host ('G4C2R_STAGE_{0:D2}={1}' -f ($i+1),$tail[$i])
 }
 return $true
}
try {
 Write-Host 'G4C2R_MODE=READ_ONLY_OFFLINE'
 Write-Host 'G4C2R_PRODUCT_MUTATION=NONE'
 $first=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4Test\G4B_STAGE_TRACE.txt'
 $second=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4C2Test\G4C2_STAGE_TRACE.txt'
 $a=Inspect-Trace 'PREVIOUS_G4B_DESKTOP' $first
 $b=Inspect-Trace 'G4C2_FRESH_START_DESKTOP' $second
 if(-not $a -and -not $b){Write-Host 'G4C2R_HOLD_NO_VALID_TRACE_AVAILABLE';exit 2}
 Write-Host 'G4C2R_STAGE_SEQUENCE_INSPECTION_PASS'
 Write-Host 'G4C2R_TIMING_NOT_VERIFIABLE_NO_STAGE_TIMESTAMPS'
 Write-Host 'G4C2R_EVENT_CORRELATION_NOT_VERIFIABLE_NO_EVENT_IDS'
 Write-Host 'G4C2R_ROOT_CAUSE=HOLD'
}catch{
 Write-Host ('G4C2R_READ_HOLD_CLASS='+$_.Exception.GetType().Name)
 exit 2
}
