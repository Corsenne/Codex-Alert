@echo off
setlocal EnableExtensions
set "PS51=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS51%" (
  echo G3_CODEX_POWERSHELL_MISSING
  pause
  exit /b 2
)
"%PS51%" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0tools\Verify-G3-Helper.ps1"
if errorlevel 1 (
  echo G3_CODEX_PRECHECK_HOLD - no link was opened.
  pause
  exit /b 2
)
"%PS51%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\G3-Check-Codex-Link.ps1"
set "RESULT=%ERRORLEVEL%"
echo.
if "%RESULT%"=="0" echo G3_CODEX_READONLY_CHECK_COMPLETE
if not "%RESULT%"=="0" echo G3_CODEX_READONLY_CHECK_HOLD exit=%RESULT%
pause
exit /b %RESULT%
