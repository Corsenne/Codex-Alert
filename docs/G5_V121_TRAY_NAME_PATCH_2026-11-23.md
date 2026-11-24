# Finish Alert Unified v1.2.1 — Tray label correction

2026-11-23. v1.2.0 installer build and first install succeeded. The user reported that launching the installed G5 app displayed tray tooltip `Finish Alert G4 TEST (not installed)`.

Root cause verified in source: `candidate-g4/desktop/src-tauri/src/lib.rs` hard-coded `.tooltip("Finish Alert G4 TEST (not installed)")`. `release/Build-Installer.ps1` had copied the test Rust code but replaced only its cache path and pipe namespace; it had not replaced the tray tooltip. The NSIS app name, identifier and window title were configured as Finish Alert Unified. The observed tooltip alone does **not** demonstrate that an old G4 process was opened instead of G5.

v1.2.1 changes only the staged release Rust tooltip to `Finish Alert Unified`, versions `release/tauri-release.conf.json`, `release/extension/manifest.json`, staged Cargo and Node package, and the output build marker. The G4 isolated-test source remains unchanged.

Update workflow: build the new setup on the original Windows PC with `G5-Build-Installer.cmd`, close the running Finish Alert Unified tray instance using `終了`, and launch the new `Finish-Alert-Unified-1.2.1-Setup.exe`. The existing 1.2.0 installer does not need to be deleted or overwritten. Because activation has not occurred, no Codex Stop Hook or existing Chrome extension migration is performed by the setup. After installation, confirm the tooltip reads `Finish Alert Unified`. Do not run G5-Activate until the original unpacked Chrome extension path/ID is confirmed.
