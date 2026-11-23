@echo off
setlocal EnableExtensions
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0release\Manage-Release.ps1" -Mode Preview
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo G5_PREVIEW_HOLD
pause
exit /b %RC%
