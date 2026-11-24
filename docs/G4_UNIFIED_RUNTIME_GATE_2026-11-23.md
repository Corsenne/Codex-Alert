# Finish Alert × Codex Alert — G4 Unified Runtime Gate (v0.1)

**2026-11-23. Source-staged, production unchanged.** This gate follows G2B FIFO synthetic acceptance, G3 isolated Codex click success and G3C isolated ChatGPT click success.

## Fixed user-facing contract
1. One desktop notification surface: exactly one active banner across ChatGPT and Codex, FIFO waiting queue; no queued voice playback.
2. ChatGPT click restores the exact original conversation (same tab if still on that URL, matching alternate, then validated conversation URL); never unrelated conversation or generic homepage.
3. Codex click opens the exact verified technical thread via codex://threads/<UUID>, only if hook/local session metadata corroborates identity; never project-only fallback.
4. Click stops the active sound before navigation. X/timeout stops sound without navigation. Duplicate callback does not reopen screens.
5. Native process and audio ownership are bounded; avoid a second resident monitor; no automatic logging of prompts, answers or transcript text.

## G4A — shared runtime and deterministic simultaneous-admission test
- New isolated Tauri G4 test ID: com.corsenne.finishalertdesktop.g4test.
- New session-local pipe: corsenne_finish_alert_g4_test_<session>.
- Source: candidate-g4/desktop, importing the accepted G2B queue/GUI plus G3 Codex and G3C Chrome callback branches.
- Codex v3 event and ChatGPT v2 event enter the same native Queue actor. Native audio starts only on current banner visibility acknowledgment.
- Codex links are optionally present and must match an explicit per-test allowlist. The synthetic test intentionally sends openTarget=null, so no real Codex app is launched by clicking.
- G4-Synthetic-Test.cmd sends 3 notifications (Codex → ChatGPT → Codex) plus duplicate first ID. Expected ACK active/queued/queued/duplicate and visible/audio one-at-a-time.
- The synthetic ChatGPT route has a valid TEST callback name but no running Chrome test host; therefore G4A tests FIFO and audio only, **not browser navigation**.

## G4B — end-to-end two-source isolated Chrome bridge test
- A separate no-monitoring Chrome test extension and separate Native Messaging host are staged under candidate-g4/.
- Extension popup manually generates ChatGPT test event. It does not monitor ChatGPT replies, so it cannot produce routine duplicate finish alerts.
- Test Native Messaging bridge forwards event with per-bridge callback endpoint and returns correlated ACK; callback returns only the event ID, not content.
- Closed/dismissed ChatGPT alert reports notification.closed so callback routing can be released.
- Bridge watchdog: when no outstanding delivered events, retire after 90 seconds without Chrome messages; if active/queued, keep bounded up to 12 minutes since last inbound event (enough for 65 × 8 second queue). This is a source-level candidate, **not yet a measured fix for the user's previous residual bridges**.
- Full G4B requires concurrently sending a Codex synthetic event and a Chrome manual event through the same isolated G4 native queue, and verifying both source-specific click routes and one audio at a time.

## G4C — real sources, regressions, bridge soak
- Do NOT register an additional live Codex Stop handler. The existing handler remains active until a rollback-capable replacement is approved.
- Do NOT load the production v1.2 Chrome completion observer alongside the stable v1.1.5 observer in the same active profile. Two active observers would cause duplicate notifications.
- Before actual cutover, preserve extension ID/settings and the exact existing Chrome one-banner behavior; separate migration must be all-or-revert.
- Test two actual simultaneous ChatGPT/Codex completions, early/late click, dismissal, repeated event IDs, unknown ACK outcome, minimized/original tab, closed tab, multiple Chrome tabs, background service worker sleep, browser restart and both sides offline.
- Process soak: collect count/oldest lifetime of Native Messaging bridge and desktop before and after multiple completion cycles, shutdown/reopen and idle windows; no unbounded accumulation.
- Privacy: user voice recordings remain local/private; public GitHub has source and synthetic silent audio generator only.

## G4A acceptance and current truth
- GitHub Actions model and Windows bridge tests execute with public source. Full Windows Tauri build uses generated SILENT WAV and icons, avoiding private asset upload.
- Windows operator must run isolated G4A test from local cloned GitHub branch and confirm FIFO display + no overlap + immediate sound stop. No browser or Codex automatic navigation is claimed for G4A synthetic test.
- **Do not claim G4 production PASS** on successful source tests or isolated G4A. Runtime integration G4B/G4C and release G5 remain HOLD.

## G5 gate
Only after G4C Windows integration, native bridge lifecycle soak and safe backup/rollback: produce one-file installer/unified Finish Alert v1.2, atomically replace exactly one Codex Stop handler and one Chrome production extension, preserve existing notification/voice/user preferences.
