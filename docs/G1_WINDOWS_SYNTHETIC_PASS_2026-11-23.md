# G1 Windows synthetic acceptance — 2026-11-23

## Observed user result

```text
G1_RELAY_SYNTHETIC_PASS
G1_SYNTHETIC_TEST_COMPLETE
```

## Acceptance

**G1 SYNTHETIC PASS**: corrected PowerShell test returned the expected final markers on a Windows machine. The previously reported `Bad event mapping` failure was caused by direct Console output bypassing the success pipeline; the corrected version uses `Write-Output` and performs explicit output, JSON, mapping, event-ID and privacy checks.

This validates the synthetic JSON conversion path only. It does **not** establish that Codex Desktop's live Stop payload has been received by the new relay, or that the existing Windows desktop renderer accepts v3.

## Remaining holds

- Active hook migration: NOT PERMITTED yet.
- Windows Rust/Tauri v3 receiver compilation: HOLD.
- ChatGPT v2 regression + Codex v3 single-banner/single-audio, cold-start, duplicate events and native permission notifications: HOLD.
- Current installed Codex and ChatGPT alert systems: UNCHANGED.

Proceed to G2 in a separate staging build; keep live environment and main branch stable.
