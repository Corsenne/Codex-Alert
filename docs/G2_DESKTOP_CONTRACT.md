# G2 Codex -> common Windows banner: source candidate (not installed)

- Preserve the exact ChatGPT Finish Alert v1.1.5 browser extension and existing v2 receiver behavior.
- Add a strictly separated v3 / source=codex branch in the Windows receiver.
- Codex v3 requires deterministic codex-<32 hex> eventId, validated project title, local source and no arbitrary openTarget or conversation URL.
- Codex UI uses the existing 420x112 JARVIS-style banner: CODEX ALERT + project name + Codexの作業が終了しました.
- Codex click-to-thread is disabled pending Windows deep-link verification (G3).
- Leo audio is a private user-provided WAV (24kHz mono PCM16) stored locally only; do not upload it to this public GitHub repository.
- The event adapter must not capture prompts, full cwd or transcripts. Native permission notifications stay enabled; no added resident poller.
- ACK loss must not create a second alert. Duplicate events must be suppressed.

## Offline validation
React queue test: 1 PASS using Node 22 type stripping.
v1.1.4 desktop source patch dry-run: PASS, five changed files.
Private candidate ZIP and WAV format: PASS.
Rust/Tauri Windows build and real Codex Desktop event: NOT TESTED.

## Acceptance before deployment
Confirm G1 actual hook payload and unique invocation; compile G2 in isolated Windows source tree; test v2 ChatGPT regression, v3 positive/negative validation, Leo single voice, native permission notification, duplicate Stop and cold start; prepare rollback before production cutover.

STATUS: G0 USER PASS; G1/G2 WINDOWS ACCEPTANCE HOLD.
