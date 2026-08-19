@echo off
REM Product CLI. Does not start Init.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0wz.ps1" %*
