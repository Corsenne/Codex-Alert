# G1 synthetic failure correction — 2026-11-23

## Windows observation
The dry-run relay displayed valid JSON, including version=3, source=codex, title=TALOS and soundId=leo, but Test-Relay.ps1 failed with Bad event mapping.

## Root cause
The candidate dry-run branch used [Console]::Out.WriteLine($json). This directly writes to the host console and does not emit a PowerShell success-pipeline object. The caller assigns $json = & $relay -DryRun and therefore receives no JSON to deserialize.

## Fix
- Change the dry-run output to Write-Output $json.
- Assert exactly one pipeline object and identify empty output vs invalid JSON vs field mapping vs deterministic ID vs privacy leakage.
- Preserve approval-event and reentrant-Stop exclusion checks.
- Production delivery, existing Codex active hook and v2 ChatGPT delivery remain unchanged.

## Verification
Static source comparison PASS; private ZIP CRC, manifest consistency PASS.
Windows PowerShell 5.1 re-execution REQUIRED. Do not claim G1 accepted without user PASS.

## Deployment
This is a **development test repair only**. Do not add a hook or install G2 to the production PC until actual Windows acceptance and rollback plan.
