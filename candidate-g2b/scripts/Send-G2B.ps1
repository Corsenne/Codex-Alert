[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$session=[Diagnostics.Process]::GetCurrentProcess().SessionId
$name='corsenne_finish_alert_g2b_test_'+$session
$pipe=[System.IO.Pipes.NamedPipeClientStream]::new('.', $name, [System.IO.Pipes.PipeDirection]::InOut, [System.IO.Pipes.PipeOptions]::Asynchronous)
try {
    $pipe.Connect(7000)
    # Do not assign ReadTimeout/WriteTimeout: this pipe stream does not support the setters.
    $utf8=[System.Text.UTF8Encoding]::new($false)
    $writer=[System.IO.StreamWriter]::new($pipe,$utf8,1024,$true)
    $reader=[System.IO.StreamReader]::new($pipe,$utf8,$false,1024,$true)
    try {
        $uid=[guid]::NewGuid().ToString('N')
        $now=[DateTime]::UtcNow.ToString('o')
        $payloads=@(
            [ordered]@{version=3;type='deliver';event=[ordered]@{version=3;source='codex';eventId=('codex-'+$uid);chatTitle='TALOS / G2B TEST';completedAt=$now;openTarget=$null};soundId='leo';soundVolume=85},
            [ordered]@{version=2;type='deliver';event=[ordered]@{version=2;source='chatgpt';eventId=('test-'+$uid);chatTitle='ChatGPT / G2B TEST';completedAt=$now;conversationUrl=$null};soundId='female';soundVolume=80;audioOwner='desktop'},
            [ordered]@{version=3;type='deliver';event=[ordered]@{version=3;source='codex';eventId=('codex-'+[guid]::NewGuid().ToString('N'));chatTitle='TALOS / SECOND TEST';completedAt=$now;openTarget=$null};soundId='leo';soundVolume=55}
        )
        $payloads+=,$payloads[0]
        $expectedStates=@('active','queued','queued','duplicate')
        for ($i=0;$i -lt $payloads.Count;$i++) {
            $body=$payloads[$i]|ConvertTo-Json -Compress -Depth 8
            $writeTask=$writer.WriteLineAsync($body)
            if (-not $writeTask.Wait(7000)) {throw 'G2B_WRITE_TIMEOUT'}
            $flushTask=$writer.FlushAsync()
            if (-not $flushTask.Wait(7000)) {throw 'G2B_FLUSH_TIMEOUT'}
            $reply=$null
            for ($n=0; $n -lt 6; $n++) {
                $readTask=$reader.ReadLineAsync()
                if (-not $readTask.Wait(7000)) {throw 'G2B_ACK_TIMEOUT'}
                $response=$readTask.Result
                if ($response.Length -gt 8192) {throw 'G2B_ACK_TOO_LARGE'}
                if ([string]::IsNullOrWhiteSpace($response)) {throw 'NO_ACK'}
                $candidate=$response|ConvertFrom-Json
                if ($candidate.type -eq 'delivery.ack') { $reply=$candidate; break }
            }
            if ($null -eq $reply) {throw 'G2B_NO_MATCHING_ACK'}
            if ($reply.type -ne 'delivery.ack' -or $reply.ok -ne $true -or $reply.eventId -ne $payloads[$i].event.eventId -or $reply.state -ne $expectedStates[$i]) {
                throw ('G2B_ACK_MISMATCH event='+$i+' reply='+$response)
            }
            Write-Host ('G2B_EVENT_'+($i+1)+'_ACK='+$reply.state)
        }
        Write-Host 'G2B_SYNTHETIC_ACK_PASS'
    } finally { $reader.Dispose();$writer.Dispose() }
} finally { $pipe.Dispose() }
