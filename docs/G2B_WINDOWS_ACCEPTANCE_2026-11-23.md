# G2B Windows acceptance — 2026-11-23

Status: **G2B SYNTHETIC INTEGRATION PASS (user-reported visual operation)**

## Actual Windows result

The operator ran the GitHub-synced isolated test `Update-And-Test.cmd` after the frontend build-mode/initialization fixes. The following console output was provided:

```text
G2B_TAURI_FRONTEND_EMBED_BUILD_PASS
G2B_ISOLATED_WINDOWS_BUILD_PASS
G2B_UI_READY_PASS
G2B_EVENT_1_ACK=active
G2B_EVENT_2_ACK=queued
G2B_EVENT_3_ACK=queued
G2B_EVENT_4_ACK=duplicate
G2B_SYNTHETIC_ACK_PASS
```

The operator additionally reported: **「いいね！ちゃんとできた！」** for the G2B GUI test.

## Accepted scope

- Windows Tauri/React embedded UI initialization handshake.
- Named-pipe synthetic delivery and acknowledgment.
- Cross-source admission order: Codex active, ChatGPT queued, second Codex queued.
- Identical event ID rejected as duplicate, instead of creating an extra pending item.
- The user reports that the test UI worked. Actual physical audio waveform / timing was not instrumented separately; do not claim precise stop latency based on ACK output alone.

## Remaining distinct acceptance (G3+)

- Validate exact ChatGPT original tab restoration via Chrome-origin connector, and Codex thread deep-link against real thread metadata.
- Verify click-to-stop audio and strict non-overlap using explicit observed results or timing instrumentation, including dismiss/timeout cases.
- Production IPC must support asynchronous click/close callbacks; the isolated G2B synchronous ACK test path is not a drop-in production replacement.
- Long-run native bridge lifecycle soak / repeated messages across Chrome sessions and duplicate source diagnostics.
- Stop Hook cutover must replace (not add alongside) the existing legacy handler, preserve Codex native permission notifications, provide rollback.
- Final unified desktop installer and Chrome v1.2 changes require separate acceptance.

The installed ChatGPT Finish Alert v1.1.5 and existing Codex alert are unchanged. The private Leo/Anna audio remains local, not committed in this public repository.
