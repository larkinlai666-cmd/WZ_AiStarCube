@echo off
REM WZ-AiWorkBench unified init panel (same as new-tab / cold-start default)
powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1" %*
