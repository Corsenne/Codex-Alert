# G4C-2 isolated real ChatGPT completion to accepted G4 FIFO — implementation candidate

Date: 2026-11-23. **SOURCE CANDIDATE / Windows user acceptance NOT RUN / production rollout HOLD.**

## Why
G4B isolated manual Chrome Native Messaging and exact-chat click/audio-stop both passed. In G4C-1D, installed stable Finish Alert observed real notifications, but exact-chat click and stop-on-click failed in one trial; the operator then disabled the installed stable v1.1.5 and confirmed G4B isolated click+voice PASS with stable native processes fully stopped. That establishes the scope for testing a new **isolated real observer**, not authorization to update the existing extension ID or native host.

## Architecture
- This candidate's Chrome `content.js` is byte-identical to repository `candidate-g2a/chrome-extension/content.js`, preserving its Stop-button/settling/quiet-time heuristic, manual stop, error suppression, title-only COMPLETE. The local installed v1.1.5 binary/source was not available for byte-level comparison.
- Its new background filters source `sender.id`, documentId, saved ChatGPT conversation URLs (including `g/<project>/c/<chat>`), type `COMPLETE`, and bounded cycle key. A serial queue and `chrome.storage.session` suppress duplicate cycles across MV3 service-worker restarts.
- It sends G4 accepted **v2 / source=chatgpt** event via **new independent Native Messaging registration** `com.corsenne.finish_alert_g4c2_test`. This host uses the tested G4 binary bytes copied to an isolated `G4C2Test/bin` path and the *existing isolated G4 desktop queue* (`corsenne_finish_alert_g4_test_<session>`). No production binary is changed.
- The accepted G4 desktop handles audio exclusively and stops it synchronously on click; it sends `notification.open` through its restricted per-bridge callback pipe to the G4C2 worker, which activates the exact original ChatGPT tab. No new native resident process.
- There is deliberately no Chrome standard notification/audio fallback for unknown ACK in this candidate, avoiding double sound. Native offline or timeout is an explicitly reported HOLD, not a successful delivery.
- No automatic Codex Stop Hook is registered. Previous Codex synthetic FIFO gate is separate.

## Safety / preflight
1. Leave installed stable Finish Alert **v1.1.5 disabled** in `chrome://extensions/`. Do not uninstall it or delete its settings/ID.
2. Disable the G4B manual test extension too, to avoid confusion; its native host registration can remain separately if already present. Never run G4B-Cleanup while the G4C2 shared isolated desktop is being tested.
3. Installed production `finish-alert-desktop.exe` and `finish-alert-bridge.exe` must be absent, as confirmed in previous Windows step.
4. G4C2 is the **only enabled auto-completion observer** on this Chrome profile; G4B is no-monitoring, and no production v1.2 observer is loaded.
5. A saved ChatGPT conversation `/c/<id>` must be used; unsaved new chat URLs are not accepted.

## Windows operator sequence
1. Fast-forward sync branch `feature/codex-finish-alert-g0-g2`. Do not discard tracked modifications or delete untracked files. HEAD must include G4C2 scripts.
2. `chrome://extensions/` → Load unpacked → select `C:\Users\user\Codex-Alert\candidate-g4c2\chrome-extension`. Its visible name is **Finish Alert G4C2 Real Completion TEST (ISOLATED)**.
3. Copy this NEW extension's ID, **not** the stable v1.1.5 ID or the previous G4B manual test ID.
4. Double-click `G4C2-Register.cmd`, provide new extension ID, and type exactly `STABLE_OFF`, `G4B_OFF`, `REGISTER`. Only an isolated HKCU Native Messaging key is created.
5. Double-click `G4C2-Start.cmd`. Require `G4C2_G4_DESKTOP_READY_PASS` or `G4C2_G4_DESKTOP_REUSED_PASS`. Existing G4 desktop and test audio assets from the prior G4B success are reused unchanged.
6. Double-click `G4C2-Real-Use.cmd`. Perform three actual reply completions on saved conversations; observe one banner, one native voice, click-to-stop and exact original tab return. Enter PASS/FAIL for each round; FAIL immediately stops gate.
7. If any failure, leave production settings untouched; report failed round and the absence/presence of banner, audio and click routing. Do not claim release PASS.

## Cleanup
Disable the **G4C2 extension** in Chrome. Close Chrome completely (no `chrome.exe` processes). If an isolated G4C2 bridge remains, do not remove key or kill by name: collect a metadata-only process snapshot for further diagnosis. After G4C2 bridge exits, run `G4C2-Cleanup.cmd`, type `CLEANUP` to remove ONLY G4C2 HKCU test registration. Remove only the test extension if desired; stable v1.1.5 remains disabled until approved product cutover. The G4 test desktop can be exited from its dedicated system tray item.

## Acceptance boundaries
- CI checks observer source fidelity, source/security contract, 3-branch source tests, Windows PowerShell operator AST, and G4 bridge Rust unit tests.
- Windows user acceptance must prove **real** ChatGPT COMPLETE, not G4B manual popup; three real cycles with visual exact-chat click and voice stop.
- G4B synthetic Codex overlap acceptance does not mean the real Codex Hook has been migrated. The existing legacy Stop hook is unchanged.
- Need separate G4C-3 soak (bridge process retirement under disconnect/long queue/worker suspension), host/extension settings rollback design, real Codex integration and G5 installer before product release.
