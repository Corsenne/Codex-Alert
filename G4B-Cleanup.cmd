@echo off
setlocal EnableExtensions
set "PS51=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS51%" (echo G4B_POWERSHELL_MISSING & pause & exit /b 2)
"%PS51%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\G4B-Cleanup.ps1"
set "RC=%ERRORLEVEL%"
if "%RC%"=="0" echo G4B-CLEANUP_COMPLETE
if not "%RC%"=="0" echo G4B-CLEANUP_HOLD
pause
exit /b %RC%
