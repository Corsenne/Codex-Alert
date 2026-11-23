# G4C-1C — Exact-identity Native Messaging Bridge recovery (opt-in)

State: SOURCE CANDIDATE, production unchanged. Windows user acceptance required.

## Evidence
User G4C-1B read-only snapshot: 11 finish-alert-bridge.exe, **all 11 with original parent not running**, **all 11 matching registered binary**, 19 Chrome processes and 1 desktop. Oldest 347 minutes. Process ancestry is not definitive Native Messaging channel liveness. Existing v1.1.4 bridge source contains an intended 180-second idle timeout, but installed binary version and active I/O frequency were not verified.

## Safety
- Always run G4C1C-Preview.cmd first (read-only). Nothing stops Chrome or other processes.
- Exit Chrome manually using its browser Exit menu after saving work, and ensure all chrome.exe processes have stopped. Background Chrome may remain even when windows are closed.
- Only then consider running G4C1C-Cleanup.cmd. It refuses if any chrome.exe process exists and refuses if even one bridge differs from exact registered EXE/user/session/terminated-parent criteria.
- It first prints the eligible PID count. To proceed, type exactly `CLEANUP <count>` such as `CLEANUP 11`, where the number is read from that run. Any other input cancels.
- Each PID is revalidated immediately before termination: Chrome process count 0; registered manifest unchanged; PID + process creation time; same logged-in user/session; exact executable path; original parent not running or PID reused; live process handle path/start time. If anything changes, it aborts.
- Never stops desktop, Codex, Chrome; no files, registry settings or Codex hooks are modified.
- Build/CI does not exercise killing: only source review, PowerShell parse and Preview mode. A passing CI is not permission to run Cleanup.

## Follow-up
1. Run G4C1C-Preview.cmd while Chrome open to get baseline metadata (optional; G4C-1B has recent baseline).
2. Save work, exit Chrome fully and rerun G4C1C-Preview.cmd: require `G4C1C_CHROME_PROCESSES=0` and review remaining eligible Bridge count.
3. If residual processes remain after Chrome exit, use G4C1C-Cleanup.cmd only with explicit typed confirmation. If no eligible processes remain, do nothing.
4. Start Chrome normally, send real ChatGPT completion, verify stable v1.1.5 notification and exact-tab click still work.
5. Monitor process counts after repeated notifications and browser restart. If growth recurs, investigate deployed bridge binary and Native Messaging timeout/port release before G4C-2.
6. G4C-2 actual Codex/ChatGPT production cutover and G5 installer remain HOLD.
