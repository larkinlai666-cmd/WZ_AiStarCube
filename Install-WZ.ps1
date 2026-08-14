#Requires -Version 5.1
<#
.SYNOPSIS
  One-shot installer: make this machine's WezTerm match WZ_AiStarCube workbench.

.DESCRIPTION
  Copies live-workbench/ → %USERPROFILE%\.config\wezterm\
  Creates empty desk-roots (or binds this repo), runs doctor checks.

  After success, other users get the SAME workflow shell as the author
  (keys, Init panel, gates, F6–F9). Their project list starts empty or
  with this repo only — personal projects are created via Init `c`.

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
$RepoRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$Src = Join-Path $RepoRoot "live-workbench"
$Dst = Join-Path $env:USERPROFILE ".config\wezterm"
$WbDst = Join-Path $Dst "workbench"

function Write-Step([string]$Msg, [string]$Color = "Cyan") {
  Write-Host ""
  Write-Host "==> $Msg" -ForegroundColor $Color
}

function Write-Ok([string]$Msg) { Write-Host "  OK  $Msg" -ForegroundColor Green }
function Write-Warn([string]$Msg) { Write-Host "  !!  $Msg" -ForegroundColor Yellow }
function Write-Bad([string]$Msg) { Write-Host "  XX  $Msg" -ForegroundColor Red }

function Test-CommandExists([string]$Name) {
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

# Agents are peers (grok / kimi / codex) — none is a hard prerequisite.
# Resolve order per agent: PATH first, then well-known install locations.
# Note: LOCALAPPDATA / ProgramFiles can be EMPTY in stripped environments
# (spawned shells, CI) — Join-Path $null crashes the whole Doctor.
function Resolve-AgentExe([string]$Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source)) { return $cmd.Source }
  $candidates = @()
  $la = $env:LOCALAPPDATA
  switch ($Name) {
    'grok' {
      $candidates += (Join-Path $env:USERPROFILE ".grok\bin\grok.exe")
      if ($la) { $candidates += (Join-Path $la "Programs\grok\grok.exe") }
    }
    'kimi' {
      $candidates += (Join-Path $env:USERPROFILE ".kimi-code\bin\kimi.exe")
      $candidates += (Join-Path $env:USERPROFILE ".kimi-code\bin\kimi.cmd")
    }
    'codex' {
      # WinGet shim links (codex is typically a .cmd shim here)
      if ($la) {
        $candidates += (Join-Path $la "Microsoft\WinGet\Links\codex.exe")
        $candidates += (Join-Path $la "Microsoft\WinGet\Links\codex.cmd")
      }
    }
  }
  foreach ($c in $candidates) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  return $null
}

