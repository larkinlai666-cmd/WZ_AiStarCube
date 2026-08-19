#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$wrap = Join-Path $root 'live-workbench\workbench\escape-wrap.ps1'
$pod = Join-Path $root 'live-workbench\workbench\escape-pod.ps1'
$launch = Join-Path $root 'live-workbench\workbench\launch.lua'
$wez = Join-Path $root 'live-workbench\wezterm.lua'
$cmd = Join-Path $root 'live-workbench\workbench\Escape-WZ.cmd'
$fail = 0
function Assert([bool]$c, [string]$n) {
  if ($c) { Write-Host "PASS: $n" } else { Write-Host "FAIL: $n"; $script:fail++ }
}

$tok = $null; $err = $null
[void][Management.Automation.Language.Parser]::ParseFile($wrap, [ref]$tok, [ref]$err)
Assert ($err.Count -eq 0) 'escape-wrap.ps1 parses on PS 5.1'
$wrapText = Get-Content -LiteralPath $wrap -Raw
Assert ($wrapText -notmatch '(?i)&\s*.*agent-discovery') 'wrap never invokes agent-discovery'
Assert ($wrapText -notmatch '@args') 'wrap does not splat'
Assert ($wrapText -notmatch 'WZ_Skill') 'wrap does not special-case the author repo'
Assert ($wrapText -match '& \$boot') 'wrap invokes bootstrap by path'

$lua = Get-Content -LiteralPath $launch -Raw
Assert ($lua.Contains('escape-wrap.ps1')) 'launch.bootstrap_args uses escape-wrap'
Assert ($lua.Contains('bootstrap_raw_args')) 'raw Init remains for F3 wizard'
$menu = $lua.Substring([Math]::Max(0, $lua.IndexOf('launch_menu')))
Assert ($menu.Contains('M.powershell') -and $menu.Contains('M.bootstrap_args()')) 'launch menu has escape shell and Init wrap'

$podText = Get-Content -LiteralPath $pod -Raw
$tok2 = $null; $err2 = $null
[void][Management.Automation.Language.Parser]::ParseFile($pod, [ref]$tok2, [ref]$err2)
Assert ($err2.Count -eq 0) 'escape-pod.ps1 parses on PS 5.1'
Assert ($podText -notmatch '(?i)&\s*.*bootstrap') 'pod never invokes bootstrap'
Assert ($podText.Contains('agent-discovery.ps1') -and $podText.Contains('& $disc')) 'pod invokes open discovery via named path'
Assert ($podText.Contains("Join-Path `$installRoot 'repair'")) 'pod cwd is install-root/repair'
Assert ($podText -notmatch 'WZ_Skill') 'pod does not special-case the author repo'
Assert ($podText.Contains('WZ_Repair | ')) 'pod writes WZ_Repair tab titles'
Assert ($podText.Contains('Write-WzRepairJournal')) 'pod records a repair journal entry'
Assert ($podText.Contains("q = stay in shell")) 'pod q cancels instead of launching agent 1'
Assert ($podText.Contains('JOURNAL.md')) 'journal lives in repair\JOURNAL.md'
$wzps = Join-Path $root 'live-workbench\workbench\wz.ps1'
$tok3 = $null; $err3 = $null
[void][Management.Automation.Language.Parser]::ParseFile($wzps, [ref]$tok3, [ref]$err3)
Assert ($err3.Count -eq 0) 'wz.ps1 parses on PS 5.1'
$st = Get-Content -LiteralPath (Join-Path $root 'live-workbench\workbench\status.lua') -Raw
Assert ($st -notmatch 'if tool == "Shell" or tool == "App"') 'tab bar does not paint desk-roots agent onto a Shell tab'

$main = Get-Content -LiteralPath $wez -Raw
Assert ($main.Contains('key = "F8"')) 'wezterm.lua binds F8'
Assert ($main.Contains('escape-pod.ps1')) 'F8 launches escape-pod.ps1'
Assert ($main.Contains('SpawnCommandInNewTab')) 'F8 opens a new tab'
$keysApply = $main.IndexOf('safe_apply("keys"')
$escapeBind = $main.IndexOf('key = "F8"')
Assert (($keysApply -ge 0) -and ($escapeBind -gt $keysApply)) 'F8 is registered after keys.lua apply'

Assert (Test-Path -LiteralPath $cmd) 'Escape-WZ.cmd is in the installable workbench folder'
$cmdText = Get-Content -LiteralPath $cmd -Raw
Assert ($cmdText.Contains('wezterm.exe')) 'L0 cmd starts wezterm'
Assert ($cmdText.Contains('-- powershell.exe')) 'L0 cmd passes an explicit shell (skips Init wrap)'

if ($fail -eq 0) { Write-Host 'ALL ESCAPE-HATCH TESTS PASSED' } else { Write-Host "FAILURES: $fail"; exit 1 }
