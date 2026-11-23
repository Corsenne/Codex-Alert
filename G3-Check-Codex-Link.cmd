@echo off
setlocal
set "PS51=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS51%" (echo HOLD: Windows PowerShell not found & pause & exit /b 2)
"%PS51%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\G3-Check-Codex-Link.ps1"
set "RESULT=%ERRORLEVEL%"
echo.
if "%RESULT%"=="0" echo G3_CODEX_READONLY_CHECK_COMPLETE
if not "%RESULT%"=="0" echo G3_CODEX_READONLY_CHECK_HOLD exit=%RESULT%
pause
exit /b %RESULT%
