# G3C — ChatGPT Original Tab Click Integration (Isolated Windows Test)

**Status: development candidate. Do not replace the working Finish Alert v1.1.5 or existing Codex Alert.**

## Why this exists
G2B validated FIFO rendering and G3 validated one real Codex thread on click. G3C now tests the full isolated path Chrome manual event → Native Messaging host → separate Tauri desktop → banner click/stop voice → callback Native Messaging host → correct Chrome conversation tab.

## Isolation by construction
| Component | Test-only identity |
|---|---|
| Chrome extension | Finish Alert G3C Click Test (NO MONITORING) |
| Native Messaging host | com.corsenne.finish_alert_g3c_test |
| Registry key | HKCU/Software/Google/Chrome/NativeMessagingHosts/com.corsenne.finish_alert_g3c_test |
| Native bridge binary | %LOCALAPPDATA%/CodexAlertDev/G3CTest/bin/finish-alert-g3c-bridge.exe |
| Desktop app | com.corsenne.finishalertdesktop.g3ctest |
| Native delivery pipe | corsenne_finish_alert_g3c_test_<session> |
| One-shot callback pipe | corsenne_finish_alert_g3c_cb_<session>_<bridge-pid> |
| Private audio/icon assets | copied from %LOCALAPPDATA%/CodexAlertDev/G2BTest, never committed to public GitHub |

The test Chrome extension has **no content_scripts**, no MutationObserver, and no automatic ChatGPT completion monitoring. It only sends one synthetic event when the user presses its popup button. It cannot generate a second real completion alert.

## Setup (once on the user's Windows PC)
1. Open `C:\Users\user\Codex-Alert` and double-click `G3C-Build.cmd`. It fast-forward fetches the feature branch, assembles a separate Tauri build from G2A+G2B+G3C overlays, runs Node and Rust tests, and compiles the isolated Native Messaging bridge. **It does not edit the registry or installed alerts.**
2. In Chrome open `chrome://extensions/`, enable Developer Mode and select **Load unpacked**. Choose `C:\Users\user\Codex-Alert\candidate-g3c\chrome-extension`. Do **not** uninstall the existing stable Finish Alert extension.
3. Copy the ID of the **G3C Click Test** extension (not the stable Finish Alert).
4. Double-click `G3C-Register.cmd`; enter that extension ID and type **REGISTER** to create only the **separate** test Native Messaging key under HKCU. The script refuses to overwrite any existing G3C registration.
5. Double-click `G3C-Start.cmd` and require `G3C_ISOLATED_UI_READY_PASS`.

## One real click trial
1. Open a saved ChatGPT conversation A in Chrome (URL must contain `/c/<id>`; no new unsaved chat).
2. Click the **G3C Click Test** extension icon, then **Send one test banner**. The popup should report accepted.
3. While the banner is displayed, switch to a different Chrome conversation B or another app.
4. Click the G3C banner body (not its X) while the female notification voice is still playing.
5. Confirm (a) audio stopped immediately; (b) Chrome returned to the exact previously selected conversation A rather than B; (c) no Chrome standard duplicate toast or additional synthetic alert appeared.
6. Repeat with conversation A's Chrome window minimized; click must restore/focus it.

## Cleanup
After testing, double-click `G3C-Cleanup.cmd` and type **CLEANUP**. It removes ONLY the G3C HKCU test registration if it still matches the generated manifest and terminates only G3C test executable paths. Remove the G3C Click Test extension manually in `chrome://extensions/`. Existing Finish Alert and Codex Alert remain installed and configured as before.

## Contract and security
- Main delivery/ACK uses a synchronous pipe transaction in the test bridge, avoiding concurrent read/write deadlock on one non-overlapped Windows handle.
- A distinct one-shot, per-bridge callback named pipe carries only the eventId back to the Native Messaging host. The bridge forwards `notification.open` to its authorized extension, which selects the exact URL/tab.
- A callback ID must match an event actually forwarded by the current test bridge. Replays are ignored by browser session idempotence data.
- Only strict ChatGPT conversation URLs are considered; no prompt or response content is collected or transmitted.
- The test bridge is **not** the final production transport. The main production migration, legacy v2 compatibility, Codex Stop Hook cutover, speaker serialization, residual bridge process soak and rollback-controlled installer remain separate acceptance gates.

## Current evidence / isolated acceptance
- G3C Chrome route model, Windows native bridge Rust tests/build, and isolated Tauri Windows build have passed in GitHub Actions.
- **G3C isolated manual browser-to-banner click scenario: user-reported PASS (2026-11-23)**. The user responded 「OK、成功！」 after the instructed end-to-end test.
- No final-run console transcript or measured audio interruption latency was supplied; minimized-window repeat was not independently confirmed.
- See `docs/G3C_WINDOWS_USER_ACCEPTANCE_2026-11-23.md` for the acceptance boundary.
- Production integration, bridge process soak, real ChatGPT detection, rollback and installer remain HOLD. Do not merge the draft PR or install candidate code over stable v1.1.5.
