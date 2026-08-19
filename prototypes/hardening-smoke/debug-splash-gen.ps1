# Debug helper: dump Get-AgentLaunchArgv for a fake native exe.
$src = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\live-workbench\workbench\bootstrap.ps1') -Raw
$m = [regex]::Match($src, '(?ms)^function Test-WzNativeAgentExe.*?^(?=function Start-GrokTab)')
if (-not $m.Success) { throw 'launch helpers not found' }
Invoke-Expression $m.Value
$fakeExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$argv = Get-AgentLaunchArgv -Exe $fakeExe -ExeArgs @('-NoLogo','-Command',"Write-Host 'AGENT-STARTED'") -AgentLabel 'Grok' -Project 'Proj X'
Write-Host ('argc=' + $argv.Count)
Write-Host ('argv0=' + $argv[0])
Write-Host ($argv -join ' | ')
