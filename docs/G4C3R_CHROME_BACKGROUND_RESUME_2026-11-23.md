# G4C-3R Chrome background inventory and phase-B resume

Prior Windows user evidence: five consecutive real ChatGPT completions were all visually PASS, isolated G4 desktop remained exactly one, isolated G4C2 bridge remained one identical PID (25588) and 5.8 MB. The user exited Chrome but twelve chrome.exe processes remained. Therefore the bridge-idle/retirement and post-reopen tests were **not performed**. No leak was established.

`G4C3-Background-Inspect.cmd` reads Chrome processes, their PID, process type (browser-root/renderer/extension-renderer/utility/GPU), parent process name and counts only, plus native process counts and isolated path/session comparisons. Raw command lines, tab URLs, extension IDs, profile paths and private conversation contents are not printed. Process types do not identify the specific service or extension keeping Chrome active.

`G4C3-Resume.cmd` is a continuation for the **already passed five replies**. It refuses if Chrome.exe count is nonzero, if the production native processes are running, if isolated test host registration is unverified, or if G4 Desktop/Bridge identity fails. It never terminates Chrome or any process, edits registry, downloads anything, or generates ChatGPT messages. After verifying Chrome count zero, it observes bridge count 120 seconds later; then it asks the operator to reopen Chrome and verify one real completion. A pass states G4C3R_PHASE_B_SHORT_LIFECYCLE_PASS, not product release. G4C3 long soak and G5 product cutover remain HOLD.

If Chrome processes persist after Chrome's Exit command, the user can inspect Windows background-app settings or manually close background tasks after saving work; do not force-terminate Chrome processes blindly or assume which extension kept them alive. The test remains HOLD until full Chrome exit is observable.

These tools do not repeat the already passed five message tests.