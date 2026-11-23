# G4C2 repeated live completion no-second-banner investigation

User evidence: with stable v1.1.5 disabled and G4C2 test host registered + accepted G4 desktop reused, first real completion produced a banner. On second real completion, no banner appeared. G4C2 real-use acceptance FAIL. Source-level reproduction alone does not identify the layer that dropped the notification.

This diagnostic changes only candidate-g4c2 Chrome extension popup/background and introduces **metadata-only** session diagnostics:
- `COMPLETE受信`: how many completion messages have reached the G4C2 background.
- `Native受理`: how many were ACKed by the isolated G4 native queue.
- `最近の結果`: accepted / duplicate / invalid-completion-source / native-unavailable / unknown-ack-timeout / native-post-failed / native-port-disconnected / delivery-exception / native-rejected.
- `バナー経路保持`: current native queued/active callback routes in memory; does not prove visible UI.
- `監視状態` / `直近の検知結果` / `最終判断`: read-only `PROBE_CONTENT` result from active ChatGPT tab.
Only aggregates and normalized result classes are stored in Chrome session, never chat messages, URLs, IDs or content. Counts cap at 1000. No product installation changes.

How to diagnose:
1. Record current FAIL in the old `G4C2-Real-Use.cmd` and exit. Keep stable v1.1.5 OFF and G4B test OFF.
2. Sync the branch, Chrome `chrome://extensions/` → find existing unpacked G4C2 extension → click its **reload** icon (do not remove/re-add or change extension ID). Refresh the saved ChatGPT tab so updated content.js is active.
3. Reproduce one completion, then another. If banner #2 is absent, open G4C2 extension popup on that same ChatGPT tab and click `再取得（読み取り専用）`.
4. Share the displayed diagnostic, not prompt or chat contents. If the detector reports completed but received count did not increase, check content-to-background messaging. If received increased but accepted did not, inspect native ACK failure. If both increased, investigate G4 queue/UI lifecycle.
5. Do not declare production acceptance based on a popup; repeat 3 real user cycles once the root cause is fixed.
