@echo off
setlocal EnableExtensions
set "PS51=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS51%" (echo G4_POWERSHELL_NOT_FOUND & pause & exit /b 2)
"%PS51%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\G4-Build.ps1"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" echo G4_TEST_BUILD_PASS
if not "%RC%"=="0" echo G4_TEST_BUILD_HOLD
pause
exit /b %RC%
