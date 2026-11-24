# G4C-3 — Isolated Native Bridge lifecycle and restart acceptance

State: source tooling only, awaiting Windows operator real-use acceptance. Scope: existing G4C2 test NativeMessagingHost and G4 desktop; production v1.1.5 remains disabled, but not removed. No Codex Hook changes.

Evidence prior to G4C-3: user confirmed G4C-2R-2 three real ChatGPT completions PASS including one banner/audio per reply, stop-on-click/exact chat, and no observed delayed repeat in this short run. This does **not** establish native host lifecycle or long-term behavior.

Bridge source candidate-g4/native-host/src/main.rs defines QUIET_POLL 90 seconds with zero outstanding events and MAX_PENDING_AGE 12 minutes after last inbound message. These are code contracts; actual Windows termination requires operator observation. A browser Chrome process remaining after user closes windows makes an exit/idle acceptance inconclusive.

Test executable is `G4C3-Lifecycle.cmd` from the repo root; no build, installation, or cleanup. It uses only read-only WMI/CIM process enumeration, test host manifest/config comparison and operator input, and never closes Chrome or kills a process. It does not access chats, contents, cookies or tokens. It prints only process count, PIDs, age, memory usage and normalized identity status.

Acceptance sequence:
1. Confirm Chrome is running, stable v1.1.5 OFF, G4B manual extension OFF, G4C2 real observer ON; G4 test Desktop is already running (run `G4C2-Start.cmd` yourself if needed). Test script validates one exact G4 desktop, zero legacy native processes, and the isolated G4C2 host registration/manifest. It cannot programmatically confirm which Chrome extensions are enabled; user must check visually.
2. Test **five separate real completions** (one banner/voice, correct click and no late repeat). Each PASS takes a process snapshot, requiring no more than one G4C2 test bridge in this single-profile isolated scenario. Any FAIL, extra bridge or identity mismatch produces HOLD without cleanup.
3. Exit Chrome manually with the browser Exit menu and return to the script. It must observe `chrome.exe` count zero; if background Chrome remains, print HOLD rather than claim a native leak or forcibly close Chrome. Wait 120 seconds from the zero-Chrome observation, then require G4C2 test bridge count zero. A bridge lingering here is HOLD (not necessarily an identified bug).
4. Reopen Chrome manually, ensure G4C2 still ON, refresh a saved conversation, perform one more real completion, and require normal banner/audio/click. The test reports **ISOLATED_SHORT_LIFECYCLE_PASS**, not G5 release.

Note: one user-driven shutdown and reopen plus six completions does not prove long-term, multi-profile, multi-day behavior. Persistent program operation, broader Windows version coverage, Codex real Hook cutover, and safe restore/rollback remain separate gates.

Do not run `G4C1C-Cleanup.cmd` (it targets the separate stable native host) to clean isolated G4C2 processes. Do not remove the G4C2 registration or production settings during this test.
