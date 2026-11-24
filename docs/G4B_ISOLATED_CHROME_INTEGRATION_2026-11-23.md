# G4B — Isolated Chrome Native Messaging × Codex Synthetic FIFO (2026-11-23)

## Status and boundary
- Stage: source-ready; **Windows user acceptance required**. G4A is user-reported PASS, while G4B is not yet PASS.
- The existing stable ChatGPT Finish Alert v1.1.5, Codex Stop Hook, and notification preferences must remain unchanged.
- No live Codex Stop Hook, no real answer detection, and no production cutover in this gate.
- The isolated G4 test extension has NO content scripts and NO completion monitor; it only emits a manually requested event.
- The G4 test Native Messaging host is `com.corsenne.finish_alert_g4_test`; test executable and pipe stay under the G4 identity.

## Prerequisites
1. Update the repository branch `feature/codex-finish-alert-g0-g2` with a fast-forward only.
2. The user has already reported `G4_TEST_BUILD_PASS` on this machine. G4B adds operator tools only; the G4 executable and bridge built in G4A may be reused unchanged.
3. Make sure no G4A synthetic runner remains open. G4B-Start refuses to launch a second G4 test executable.
4. Chrome desktop is available. Use a saved ChatGPT conversation URL like `https://chatgpt.com/c/<id>` (not an unsaved new chat).

## Isolated setup — Chrome only
1. Open `chrome://extensions/`, enable **Developer mode**, and **Load unpacked** from `C:\Users\user\Codex-Alert\candidate-g4\chrome-extension`.
2. Copy the ID of **Finish Alert G4 Manual Test (NO MONITORING)**. Do not copy the original stable Finish Alert ID.
3. Run **G4B-Register.cmd**; paste the G4 test extension ID, read the exact HKCU scope, and type `REGISTER`. It rejects an existing G4 test key and never overwrites production keys.
4. Run **G4B-Start.cmd**. Require `G4B_ISOLATED_UI_READY_PASS`.
5. Keep the stable extension and Codex alert installed. The G4 extension cannot automatically observe completions.

## Test 1 — Live Chrome native event and exact-tab click
1. Open saved ChatGPT conversation A in Chrome.
2. Click the **G4 test extension** and its **Send one test banner** button. The popup must report that the banner was accepted.
3. Switch to another chat B or an unrelated app, then click the G4 ChatGPT banner.
4. Expected: its voice stops before navigation; the exact original conversation A receives focus, not B, no extra Chrome notification appears.
5. Inspect the stage-only trace (fixed strings, no conversation URLs or prompts) at:
   `%LOCALAPPDATA%\CodexAlertDev\G4Test\G4B_STAGE_TRACE.txt`.
   Expected includes `G4_CHATGPT_CALLBACK_SENT`. Do not infer an exact browser focus solely from the trace; confirm it visually.

## Test 2 — Mixed source FIFO (ChatGPT first)
1. Start **G4B-Codex-Test.cmd** and leave it at the Enter prompt.
2. In Chrome conversation A, send the manual G4 test banner again.
3. Promptly press Enter in the waiting Codex test window (ideally before the first banner expires). Require `G4B_CODEX_SYNTHETIC_ACK=queued`; `active` means the first notification had already completed or timed out, so repeat the overlap test.
4. Expect one visible banner and one voice at a time. Clicking the ChatGPT banner stops its voice, brings conversation A to the front, then the queued CODEX / G4B SYNTHETIC banner appears.
5. Clicking the synthetic Codex banner does **not** open the Codex app: its `openTarget` is deliberately null. Real Codex exact-thread click was separately evaluated in G3.
6. Repeat with Codex sent first and the Chrome manual event promptly after it; verify the opposite source order if practical.

## Acceptance boundary
- G4B PASS requires user-observed Chrome Native Messaging delivery, exact conversation return, and at least one truly queued mixed-source alert (Codex sender ACK=queued) with no overlapping voice/banner.
- If a call errors, retain stable products and report `G4B_*_HOLD`, not production PASS.
- The bridge watchdog aims to retire after 90 s without pending events, capped at 12 min; **long-running process soak is deferred to G4C**, not asserted as a G4B PASS.
- No automatic live Codex hook registration or replacement, no production v1.2 Chrome observer, and no installer cutover.

## Isolated cleanup
1. Run **G4B-Cleanup.cmd**, type `CLEANUP` to remove the single G4 HKCU test registration and stop only G4 test executables (full-path checks).
2. Remove **Finish Alert G4 Manual Test (NO MONITORING)** from `chrome://extensions/`. Do **not** remove the stable v1.1.5 extension.
3. Inspect `G4B_TEST_CLEANUP_PASS`. Existing stable settings and products are not changed.

## Source and validation
- G4B operator commands: `G4B-Register.cmd`, `G4B-Start.cmd`, `G4B-Codex-Test.cmd`, `G4B-Cleanup.cmd`.
- Windows PowerShell 5.1 AST parsing and Node source contracts run under G4 GitHub Actions; this does not replace user visual testing.
