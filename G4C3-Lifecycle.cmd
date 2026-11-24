@echo off
setlocal EnableExtensions
set "PS51=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS51%" (echo G4C3_POWERSHELL_MISSING & pause & exit /b 2)
set "MODE=Guided"
if /I "%~1"=="snapshot" set "MODE=Snapshot"
"%PS51%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\G4C3-Lifecycle.ps1" -Mode %MODE%
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" echo G4C3_DRIVER_COMPLETE
if not "%RC%"=="0" echo G4C3_DRIVER_HOLD
pause
exit /b %RC%
