#Requires -Version 5.1
<#
.SYNOPSIS
  One-shot Windows installer for the WZ_AiStarCube_win WezTerm workbench.

.DESCRIPTION
  Copies live-workbench/ → %USERPROFILE%\.config\wezterm\ using verified,
  atomic writes. Creates empty desk-roots (or binds this repo), then runs doctor.

  The install contains no private tasks, Agent credentials, or conversations.
  Other users receive the same keys, Init panel, gates, and open Agent discovery.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1
  powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1 -ProjectsRoot D:\MyProjects
  powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1 -SkipBindRepo
#>
[CmdletBinding()]
param(
  [string]$ProjectsRoot = "",
  [switch]$SkipBindRepo,
  [switch]$NoBackup,
  [switch]$DoctorOnly
)

$ErrorActionPreference = "Stop"

function Test-WindowsHost {
  return [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

function Commit-WzAtomicFile {
  param([string]$TemporaryPath, [string]$Destination)
  $backup = $Destination + '.swap.' + $PID + '.' + [guid]::NewGuid().ToString('N')
  try {
    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
      [System.IO.File]::Replace($TemporaryPath, $Destination, $backup, $true)
    } else {
      [System.IO.File]::Move($TemporaryPath, $Destination)
    }
  } finally {
    if ((Test-Path -LiteralPath $backup -PathType Leaf) -and -not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
      [System.IO.File]::Move($backup, $Destination)
    }
    if (Test-Path -LiteralPath $backup -PathType Leaf) {
      Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
    }
  }
}

function Write-WzUtf8LinesAtomic {
  param([string]$Path, [string[]]$Lines)
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  $tmp = Join-Path $dir ((Split-Path -Leaf $Path) + '.tmp.' + $PID + '.' + [guid]::NewGuid().ToString('N'))
  $utf8 = New-Object System.Text.UTF8Encoding $false
  try {
    [System.IO.File]::WriteAllLines($tmp, $Lines, $utf8)
    Commit-WzAtomicFile -TemporaryPath $tmp -Destination $Path
  } finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
  }
}

function Copy-WzFileAtomic {
  param([string]$Source, [string]$Destination)
  $dir = Split-Path -Parent $Destination
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  $tmp = Join-Path $dir ((Split-Path -Leaf $Destination) + '.tmp.' + $PID + '.' + [guid]::NewGuid().ToString('N'))
  try {
    Copy-Item -LiteralPath $Source -Destination $tmp -Force
    if ((Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash) {
      throw "Copy verification failed: $Source"
    }
    Commit-WzAtomicFile -TemporaryPath $tmp -Destination $Destination
  } finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
  }
}

$RepoRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$Src = Join-Path $RepoRoot "live-workbench"
$Dst = Join-Path $env:USERPROFILE ".config\wezterm"
$WbDst = Join-Path $Dst "workbench"

function Write-Step([string]$Msg, [string]$Color = "Cyan") {
  Write-Host ""
  Write-Host "==> $Msg" -ForegroundColor $Color
}

function Write-Ok([string]$Msg) { Write-Host "  OK  $Msg" -ForegroundColor Green }
function Write-Warn([string]$Msg) { Write-Host "  !!  $Msg" -ForegroundColor DarkCyan }
function Write-Bad([string]$Msg) { Write-Host "  XX  $Msg" -ForegroundColor Red }

function Test-CommandExists([string]$Name) {
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-DetectedAgents {
  # Same open, metadata-driven inventory as Init/F3/F6. No product whitelist.
  $helper = Join-Path $WbDst 'agent-discovery.ps1'
  $root = $WbDst
  if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
    $root = Join-Path $Src 'workbench'
    $helper = Join-Path $root 'agent-discovery.ps1'
  }
  if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) { return @() }
  try { return @(& $helper -WorkbenchDir $root) } catch { return @() }
}

function Resolve-WezExe {
  $candidates = @()
  if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles "WezTerm\wezterm.exe") }
  $pf86 = ${env:ProgramFiles(x86)}
  if ($pf86) { $candidates += (Join-Path $pf86 "WezTerm\wezterm.exe") }
  # Stripped environments (CI / automation shells) may drop ProgramFiles from
  # the process env; known-folder lookup survives that.
  try {
    $kf = [Environment]::GetFolderPath('ProgramFiles')
    if ($kf) { $candidates += (Join-Path $kf "WezTerm\wezterm.exe") }
  } catch {}
  $wezCmd = Get-Command wezterm -ErrorAction SilentlyContinue
  if ($wezCmd) { $candidates += $wezCmd.Source }
  foreach ($c in $candidates) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  return $null
}

