@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL%" (
 echo HOLD: Windows PowerShell 5.1 was not found.
 pause
 exit /b 2
)
"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Update-And-Test.ps1"
set "RESULT=%ERRORLEVEL%"
echo.
if "%RESULT%"=="0" (
 echo G2B_GITHUB_TEST_RUN_COMPLETE - VISUAL AND AUDIO ACCEPTANCE STILL REQUIRED
) else (
 echo G2B_GITHUB_TEST_HOLD exit=%RESULT%
)
pause
exit /b %RESULT%
