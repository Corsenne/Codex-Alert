# Unified Finish Alert — G2/G3 requirements revision (2026-11-23)

**Design/source prototype only. No production upgrade.**
Stable ChatGPT Finish Alert v1.1.5 and legacy Codex alert must stay installed while integration is tested.

## User-approved requirements
1. Clicking ChatGPT banner: activate the original Chrome tab/conversation; clicking Codex banner: open the **specific** Codex thread. Close X dismisses without navigation.
2. Exactly **one** banner is displayed at a time across ChatGPT and Codex. All others wait FIFO, with **no voice playback while waiting**.
3. Diagnose currently repeating ChatGPT Finish Alert before cutover.
4. Clicking a banner **stops its current voice immediately**, then routes navigation and advances the queue.

## Source-level findings
- v1.1.4/G2 UI queue currently shows up to **3 visible** banners; not compatible with #2.
- v1.1.5 Chrome calls its offscreen audio player on completion, before native banner timing. G2 Codex Rust plays Leo on IPC receive, before actual visibility. A visual-only queue would **not** serialize audio.
- Chrome de-duplication keys documentId + cycleId for 120s. The content script generates a new cycle ID per observed Stop-button generation. Two cycles caused by one actual answer may be treated as two real events. Multiple installed extension IDs independently emit random event IDs, bypassing per-instance deduplication. These are **possible conditions**, not a confirmed diagnosis of the user's current PC.
- Chrome click routing for recent event IDs lasts only 120s and needs extension for long queues. G2 Codex source has openTarget=null and intentionally disables Codex banner click.
- The current Chrome offscreen renderer only has PLAY_SOUND, not STOP_SOUND.

## Target design
One Windows notification actor is the final owner of FIFO queue, visible banner, sound playback and stop/open ordering. The React UI renders only the currently active banner. On active event: show+play. On click: **stop audio first**, hide, open strict source-specific target, then activate next. On X: stop+hide, but do not navigate. On timeout: stop+hide, then activate next.

The eventual unified app must transfer ChatGPT audio ownership to Windows; do so only in a staged v1.2 candidate after native v2 regression. Explicit never-sent native failures may use the existing Chrome fallback; ambiguous ACK must not trigger duplicate banners or audio. Do not silently drop events on queue overflow.

ChatGPT: target original tab first, validated conversation URL second; maintain pending event route while queued, not only two minutes. Codex: official codex://threads/<thread-id> deep links. Confirm real Stop Hook session ID maps to technical thread ID, e.g. compare Codex "Copy chat deep link" against Stop metadata; never assume project cwd is a specific chat. Codex standard permission notifications remain enabled.

## Gates
- G2 receiver Windows compile, v2 regression and v3 validation.
- G2A queue FIFO with one visible banner, no overlap, bounded queue with explicit overflow, audio starts only on activation.
- G2B stop-before-open, click focus, X dismiss, long queue route recovery, audio from one native owner.
- G3 validated exact Codex deep link with live Windows Desktop test; dual Chrome extension and multi-cycle duplicate diagnosis.
- G4 acceptance with simultaneous long ChatGPT/Codex turns, old Codex Stop replacement exactly once, rollback to stable v1.1.5.

A pure candidate transition reducer and six Node tests were written offline and passed. **This does not constitute Windows G2 integration acceptance.**
