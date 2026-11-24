# Finish Alert Unified v1.2.0 — Initial installer and update workflow

**Status: installer source candidate. No Windows customer installer has yet been produced using the real private audio; no production settings have been changed.**

## Release user experience

- Build an NSIS `Finish-Alert-Unified-1.2.0-Setup.exe` on the original Windows development PC using `G5-Build-Installer.cmd`.
- Run the setup EXE once. It installs a separate *Finish Alert Unified* app per-user, leaving the existing Finish Alert v1.1.5/v1.1.4 application and original Chrome extension untouched. This provides a reversible transition and avoids a destructive replacement.
- Use `G5-Preview.cmd` then `G5-Activate.cmd` **once** to connect the installed binary to the existing Chrome extension ID/online settings and single Codex Stop Hook. This requires the existing stable Chrome extension to be an **unpacked extension**, its ORIGINAL folder, the original extension ID shown at chrome://extensions, and explicit human consent. It refuses unverified directories and nonunique Stop Hook configuration. It does not install a second Chrome extension ID.
- The activation backs up the original Stop hooks.json, original Native Messaging manifest and original Chrome extension files to a private LOCALAPPDATA folder, then installs the v1.2 extension files INTO THE SAME ORIGINAL folder. It updates one Stop Hook command and the HKCU Native Messaging host `com.corsenne.finish_alert`; Codex PermissionRequest and other hook groups are left unchanged. Browser reload may be required to load the updated unpacked extension.
- After activation, subsequent versioned NSIS updates use the same app identity/installer. The postinstall hook calls `Manage-Release.ps1 -Mode RegisterInstall`, which automatically updates the previously activated bridge and same extension folder **only if stored state is valid**. Versioned bridge directories avoid replacing a running bridge executable. If the state is absent, the installer only records its location and does not mutate the original setup.
- `G5-Rollback.cmd` restores original hook JSON, original extension files and original Native Messaging registry target from the first pre-cutover backup. The original app is not removed. Uninstall the new Unified app **only after rollback**.

## Conditions that still require operator confirmation

The repository does not contain the installed v1.1.5 Chrome source or private audio assets. It cannot certify the Chrome extension’s original unpacked path or ID automatically. If the stable extension is Web Store-managed or the original unpacked directory cannot be identified, keep the migration **HOLD**, rather than silently installing a different ID or overwriting Chrome settings.

The Windows setup build requires local private audio and icons:
- `%LOCALAPPDATA%\CodexAlertDev\G2BTest\desktop\src-tauri\src\assets\*.wav` (4 local UI tones);
- `%LOCALAPPDATA%\CodexAlertDev\G2BTest\private\private-leo.wav` or existing G4 private Leo clip;
- icons from the same G2B staging workspace.

The builder does not upload private voice files to GitHub. GitHub Actions uses **synthetic silence** only for build verification; synthetic installers must never be distributed to users. Ensure rights to distribute any included private audio before sharing the EXE outside the original PC.

## Release acceptance, streamlined

Build the NSIS installer, activate the exact existing user extension, then observe **one actual ChatGPT reply and one actual Codex Stop completion**, banner and audio exactly once, source-specific click-to-stop and original destination. If those work and approval notifications remain intact, release v1.2.0. Later updates use the same installer and short practical regression only. No Chrome-exit/Bridge idle/multi-day soak gate.

## Source/staged boundary

Release is a distinct product namespace `com.corsenne.finishalertdesktop.unified` and pipe `corsenne_finish_alert_v12_<session>`. The separate stable app remains installed and can be used after rollback. No migration proceeds without the one-time confirmation.

**No release has been installed by this repository change.**
