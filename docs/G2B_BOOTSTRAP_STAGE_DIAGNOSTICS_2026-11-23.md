# G2B UI_BOOTSTRAP_HOLD: stage-only WebView/React startup diagnostics (2026-11-23)

## Repeat failure
The user's GitHub direct run after the Tauri CLI build change still reported `G2B_ISOLATED_WINDOWS_BUILD_PASS`, then `HOLD: G2B_UI_BOOTSTRAP_HOLD`. The trace contained PageLoad Started followed by PageLoad Finished three times, **without UI_READY_INVOKED**.

It is NOT yet established whether the new Tauri embedded asset build marker was present in the complete console output; the supplied excerpt began at Rust warnings and the final build marker. Therefore do not call the previous devUrl hypothesis confirmed or disproven solely from this tail.

## Why PageLoad Finished is not enough
Windows WebView2 may finish navigation to a failed page, a development URL, or HTML whose JavaScript fails. The Tauri front-end invokes `ui_ready` only after the React module loads, the React effect runs, and `@tauri-apps/api/event.listen` resolves. An exception or missing IPC bridge at any earlier point prevents UI_READY.

Per official Tauri v2 core ACL, `core:default` includes `core:event:default` and `allow-listen`, so absent permission is not assumed as the cause without the new evidence.

## Test-only diagnostics staged
- Rust on_page_load logs only fixed page-origin classes (DEV_SERVER, EMBEDDED_APP, ABOUT, OTHER) with no actual URL/path.
- HTML adds fixed-stage DOM, JS error/unhandled-rejection tracing to a dedicated `g2b_diagnostic` Tauri command (non-content).
- React test source logs module startup, effect startup, event listener success/failure, ui_ready invocation success/failure.
- Native command accepts allowlisted *fixed stage names only*. It never logs messages, file paths, source event IDs, user content, error objects, stack traces or complete URLs.
- Build script confirms compiled dist/index.html includes HTML marker and one compiled JS asset contains React module marker. Prints `G2B_FRONTEND_DIAGNOSTIC_ASSETS_PASS` and the truncated development commit hash.

## Interpretation
- DEV_SERVER origin: application is navigating to a development server, possibly not running; inspect isolated build packaging.
- EMBEDDED_APP origin + HTML stages: correct page loaded; inspect React bundle/module/error markers.
- HTML but no React module: asset loading, CSP or JavaScript execution failure.
- React module/effect but no listener registered: Tauri API/event permissions or async listener exception.
- Listener registered but ui_ready rejected: invoke routing or UI hide error.
- `G2B_UI_READY_PASS`: proceed to synthetic ACK/visual/audio tests; do not infer visible/audio success from handshake alone.
- If only PageLoad messages appear, leave G2B HOLD and inspect the Tauri debug WebView DevTools in the next gate, rather than relaxing readiness.

## Scope
No production installation or modification. Existing stable ChatGPT Finish Alert v1.1.5, legacy Codex Stop Hook and all private Leo/Anna audio remain unchanged. This is a **test-only tracing patch**, with Windows re-test needed. The source test itself is not proof of runtime functionality.
