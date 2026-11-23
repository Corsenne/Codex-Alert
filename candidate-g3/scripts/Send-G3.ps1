# Isolated G3 test driver. Requires a verified local env target set by Run-G3-Click-Test.ps1.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
try {
    $link=[string]$env:FINISH_ALERT_G3_ALLOWED_LINK
    if($link -notmatch '^codex://threads/[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'){
        throw 'G3_NO_VERIFIED_LINK'
    }
    $session=[Diagnostics.Process]::GetCurrentProcess().SessionId
    $pipeName='corsenne_finish_alert_g3_click_test_'+$session
    $pipe=[IO.Pipes.NamedPipeClientStream]::new('.', $pipeName,[IO.Pipes.PipeDirection]::InOut,[IO.Pipes.PipeOptions]::Asynchronous)
    try {
        $pipe.Connect(7000)
        $utf8=[Text.UTF8Encoding]::new($false)
        $writer=[IO.StreamWriter]::new($pipe,$utf8,1024,$true)
        $reader=[IO.StreamReader]::new($pipe,$utf8,$false,1024,$true)
        try {
            $id='codex-'+[guid]::NewGuid().ToString('N')
            $event=[ordered]@{
                version=3;type='deliver'
                event=[ordered]@{
                    version=3;source='codex';eventId=$id
                    chatTitle='CODEX G3 CLICK TEST'
                    completedAt=[DateTime]::UtcNow.ToString('o')
                    openTarget=$link
                }
                soundId='leo';soundVolume=85
            }
            $json=$event|ConvertTo-Json -Depth 8 -Compress
            $task=$writer.WriteLineAsync($json)
            if(-not $task.Wait(7000)){throw 'G3_SEND_TIMEOUT'}
            $flush=$writer.FlushAsync()
            if(-not $flush.Wait(7000)){throw 'G3_FLUSH_TIMEOUT'}
            $ackTask=$reader.ReadLineAsync()
            if(-not $ackTask.Wait(7000)){throw 'G3_ACK_TIMEOUT'}
            $line=$ackTask.Result
            if([string]::IsNullOrWhiteSpace($line) -or $line.Length -gt 8192){throw 'G3_ACK_MISSING_OR_TOO_LARGE'}
            $reply=$line|ConvertFrom-Json
            if($reply.type -ne 'delivery.ack' -or $reply.ok -ne $true -or
                $reply.state -ne 'active' -or $reply.eventId -ne $id){
                throw 'G3_EVENT_NOT_ACCEPTED'
            }
            Write-Host 'G3_TEST_NOTIFICATION_ACK_ACTIVE_PASS'
        }finally{$reader.Dispose();$writer.Dispose()}
    }finally{$pipe.Dispose()}
}catch{
    Write-Host ('G3_TEST_DRIVER_HOLD: '+$_.Exception.Message)
    exit 2
}
