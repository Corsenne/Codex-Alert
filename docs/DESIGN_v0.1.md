# Codex-Alert G0-G2 architecture candidate / 2026-11-23

## Baseline
- Codex Desktop: event-triggered PowerShell / WinForms codex-alert.ps1, notifications for Stop and possibly approval. Actual active hook settings are not included in the user-supplied ZIP.
- ChatGPT Finish Alert: stable v1.1.5 Chrome and v1.1.4 Tauri Windows banner. Do not edit its working detection, audio or old v2 wire format.

## G0 (required before any switch-over)
Use Inspect.cmd on the Codex PC. Verify user config hooks.json and config.toml, plus any project/plugin/system hook sources. Hooks may be loaded from multiple scopes and trigger twice. Keep existing approval notifications. No automated uninstallation or replacement.

## G1 candidate
Stop receives JSON on stdin. The adapter uses session_id + NUL + turn_id for a deterministic SHA-256 event ID; title comes only from the last component of cwd. Do not read/send the assistant message, full cwd or transcripts. Event v3 / source codex / soundId leo is sent once to the existing local named pipe. No polling or new resident process. An ACK timeout must not trigger a second sound or Chrome notification.

## G2 pending
Extend the Tauri renderer to accept v3 codex in an independent, strictly validated branch; v2 chatgpt remains backward compatible. Reuse the approved 420 x 112 dark-blue / cyan banner design. Use CODEX ALERT heading, project title and Codex completion message. Play Leo audio exactly once on Windows; Chrome audio stays on its existing path. Audio stays local and is not published to this public repository until appropriate rights are confirmed. Click-to-thread is G3, not presumed.

## Acceptance
G0: active Stop/PermissionRequest wiring observed and reviewed; no changes.
G1: Windows PowerShell synthetic tests, deterministic IDs, no PII transfer, no approval-hook mutation.
G2: Windows Rust/Tauri build, v2 regression, v3 one-banner/one-voice.
G3: Desktop live long-run, cold start, permissions, duplicate hook sources, click restoration, rollback.
STATUS: SOURCE CANDIDATE ONLY; no installation changes; G0 AND G2 HOLD.
