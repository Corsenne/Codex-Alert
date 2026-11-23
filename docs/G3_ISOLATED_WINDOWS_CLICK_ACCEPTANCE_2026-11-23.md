# G3 isolated Windows banner click acceptance — user confirmation (2026-11-23)

## Result
**G3 isolated Codex banner click scenario: USER-REPORTED PASS.**

The user reported 'OK,成功！' following the isolated G3 re-test instructions. The scenario asked for the following observable behaviors:
- Codex synthetic banner displayed.
- Leo voice stopped when the banner was clicked while speaking.
- The clicked notification opened the exact selected Codex Desktop conversation.

The user confirms overall success of that scenario. **The console output from this final run was not supplied**, so this entry records user-observed acceptance, not an independently inspected log of G3_AUDIO_STOP_CALLED or G3_THREAD_OPEN_DISPATCHED. Audio stop latency was not instrumented.

## Already established
- G0 active user-level Codex Stop hook inspection PASS.
- G1 synthetic event relay Windows PASS.
- G2A Rust unit tests 5/5 PASS.
- G2B isolated GUI/queue ACK active,queued,queued,duplicate PASS with user visual confirmation.
- G3 standalone Windows deep link validation and actual exact-thread opening PASS.
- G3 isolated native click experiment source tests and Windows PowerShell parser CI PASS.

## Still HOLD (do not imply release readiness)
- Production bidirectional native bridge callbacks from real ChatGPT and Codex.
- Chrome original-tab restoration tested with actual banner click, including suspended service worker and tab navigation.
- End-to-end cross-source FIFO and one-owner voice under simultaneous *real* ChatGPT + Codex completions.
- Bridge lifetime soak and prevention of accumulated native messaging processes.
- Safe cutover from exactly one legacy Codex Stop hook; preserve Codex permission prompts.
- Rollback-tested unified installer, notification handling on shutdown and process restart.

## Safety
The stable installed ChatGPT Finish Alert v1.1.5 and legacy Codex Alert remain unchanged. Only isolated G3 test binaries are built/run; do not merge this draft as a production release. Private Leo and Anna voice assets remain local and are not committed to public GitHub.
