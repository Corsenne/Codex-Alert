# G3 routing source acceptance — 2026-11-23

## GitHub Actions PASS

On commit d1616132a07153c2799034dbc681b30411730905:

- G3 source Node tests: PASS on GitHub Actions (native URL allowlists, chat tab fallback, stale click/no route).
- Windows PowerShell synthetic Stop-to-link mapper: PASS in the workflow.
- Windows pure Rust routing validator: PASS in the workflow.
- Workflow run URLs:
  - https://github.com/Corsenne/Codex-Alert/actions/runs/45115359969
  - https://github.com/Corsenne/Codex-Alert/actions/runs/45115355729

These successes validate source-only code on CI runners. They are **not** evidence of integrated Tauri UI callback dispatch, Chrome service worker persistence under real loads, or real Codex Desktop deep-link focus.

## Code staged (not installed)

- candidate-g3/routing.mjs and routing.test.mjs: exact Codex UUID, checked local transcript name, original ChatGPT tab / alternate tab / exact URL.
- candidate-g3/chrome-extension/background.js: session-only route metadata and fail-closed ChatGPT tab selection.
- candidate-g3/desktop/src-tauri/src/g3_routing.rs, lib.rs, ipc.rs: strict Codex URL native candidate and stop-before-open source.
- candidate-g3/Codex-Stop-Relay.ps1: synthetic DRY-RUN ONLY, never registered with live Codex.
- tools/G3-Check-Codex-Link.ps1 and G3-Check-Codex-Link.cmd: user-provided Copy deeplink -> local session_meta ID validation -> local handler check -> OPEN only on explicit human command.
- Update-And-Test.cmd now syncs and runs G3 source tests before the existing isolated G2B application test. No ZIP required.

## Next Windows acceptance

Run Update-And-Test.cmd once to sync development branch, then G3-Check-Codex-Link.cmd and paste one local Codex conversation's **Copy deeplink**. The user may type OPEN only after strict validation. Verify **the same thread** opens in Codex Desktop.

If CODEX_URL_HANDLER_NOT_REGISTERED or metadata lookup fails, G3 exact Codex click stays HOLD, never guess the target. After that validate the true native Chrome callback / Codex URI sender under a separate G3 GUI test, preserve one active banner, stop audio before launching, and certify bridge process long-run behavior before production installer.

Stable ChatGPT Finish Alert v1.1.5 and legacy Codex Stop hook remain installed and unchanged.
