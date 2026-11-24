# G4B synthetic Codex event delivered into the isolated G4 queue only.
# The real Codex Stop Hook is NOT installed or touched by this script.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Join-Path $env:LOCALAPPDATA 'CodexAlertDev\G4Test'
$testExe=Join-Path $root 'desktop\src-tauri\target\debug\finish-alert-g4-test.exe'
$pipe=$null
$reader=$null
$writer=$null
try {
    if(-not(Test-Path -LiteralPath $testExe -PathType Leaf)){throw 'G4B_DESKTOP_TEST_NOT_BUILT'}
    $active=@(Get-Process -Name 'finish-alert-g4-test' -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -and [IO.Path]::GetFullPath($_.Path) -ieq [IO.Path]::GetFullPath($testExe)
    })
    if($active.Count -ne 1){throw 'G4B_DESKTOP_TEST_NOT_RUNNING_EXACTLY_ONCE'}
    Write-Host 'G4B TEST ONLY: this sends one synthetic Codex event; no real Codex Hook or deep link.'
    Write-Host 'Recommended: open an existing ChatGPT conversation A, then send the Chrome G4 test banner.'
    Write-Host 'Press ENTER promptly afterward to queue this Codex event before the first banner expires.'
    $answer=Read-Host 'Press ENTER to send; type CANCEL to abort'
    if(-not [string]::IsNullOrEmpty($answer)){Write-Host 'G4B_CODEX_SEND_CANCELLED';exit 0}
    $session=[Diagnostics.Process]::GetCurrentProcess().SessionId
    $name='corsenne_finish_alert_g4_test_'+$session
    $pipe=[IO.Pipes.NamedPipeClientStream]::new('.', $name,
        [IO.Pipes.PipeDirection]::InOut, [IO.Pipes.PipeOptions]::Asynchronous)
    $pipe.Connect(7000)
    $utf8=[Text.UTF8Encoding]::new($false)
    $writer=[IO.StreamWriter]::new($pipe,$utf8,1024,$true)
    $reader=[IO.StreamReader]::new($pipe,$utf8,$false,1024,$true)
    $id='codex-'+[guid]::NewGuid().ToString('N')
    $message=[ordered]@{
        version=3;type='deliver'
        event=[ordered]@{
            version=3;source='codex';eventId=$id
            chatTitle='CODEX / G4B SYNTHETIC'
            completedAt=[DateTime]::UtcNow.ToString('o')
            openTarget=$null
        }
        soundId='leo';soundVolume=75
    }
    $json=$message|ConvertTo-Json -Depth 8 -Compress
    $write=$writer.WriteLineAsync($json)
    if(-not $write.Wait(7000)){throw 'G4B_CODEX_WRITE_TIMEOUT'}
    $flush=$writer.FlushAsync()
    if(-not $flush.Wait(7000)){throw 'G4B_CODEX_FLUSH_TIMEOUT'}
    $reading=$reader.ReadLineAsync()
    if(-not $reading.Wait(7000)){throw 'G4B_CODEX_ACK_TIMEOUT'}
    $line=$reading.Result
    if([string]::IsNullOrWhiteSpace($line) -or $line.Length -gt 8192){throw 'G4B_CODEX_ACK_INVALID'}
    $ack=$line|ConvertFrom-Json
    if($ack.type -cne 'delivery.ack' -or $ack.ok -ne $true -or
       $ack.eventId -cne $id -or @('active','queued') -cnotcontains $ack.state) {
        throw 'G4B_CODEX_ACK_MISMATCH'
    }
    Write-Host ('G4B_CODEX_SYNTHETIC_ACK='+$ack.state)
    Write-Host 'G4B_CODEX_SYNTHETIC_ACK_PASS'
    Write-Host 'This Codex event has openTarget=null; clicking it must NOT launch real Codex.'
}catch{
    Write-Host ('G4B_CODEX_SYNTHETIC_HOLD: '+$_.Exception.Message)
    exit 2
}finally{
    if($null -ne $reader){$reader.Dispose()}
    if($null -ne $writer){$writer.Dispose()}
    if($null -ne $pipe){$pipe.Dispose()}
}
