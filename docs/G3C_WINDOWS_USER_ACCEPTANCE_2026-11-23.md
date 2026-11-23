# G3C isolated ChatGPT click return — Windows user acceptance (2026-11-23)

**Result: USER-REPORTED PASS for the manual G3C scenario.**

## Evidence
- After executing the G3C test instructions, the user reported: **「OK、成功！」**.
- The instructed scenario: open ChatGPT conversation A, use the G3C no-monitoring test extension to generate one manual banner, switch to another ChatGPT conversation B, click the banner, and check that the voice stops and the correct original conversation A returns.
- The user confirmed overall success. No individual final-run console log, click latency measurement, or separate screenshot was supplied.
- The optional minimized-window repeat was not separately confirmed in the message; do not mark that Windows visual subtest passed solely from the general report.

## What can now be accepted
- G3C **isolated** manual Chrome test-extension → native messaging bridge → separate Windows Tauri banner → click callback → original ChatGPT conversation return: **user-observed PASS**.
- Stop-on-click audio is included in the overall success report but no measurable interruption latency is available.
- Distinct test identities prevented intentional modifications of the stable installed Finish Alert v1.1.5 and legacy Codex Alert. This report does not verify that cleanup has been performed.

## Still HOLD for production
- End-to-end *real* ChatGPT answer completion detection → shared native FIFO banner → browser exact-tab return.
- Concurrent real ChatGPT/Codex notification serialization and one-owner voice playback across sources.
- Production-safe duplex callback transport, native bridge lifecycle soak preventing accumulated orphan processes, multiple-tab/cold-start/reconnect regressions.
- Exact Codex Stop Hook cutover (replace one legacy handler, never duplicate), permission notifications preserved.
- User-approved rollback and one-file installation/update acceptance.

## Next operational step
Run G3C-Cleanup.cmd and type CLEANUP to remove only the dedicated G3C test Native Messaging registration and stop its own executables; remove the separate no-monitoring test extension from chrome://extensions/. Do not remove the stable Finish Alert extension.

**This is not a release or production cutover authorization.**