# G4C-1D — Stable Chrome Finish Alert v1.1.5 repeated real-use validation

Status: source candidate, local user real-reply validation required. **G4C-2 production cutover HOLD**.

## Context
- G4C-1C cleaned up 11 verified bridge processes (operator reported cleanup complete, then 0 bridges with Chrome closed).
- One subsequent bridge PID 27756 was observed at 1 minute and again at 43 minutes while Chrome processes were present; a later read-only preview recorded 0 bridges with Chrome running.
- These observations prove the process *can* retire in at least one scenario, not that idle retention or per-port disconnection is correct under all circumstances.
- The installed stable native bridge may differ from candidate-g2a source. No production binary patch or Chrome extension change is authorized by this gate.

## Operator procedure
1. Leave installed stable extension enabled. Ensure **G4 test extension is not still observing anything** (its isolated version had no completion content script). Do not install a new observer.
2. Fast-forward sync the development branch, then run `G4C1D-Real-Use.cmd`. Requires Chrome already running. It reports a metadata-only baseline and prompts for results.
3. For each of **3 separate real ChatGPT assistant replies**, verify: exactly one banner, one voice, exact conversation returned on click, then in PowerShell enter `PASS` or `FAIL`; or `STOP` to halt without changing anything.
4. The script prints after-each-reply count and PID/age/memory and a bounded summary. This **does not measure actual completion detection**, which the user confirms visually. A passing script is not a substitute for that confirmation.
5. Optional: launch `G4C1D-Snapshot.cmd` at other points, including after user-driven browser exit. No tools stop Chrome or native processes.

## Interpretation
- One or several bridged processes while Chrome is open is not automatically abnormal. The stable extension may retain an active Native Messaging port for queued/click routing.
- Do not infer resource leakage from a transient new PID or a single count. Repeated monotonic growth across separate independent replies, or surviving long after Chrome exits with no native port activity, requires investigation.
- A clean 3/3 test means only **short real-use regression** passed; long-duration/idle and process-soak acceptance remain separate.
- If regression occurs, report **G4C-1D HOLD** and do not proceed to real source cutover. Never cleanup with active Chrome.
