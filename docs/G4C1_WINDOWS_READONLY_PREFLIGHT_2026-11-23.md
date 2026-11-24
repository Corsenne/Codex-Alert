# G4C-1 — Existing Windows Environment Read-only Preflight

Date: 2026-11-23. Status: **SOURCE CANDIDATE / LOCAL USER TEST REQUIRED**.

## Evidence and boundary
- G4A mixed native queue/audio: user-reported Windows PASS.
- G4B-1 manual Chrome Native Messaging → separate G4 Tauri banner → exact chat tab: 5/5 user-reported PASS.
- G4B-2 both mixed source orders: user-reported PASS; ChatGPT-first synthetic Codex ACK was explicitly `queued`. This was **not real Codex Stop Hook integration**.
- G4C must avoid two competing ChatGPT completion observers, a second active Codex Stop hook, or overwriting either installed stable notification system.

## Purpose
Run `G4C1-Inspect.cmd` to capture a **read-only** snapshot of production and test environment. It does not call install, unregister, stop, edit, save, network or privileged commands.

The report prints:
1. Local Git branch/short HEAD and whether tracked files have changes.
2. User-scoped Codex `hooks.json` presence/parse result, SHA256, Stop and PermissionRequest group/handler counts, legacy/new relay name counts.
3. User-scoped `config.toml` desktop turn/permission notification switches and approximate inline hook counts.
4. Matching alert-related Chrome Native Messaging host *names* across HKCU/HKLM, manifest parse class, executable existence and allowed-origin count.
5. Alert-named process PIDs, age (minutes, where readable), total process count and oldest age; test host registration counts.
6. Explicit NOT VERIFIED labels for whether the original Chrome extension is active, project/system/plugin Codex hooks, real completion events and process soak.

Privacy: No raw hooks commands, executable paths, Chrome extension IDs, conversation URLs, prompt/response texts, private voice files or settings files printed or uploaded to GitHub. Local script stdout can be pasted back for assessment.

## Procedure
1. If the G4B test extension, registration or desktop process still exists, **do not delete by hand**. Note the current state. Finish the G4B cleanup in a separate explicit step using `G4B-Cleanup.cmd` after checking its registered key has not changed. Only the test extension should be removed from Chrome, not the stable extension.
2. Sync repo using `git fetch` + `git merge --ff-only` after checking there are no tracked modifications. Git sync is a separate user-controlled step; the inventory command itself does not sync.
3. Run `G4C1-Inspect.cmd` from `C:\Users\user\Codex-Alert` (or double-click from Explorer).
4. Inspect console output, which ends with `G4C1_READONLY_INSPECTION_COMPLETE` and `G4C1_PRODUCT_RELEASE=HOLD`.
5. Review whether user scoped Stop handler count remains one, whether permission notification is enabled, and whether production bridge/desktop processes show unexplained accumulation. Unknown values remain unknown; do not treat absence of evidence as PASS.

## Acceptance criteria (G4C-1)
- Windows PowerShell 5.1 AST parse PASS and zero direct mutations.
- Audit prints sanitized data even if optional files are absent or registry scopes inaccessible.
- Correctly distinguish G4/G3C test keys from production host registrations.
- 1 Stop handler is a *target*, not an automatic fallback if there are zero/multiple; any unexpected count requires further manual investigation before integration.
- No product change is authorized by a passing preflight. **G4C-2 (real event integration) and G4C-3 (lifetime soak) remain HOLD.**

## G4C-2 architecture prerequisite
Prior to any actual replacement: make read-only snapshot, generate backup/diff and rollback plan for exact registered Chrome native host and Codex existing Stop handler. Preserve the original Chrome extension ID, storage, One Voice, tab return, and existing Codex permission notifications. Do not launch a second completion observer nor register a second Stop hook. Require user approval of the proposed swap. Production integration will need a compatibility test for existing v2 events and a v3 Codex relay, with one shared voice owner.

## G4C-3
Perform timed Windows observations while operating actual source integrations: before/completions/after-closure and idle, with manual process inventories. Verify no persistent unused bridge process growth. Distinguish a currently connected Chrome native host from a genuine orphan. Repeat after Chrome restart and desktop restart. User-visible checks remain necessary; no automatic release PASS.
