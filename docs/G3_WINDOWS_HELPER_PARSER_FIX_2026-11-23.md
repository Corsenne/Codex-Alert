# G3 Windows PowerShell parser failure — corrective audit (2026-11-23)

## Reproduced user error
The user ran `G3-Check-Codex-Link.cmd` and Windows PowerShell 5.1 reported unexpected token at line 10, missing closing parentheses, missing string terminator and missing try/catch end.

## Confirmed cause
The GitHub file `tools/G3-Check-Codex-Link.ps1` was corrupted during a previous partial replacement. A regex assignment was truncated after the concatenation `('^codex://threads/('+$uuidPattern+')`, then most of the script was duplicated after the first catch. This was a **source syntax error**, not a Codex URI scheme error, installed alert failure or the user's fault.

## Correction
- Completely replaced the broken script rather than patching individual lines. It now parses a single anchored `codex://threads/<UUID>` regular expression via .NET Regex Match.
- The helper checks the local rollout filename and first-line session_meta UUID only, then the Windows codex:// registration. It never opens anything without the user's explicit `OPEN`.
- Added `tools/Verify-G3-Helper.ps1` to parse the helper with the Windows PowerShell 5.1 AST parser and to detect duplicated metadata validation blocks.
- Updated `G3-Check-Codex-Link.cmd` to run parser preflight **before** invoking the interactive helper; a damaged script exits with HOLD rather than confusing parser errors.
- Updated the GitHub Windows workflow to parse the helper on each related change and expanded `tools/Update-And-Test.ps1` to perform preflight after Git sync.

## Evidence
GitHub Actions `G3 Routing Source Tests` Windows job parsed the repaired interactive helper with Windows PowerShell 5.1 and passed. Other G3 Node, PowerShell synthetic and Rust validator steps also passed:
https://github.com/Corsenne/Codex-Alert/actions/runs/45116175302

## Scope / residual
This was a developer-source-only repair. No production Chrome extension, Finish Alert v1.1.5, live Codex hook or Windows desktop executable was modified.

G3 **exact-thread real Windows opening** remains HOLD until the user updates the Git clone and executes G3-Check-Codex-Link.cmd with the Codex application's own Copy deeplink. A syntax PASS does not prove the actual Codex URI handler can open the correct thread.
