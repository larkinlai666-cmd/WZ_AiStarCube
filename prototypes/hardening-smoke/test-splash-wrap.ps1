# Splash-wrapper smoke: extract Get-AgentSplashScript/Get-AgentSplashSpawn from the
# LIVE bootstrap.ps1, build a spawn command for a fake agent, run it, verify the
# cat splash prints and the agent line executes.
$ErrorActionPreference = 'Stop'
$boot = 'C:\Users\Administrator\.config\wezterm\workbench\bootstrap.ps1'
$src = Get-Content -LiteralPath $boot -Raw
$m = [regex]::Match($src, '(?ms)^function Get-AgentSplashScript.*?^(?=function Start-GrokTab)')
if (-not $m.Success) { Write-Host 'FAIL: helpers not found in bootstrap.ps1'; exit 1 }
Invoke-Expression $m.Value

$fakeExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$fakeArgs = @('-NoLogo', '-Command', "Write-Host 'AGENT-STARTED'")
$argv = Get-AgentSplashSpawn -Exe $fakeExe -ExeArgs $fakeArgs -AgentLabel 'Grok' -Project 'Proj X'
Write-Host ('argv0=' + $argv[0] + ' flags=' + ($argv[1..2] -join ' '))

$out = & $fakeExe $argv[1] $argv[2] $argv[3] 2>&1 | Out-String
$okCat   = $out -match '/\\_/\\'
$okFace  = $out -match '\( o\.o \)'
$okLabel = $out -match 'Proj X . Grok'
$okAgent = $out -match 'AGENT-STARTED'
Write-Host ("cat-art={0} face={1} label={2} agent-ran={3}" -f $okCat, $okFace, $okLabel, $okAgent)
if ($okCat -and $okFace -and $okLabel -and $okAgent) { Write-Host 'ALL PASS' } else { Write-Host 'FAIL'; Write-Host $out; exit 1 }

# quoting edge: exe path with spaces + arg with quote
$argv2 = Get-AgentSplashSpawn -Exe "C:\Program Files\WezTerm\wezterm.exe" -ExeArgs @("--ver'sion") -AgentLabel "Codex" -Project "O'Neil"
$cmd2 = $argv2[3]
$okQ = ($cmd2 -match "O''Neil") -and ($cmd2 -match "--ver''sion") -and ($cmd2 -match "C:\\Program Files\\WezTerm")
Write-Host ("quoting-edge={0}" -f $okQ)
if (-not $okQ) { Write-Host $cmd2; exit 1 }
Write-Host 'ALL PASS (quoting)'
