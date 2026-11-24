# Synthetic G4 mixed-source FIFO delivery (NO Chrome integration, NO real Codex Hook).
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$session=[Diagnostics.Process]::GetCurrentProcess().SessionId
$pipe=[IO.Pipes.NamedPipeClientStream]::new('.',
  ('corsenne_finish_alert_g4_test_'+$session),
  [IO.Pipes.PipeDirection]::InOut,[IO.Pipes.PipeOptions]::Asynchronous)
try{
  $pipe.Connect(7000)
  $utf8=[Text.UTF8Encoding]::new($false)
  $writer=[IO.StreamWriter]::new($pipe,$utf8,1024,$true)
  $reader=[IO.StreamReader]::new($pipe,$utf8,$false,1024,$true)
  try{
    $uid=[guid]::NewGuid().ToString('N')
    $id1='codex-'+$uid
    $id2='test-'+$uid
    $id3='codex-'+[guid]::NewGuid().ToString('N')
    $stamp=[DateTime]::UtcNow.ToString('o')
    $callbackName='\\.\pipe\corsenne_finish_alert_g4_cb_'+$session+'_'+[Diagnostics.Process]::GetCurrentProcess().Id
    $messages=@(
      [ordered]@{version=3;type='deliver';event=[ordered]@{
        version=3;source='codex';eventId=$id1;chatTitle='CODEX / G4 SYNTHETIC'
        completedAt=$stamp;openTarget=$null};soundId='leo';soundVolume=85},
      [ordered]@{version=2;type='deliver';event=[ordered]@{
        version=2;source='chatgpt';eventId=$id2;chatTitle='CHATGPT / G4 SYNTHETIC'
        completedAt=$stamp;conversationUrl='https://chatgpt.com/c/12345678'
        bridgeCallbackPipe=$callbackName;tabId=0;windowId=0};
        soundId='female';soundVolume=85;audioOwner='desktop'},
      [ordered]@{version=3;type='deliver';event=[ordered]@{
        version=3;source='codex';eventId=$id3;chatTitle='CODEX / SECOND'
        completedAt=$stamp;openTarget=$null};soundId='leo';soundVolume=60}
    )
    $messages+=,$messages[0]
    $expected=@('active','queued','queued','duplicate')
    for($i=0;$i -lt $messages.Count;$i++){
      $json=$messages[$i]|ConvertTo-Json -Depth 8 -Compress
      $write=$writer.WriteLineAsync($json)
      if(-not $write.Wait(7000)){throw 'G4_WRITE_TIMEOUT'}
      $flush=$writer.FlushAsync()
      if(-not $flush.Wait(7000)){throw 'G4_FLUSH_TIMEOUT'}
      $read=$reader.ReadLineAsync()
      if(-not $read.Wait(7000)){throw 'G4_ACK_TIMEOUT'}
      $line=$read.Result
      if([string]::IsNullOrWhiteSpace($line) -or $line.Length -gt 8192){throw 'G4_ACK_INVALID_LENGTH'}
      $response=$line|ConvertFrom-Json
      if($response.type -ne 'delivery.ack' -or $response.ok -ne $true -or
         $response.eventId -ne $messages[$i].event.eventId -or
         $response.state -ne $expected[$i]){
        throw ('G4_ACK_MISMATCH_'+$i)
      }
      Write-Host ('G4_EVENT_'+($i+1)+'_ACK='+$response.state)
    }
    Write-Host 'G4_MIXED_SOURCE_FIFO_ACK_PASS'
  }finally{$reader.Dispose();$writer.Dispose()}
} catch{
  Write-Host ('G4_SYNTHETIC_DELIVERY_HOLD: '+$_.Exception.Message)
  exit 2
}finally{$pipe.Dispose()}
