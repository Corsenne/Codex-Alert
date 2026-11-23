# Codex-Alert — Finish Alert × Codex unified desktop alerts

Development branch: `feature/codex-finish-alert-g0-g2`

## Current acceptance (2026-11-23)

- **ChatGPT real completion: accepted in the isolated G4C2 observer.** User reported 3/3 real replies PASS followed by 5/5 PASS in G4C3: one banner, one voice, click-to-stop, exact-chat restoration and no observed extra/delayed notification in these rounds.
- **Shared ChatGPT + Codex queue:** mixed-source FIFO/voice sequencing passed in isolated synthetic tests. The Codex leg was synthetic; the real Codex Stop Hook has **not** been switched.
- **Native processes:** during the G4C3 five-reply run, exactly one isolated bridge remained, with the same PID and reported working set. Chrome had background processes after window exit; browser-exit/bridge-retirement was inconclusive. This is **not** proof of a bridge leak.
- **Cutover:** not performed; original Finish Alert v1.1.5 remains installed but disabled for the isolated observer; installed Codex Hook remains unchanged.
- **The G4C3 detailed lifecycle investigation is closed without acceptance.** Do not expand it into more test gates unless a user-visible bug occurs. Source inspection tools remain available for troubleshooting only.

## Practical completion scope

Finish the real Codex Stop-to-G4 delivery and verified exact-thread click; then prepare a straightforward reversible installation/update that keeps the existing Chrome extension's identity and preferences where technically feasible and preserves Codex permission notifications. Verify end to end once on Windows with a real Codex completion plus a real ChatGPT completion, including one banner/voice and source-correct click. Perform the cutover only after inspecting the actual active hook locations, approving the concrete configuration diff and storing rollback copies.

No additional Chrome-background, 90-second idle, repeated five-completion or process-soak test is a release prerequisite. Production still HOLD until the real Codex Hook and migration are complete.

Read `docs/G4_TO_G5_PRACTICAL_FINISH_2026-11-23.md` for the remaining implementation contract.
