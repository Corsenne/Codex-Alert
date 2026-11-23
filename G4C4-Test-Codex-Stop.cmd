@echo off
setlocal EnableExtensions
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\G4C4-Test-Codex-Stop.ps1"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" echo G4C4_TEST_DRIVER_PASS
if not "%RC%"=="0" echo G4C4_TEST_DRIVER_HOLD
pause
exit /b %RC%
