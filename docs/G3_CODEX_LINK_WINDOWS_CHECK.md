# G3 Codex exact-thread check helper (no installation changes)

Run G3-Check-Codex-Link.cmd from the existing Git-cloned Codex-Alert directory after syncing.
In Codex Desktop choose one existing local conversation and use Copy deeplink.
Paste codex://threads/<technical-UUID> into the prompt.

The helper allows only a canonical local thread link, searches local CODEX_HOME/sessions rollout filenames for exact UUID,
reads only the first session_meta JSONL line, compares payload.id, and checks codex:// URL handler registration.
It reports stage labels only, never chat contents, paths or prompts.
It opens nothing unless the user explicitly types OPEN. If no handler, it fails closed.

Windows historically had Codex protocol registration issues: https://github.com/openai/codex/issues/14686
Even successful dispatch requires visually verifying that the identical chat opens.
This test never mutates Finish Alert installation or Codex Hook settings.