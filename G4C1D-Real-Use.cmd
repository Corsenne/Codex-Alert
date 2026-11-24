@echo off
setlocal EnableExtensions
set "PS51=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS51%" (echo G4C1D_POWERSHELL_MISSING & pause & exit /b 2)
"%PS51%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\G4C1D-Real-Use.ps1" -Mode Manual
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" echo G4C1D_MANUAL_DRIVER_COMPLETE
if not "%RC%"=="0" echo G4C1D_MANUAL_DRIVER_HOLD
pause
exit /b %RC%
