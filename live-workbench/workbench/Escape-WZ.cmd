@echo off
REM L0: WezTerm config may be dead. Still do not run Init.
setlocal
set "HERE=%~dp0"
set "WEZ="
if exist "%ProgramFiles%\WezTerm\wezterm.exe" set "WEZ=%ProgramFiles%\WezTerm\wezterm.exe"
if not defined WEZ if exist "%ProgramFiles(x86)%\WezTerm\wezterm.exe" set "WEZ=%ProgramFiles(x86)%\WezTerm\wezterm.exe"
if defined WEZ (
  "%WEZ%" start --cwd "%HERE%..\repair" -- powershell.exe -NoLogo -NoProfile -NoExit -ExecutionPolicy Bypass -File "%HERE%escape-pod.ps1"
  exit /b 0
)
echo WezTerm not found. Opening repair pod in this console.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HERE%escape-pod.ps1"
exit /b 1
