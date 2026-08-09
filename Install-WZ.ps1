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

function Resolve-GrokExe {
  $cmd = Get-Command grok -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source)) { return $cmd.Source }
  foreach ($c in @(
      (Join-Path $env:USERPROFILE ".grok\bin\grok.exe"),
      (Join-Path $env:LOCALAPPDATA "Programs\grok\grok.exe")
    )) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  return $null
}

function Resolve-WezExe {
  foreach ($c in @(
      (Join-Path $env:ProgramFiles "WezTerm\wezterm.exe"),
      (Get-Command wezterm -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    )) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  return $null
}

function Invoke-Doctor {
  Write-Step "Doctor (preflight)"
  $fail = 0

  if ($env:OS -notmatch "Windows") {
    Write-Bad "This workbench snapshot targets Windows + PowerShell + WezTerm."
    $fail++
  } else {
    Write-Ok "Windows host"
  }

  $wez = Resolve-WezExe
  if ($wez) { Write-Ok "WezTerm: $wez" } else {
    Write-Bad "WezTerm not found. Install: https://wezfurlong.org/wezterm/"
    $fail++
  }

  $grok = Resolve-GrokExe
  if ($grok) { Write-Ok "Grok CLI: $grok" } else {
    Write-Bad "Grok Build CLI not found (PATH or ~/.grok/bin/grok.exe)."
    Write-Warn "Workbench UI still installs; AI tabs need Grok to be useful."
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
  $roots = Join-Path $WbDst "desk-roots.tsv"
  $map = [ordered]@{}
  if (Test-Path -LiteralPath $roots) {
    foreach ($line in Get-Content -LiteralPath $roots -ErrorAction SilentlyContinue) {
      $t = $line.Trim()
      if ($t -eq "" -or $t.StartsWith("#")) { continue }
      $parts = $t -split "`t", 2
      if ($parts.Count -lt 2) { $parts = $t -split "\s+", 2 }
      if ($parts.Count -ge 2) { $map[$parts[0]] = $parts[1].TrimEnd('\') }
    }
  }
  $pk = $RepoRoot.TrimEnd('\').ToLowerInvariant()
  foreach ($k in @($map.Keys)) {
    if ($map[$k].TrimEnd('\').ToLowerInvariant() -eq $pk -and $k -ne $name) { $map.Remove($k) }
  }
  $map[$name] = $RepoRoot
  $out = @(
    "# AI STAR CUBE desk roots - project_name<TAB>absolute_path",
    "# Bound by Install-WZ.ps1"
  )
  foreach ($k in ($map.Keys | Sort-Object)) { $out += ($k + "`t" + $map[$k]) }
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
  3. Enter = open/resume bound project ·  c = create NEW project (path freezes).
  4. F9 switch project · F6 AI desk · F7 Explorer · F8 cheatsheet.
  5. Leader is Alt+z then a letter (NOT Alt+; — IME-safe).
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
