@echo off
setlocal EnableExtensions
set "PS51=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS51%" (echo G4C2_POWERSHELL_MISSING & pause & exit /b 2)
"%PS51%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\G4C2-Start.ps1"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" echo G4C2_START_DRIVER_COMPLETE
if not "%RC%"=="0" echo G4C2_START_DRIVER_HOLD
pause
exit /b %RC%
