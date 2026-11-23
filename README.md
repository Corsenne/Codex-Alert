# Codex-Alert

Development of a lightweight Codex Desktop completion notifier using the existing Finish Alert Windows banner.

**Status: G0 inspection and G1 candidate. No production installation has happened.**

- Preserve the existing Codex completion hook and approval notifications until active Windows settings are reviewed.
- Keep ChatGPT Finish Alert v1.1.5 and its browser detection / One Voice unchanged.
- An event-driven relay forwards Stop events to the shared desktop renderer. No polling or additional resident application.
- Public repository contains no private paths, credentials or Ondoku audio files.

## Files

- Inspect.cmd + tools/Inspect-CodexAlert.ps1: sanitized, read-only G0 audit.
- src/Codex-Stop-Relay.ps1: candidate native-pipe sender (not registered with Codex).
- tests/Test-Relay.ps1: Windows PowerShell 5.1 synthetic checks.
- docs/DESIGN_v0.1.md: architecture, audio handling and acceptance gates.

## Voice

The supplied Ondoku Leo voice says: コーデックスの作業が終了しました。確認してください。 The 3.696 s source MP3 was converted to 24 kHz, mono, PCM16 WAV for **private local staging only**. It is deliberately not published until licensing/distribution permission is confirmed.

Before modifying hooks.json, perform G0, review the planned diff, back up active settings, and get explicit switch-over approval. No existing alert settings are altered by these source files.
