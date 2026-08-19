#Requires -Version 5.1
# Highest product gate: no feature may treat one Agent brand as the only door.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$fail = 0
function Assert([bool]$c, [string]$n) {
  if ($c) { Write-Host "PASS: $n" } else { Write-Host "FAIL: $n"; $script:fail++ }
}

$pod = Join-Path $root 'live-workbench\workbench\escape-pod.ps1'
$wrap = Join-Path $root 'live-workbench\workbench\escape-wrap.ps1'
$podText = Get-Content -LiteralPath $pod -Raw
$wrapText = Get-Content -LiteralPath $wrap -Raw

Assert ($podText.Contains('agent-discovery.ps1')) 'escape pod uses open discovery, not a brand path'
Assert ($podText.Contains('Sort-Object Label, Id')) 'escape pod lists agents as equals'
Assert ($podText -match 'Enter = 1') 'multi-agent pod is a chooser, not a silent brand default'
Assert ($podText -notmatch '(?m)^[^#\r\n]*\\?\.grok\\bin\\grok\.exe') 'pod does not hardcode grok.exe as the starter'
Assert ($wrapText -notmatch '(?m)^[^#\r\n]*\\?\.grok\\bin\\grok\.exe') 'wrap banner does not hardcode grok.exe'

$frontDoors = @(
  (Join-Path $root 'live-workbench\workbench\escape-pod.ps1'),
  (Join-Path $root 'live-workbench\wezterm.lua')
)
foreach ($p in $frontDoors) {
  $t = Get-Content -LiteralPath $p -Raw
  Assert ($t -notmatch 'Starting Grok for self-repair') ('no Grok-only repair slogan in ' + (Split-Path -Leaf $p))
}

$wez = Get-Content -LiteralPath (Join-Path $root 'live-workbench\wezterm.lua') -Raw
Assert ($wez.Contains('escape-pod.ps1')) 'F8 still launches the (now equal) pod'
Assert ($podText.Contains("Join-Path `$installRoot 'repair'")) 'repair desk is next to the install, not a user project'
Assert (Test-Path -LiteralPath (Join-Path $root 'live-workbench\workbench\wz.ps1')) 'wz.ps1 product CLI exists'

if ($fail -eq 0) { Write-Host 'ALL AGENT-PARITY TESTS PASSED' } else { Write-Host "FAILURES: $fail"; exit 1 }
