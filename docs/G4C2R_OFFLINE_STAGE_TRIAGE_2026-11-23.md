# G4C2R — Offline, read-only native stage-log triage

State: diagnostic source candidate, not production acceptance.

The G4 native queue can hold events; its 8s timeout is driven by WebView React setTimeout rather than an independent native watchdog. The observation of late back-to-back banners is consistent with queue release being delayed, but cannot prove the timer itself stalled.

After G4C2 was stopped (desktop and bridge 0), G4C2R-Inspect.cmd reads two existing test-only trace paths in LocalAppData: the G4B_STAGE_TRACE.txt from earlier G4B boot (likely when G4C2-Start reused it), and G4C2_STAGE_TRACE.txt from a fresh G4C2 boot. It never starts any process or rewrites any registry key or source file.

Each trace records only allowlisted static stage labels. Print counters for active/queued and voice/callback stages, plus at most 48 recent labels. No URL, title, event ID or conversation text can be printed. Unknown lines are counted but hidden.

Interpretation: queued markers followed by later audio/callback markers support a queue-delivery explanation. Missing markers are inconclusive if tracing was not active. The files contain no per-stage timestamps or event IDs, so this cannot establish exact timing, one-to-one correlation or a root cause.

Operator: fast-forward sync the feature branch. Keep stable v1.1.5 and G4C2 OFF. Run G4C2R-Inspect.cmd only. Send console output for review. Do not restart G4C2 or generate new notification events for this step.
