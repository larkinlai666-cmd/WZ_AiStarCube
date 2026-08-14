#requires -Version 5.1
<#
.SYNOPSIS
  Static guard: WezTerm workbench must not call run_child_process at config load.

.DESCRIPTION
  Catastrophic failure (2026-08-09):
    launch.lua resolve_grok_exe() called wezterm.run_child_process({"where.exe","grok"})
    at require()-time → "attempt to yield across a C-call boundary"
    → WezTerm discards the entire user config → stock UI.

  Exit 0 = OK, 1 = FAIL, 2 = path missing
#>
param(
  [string]$WorkbenchRoot = ""
)

$ErrorActionPreference = "Stop"

if (-not $WorkbenchRoot -or $WorkbenchRoot -eq "") {
  $cand = @(
    (Join-Path $env:USERPROFILE ".config\wezterm"),
    (Join-Path $PSScriptRoot "..\live-workbench")
  )
  foreach ($c in $cand) {
    if (Test-Path (Join-Path $c "workbench\launch.lua")) {
      $WorkbenchRoot = (Resolve-Path $c).Path
      break
    }
  }
}

if (-not $WorkbenchRoot -or -not (Test-Path $WorkbenchRoot)) {
  Write-Host "FAIL: workbench root not found" -ForegroundColor Red
  exit 2
}

$wb = Join-Path $WorkbenchRoot "workbench"
$fail = New-Object System.Collections.Generic.List[string]
$warn = New-Object System.Collections.Generic.List[string]

function Test-LoadScopeSpawn {
  param([string]$FilePath)
  $hits = New-Object System.Collections.Generic.List[string]
  $lines = Get-Content -LiteralPath $FilePath -Encoding UTF8
  # Stack frames: "fn" = function body, "ctl" = if/for/while/repeat
  $stack = New-Object System.Collections.Generic.List[string]
  $fnDepth = 0

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $raw = $lines[$i]
    $trim = $raw.Trim()
    $lineNo = $i + 1
    if ($trim -match '^--') { continue }
    if ($trim -eq '') { continue }

    # Opens
    if ($trim -match '^(local\s+)?function\b' -or $trim -match '\bfunction\s*\(') {
      $stack.Add('fn')
      $fnDepth++
    }
    elseif ($trim -match '^\bif\b' -or $trim -match '^\bfor\b' -or $trim -match '^\bwhile\b' -or $trim -match '^\brepeat\b') {
      $stack.Add('ctl')
    }

    # Danger only when not inside any function (true module load / top-level)
    if ($fnDepth -eq 0 -and $trim -match 'run_child_process') {
      $hits.Add(('{0}:{1}: LOAD-SCOPE run_child_process -> {2}' -f $FilePath, $lineNo, $trim))
    }

    # Closes: one "end" pops one frame
    if ($trim -eq 'end' -or $trim -match '^end\s*\)' -or $trim -match '^end\s*,' -or $trim -match '^end\s*$') {
      if ($stack.Count -gt 0) {
        $top = $stack[$stack.Count - 1]
        $stack.RemoveAt($stack.Count - 1)
        if ($top -eq 'fn' -and $fnDepth -gt 0) { $fnDepth-- }
      }
    }
  }
  return $hits
}

# 1) launch.lua classic bomb
$launch = Join-Path $wb "launch.lua"
if (-not (Test-Path $launch)) {
  $fail.Add('missing workbench/launch.lua')
} else {
  $text = Get-Content -LiteralPath $launch -Raw -Encoding UTF8
  if ($text -match 'run_child_process\s*\(\s*\{\s*"where') {
    $fail.Add('launch.lua: run_child_process + where.exe double-quote pattern (config-load bomb)')
  }
  if ($text -match "run_child_process\s*\(\s*\{\s*'where") {
    $fail.Add('launch.lua: run_child_process + where.exe single-quote pattern (config-load bomb)')
  }
  # Generalized (D-004 agent registry): any resolve_<name>_exe → M.<name>_exe
  # path, not just grok. Backreference keeps function/field names paired.
  $chunk = [regex]::Match(
    $text,
    'function resolve_(\w+)_exe[\s\S]*?^M\.\1_exe\s*=',
    [System.Text.RegularExpressions.RegexOptions]::Multiline
  )
  if ($chunk.Success -and $chunk.Value -match 'run_child_process') {
    $fail.Add(('launch.lua: resolve_{0}_exe path to M.{0}_exe uses run_child_process' -f $chunk.Groups[1].Value))
  }
  foreach ($h in (Test-LoadScopeSpawn -FilePath $launch)) { $fail.Add([string]$h) }
  if ($text -notmatch 'MUST NOT call wezterm\.run_child_process') {
    $warn.Add('launch.lua missing MUST NOT run_child_process safety comment')
  }
}

# 2) Other modules: no top-level run_child_process
Get-ChildItem -LiteralPath $wb -Filter '*.lua' -File | ForEach-Object {
  if ($_.Name -eq 'launch.lua') { return }
  foreach ($h in (Test-LoadScopeSpawn -FilePath $_.FullName)) {
    $fail.Add([string]$h)
  }
}

# 3) wezterm.lua soft-fail + package.loaded
$rootLua = Join-Path $WorkbenchRoot 'wezterm.lua'
if (Test-Path $rootLua) {
  $rootText = Get-Content -LiteralPath $rootLua -Raw -Encoding UTF8
  if ($rootText -notmatch 'safe_require|pcall\s*\(\s*require') {
    $warn.Add('wezterm.lua does not soft-fail module require')
  }
  if ($rootText -notmatch 'package\.loaded') {
    $warn.Add('wezterm.lua does not clear package.loaded for workbench.* on reload')
  }
  foreach ($h in (Test-LoadScopeSpawn -FilePath $rootLua)) {
    $fail.Add([string]$h)
  }
} else {
  $fail.Add('missing wezterm.lua')
}

Write-Host "Workbench: $WorkbenchRoot"
Write-Host '--- runtime run_child_process sites (OK inside functions) ---'
Get-ChildItem -LiteralPath $wb -Filter '*.lua' -File | ForEach-Object {
  Select-String -LiteralPath $_.FullName -Pattern 'run_child_process' | ForEach-Object {
    $t = $_.Line.Trim()
    if ($t -match '^--') { return }
    Write-Host ('  {0}:{1}: {2}' -f $_.Filename, $_.LineNumber, $t)
  }
}

Write-Host ''
if ($warn.Count -gt 0) {
  Write-Host 'WARN:' -ForegroundColor DarkCyan
  $warn | ForEach-Object { Write-Host ('  - ' + $_) -ForegroundColor DarkCyan }
}
if ($fail.Count -gt 0) {
  Write-Host 'FAIL: config load safety violations' -ForegroundColor Red
  $fail | ForEach-Object { Write-Host ('  - ' + $_) -ForegroundColor Red }
  Write-Host ''
  Write-Host 'If these ship, WezTerm may show stock UI and drop AI STAR CUBE entirely.' -ForegroundColor Red
  exit 1
}

Write-Host 'OK: no load-time yield/subprocess hazards detected.' -ForegroundColor Green
exit 0
