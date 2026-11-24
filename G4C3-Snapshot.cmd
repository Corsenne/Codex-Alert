@echo off
setlocal EnableExtensions
call "%~dp0G4C3-Lifecycle.cmd" snapshot
exit /b %ERRORLEVEL%
