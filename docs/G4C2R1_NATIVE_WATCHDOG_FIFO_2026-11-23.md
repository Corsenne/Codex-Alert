# G4C-2R-1 Native watchdog and bounded FIFO candidate

Status: isolated G4 test source only. Stable Finish Alert Chrome v1.1.5, production Native Host and the existing Codex Stop Hook remain unchanged.

Motivation: G4C2 real notification test generated late back-to-back banners. The G4C2R offline trace recorded two queued events and later voice requests; it has no event correlation/timestamps. This is evidence of queuing, not definitive proof that JavaScript timer delays caused the observed problem.

Changes in isolated candidate-g4 desktop: one Native background worker checks the current event approximately every 125 ms. Once WebView paints and confirms visibility, the native timeout is 8 seconds. If paint never confirms, it retires an active event 12 seconds after native admission, preventing a permanently blocked FIFO. The previous WebView-only setTimeout is removed. It also emits a correlated `finish-alert:cleared` signal and hides the native window when no events remain.

Late FIFO entries queued for at least 20 seconds are skipped upon promotion and their ChatGPT `notification.closed` callback is released, avoiding late notification storms. Newer entries preserve FIFO ordering. Each native completion atomically validates the event ID under the queue lock so a click, dismissal and watchdog racing can only finish an event once. The existing exact-chat click and stop-before-route paths are preserved.

Only allowlisted stage names are logged: G4R_NATIVE_VISIBLE_TIMEOUT, G4R_NATIVE_UNPAINTED_TIMEOUT, G4R_PROMOTED_WAIT_LE_5S, G4R_PROMOTED_WAIT_GT_5S, G4R_STALE_QUEUED_DROPPED, G4R_PROMOTED_NEXT, G4R_STALE_ACTION_IGNORED, G4R_NATIVE_HIDE_PASS/FAILED. No conversation content, title, raw event ID or URL in stage traces.

Tradeoff: an event old enough to be stale when it reaches the head is intentionally not displayed. This is isolated-test behavior to prioritize timely notifications over backlogged ones, and must be user-accepted before production adoption. The current 20-second threshold is a candidate, not a production requirement.

Validation: source-model tests, Windows Rust/desktop build, synthetic FIFO click+timeout regression and separate live G4C2 trial are required. Avoid enabling G4C2/Finish Alert together. Existing running test desktop would have to be rebuilt while fully stopped before observing any native watchdog changes. Do not run `G4-Build.cmd` during an active G4B/G4C2 test process or over an existing active test binary.

G4C-2R-1 release status: HOLD until Windows build and real consecutive reply acceptance.