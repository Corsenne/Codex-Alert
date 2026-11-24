# G4C4 — Real Codex Stop → shared G4 queue, source candidate

2026-11-23. Source implemented. Real Codex Hook remains unchanged.

Candidate adapter: candidate-g4/Codex-Stop-to-G4.ps1. Receives Stop JSON from STDIN, ignores recursive stop_hook_active, computes deterministic event ID from session+turn, sends metadata over the existing isolated G4 same-session native pipe. It never starts a second notifier, edits Codex configuration, reads transcript body, or sends any content to a network service.

Exact Codex navigation: adapter checks the first session_meta line of the rollout JSONL under the selected CODEX_HOME/sessions; it includes a local-only transcriptPath only on match. G4 Rust independently verifies canonical path within the same sessions root and first-line metadata on delivery and on click. Transcript path is not serialized to the GUI. Unknown/unsafe link results in banner without a click target; no homepage/project fallback.

The old G3 one-link environment consent remains available for prior synthetic tests only. The actual real Stop Hook registration is a separate user-approved cutover, not performed here. ChatGPT completion observer and Native Messaging are not modified.

Test runner: G4C4-Test-Codex-Stop.cmd (synthetic only, no app or hook changes). Windows CI must also compile G4 and run Rust tests. Existing installed G4 EXE must be rebuilt after syncing for dynamic Codex links.

Next: inspect actual Codex active hook command and approval alert wiring read-only, then create reversible single-hook switch plan. Do not introduce process-idle/Chrome-exit micro-gates.