# G4 → G5 practical finish / scope reset (2026-11-23)

## User direction

Stop subdividing implementation into escalating micro-validation gates. The goal is a practical unified notification app, not proof of every Chrome/Native Messaging process lifetime. Reopen detailed diagnostics only if a **user-visible regression** or unsafe behavior is observed. This change supersedes previous requests for mandatory bridge idle/Chrome-exit soak as a release gate. Existing test code is retained as optional diagnostics, not removed from the repository.

## Evidence preserved without overstating it

- G4C-2R-2 user-reported 3/3 real ChatGPT completions PASS, including banner, sound, click-stop and exact conversation restore.
- G4C-3 user-reported five additional real ChatGPT completions PASS. Snapshots show one isolated G4 Desktop, one isolated G4C2 Bridge and no observed bridge growth during those events.
- Chrome's Exit left 12 processes, later 11 including one browser-root. Bridge idle retirement/reopen result **HOLD/unverified**; do not label this a failure of Bridge, or treat it as a user-visible regression.
- Mixed ChatGPT/Codex G4 FIFO previously PASS only for synthetic Codex messages. Isolated G3 verified Codex exact-thread deep link separately. Those facts do **not** prove automatic Codex completion delivery.

## Product behavior, minimal acceptance

1. One visible native banner, FIFO across real ChatGPT and real Codex completions; one voice at a time. Source-specific voice once on activation.
2. On clicking ChatGPT: stop sound, bring the exact original conversation/tab forward. On clicking Codex: stop sound, open only the verified exact Codex thread; never project/homepage fallback. X/timeout dismisses without navigation.
3. Existing Chrome extension ID and preferences are preserved where technically feasible; avoid two automatic Chrome completion observers. Do not replace existing stable v1.1.5 or enable a second observer blindly.
4. Existing Codex permission/approval alerts must remain unchanged. Actual active Stop Hook locations (config.toml/hooks.json/system/project/plugin) must be inspected before a single controlled replacement. Store rollback copies and require explicit user approval for changes.
5. No transcript, prompt, answer, private voice audio or credential enters GitHub. No extra resident monitor.

## Only remaining implementation work

**A. Real Codex adapter:** G3 contains session metadata to exact-thread resolution, but its candidate script is dry-run-only. G4 currently accepts real ChatGPT events, while Codex events come from synthetic test senders. Implement a production-suitable Stop-event ingress to the G4 FIFO and safe per-event thread verification, rather than the current G4 exact-one-thread environment allowlist. Do not change the live Hook during source implementation.

**B. Unified packaging and reversible migration:** install/update one native desktop and Chrome bridge, preserve stable settings/extension identity, privately stage audio, and generate a rollback-safe before/after plan for the actual Windows environment. Do not infer that private assets or installed stable executable are in this public repository.

**C. One user-visible real-world sign-off:** confirm ChatGPT real reply and Codex real Stop completion each give exactly one banner+correct voice, click-to-stop and source-specific return, and no obvious duplicate or broken approval alerts. If PASS, proceed to release, not a new chain of timing/soak gates.

## Deliberate non-goals

- No Chrome zero-process prerequisite.
- No 120-second retirement test.
- No mandatory G4C3R repeat or background-app settings change.
- No claims that a candidate isolated test extension can simply be relabeled as a production Chrome update preserving extension ID.
- No silent live Hook overwrite.
- No release declaration before the missing real Codex delivery and cutover work is done.

## Status

G4C3 detailed diagnostics: **CLOSED / NOT A RELEASE BLOCKER** (not PASS).
ChatGPT isolated real observer: **ACCEPTED FOR THIS SCOPE**.
Codex automatic Stop integration and installer/migration: **IMPLEMENTATION PENDING**.
Production cutover: **NOT PERFORMED**.
