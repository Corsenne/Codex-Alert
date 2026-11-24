# G3 Isolated Codex banner click-to-thread test (2026-11-23)

**Status: source staged / Windows integrated GUI click acceptance PENDING.**

## Entry evidence
The user previously verified Codex Desktop deep-link format, local session_meta identity, registered codex:// handler, and visually confirmed that a copied link opened the exact original conversation when Codex was initially closed.
G2B isolated Tauri/WebView2 bootstrap and synthetic FIFO active/queued/queued/duplicate ACK passed on the user's Windows PC.

## Isolation
Run G3-Click-Test.cmd from the existing Git clone; it fast-forward fetches and builds a separate test workspace under LOCALAPPDATA/CodexAlertDev/G3ClickTest.
- Tauri app ID: com.corsenne.finishalertdesktop.g3clicktest
- EXE: finish-alert-g3-click-test.exe
- Named pipe: corsenne_finish_alert_g3_click_test_<Windows session ID>
- Private Leo/Anna WAV and icons are copied locally from the previously built G2B private workspace, never published to GitHub.
- It never modifies the installed ChatGPT Finish Alert v1.1.5, existing Codex Alert Stop Hook or Codex native permission notifications.

## Test
1. Script prompts for one Codex Desktop Copy deeplink and checks canonical codex://threads/<UUID>, local rollout filename/first-line session_meta ID, and Windows codex:// scheme registration.
2. Script sends only that explicitly verified URI into its own test child process via local environment variable; native IPC rejects any different openTarget.
3. Once G3_UI_READY_PASS is observed, switch Codex to another conversation or close Codex. Press Enter to send one synthetic G3 alert.
4. At G3_TEST_NOTIFICATION_ACK_ACTIVE_PASS, click the synthetic banner **while Leo voice is playing**.
5. Rust calls stop_audio() synchronously inside queue lock **before** calling the URI open handler. It traces G3_AUDIO_STOP_CALLED and G3_THREAD_OPEN_DISPATCHED (if ShellExecuteW accepted the request).
6. Operator must confirm the voice audibly stopped and the *exact* original conversation opened.

## Expected markers
```text
G3_GITHUB_SYNC_PASS
G3_CODEX_EXACT_TARGET_VALIDATED_PASS
G3_PRIVATE_ASSETS_READY
G3_ROUTING_SOURCE_TESTS_PASS
G3_ISOLATED_WINDOWS_BUILD_PASS
G3_UI_READY_PASS
G3_TEST_NOTIFICATION_ACK_ACTIVE_PASS
G3_AUDIO_STOP_CALLED
G3_THREAD_OPEN_DISPATCHED
G3_CLICK_SEQUENCE_ACCEPTED_VISUAL_CONFIRMATION_REQUIRED
```

These markers prove event/command ordering and OS launch dispatch only, **not actual audible stop latency nor correct foreground target**. G3 final PASS requires explicit user observation of both.

## Current limitations
- The isolated G3 IPC is a synchronous request/ACK test server. It must not replace the production async click callback channel.
- Test only covers Codex click. Chrome original-tab callback integration, queue/audio long-run soak, native bridge process lifecycle and the controlled production migration are separate gates.
- No permanent new resident process is installed; script terminates only the G3 test EXE it launched.
- Thread UUID and transcript content are never written to GitHub or stage logs.
