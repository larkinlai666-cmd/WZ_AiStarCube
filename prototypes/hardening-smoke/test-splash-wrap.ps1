# Agent launch argv: extract Test-WzNativeAgentExe / Get-AgentLaunchArgv /
# Get-AgentShimSpawn from live-workbench bootstrap. Native .exe is argv0;
# shims stay on powershell -NoExit and never paint a cover cat.
param([string]$BootstrapPath = (Join-Path $PSScriptRoot '..\..\live-workbench\workbench\bootstrap.ps1'))
$ErrorActionPreference = 'Stop'
$boot = (Resolve-Path -LiteralPath $BootstrapPath).Path
$src = Get-Content -LiteralPath $boot -Raw
$m = [regex]::Match($src, '(?ms)^function Test-WzNativeAgentExe.*?^(?=function Start-GrokTab)')
if (-not $m.Success) { Write-Host 'FAIL: launch helpers not found in bootstrap.ps1'; exit 1 }
Invoke-Expression $m.Value

$fakeExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$fakeArgs = @('-NoLogo', '-Command', "Write-Host 'AGENT-STARTED'")
$argv = Get-AgentLaunchArgv -Exe $fakeExe -ExeArgs $fakeArgs -AgentLabel 'Arbitrary Agent' -Project 'Proj X'
Write-Host ('native-argv0=' + $argv[0] + ' argc=' + $argv.Count)
if ($argv[0] -ne $fakeExe) {
  Write-Host 'FAIL: native .exe must be argv0 (no PowerShell cover)'
  exit 1
}
if (($argv -join ' ') -match '/\\_/\\' -or ($argv -join ' ') -match 'handing off') {
  Write-Host 'FAIL: native launch argv still contains a cover cat'
  exit 1
}
$okArg1 = ($argv[1] -eq '-NoLogo')
$okArg2 = ($argv[2] -eq '-Command')
Write-Host ("direct-spawn={0} args-kept={1}" -f $true, ($okArg1 -and $okArg2))
if (-not ($okArg1 -and $okArg2)) { Write-Host ($argv -join ' | '); exit 1 }

$shimPath = Join-Path $env:TEMP 'wz-launch-shim.cmd'
Set-Content -LiteralPath $shimPath -Value '@echo SHIM-STARTED' -Encoding ASCII
$shimArgv = Get-AgentLaunchArgv -Exe $shimPath -ExeArgs @('hello') -AgentLabel 'Shim' -Project 'Proj X'
if ($shimArgv[0] -ne 'powershell.exe' -or $shimArgv -notcontains '-NoExit') {
  Write-Host 'FAIL: shim must stay on powershell -NoExit'
  Write-Host ($shimArgv -join ' | ')
  exit 1
}
$shimCmd = $shimArgv[-1]
if ($shimCmd -match '/\\_/\\' -or $shimCmd -match 'handing off') {
  Write-Host 'FAIL: shim wrap still paints a cover cat'
  Write-Host $shimCmd
  exit 1
}
if ($shimCmd -notmatch [regex]::Escape($shimPath.Replace("'", "''")) -and $shimCmd -notmatch 'wz-launch-shim') {
  Write-Host 'FAIL: shim command does not invoke the .cmd path'
  Write-Host $shimCmd
  exit 1
}
Write-Host 'ALL PASS (native direct + shim host, no cat)'

# quoting edge: exe path with spaces + arg with quote (shim path, so wrap)
$argv2 = Get-AgentShimSpawn -Exe "C:\Program Files\WezTerm\tool.cmd" -ExeArgs @("--ver'sion")
$cmd2 = $argv2[-1]
$okQ = ($cmd2 -match "--ver''sion") -and ($cmd2 -match "C:\\Program Files\\WezTerm")
Write-Host ("quoting-edge={0}" -f $okQ)
if (-not $okQ) { Write-Host $cmd2; exit 1 }
Write-Host 'ALL PASS (quoting)'
