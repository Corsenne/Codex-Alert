# G3 Windows Codex/ChatGPT native click routing (source candidate only)

Status: **G3 SOURCE STAGED / WINDOWS CLICK TEST HOLD**.

Native candidate added under candidate-g3/desktop/src-tauri/src:
- g3_routing.rs validates only codex://threads/<canonical UUID>. No arbitrary URI, URL parameters or project roots.
- lib.rs uses stop_audio() inside queue lock BEFORE trying Codex navigation.
- ipc.rs accepts an optional validated openTarget for v3/codex only; v2 ChatGPT request handling is unchanged.
- ChatGPT still first dispatches its source event ID to the Native Messaging origin connection (so Chrome can focus the exact tab); only on failure does Windows try the stored strict conversation URL. The separate G3 Chrome candidate strengthens original tab/URL matching and uses ephemeral session storage.

**Source candidate != release**. The G2B isolated synchronous IPC handler must not be installed as the production duplex transport. Click callbacks require event-correlated, tested bidirectional communication and long-running bridge survival. Current stable Chrome/Windows alert and legacy Codex Hook remain untouched.

Codex openTarget must be produced by a Stop Hook adapter only when the session UUID and transcript metadata match and when the user's Windows Codex Desktop deep-link handler has been tested. Otherwise openTarget=null; clicking only stops speech/dismisses.
The shell call may dispatch but does not prove correct window focus; real user observation required.

Unit tests in g3_routing.rs reject crafted/non-thread URLs. Windows Rust compilation and actual click/stop tests pending.
