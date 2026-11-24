@echo off
setlocal EnableExtensions
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0release\Enable-Codex-Diagnostics.ps1"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo G5_CODEX_DIAG_HOLD
pause
exit /b %RC%
