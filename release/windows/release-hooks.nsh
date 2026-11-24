; Finish Alert Unified per-user NSIS hook.
; Installer only records location, then updates an already ACTIVATED user profile.
; First install DOES NOT change existing Chrome extension or Codex hooks.
!macro NSIS_HOOK_POSTINSTALL
  IfFileExists "$INSTDIR\resources\release\Manage-Release.ps1" 0 done_install_hook
  nsExec::ExecToLog '"$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\resources\release\Manage-Release.ps1" -Mode RegisterInstall -InstallDir "$INSTDIR"'
  Pop $0
  StrCmp $0 "0" done_install_hook
  MessageBox MB_ICONEXCLAMATION|MB_OK "Finish Alert files installed. Existing notification integration was not changed; run activation/update helper if needed."
  done_install_hook:
!macroend
; Uninstall never deletes protected original backup or edits users' Codex/Chrome.
; Existing integration must be manually restored first by Rollback helper.
