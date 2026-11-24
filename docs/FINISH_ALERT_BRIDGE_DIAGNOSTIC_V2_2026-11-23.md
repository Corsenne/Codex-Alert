# Finish Alert residual native bridge diagnostic (2026-11-23)

**Evidence: user's read-only V2 diagnostic. No installed software or Chrome configuration modified.**

| Field | Observed |
|---|---|
| Installed manifest | v1.1.5 |
| Chrome profiles examined | 3 |
| Preferences + Secure Preferences parsed | 6 / 6 |
| Finish Alert matching extension records | 1 in Default / Secure Preferences |
| finish-alert-bridge.exe | **27 processes; 106.9 MB aggregate working set; oldest 2497 minutes** |
| finish-alert-desktop.exe | 1 process; 27.4 MB aggregate working set; oldest 2528 minutes |
| Mutation | NONE |

## Interpretation

There is strong evidence of accumulated native-messaging bridge processes. It is not evidence of 27 enabled Chrome extensions or of 27 completion notifications: bridge processes pass messages; Chrome content script generates completion events. The 1 extension preference record does not prove whether it is enabled, but makes same-profile duplicate installs less likely.

Existing v1.1.4 bridge source runs a native messaging host per connectNative port, forwards v2 messages to one session-local pipe, and normally exits when Chrome closes stdin. Chrome background v1.1.5 schedules disconnect after 90 s idle and calls closeNative on ACK timeout. This means 27 long-lived bridge instances warrant lifecycle/handle-leak investigation, not automatic assumption that 27 broadcasts occur. The Tauri desktop's IPC server accepts multiple connections and broadcasts notification.open to all; this could cause duplicate *click callbacks*, not new completion events.

## Short-term safe recovery

A separately delivered local-only tool offers a read-only Audit.cmd and opt-in Cleanup.cmd (Windows PowerShell 5.1), which:
- **refuses cleanup if any chrome.exe is running**;
- validates exact expected bridge EXE in LOCALAPPDATA, current Windows session, process identity and creation time;
- stops only selected bridge processes after typed confirmation;
- does **not** terminate desktop, Chrome or Codex, and does not edit settings/files.
Run only after saving work and manually closing all Chrome windows. If bridge path differs, stop and inspect; never kill broadly by name.

After cleanup, reopen Chrome and test 1 turn -> exactly 1 custom banner + 1 voice, then observe bridge count after multiple 90s idle intervals. If repeating notifications persist, collect **non-content** event correlation: documentId / cycleId / eventId / tab ID, with a separately audited read-only logging plan, not transcripts.

## Permanent correction gate

1. Confirm bridge process lifetime vs port disconnect/EOF, including Chrome shut down, worker suspension, multiple tabs, failed ACK and staged replay.
2. Fix host idle/shutdown semantics without breaking click-to-original-chat or introducing duplicate sound.
3. Keep stable v1.1.5 unchanged until a Windows integration build passes event delivery regression, timeout/no-duplicate, CPU/memory soak and safe rollback.
4. Unified G2 must remain a separate development branch; do not conflate this process leak with Codex Stop hook.

**Status: orphan bridge cleanup candidate, repeat-notification causality UNCONFIRMED.**
