$ErrorActionPreference = 'Stop'
$boot = 'C:\Users\Administrator\.config\wezterm\workbench\bootstrap.ps1'
$src = Get-Content -LiteralPath $boot -Raw
$m = [regex]::Match($src, '(?ms)^function Get-AgentSplashScript.*?^(?=function Start-GrokTab)')
if (-not $m.Success) { Write-Host 'FAIL: helpers not found'; exit 1 }
Invoke-Expression $m.Value
$fakeExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$argv = Get-AgentSplashSpawn -Exe $fakeExe -ExeArgs @('-NoLogo','-Command',"Write-Host 'AGENT-STARTED'") -AgentLabel 'Grok' -Project 'Proj X'
Write-Host '===== generated -Command payload ====='
Write-Host $argv[-1]
Write-Host '======================================'
