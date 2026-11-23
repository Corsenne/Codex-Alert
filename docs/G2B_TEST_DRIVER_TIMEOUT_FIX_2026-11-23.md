# G2B Windows synthetic driver timeout fix — 2026-11-23

## Windows result
- `G2B_ISOLATED_WINDOWS_BUILD_PASS`
- Driver stopped before sending synthetic alerts: assigning `NamedPipeClientStream.ReadTimeout=7000` threw `タイムアウトはこのストリームでサポートされていません。`
- Production Finish Alert and live Codex hooks were not affected.

## Root cause
The test-only PowerShell 5.1 sender used synchronous named-pipe mode and assigned ReadTimeout/WriteTimeout values which are not supported on this stream. G2B GUI and audio remain untested.

## Correction
- Open the client named pipe with `PipeOptions.Asynchronous`.
- Remove direct ReadTimeout/WriteTimeout assignments.
- Use `WriteLineAsync`, `FlushAsync` and `ReadLineAsync` with bounded `Task.Wait(7000)`; error on ACK timeout, missing ACK, bad state or unexpected payload.
- Continue verifying ACK sequence: `active`, `queued`, `queued`, `duplicate`.

## Delivery / protection
A small private local-only hotfix ZIP was given to the user. Its one-click updater scans **Downloads**, validates `com.corsenne.finishalertdesktop.g2btest`, checks the expected unpatched driver SHA-256, backs up the old driver, and replaces just that development file. The prior compiled G2B test EXE may be reused; no installed ChatGPT Finish Alert, live Chrome extension or Codex hook is changed.

The patched driver is a source candidate. Static checks and ZIP CRC PASS. PowerShell 5.1 transport + actual G2B GUI/audio must be re-run and confirmed on Windows before G2B acceptance.

## Expected result
`G2B_SYNTHETIC_ACK_PASS` and user confirmation of one banner at a time; first Leo voice stops when banner clicked; remaining voice tracks the visible queue.
