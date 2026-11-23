# G2B UI bootstrap HOLD — devUrl / build mode mismatch (2026-11-23)

## Observed Windows evidence

The user ran the GitHub-backed `Update-And-Test.cmd`:
- G2B_ISOLATED_WINDOWS_BUILD_PASS
- `HOLD: G2B_UI_BOOTSTRAP_HOLD`
- Sanitized trace: `G2B_PAGE_LOAD_STARTED` then three `G2B_PAGE_LOAD_FINISHED` messages.
- No `G2B_UI_READY_INVOKED` or `G2B_UI_READY_PASS`.

This proves that Tauri receives page-load events, but **does not prove that the React application ran**. Rust unit tests and frontend compilation passing do not establish runtime frontend availability.

## Code-level mismatch

Previously, the Windows test runner:
1. Executed `npm.cmd run build` to create `dist/`.
2. Executed plain `cargo build` to create a **debug** EXE.
3. Launched that EXE without starting the Vite server.

The Tauri configuration has **two separate frontend locations**:
- `devUrl = http://127.0.0.1:1420` (development Vite server);
- `frontendDist = ../dist` (production embedded assets).

A raw Cargo debug build can use the dev-mode URL. There is no Vite listener because the script only compiled the frontend. Thus an empty/failed WebView navigation can produce PageLoad Started/Finished without ever running React, and no UI-ready invoke. This is a strong source-backed **root-cause hypothesis**; Windows page URL or successful re-test is required for final confirmation.

Tauri official references:
- https://v2.tauri.app/reference/config/
- https://v2.tauri.app/reference/cli/ (build uses frontendDist and beforeBuildCommand; --debug; --no-bundle)

## Isolated correction

Modify only `tools/Update-And-Test.ps1`:
- Keep Node tests and `cargo test`.
- Replace manual `npm.cmd run build` + plain `cargo build` with:
  `npm.cmd run tauri -- build --debug --no-bundle`
- The Tauri CLI runs `beforeBuildCommand` and embeds `frontendDist` into the isolated test EXE; `--debug` keeps the output under `target/debug`, `--no-bundle` avoids creating a deployable installer.
- Verify `dist/index.html` and the test EXE exist, then print `G2B_TAURI_FRONTEND_EMBED_BUILD_PASS`, followed by the existing build PASS.
- Continue waiting for actual `G2B_UI_READY_PASS` before injecting synthetic events; **do not bypass the GUI readiness gate**.

## Scope / rollback

- This change affects only test build invocation and adds no app runtime code or production installation steps.
- Existing ChatGPT Finish Alert v1.1.5 and Codex legacy Hook remain untouched.
- This test-runner change has source/static validation, but has **not** been executed on Windows. Do not upgrade G2B to PASS until actual UI_ready, ACK and visual/audio acceptance.

## Expected next log

```text
G2B_GITHUB_SYNC_PASS
G2B_TAURI_FRONTEND_EMBED_BUILD_PASS
G2B_ISOLATED_WINDOWS_BUILD_PASS
G2B_UI_READY_PASS
```

After pressing Enter: `G2B_EVENT_1_ACK=active`, events 2/3 queued, event 4 duplicate, `G2B_SYNTHETIC_ACK_PASS`.
Even then, actual visible one-at-a-time banners, voice non-overlap and click-to-stop need user confirmation.

If UI_BOOTSTRAP_HOLD persists, gather only stage-only logs and add **protocol-scheme-only** WebView load diagnostics to distinguish error page, JavaScript/CSP failure and invoke permission; do not change arbitrary delays or disable readiness gates.
