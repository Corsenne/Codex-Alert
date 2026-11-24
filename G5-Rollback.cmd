@echo off
setlocal EnableExtensions
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0release\Manage-Release.ps1" -Mode Rollback
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo G5_ROLLBACK_HOLD
pause
exit /b %RC%
