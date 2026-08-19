#Requires -Version 5.1
# F8 / wz repair. NEVER run bootstrap.ps1.
# cwd = <install-root>\repair  (product facility, not a user TASK).
# Agents from open discovery, listed as equals. ASCII only.

$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot
$installRoot = Split-Path -Parent $here
$repairRoot = Join-Path $installRoot 'repair'

function Get-WzWezExe {
  if ($env:ProgramFiles) {
    $c = Join-Path $env:ProgramFiles 'WezTerm\wezterm.exe'
    if (Test-Path -LiteralPath $c -PathType Leaf) { return $c }
  }
  $cmd = Get-Command wezterm -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return [string]$cmd.Source }
  return $null
}

function Ensure-WzRepairDesk {
  try {
    if (-not (Test-Path -LiteralPath $repairRoot -PathType Container)) {
      New-Item -ItemType Directory -Force -Path $repairRoot | Out-Null
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $installTxt = Join-Path $repairRoot 'INSTALL.txt'
    [System.IO.File]::WriteAllLines($installTxt, @(
      ('INSTALL=' + $installRoot),
      'This folder is the WZ repair desk. Do not use it for daily project work.',
      'Fix the install tree named above. Notes: INCIDENT.md  History: JOURNAL.md'
    ), $utf8)
    $incident = Join-Path $repairRoot 'INCIDENT.md'
    if (-not (Test-Path -LiteralPath $incident -PathType Leaf)) {
      [System.IO.File]::WriteAllLines($incident, @(
        '# WZ repair notes',
        '',
        '- When it broke:',
        '- What you pressed:',
        '- What you saw:',
        '',
        'Daily work stays in Init. Press F8 to return here.'
      ), $utf8)
    }
    return $true
  } catch {
    Write-Host ('  repair desk unavailable: ' + $_.Exception.Message) -ForegroundColor DarkYellow
    return $false
  }
}

function Read-WzTextTail {
  param([string]$Path, [int]$Lines = 8)
  if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
  try { return @(Get-Content -LiteralPath $Path -Tail $Lines -ErrorAction Stop) } catch { return @() }
}

function Write-WzRepairJournal {
  param([string]$Kind, [string]$Detail, [string[]]$Agents)
  $journal = Join-Path $repairRoot 'JOURNAL.md'
  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $block = New-Object System.Collections.Generic.List[string]
  [void]$block.Add('')
  [void]$block.Add('## ' + $stamp + '  ' + $Kind)
  [void]$block.Add('install: ' + $installRoot)
  if ($Agents -and $Agents.Count -gt 0) { [void]$block.Add('agents: ' + ($Agents -join ', ')) }
  else { [void]$block.Add('agents: (none)') }
  if ($Detail) { [void]$block.Add('detail: ' + $Detail) }
  $loadErr = Join-Path $here 'last-load-errors.txt'
  foreach ($l in @(Read-WzTextTail -Path $loadErr -Lines 6)) { [void]$block.Add('load: ' + $l) }
  $dbg = Join-Path $here 'discovery-debug.log'
  foreach ($l in @(Read-WzTextTail -Path $dbg -Lines 4)) { [void]$block.Add('discovery: ' + $l) }
  try {
    if (-not (Test-Path -LiteralPath $journal -PathType Leaf)) {
      $utf8 = New-Object System.Text.UTF8Encoding $false
      [System.IO.File]::WriteAllText($journal, "# WZ repair journal`r`n", $utf8)
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $sw = New-Object System.IO.StreamWriter($journal, $true, $utf8)
    try { foreach ($l in $block) { $sw.WriteLine($l) } } finally { $sw.Dispose() }
    $item = Get-Item -LiteralPath $journal
    if ($item.Length -gt 80000) {
      $keep = @(Get-Content -LiteralPath $journal -Tail 200)
      [System.IO.File]::WriteAllLines($journal, (@('# WZ repair journal (rotated)') + $keep), $utf8)
    }
  } catch {
    Write-Host ('  journal write skipped: ' + $_.Exception.Message) -ForegroundColor DarkYellow
  }
}

function Show-WzRepairJournalTail {
  $journal = Join-Path $repairRoot 'JOURNAL.md'
  $lines = @(Read-WzTextTail -Path $journal -Lines 24)
  if ($lines.Count -eq 0) { return }
  Write-Host '  recent journal' -ForegroundColor DarkGray
  $shown = 0
  for ($i = $lines.Count - 1; $i -ge 0 -and $shown -lt 12; $i--) {
    $t = [string]$lines[$i]
    if ($t.StartsWith('## ')) {
      Write-Host ('    ' + $t.Substring(3)) -ForegroundColor DarkGray
      $shown++
    }
  }
}

function Get-WzPodAgents {
  $disc = Join-Path $here 'agent-discovery.ps1'
  if (-not (Test-Path -LiteralPath $disc -PathType Leaf)) { return @() }
  $out = @()
  try {
    $out = @(& $disc -WorkbenchDir $here)
  } catch {
    Write-Host ('  discovery failed: ' + $_.Exception.Message) -ForegroundColor DarkYellow
    return @()
  }
  return @($out | Where-Object { $_.Id -and $_.Exe } | Sort-Object Label, Id)
}

function Set-WzPodTabTitle {
  param([string]$Title)
  try { $Host.UI.RawUI.WindowTitle = $Title } catch {}
  $pane = $env:WEZTERM_PANE
  if ($pane -notmatch '^\d+$') { return }
  $wez = Get-WzWezExe
  if (-not $wez) { return }
  try { & $wez @('cli', 'set-tab-title', '--pane-id', "$pane", $Title) 2>$null | Out-Null } catch {}
}

function Start-WzPodAgent {
  param($Agent, [string]$Cwd)
  $id = ([string]$Agent.Id).ToLowerInvariant()
  $exe = [string]$Agent.Exe
  $label = [string]$Agent.Label
  if (-not $exe -or -not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    Write-Host ('  missing executable for ' + $label) -ForegroundColor Red
    return
  }
  try { Set-Location -LiteralPath $Cwd } catch {}
  $safeLabel = ([string]$label -replace '[\r\n\|]', ' ').Trim()
  if (-not $safeLabel) { $safeLabel = $id }
  if ($safeLabel.Length -gt 24) { $safeLabel = $safeLabel.Substring(0, 24) }
  Set-WzPodTabTitle -Title ('WZ_Repair | ' + $safeLabel)
  Write-Host ('  starting ' + $label + ' ...') -ForegroundColor Yellow
  Write-Host ''
  if ($id -eq 'grok') { & $exe --cwd $Cwd }
  elseif ($id -eq 'codex') { & $exe -C $Cwd }
  else { & $exe }
  Write-Host ''
  Set-WzPodTabTitle -Title 'WZ_Repair | Shell'
  Write-Host ('  ' + $label + ' exited. This shell stays open. F8 opens another pod.') -ForegroundColor DarkGray
}

$deskOk = [bool](Ensure-WzRepairDesk)
if ($deskOk) { try { Set-Location -LiteralPath $repairRoot } catch {} }
else { try { Set-Location -LiteralPath $here } catch {} }
Set-WzPodTabTitle -Title 'WZ_Repair | Shell'

Write-Host ''
Write-Host '  WZ ESCAPE POD  (F8 / wz repair)' -ForegroundColor Cyan
Write-Host '  Install repair desk. Not a daily project. History: repair\JOURNAL.md' -ForegroundColor DarkGray
Write-Host ('  cwd: ' + $(if ($deskOk) { $repairRoot } else { $here })) -ForegroundColor DarkGray
Write-Host ('  install: ' + $installRoot) -ForegroundColor DarkGray

$agents = @(Get-WzPodAgents)
$agentNames = @($agents | ForEach-Object { [string]$_.Label })
Write-WzRepairJournal -Kind 'F8' -Detail $('deskOk=' + $deskOk + ' agentCount=' + $agents.Count) -Agents $agentNames
Show-WzRepairJournalTail

if ($agents.Count -eq 0) {
  Write-Host '  no self-described or locally registered Agent on this machine.' -ForegroundColor Yellow
  Write-Host '  install any CLI or add workbench\agent-registry.local.tsv' -ForegroundColor Yellow
  Write-Host '  shell stays open for manual repair. F8 opens another pod.' -ForegroundColor DarkGray
  Write-Host ''
  return
}

Write-Host '  2 AGENT  (equals)' -ForegroundColor Magenta
for ($i = 0; $i -lt $agents.Count; $i++) {
  Write-Host ('    [' + ($i + 1) + '] ' + $agents[$i].Label) -ForegroundColor Yellow
}

$pick = 1
$redir = $false
try { $redir = [Console]::IsInputRedirected } catch {}
if ($agents.Count -gt 1 -and -not $redir) {
  Write-Host -NoNewline '  agent number + Enter (Enter = 1, q = stay in shell) ' -ForegroundColor Yellow
  $line = Read-Host
  if ($null -ne $line) {
    $line = ([string]$line).Trim()
    if ($line -eq 'q' -or $line -eq 'Q') {
      Write-Host '  stayed in repair shell. F8 opens another pod.' -ForegroundColor DarkGray
      Write-Host ''
      return
    }
    $n = 0
    if ($line -and [int]::TryParse($line, [ref]$n) -and $n -ge 1 -and $n -le $agents.Count) { $pick = $n }
  }
}

$launchCwd = $repairRoot
if (-not $deskOk -or -not (Test-Path -LiteralPath $launchCwd -PathType Container)) { $launchCwd = $here }
Start-WzPodAgent -Agent $agents[$pick - 1] -Cwd $launchCwd
Write-Host ''