function Invoke-Doctor {
  Write-Step "Doctor (preflight)"
  $fail = 0

  if (-not (Test-WindowsHost)) {
    Write-Bad "This repository supports Windows only (PowerShell 5.1+ and WezTerm)."
    $fail++
  } else {
    Write-Ok "Windows host (supported platform)"
  }

  $wez = Resolve-WezExe
  if ($wez) { Write-Ok "WezTerm: $wez" } else {
    Write-Bad "WezTerm not found. Install: https://wezfurlong.org/wezterm/"
    $fail++
  }

  $foundAgents = @(Get-DetectedAgents)
  foreach ($a in $foundAgents) { Write-Ok ("Agent {0}: {1}" -f $a.Label, $a.Exe) }
  if ($foundAgents.Count -eq 0) {
    Write-Bad "No self-described or locally registered agent CLI found. Install at least one."
    Write-Warn "Workbench UI still installs; AI tabs need an agent CLI to be useful."
    $fail++
  }

  $cfg = Join-Path $Dst "wezterm.lua"
  $desk = Join-Path $WbDst "desk.lua"
  $boot = Join-Path $WbDst "bootstrap.ps1"
  if (Test-Path -LiteralPath $cfg) { Write-Ok "config: $cfg" } else {
    Write-Bad "Missing wezterm.lua at $cfg — run install first"
    $fail++
  }
  if (Test-Path -LiteralPath $desk) { Write-Ok "module: desk.lua" } else {
    Write-Bad "Missing workbench/desk.lua"
    $fail++
  }
  if (Test-Path -LiteralPath $boot) { Write-Ok "module: bootstrap.ps1" } else {
    Write-Bad "Missing workbench/bootstrap.ps1"
    $fail++
  }

  $roots = Join-Path $WbDst "desk-roots.tsv"
  if (Test-Path -LiteralPath $roots) {
    $n = @(Get-Content -LiteralPath $roots | Where-Object { $_ -and $_ -notmatch '^\s*#' }).Count
    Write-Ok "desk-roots.tsv ($n bindings)"
  } else {
    Write-Warn "No desk-roots.tsv yet (empty task list until you create/bind)"
  }

  if ($ProjectsRoot) {
    Write-Ok "WZ_PROJECTS_ROOT override requested: $ProjectsRoot"
  } elseif ($env:WZ_PROJECTS_ROOT) {
    Write-Ok "env WZ_PROJECTS_ROOT=$($env:WZ_PROJECTS_ROOT)"
  } else {
    Write-Warn "No WZ_PROJECTS_ROOT — new projects default to Documents\AIProjects"
  }

  Write-Host ""
  if ($fail -gt 0) {
    Write-Host "Doctor: $fail blocking issue(s)." -ForegroundColor Red
  } else {
    Write-Host "Doctor: ready." -ForegroundColor Green
  }
  return $fail
}

function Backup-Existing {
  if (-not (Test-Path -LiteralPath $Dst)) { return }
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $bak = Join-Path $env:USERPROFILE ".config\wezterm.bak-$stamp"
  $suffix = 1
  while (Test-Path -LiteralPath $bak) {
    $bak = Join-Path $env:USERPROFILE (".config\wezterm.bak-{0}-{1}" -f $stamp, $suffix)
    $suffix++
  }
  Write-Step "Backup existing config → $bak"
  Copy-Item -LiteralPath $Dst -Destination $bak -Recurse -Force
  Write-Ok "Backup complete"
}

