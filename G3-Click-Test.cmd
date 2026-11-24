@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "PS51=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS51%" (echo G3_POWERSHELL_MISSING & pause & exit /b 2)
"%PS51%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Run-G3-Click-Test.ps1"
set "RESULT=%ERRORLEVEL%"
echo.
if "%RESULT%"=="0" (echo G3_CLICK_TEST_FLOW_COMPLETE - VERIFY ORIGINAL THREAD VISUALLY) else (echo G3_CLICK_TEST_HOLD exit=%RESULT%)
pause
exit /b %RESULT%
