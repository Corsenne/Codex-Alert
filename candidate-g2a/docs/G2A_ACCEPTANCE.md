# G2A candidate: explicit acceptance and blockers

## Verified locally on Linux, 2026-11-23

- Node Chrome tests: content detection regression, config/popup, audio preview, native receiver compatibility, confirmed native audio ownership, no ambiguous-ACK double notification, Chrome fallback, queue-full no audio overlap.
- Pure transition model: six FIFO/one-visible/stop-before-open/overflow/stale event cases PASS.
- Tauri front-end source checks: two PASS.
- Native source contract static checks: PASS.
- SHA-256 and ZIP CRC checks: PASS.
- Supplied private WAV: RIFF PCM16 format checked.

## Not verified (do not claim G2 completed)

- Windows Rust/Tauri/Native Messaging compilation or runtime.
- Actual sound stop timing and acoustic non-overlap across Chrome/Codex.
- Whether 180-sec idle bridge watchdog and null stdio eliminate bridge process accumulation on this PC.
- Correct foreground selection of old ChatGPT tab under Chrome MV3 service worker restarts.
- Codex exact-thread link: G3 on hold pending live session ID comparison. Clicking Codex at G2 stops/dismisses but does not choose a guessed thread.
- Installer and controlled cutover of the existing legacy Codex Stop hook.

## Regression philosophy

- Existing installed ChatGPT Finish Alert v1.1.5 **not modified**.
- Existing Codex WinForms Stop Hook **not modified**.
- Codex standard permission notifications remain enabled.
- Do not deploy Chrome v1.2 alone; deploy tested Windows v1.2 first, then browser v1.2, then change Codex Stop Hook exactly once after acceptance.

## Windows steps

Run `Test-G2.cmd` from an extracted folder. It does not install anything. `node` is required for source tests; if `cargo` exists it will run native bridge + Tauri Rust unit tests. To verify UI itself, `npm install`, `npm run build` from `desktop` and Windows Tauri host test must follow on the isolated source copy.

A printed Node PASS without Cargo means **G2A_SOURCE_PASS / WINDOWS_RUNTIME_HOLD**.
