@echo off
setlocal
set "PS51=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS51%" (echo HOLD: PowerShell 5.1 missing & pause & exit /b 2)
"%PS51%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\G3C-Audit.ps1"
set "RC=%ERRORLEVEL%"
pause
exit /b %RC%
