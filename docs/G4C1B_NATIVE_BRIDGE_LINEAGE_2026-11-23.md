# G4C-1B — Native Messaging Bridge Process Lineage

- Status: isolated read-only diagnostic; no production mutation or installer.
- Trigger: G4C-1 on 2026-11-23 reported **11** `finish-alert-bridge.exe` processes and one `finish-alert-desktop.exe`, with oldest reported bridge age **343 min**. G4C-1 passed as an inventory; production cutover remains **HOLD**.
- Earlier native V2 read-only diagnostic reported 27 bridges with oldest 2497 minutes. Both are snapshots; the change does not establish a leak fix.
- Existing user-scoped Codex Stop: one legacy hook, zero new relays. Permission notifications on. Chrome native host: one valid installed registration. Neither needs changing for this inspection.

## Run
1. Sync branch `feature/codex-finish-alert-g0-g2` fast-forward only. Do not discard local changes or delete untracked files.
2. Double-click `G4C1B-Bridge-Lineage.cmd` or call it from PowerShell.
3. Copy the JSON summary. It contains PIDs, elapsed time, parent PIDs and names, session ID, executable match class and working-set MB. No command-line arguments or private paths are printed.
4. Require `G4C1B_READONLY_BRIDGE_DIAGNOSTIC_PASS`; do not interpret it as product approval.

## Interpretation rules
- A bridge whose parent PID is missing or reused may indicate stale/disconnected host, but this *does not prove* it is orphaned.
- A bridge with a living Chrome parent may still have a broken connection; conversely a short-lived Chrome process may have exited while a healthy worker stays alive.
- The tool cannot determine an active native port from process ancestry alone. `chrome_port_connection=NOT_VERIFIED`.
- Memory use and age are observation only. Never kill a process based solely on name or age.
- The legacy v1.1.4 bridge source already intended an idle watchdog, but current running binary version must be proven separately; no automatic upgrade is allowed.
- For lifecycle soak: perform independent snapshots around safe user-driven Chrome app restarts and normal alert cycles, then compare process identity/age. Log only metadata, never message contents.

## Gate decision
- G4C-1 inventory: PASS (user-provided console).
- G4C-1B: Windows process lineage required.
- G4C-2 real event cutover: HOLD pending lifecycle remediation design and backup/rollback.
- G5 release: HOLD.
