# Finish Alert × Codex Alert — G2A integrated development candidate

**Status: development source and isolated tests only. DO NOT overwrite the working installed v1.1.5 / legacy Codex Alert.**

## Design requirements

- Existing stable Chrome v1.1.5 is unmodified on the user's PC; this package contains a separate Chrome v1.2.0 **candidate**.
- Legacy v2 ChatGPT notifications are still accepted, with Chrome owning legacy audio (soundVolume=0). New Chrome v1.2 opts into Windows audio using `audioOwner:'desktop'`, preserving the old wire version=2.
- Codex v3 is separate, with Leo local voice and no speculative deep-link. The current Stop Hook remains unchanged.
- The Windows native alert actor now owns a 1-active + FIFO-waiting queue, <=64 waiting and <=256 recent event IDs. Only the active event appears; only it may play sound after UI-visible ACK. Clicking / X / timeout stop the currently playing WAV before the next alert is presented.
- On click, ChatGPT first targets the original Native Messaging connection; if it no longer exists, only a validated ChatGPT conversation URL can be opened by Windows. Exact Codex thread routing is **G3 HOLD**, not silently guessed.
- Chromium bridge process has a bounded 180s idle exit and launches the Tauri app with stdio redirected to null, to reduce inherited-handle leaks and stale bridge processes.

## Tests

Double-click **`Test-G2.cmd`** on a Windows development PC. It does not modify the installed app or Codex hooks, but may create normal build artifacts/caches in this extracted directory. If Cargo is available it also attempts `cargo test` for both Rust crates; this may download dependencies. Do not interpret a Node-only PASS as a Windows runtime PASS.

## Important handover safeguards

1. **Do not deploy candidate Chrome v1.2 before candidate Windows receiver.** Old Windows ignores `audioOwner`, so the new extension could go silent. Deploy both only through a reviewed, rollback-capable updater *after Windows acceptance*.
2. Do not register a second Codex Stop Hook. Existing one user-level hook remains active until controlled switch-over.
3. The included `private-leo.wav` came from the user and is for private integration testing only; do not publish to GitHub or distribute without checking the audio license. Windows source loads it from `%LOCALAPPDATA%\FinishAlertDesktop\private-audio\codex-leo.wav`.
4. The current cross-source queue test covers pure state transitions, not actual Windows sound/GUI or Codex thread-ID mapping.
5. Re-test bridge process counts over an extended session before saying that the original 27-process leak is permanently fixed.

## Remaining G2/G3 hold

- Windows Rust/Tauri compilation and UI event integration.
- Audio starts only on active, click stops audio, simultaneous/long queues and no duplication with both sources.
- Codex exact-thread deep-link correspondence; the G2 prototype currently *only dismisses* Codex on click.
- Native transport reconnection/loss, UI render failures, overflow, 3-minute idle and Chrome multi-profile conditions.
- Rollback-safe single-Setup.exe deployment and stable v1.1.5 regression.
