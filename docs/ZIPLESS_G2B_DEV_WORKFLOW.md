# ZIP-less G2B development workflow

After the initial clone, **no manual ZIP downloads or unpacking** are needed.

## One-time setup (Windows PowerShell)

Use the GitHub feature branch. Keep it separate from installed Finish Alert and Codex:

`git clone --branch feature/codex-finish-alert-g0-g2 https://github.com/Corsenne/Codex-Alert.git "$HOME\Codex-Alert"`

Then open `%USERPROFILE%\Codex-Alert\Update-And-Test.cmd` from Explorer.

## Repeated development updates

Double-click **Update-And-Test.cmd**. It checks for Git/Cargo/Node, refuses a dirty tracked working tree and wrong branch, does a fast-forward-only Git update, builds in **%LOCALAPPDATA%\CodexAlertDev\G2BTest**, and runs isolated synthetic G2B tests. It never changes existing installed Chrome extension, native bridge, Windows banner, or Codex Hook.

## Private files

Audio and Tauri icon files are not in the public GitHub repository. The script automatically copies them **locally** on first run from an already extracted G2B package in Downloads (preferably `FinishAlert_Codex_G2B_UI_READY_FIXED`). They are stored under the test workspace and reused. If detection fails, the script stops with `G2B_PRIVATE_ASSET_FOLDER_NOT_FOUND`. It never uploads or publishes these files.

No continuous background process is installed. The test application has distinct app ID, executable and named pipe. This is **not a release installer**.

## Acceptance

The script reports separately:
- G2B_GITHUB_SYNC_PASS
- G2B_ISOLATED_WINDOWS_BUILD_PASS
- G2B_UI_READY_PASS
- G2B_SYNTHETIC_ACK_PASS
- G2B_GITHUB_TEST_COMPLETE_VISUAL_AUDIO_USER_CONFIRMATION_REQUIRED

Actual user verification of one visible banner at a time, voice non-overlap and click-to-stop is still mandatory.