function Resolve-WezExe {
  $candidates = @()
  if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles "WezTerm\wezterm.exe") }
  $pf86 = ${env:ProgramFiles(x86)}
  if ($pf86) { $candidates += (Join-Path $pf86 "WezTerm\wezterm.exe") }
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

  if ($env:OS -and $env:OS -notmatch "Windows") {
    Write-Bad "This workbench snapshot targets Windows + PowerShell + WezTerm."
    $fail++
  } else {
    # empty $env:OS = stripped spawn env, not a non-Windows host
    Write-Ok "Windows host"
  }

  $wez = Resolve-WezExe
  if ($wez) { Write-Ok "WezTerm: $wez" } else {
    Write-Bad "WezTerm not found. Install: https://wezfurlong.org/wezterm/"
    $fail++
  }

  # Agents are peers: at least ONE of grok/kimi/codex must be usable.
  # A missing grok only warns — kimi/codex-only setups are fully supported.
  $foundAgents = @()
  foreach ($a in @('grok', 'kimi', 'codex')) {
    $exe = Resolve-AgentExe $a
    if ($exe) {
      Write-Ok "$a CLI: $exe"
      $foundAgents += $a
    } elseif ($a -eq 'grok') {
      Write-Warn "grok CLI not found — fine if you only use kimi/codex (可只用 kimi/codex)"
    } else {
      Write-Warn "$a CLI not found"
    }
  }
  if ($foundAgents.Count -eq 0) {
    Write-Bad "No agent CLI found (grok / kimi / codex). Install at least one."
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
    # NOTE: "GrokProjects"/"GrokProject" is a HISTORICAL name kept for backward
    # compatibility with existing installs — the default root is agent-neutral
    # in practice. Do not rename the path itself (would orphan existing roots).
    Write-Warn "No WZ_PROJECTS_ROOT — new projects default to Documents\GrokProjects or existing *:\GrokProject"
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
    (Join-Path $Src "workbench\keys.lua"),
    (Join-Path $Src "workbench\status.lua"),
    (Join-Path $Src "workbench\projects.lua")
  )
  foreach ($m in $must) {
    if (-not (Test-Path -LiteralPath $m)) { throw "Incomplete snapshot: missing $m" }
  }

  Write-Step "Install workbench → $Dst"
  New-Item -ItemType Directory -Force -Path $WbDst | Out-Null
  Copy-Item (Join-Path $Src "wezterm.lua") (Join-Path $Dst "wezterm.lua") -Force
  if (Test-Path (Join-Path $Src "README.md")) {
    Copy-Item (Join-Path $Src "README.md") (Join-Path $Dst "README.md") -Force
  }
  Get-ChildItem (Join-Path $Src "workbench") -File | ForEach-Object {
    # Never overwrite personal bindings with examples
    if ($_.Name -match '^(desk-roots|favorites)') { return }
    if ($_.Name -match '\.example\.') { return }
    Copy-Item $_.FullName (Join-Path $WbDst $_.Name) -Force
  }
  Write-Ok "Copied wezterm.lua + workbench modules"

  $roots = Join-Path $WbDst "desk-roots.tsv"
  if (-not (Test-Path -LiteralPath $roots)) {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $lines = @(
      "# AI STAR CUBE desk roots - project_name<TAB>absolute_path",
      "# Created by Install-WZ.ps1 — add projects via Init panel key  c  or open-project.ps1",
      "# Weak paths (home/Desktop/Documents root/Downloads) are NOT valid project roots"
    )
    [System.IO.File]::WriteAllLines($roots, $lines, $utf8)
    Write-Ok "Created empty desk-roots.tsv"
  } else {
    Write-Ok "Kept existing desk-roots.tsv (personal bindings preserved)"
  }

  $fav = Join-Path $WbDst "favorites.txt"
  if (-not (Test-Path -LiteralPath $fav)) {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($fav, @("# favorites — one absolute path per line"), $utf8)
    Write-Ok "Created empty favorites.txt"
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
    Write-Warn "Repo folder name '$name' is reserved — binding as WZ_AiStarCube"
    $name = "WZ_AiStarCube"
  }
  # Unified semantics with open-project.ps1: the row we BIND gets an explicit
  # 3rd agent column (first available of grok/kimi/codex). Rows we did not
  # touch keep whatever they had (legacy 2-column rows stay 2-column).
  $bindAgent = ""
  foreach ($a in @('grok', 'kimi', 'codex')) {
    if (Resolve-AgentExe $a) { $bindAgent = $a; break }
  }
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
    "# Bound by Install-WZ.ps1 — optional 3rd column agent: grok / kimi / codex (peers)"
  )
  foreach ($k in ($map.Keys | Sort-Object)) {
    if ($agentMap.Contains($k)) {
      $out += ($k + "`t" + $map[$k] + "`t" + $agentMap[$k])
    } else {
      $out += ($k + "`t" + $map[$k])
    }
  }
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllLines($roots, $out, $utf8)

  $marker = Join-Path $RepoRoot ".wz-project"
  $ml = @(
    "# WZ project identity — frozen at install/bind",
    "name=$name",
    "path=$RepoRoot",
    ("created={0:yyyy-MM-ddTHH:mm:ssK}" -f (Get-Date))
  )
  [System.IO.File]::WriteAllLines($marker, $ml, $utf8)
  Write-Ok "TASK $name -> $RepoRoot"
  Write-Ok "marker $marker"
}

# ---- main ----
Write-Host ""
Write-Host "  WZ_AiStarCube / AI STAR CUBE installer" -ForegroundColor White
Write-Host "  Repo: $RepoRoot" -ForegroundColor DarkGray

if (-not (Test-Path -LiteralPath $Src)) {
  throw "Missing live-workbench/ — re-clone https://github.com/larkinlai666-cmd/WZ_AiStarCube"
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

Write-Step "Next steps" "Yellow"
Write-Host @"
  1. Restart WezTerm (or press Ctrl+Shift+R to reload config).
  2. You should land on the Init panel (task table).
  3. Enter = pick task row → pick agent in 2 AGENT zone ·  c = create NEW project (path freezes).
  4. F1 cheatsheet · F3 new-project wizard · F6 AI desk · F7 Explorer · F4 close pane.
  5. F5 (or Ctrl+Shift+R) reloads config; no Leader layer (IME-safe, F2 left to agents).
  6. Optional: open this repo with correct cwd:
       powershell -ExecutionPolicy Bypass -File .\open-project.ps1

  Docs: README.md · docs/PORTABILITY.md · live-workbench/INSTALL.md
"@ -ForegroundColor Gray

if ($fail -gt 0) {
  Write-Host ""
  Write-Host "Install finished with $fail doctor warning(s). Fix prerequisites, then re-run:" -ForegroundColor Yellow
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1 -DoctorOnly" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "Install complete — workflow shell matches upstream snapshot." -ForegroundColor Green
exit 0