function Install-Workbench {
  if (-not (Test-Path -LiteralPath $Src)) {
    throw "live-workbench/ missing under $RepoRoot — clone incomplete?"
  }
  $must = @(
    (Join-Path $Src "wezterm.lua"),
    (Join-Path $Src "workbench\desk.lua"),
    (Join-Path $Src "workbench\bootstrap.ps1"),
    (Join-Path $Src "workbench\agent-discovery.ps1"),
    (Join-Path $Src "workbench\keys.lua"),
    (Join-Path $Src "workbench\status.lua"),
    (Join-Path $Src "workbench\projects.lua")
  )
  foreach ($m in $must) {
    if (-not (Test-Path -LiteralPath $m)) { throw "Incomplete snapshot: missing $m" }
  }

  Write-Step "Install workbench → $Dst"
  New-Item -ItemType Directory -Force -Path $WbDst | Out-Null
  Copy-WzFileAtomic -Source (Join-Path $Src "wezterm.lua") -Destination (Join-Path $Dst "wezterm.lua")
  if (Test-Path (Join-Path $Src "README.md")) {
    Copy-WzFileAtomic -Source (Join-Path $Src "README.md") -Destination (Join-Path $Dst "README.md")
  }
  Get-ChildItem (Join-Path $Src "workbench") -File | ForEach-Object {
    # Never overwrite personal bindings with examples
    if ($_.Name -match '^(desk-roots|favorites|agent-registry\.local)') { return }
    if ($_.Name -match '\.example\.') { return }
    Copy-WzFileAtomic -Source $_.FullName -Destination (Join-Path $WbDst $_.Name)
  }
  Write-Ok "Copied wezterm.lua + workbench modules"

  $roots = Join-Path $WbDst "desk-roots.tsv"
  if (-not (Test-Path -LiteralPath $roots)) {
    $lines = @(
      "# AI STAR CUBE desk roots - project_name<TAB>absolute_path",
      "# Created by Install-WZ.ps1 — add projects via Init panel key  c  or open-project.ps1",
      "# Weak paths (home/Desktop/Documents root/Downloads) are NOT valid project roots"
    )
    Write-WzUtf8LinesAtomic -Path $roots -Lines $lines
    Write-Ok "Created empty desk-roots.tsv"
  } else {
    Write-Ok "Kept existing desk-roots.tsv (personal bindings preserved)"
  }

  $fav = Join-Path $WbDst "favorites.txt"
  if (-not (Test-Path -LiteralPath $fav)) {
    Write-WzUtf8LinesAtomic -Path $fav -Lines @("# favorites — one absolute path per line")
    Write-Ok "Created empty favorites.txt"
  }

  $localAgents = Join-Path $WbDst 'agent-registry.local.tsv'
  if (-not (Test-Path -LiteralPath $localAgents)) {
    Write-WzUtf8LinesAtomic -Path $localAgents -Lines @(
      '# Optional fallback for silent standalone CLIs: id<TAB>label<TAB>command aliases separated by |',
      '# Metadata-discovered npm/Python/manifest agents do not need a row here.'
    )
    Write-Ok 'Created agent-registry.local.tsv (open local fallback)'
  } else {
    Write-Ok 'Kept agent-registry.local.tsv (personal Agent registrations preserved)'
  }

  $repair = Join-Path $Dst 'repair'
  if (-not (Test-Path -LiteralPath $repair -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $repair | Out-Null
  }
  Write-WzUtf8LinesAtomic -Path (Join-Path $repair 'INSTALL.txt') -Lines @(
    ('INSTALL=' + $Dst),
    'This folder is the WZ repair desk. Do not use it for daily project work.'
  )
  $incident = Join-Path $repair 'INCIDENT.md'
  if (-not (Test-Path -LiteralPath $incident -PathType Leaf)) {
    $srcIncident = Join-Path $Src 'repair\INCIDENT.md'
    if (Test-Path -LiteralPath $srcIncident -PathType Leaf) {
      Copy-WzFileAtomic -Source $srcIncident -Destination $incident
    } else {
      Write-WzUtf8LinesAtomic -Path $incident -Lines @(
        '# WZ repair notes',
        '',
        'Do not treat this folder as a daily project.'
      )
    }
    Write-Ok 'Created repair/INCIDENT.md'
  } else {
    Write-Ok 'Kept existing repair notes (not overwritten)'
  }
}

function Bind-ThisRepo {
  if ($SkipBindRepo) {
    Write-Warn "SkipBindRepo: not registering clone as a task"
    return
  }
  Write-Step "Bind this clone as first TASK"
  $name = Split-Path -Leaf $RepoRoot
  if ($name -match '^(?i:home|desktop|documents|downloads)$') {
    Write-Warn "Repo folder name '$name' is reserved — binding as WZ_AiStarCube_win"
    $name = "WZ_AiStarCube_win"
  }
  # Unified semantics: the row we BIND gets an explicit 3rd agent column (first
  # dynamically discovered peer). Rows we did not
  # touch keep whatever they had (legacy 2-column rows stay 2-column).
  $bindAgent = ""
  $detectedAgents = @(Get-DetectedAgents)
  if ($detectedAgents.Count -gt 0) { $bindAgent = [string]$detectedAgents[0].Id }
  $roots = Join-Path $WbDst "desk-roots.tsv"
  $map = [ordered]@{}
  $agentMap = @{}
  if (Test-Path -LiteralPath $roots) {
    foreach ($line in Get-Content -LiteralPath $roots -ErrorAction SilentlyContinue) {
      $t = $line.Trim()
      if ($t -eq "" -or $t.StartsWith("#")) { continue }
      # tolerate 2 or 3 TAB columns (name, path, optional agent)
      $parts = $t -split "`t"
      if ($parts.Count -lt 2) { $parts = $t -split "\s+", 2 }
      if ($parts.Count -ge 2) {
        $map[$parts[0]] = $parts[1].TrimEnd('\')
        if ($parts.Count -ge 3 -and $parts[2].Trim()) {
          $agentMap[$parts[0]] = $parts[2].Trim().ToLowerInvariant()
        }
      }
    }
  }
  $pk = $RepoRoot.TrimEnd('\').ToLowerInvariant()
  foreach ($k in @($map.Keys)) {
    if ($map[$k].TrimEnd('\').ToLowerInvariant() -eq $pk -and $k -ne $name) {
      $map.Remove($k)
      $agentMap.Remove($k)
    }
  }
  $map[$name] = $RepoRoot
  if ($bindAgent) { $agentMap[$name] = $bindAgent }
  $out = @(
    "# AI STAR CUBE desk roots - project_name<TAB>absolute_path[<TAB>agent]",
    "# Bound by Install-WZ.ps1 — optional 3rd column is any discovered Agent route id"
  )
  foreach ($k in ($map.Keys | Sort-Object)) {
    if ($agentMap.Contains($k)) {
      $out += ($k + "`t" + $map[$k] + "`t" + $agentMap[$k])
    } else {
      $out += ($k + "`t" + $map[$k])
    }
  }
  Write-WzUtf8LinesAtomic -Path $roots -Lines $out

  $marker = Join-Path $RepoRoot ".wz-project"
  $ml = @(
    "# WZ project identity — frozen at install/bind",
    "name=$name",
    "path=$RepoRoot",
    ("created={0:yyyy-MM-ddTHH:mm:ssK}" -f (Get-Date))
  )
  $markerMatches = $false
  if (Test-Path -LiteralPath $marker -PathType Leaf) {
    $existing = @(Get-Content -LiteralPath $marker -Encoding UTF8 -ErrorAction SilentlyContinue)
    $markerMatches = ($existing -contains ('name=' + $name)) -and ($existing -contains ('path=' + $RepoRoot))
  }
  if (-not $markerMatches) { Write-WzUtf8LinesAtomic -Path $marker -Lines $ml }
  Write-Ok "TASK $name -> $RepoRoot"
  Write-Ok "marker $marker"
}

# ---- main ----
Write-Host ""
Write-Host "  WZ_AiStarCube_win / AI STAR CUBE installer" -ForegroundColor White
Write-Host "  Repo: $RepoRoot" -ForegroundColor DarkGray

if (-not (Test-WindowsHost)) {
  Write-Bad 'Unsupported platform. WZ_AiStarCube_win is a pure Windows project.'
  exit 1
}

if (-not (Test-Path -LiteralPath $Src)) {
  throw "Missing live-workbench/ — re-clone https://github.com/larkinlai666-cmd/WZ_AiStarCube_win"
}

if ($ProjectsRoot) {
  $env:WZ_PROJECTS_ROOT = $ProjectsRoot.Trim().TrimEnd('\')
  # Persist user-level for future Init wizards (this user only)
  [Environment]::SetEnvironmentVariable("WZ_PROJECTS_ROOT", $env:WZ_PROJECTS_ROOT, "User")
  Write-Ok "Set user env WZ_PROJECTS_ROOT=$($env:WZ_PROJECTS_ROOT)"
}

if ($DoctorOnly) {
  $code = Invoke-Doctor
  exit $code
}

if (-not $NoBackup) { Backup-Existing }
Install-Workbench
Bind-ThisRepo
$fail = Invoke-Doctor

Write-Step "Next steps" "Cyan"
Write-Host @"
  1. Restart WezTerm (or press Ctrl+Shift+R to reload config).
  2. You should land on the Init panel (task table).
  3. Enter = pick task row → pick agent in 2 AGENT zone ·  c = create NEW project (path freezes).
  4. F1 cheatsheet · F3 new-project wizard · F6 AI desk · F7 Explorer · F8 repair pod · F4 close pane.
  5. F5 (or Ctrl+Shift+R) reloads config. If Init is dead: F8, or workbench\wz.cmd repair.
  6. Optional: open this repo with correct cwd:
       powershell -ExecutionPolicy Bypass -File .\open-project.ps1

  Docs: README.md · docs/PORTABILITY.md · live-workbench/INSTALL.md
"@ -ForegroundColor Gray

if ($fail -gt 0) {
  Write-Host ""
  Write-Host "Install finished with $fail doctor warning(s). Press F8 in WezTerm for the repair pod, or:" -ForegroundColor DarkCyan
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1 -DoctorOnly" -ForegroundColor Cyan
  Write-Host "  powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\.config\wezterm\workbench\wz.ps1 -Command doctor" -ForegroundColor Cyan
  exit 1
}

Write-Host ""
Write-Host "Install complete — workflow shell matches upstream snapshot." -ForegroundColor Green
exit 0
