# G2B UI-ready startup repair (test only, 2026-11-23)

After the ACK deadlock repair, the Windows user test built successfully and returned `ui-not-ready`. Trace: G2B_PIPE_ACCEPTED, G2B_REQUEST_LINE_READ, G2B_WEBVIEW_NOT_READY, G2B_ACK_UI_NOT_READY_SENT, G2B_PIPE_EOF. Transport and ACK now work; React has not signaled its `ui_ready` state.

## Hypothesis and fix
Creating a Tauri WebView `visible:false` may defer/damage event-listener initialization on Windows WebView2. A separate initial React effect may also hide the window before `ui_ready` is invoked. See Tauri issue https://github.com/tauri-apps/tauri/issues/15652. This is a source-level **hypothesis**, not confirmed runtime root cause.

The isolated test bootstrap starts with an empty transparent, taskbar-hidden, unfocusable window `visible:true`. React registers its event listener, then invokes `ui_ready`. Rust hides the empty window and only then marks UI ready. Initial `count=0` cannot hide it before handshake. Stage-only PageLoad and ready logs exclude paths, event IDs and chat text.

The private complete ZIP also updates `Run-G2B.ps1` to wait for `G2B_UI_READY_PASS` (up to 30 seconds) **before** requesting Enter or sending any event. If the UI does not initialize, it reports `G2B_UI_BOOTSTRAP_HOLD` with stage-only diagnostics.

Offline tests: 6 queue + 3 bootstrap source contracts + 2 React display = 11 PASS; ZIP integrity PASS. Windows Rust build and real banner/audio after this fix still require user verification.

Existing stable ChatGPT v1.1.5 and live Codex-Alert hooks are unchanged. G2B test has its own EXE, Tauri app identity and pipe. Never merge the test-only synchronous IPC handler into the production duplex transport; G3 routing still requires a separate verified implementation. The supplied Leo/Anna audio is private and must not be committed to public GitHub.