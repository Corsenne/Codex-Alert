# G4C-2 registration blocked by missing Get-FileHash — limited correction

Date: 2026-11-23. Scope: G4C2 test-only installer and real-use preflight.

## Observed Windows failure
- User typed `STABLE_OFF`, `G4B_OFF`, `REGISTER` correctly, but registration failed with `G4C2_REGISTER_HOLD=用語 'Get-FileHash' ... 認識されません`.
- The original script checks the copied test bridge SHA256 **before creating the HKCU native-host key**, so no successful registration was claimed.
- The previous failed attempt may have left an exact copy of `finish-alert-g4c2-bridge.exe` in the G4C2 isolated test bin folder.

## Correction
- Replace use of `Get-FileHash` with a local `Get-Sha256Hex` function based on `[IO.File]::OpenRead` and `[Security.Cryptography.SHA256]::Create` with proper disposal.
- If test EXE exists and its digest matches source, reuse it. A mismatched existing file is **HOLD**, never overwritten. Verify the digest after the copy path as well.
- Do not touch installed Finish Alert v1.1.5, Codex Hook, or original NativeMessagingHosts registration.
- The user-facing `G4C2-Real-Use.cmd` now refuses to start unless the *isolated G4C2* HKCU key points to its expected local test manifest, host executable is present, and manifest allowed-origin matches the test bridge-config extension ID.
- CI tests the exact helper on `abc` and checks its SHA256 against an established known value. CI does not register a real native host or run Chrome.

## Operator retry
1. Keep legacy Finish Alert disabled and the prior G4B extension disabled.
2. Fast-forward update the same feature branch. Do not manually delete partial G4C2 binary or the registered production host.
3. Run `G4C2-Register.cmd`, paste the **same isolated G4C2** Chrome extension ID, enter `STABLE_OFF`, `G4B_OFF`, `REGISTER`.
4. Require `G4C2_TEST_BRIDGE_SHA256_VERIFIED` and `G4C2_ISOLATED_NATIVE_HOST_REGISTERED_PASS`.
5. Run `G4C2-Start.cmd` (reuses the accepted isolated G4 native app) and `G4C2-Real-Use.cmd` only after registration succeeds.
6. Windows real reply UI/voice/click acceptance still HOLD. Do not claim G5 release.
