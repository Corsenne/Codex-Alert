@echo off
setlocal
set "PS51=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS51%" (echo HOLD: Windows PowerShell missing & pause & exit /b 2)
"%PS51%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tests\Test-G3-Stop-Link.ps1"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" echo G3_SYNTHETIC_LINK_TEST_COMPLETE
if not "%RC%"=="0" echo G3_SYNTHETIC_LINK_TEST_HOLD
pause
exit /b %RC%
