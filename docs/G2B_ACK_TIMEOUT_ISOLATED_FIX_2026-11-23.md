# G2B ACK timeout after ReadTimeout hotfix — 2026-11-23

## Exact observed result
- G2B isolated Windows Cargo build PASS (with non-fatal dead_code warnings).
- The first source driver failed because it assigned ReadTimeout on an unsupported NamedPipeClientStream mode.
- The asynchronous PowerShell driver hotfix removed this exception, but the next live test stopped with **HOLD: G2B_ACK_TIMEOUT**, before any G2B_EVENT_1_ACK.
- Windows GUI/audio behavior remains **unverified**; do not mark G2B PASS.

## Source-level root-cause candidate
The test-only Rust IPC server creates a **synchronous** (non-overlapped) named pipe. The reader loop and separate ACK-writing thread share a duplicated handle. The reader can re-enter a blocking ReadFile while the ACK writer tries to WriteFile on the same underlying synchronous pipe. According to Microsoft named pipe documentation, concurrent operations on one pipe handle require correctly configured overlapped mode, so this design is a credible source of deadlock. It has not yet been confirmed by a Windows debugger.

## Isolated G2B correction
- Use a single synchronous request handler: ReadLine -> validate/admit -> WriteLine ACK -> flush -> next ReadLine. No separate writer thread for ACK.
- Keep PowerShell client async WriteLineAsync / FlushAsync / ReadLineAsync with bounded Task.Wait(7000).
- Synthetic click events do NOT navigate or send callbacks in this isolated test; production duplex/click handling requires separate G3 design.
- Optionally emit stage-only trace to isolated test folder (G2B_PIPE_ACCEPTED, G2B_REQUEST_LINE_READ, G2B_EVENT_ACTIVE/QUEUED/DUPLICATE, G2B_ACK_SENT); never include chat contents, cwd or event IDs.
- The user-private corrected full ZIP replaces previous G2B packages, so no further old hotfix is needed.

## Offline validation
- Source-structure sanity checks PASS.
- Existing Node synthetic FIFO model 6/6 PASS.
- ZIP manifest SHA256 and ZIP CRC PASS.
- Windows Rust compile and ACK delivery after fix are **NOT YET VERIFIED**.

## Operational isolation
- Test binary and pipe retain G2B-only identity and use the user-local private Leo WAV.
- No writes to installed Finish Alert v1.1.5, Native Messaging registration, Codex hooks or Windows alert services.
- Do not merge into main, do not install source candidate, do not claim audio/GUI PASS without user test.

## Follow-up
Run **Run-G2B.cmd** from the NEW extracted full ZIP. If it fails, report the printed stage-only G2B trace. Only after G2B_ACK and real sound/display confirmation proceed to G3.
