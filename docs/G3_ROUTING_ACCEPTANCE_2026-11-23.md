# G3 routing acceptance — source-only candidate (2026-11-23)

## Scope
- Implement exact chat selection policy and stop-before-open ordering as a pure, tested module.
- Do NOT install the candidate or replace the stable ChatGPT v1.1.5 / Codex legacy notifier.
- Current user-requested UX: click to open exact ChatGPT or Codex screen; only one banner/audio at a time; click stops active sound.

## Codex
Official Codex Desktop canonical local thread link is `codex://threads/<technical-thread-id>`.
Source: https://learn.chatgpt.com/docs/app/commands
The Stop Hook includes `session_id`, `turn_id`, `transcript_path`; it does not guarantee that `session_id` is always a navigable thread UUID. Source: https://learn.chatgpt.com/docs/hooks
A candidate link may be derived **only** when Stop session_id is UUID and the local rollout transcript filename ends with that exact UUID under CodexHome/sessions. This *still requires* local file exists + session_meta id inspection and Windows handler verification; non-matching/hidden sessions fail closed. It is never safe to open project cwd instead of the exact thread.
Windows has had protocol handler registration bugs; test `codex://` before enablement: https://github.com/openai/codex/issues/14686

## ChatGPT
Prefer the original tab/window if the saved exact conversation URL still matches. If it navigated away, find another exact matching tab. If none, create a tab at the validated saved exact URL. If the URL was absent, never open a generic ChatGPT home page as a false click target.
Extend active route persistence beyond in-memory MV3 service-worker lifetime in a separate G3 bridge patch; the pure module alone does not solve background-worker suspension.

## Audio
Active banner click: stop audio synchronously before any open action, then dismiss. Dismiss X/timeouts stop audio without navigation. The 1-active FIFO actor from G2B remains owner of playback.

## Tests / readiness
`node --test candidate-g3/routing.test.mjs` validates exact UUID link, rejected URL forms, transcript naming, original Chrome tab reuse, changed tab fallback, closed tab create, unavailable target, stop-before-open and stale event rejection.
This is **G3 routing-source validation only**. Not proof that the Codex Desktop Windows URI handler opens the right thread or native callbacks survive MV3 suspension. Those remain G3 Windows HOLD.
