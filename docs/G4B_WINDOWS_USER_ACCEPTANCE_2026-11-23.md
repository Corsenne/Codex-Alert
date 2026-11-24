# G4B Windows User Acceptance — 2026-11-23

- **G4B-1 user-reported PASS:** all five items (test event accepted, one banner, one voice, click stop, exact ChatGPT conversation focus).
- **G4B-2 user-reported PASS:** ChatGPT first, then Codex synthetic event (console `G4B_CODEX_SYNTHETIC_ACK=queued` and `G4B_CODEX_SYNTHETIC_ACK_PASS`); then Codex first, ChatGPT second and manual visual acceptance `PASS`.
- No screenshot, timing measurements, process lifetime inventory, or real completion events were supplied for the final G4B run. Preserve this limitation.
- The Codex event used `openTarget=null` and deliberately did not open a real Codex thread; actual exact thread open was treated separately in G3.
- **G4B isolated integration accepted; G4C real event integration and G5 release remain HOLD.**
