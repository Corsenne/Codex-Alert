# G2B Isolated Windows GUI/audio acceptance — 2026-11-23

## Entry evidence
The user's Windows machine returned G2A_WINDOWS_RUST_TESTS_PASS. Five Tauri library unit tests passed:
- cross-source FIFO and silent waiting;
- exact ChatGPT conversation URL allowlist;
- bounded duplicate queue;
- v2/v3 validation and control-character rejection;
- PCM16 WAV scaling.
Main binary and doc tests reported zero tests. This is **Rust unit/build acceptance only**, not GUI/audio acceptance.

## Test packaging
A private ZIP `FinishAlert_Codex_G2B_Isolated_GUI_Test.zip` was prepared for this user's Windows machine. It contains a copy of the G2A development desktop, not an installer.
It uses:
- Tauri ID: `com.corsenne.finishalertdesktop.g2btest`
- EXE: `finish-alert-g2b-test.exe`
- separate pipe `corsenne_finish_alert_g2b_test_<session-id>`
- isolated audio-cache folders
- private local Leo WAV via `FINISH_ALERT_G2B_PRIVATE_WAV`
- test-tagged banner headings and no real browser/Codex click navigation.

Chrome Native Messaging extension registration, live Codex hooks and installed Finish Alert Desktop are not altered. The scripts do not stop the installed desktop or bridge processes.

## How to run
Extract privately delivered ZIP in an ordinary Downloads folder, and double-click `Run-G2B.cmd`. The script builds the dedicated test binary from source, starts it, waits for Enter, and sends synthetic messages to the TEST pipe only. It requests:
1. Codex / Leo / active;
2. ChatGPT / female / queued;
3. Codex / Leo / queued;
4. duplicate of event 1 / duplicate.

Expected machine-readable result: `G2B_SYNTHETIC_ACK_PASS`. Only the operator can verify actual visual/audio behavior.

## User acceptance checklist
- Exactly one 420px-class banner visible at a time, FIFO Codex -> ChatGPT -> Codex.
- Only active event speaks; queued voices do not overlap.
- Clicking first Codex banner while Leo speaks stops sound and moves to next banner. **No navigation** in this isolated test.
- The X and timeout also stop the active voice before the next one is shown.
- Duplicate event does not create a fourth banner or speech.
- Installed stable ChatGPT v1.1.5 remains functional afterward.

## Explicitly not covered yet
- G3 actual Codex thread-deep-link and Chrome original tab activation.
- Native bridge 180-second idle process count soak.
- Full packaging, rollback, migration, loaded production hook.
- Rust/Tauri build and true UI/audio proof must come from Windows output and user observations.

Test-only package includes user-owned audio locally; **never upload Leo/Anna recordings to public GitHub** without confirming the license. The repository contains source/contract only.

**G2B acceptance: HOLD until user-reported Windows visual/audio test.**
