@echo off
setlocal
set "PS51=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS51%" (
  echo Windows PowerShell 5.1 is unavailable.
  pause
  exit /b 1
)
"%PS51%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Inspect-CodexAlert.ps1"
set "ERR=%ERRORLEVEL%"
echo.
if %ERR% EQU 0 echo G0_READONLY_AUDIT_COMPLETE
if %ERR% NEQ 0 echo G0_READONLY_AUDIT_FAILED
pause
exit /b %ERR%
