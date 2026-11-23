# G3 Codex deep-link Windows test — 2026-11-23

## User-provided result

The user executed the read-only `G3-Check-Codex-Link.cmd` on the Codex Windows Desktop PC, pasted a **local** copied `codex://threads/<UUID>` link, and typed `OPEN`.

Observed stage markers:
```text
G3_HELPER_PARSER_PASS
G3_CODEX_DEEPLINK_FORMAT_PASS
G3_CODEX_SESSION_META_ID_PASS
G3_CODEX_URL_HANDLER_REGISTERED
G3_CODEX_LINK_DISPATCHED_USER_VISUAL_CONFIRMATION_REQUIRED
G3_CODEX_READONLY_CHECK_COMPLETE
```

The actual thread identifier is intentionally omitted from this public record.

## Interpretation

- PowerShell helper parses on Windows.
- The copied link has a valid thread UUID shape.
- Local Codex session metadata's thread ID matches the link.
- The Windows `codex://` protocol handler is registered.
- A scheme-launch dispatch was attempted without reported error.
- **The actual Codex Desktop foreground thread has not yet been visually confirmed by the user.**
- The standalone helper is not proof that the future Finish Alert banner's click routing or sound cancellation works.

## Next acceptance

Obtain a simple user confirmation: did the exact originally chosen Codex conversation open (not merely the Codex app or a different thread)?

If yes, mark the deep-link handler gate PASS and proceed to isolated G3 native banner click-to-verified-thread integration, along with stop-audio-before-navigation. Maintain one visible FIFO banner and do not replace installed Finish Alert v1.1.5 or legacy Codex Stop Hook before independent tests and rollback plan.
