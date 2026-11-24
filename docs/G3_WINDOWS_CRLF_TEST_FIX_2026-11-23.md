# G3 Windows click-contract false HOLD — line-ending audit (2026-11-23)

## Reported
- G3 routing source tests passed.
- G3 isolated desktop Node suite: 8 passed / 1 failed.
- The failing test was `G3 click stops sound before opening only the authorized Codex link` at the assertion `start>=0 && end>start`.
- The G3 script stopped safely before the Rust/Tauri build and before launching any test click.

## Confirmed root cause
The test found the end of a Rust function with the exact string `#[cfg(windows)]\nfn open_chat_url`. The source file in the GitHub blob has LF newlines, but Git on Windows can check out source files with CRLF. In a simulated CRLF copy, the original test `indexOf` returns -1 even though the correct native function and audio-stop + Codex-link instructions are present. This is a test harness portability bug, not evidence that native click ordering failed.

## Correction
- Normalize CRLF to LF inside the source-contract test before locating the function boundary.
- Improve distinct failure messages for missing handler versus missing boundary.
- Add an explicit LF/CRLF regression test.
- Expand GitHub Actions Windows job to execute the source-contract suite (previously run only on Linux).
- Preserve the native G3 click code, allowlisted exact target, audio-stop call and isolated app identity unmodified.

## Acceptance
Wait for the GitHub Windows test job to pass; then rerun the already checked-out local `G3-Click-Test.cmd` from the user's clone. No ZIP and no installed app update are needed; the launcher syncs the feature branch itself.

Expected after this fix: `G3_ROUTING_SOURCE_TESTS_PASS`, Node G3 click-contract PASS, Rust/Tauri isolated build, and then one synthetic Codex banner. Actual audible Leo stop and the exact Codex chat opening remain operator-observed G3 gates.

Stable ChatGPT Finish Alert v1.1.5 and the existing Codex Stop Hook were not modified.
