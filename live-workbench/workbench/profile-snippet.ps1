# Optional: add to your PowerShell profile for AI STAR CUBE shell panes
#   notepad $PROFILE
#   then:  . "$env:USERPROFILE\.config\wezterm\workbench\profile-snippet.ps1"

# Ensure agent CLIs are on PATH (grok + kimi; codex is usually a WinGet shim already on PATH)
$grokBin = Join-Path $env:USERPROFILE ".grok\bin"
$kimiBin = Join-Path $env:USERPROFILE ".kimi-code\bin"
foreach ($agentBin in @($grokBin, $kimiBin)) {
  if (Test-Path $agentBin) {
    if (-not ($env:Path -split ';' | Where-Object { $_ -ieq $agentBin })) {
      $env:Path = "$agentBin;$env:Path"
    }
  }
}

# Agent completions (if present)
foreach ($agentComp in @(
    (Join-Path $env:USERPROFILE ".grok\completions\powershell\grok.ps1"),
    (Join-Path $env:USERPROFILE ".kimi-code\completions\powershell\kimi.ps1")
  )) {
  if (Test-Path $agentComp) {
    . $agentComp
  }
}

# Quick jumps
function wb {
  <#
    .SYNOPSIS  Open AI workbench helpers from any shell pane
  #>
  param(
    [Parameter(Position = 0)]
    [ValidateSet('grok', 'kimi', 'codex', 'doctor', 'home', 'config', 'help')]
    [string]$Cmd = 'help'
  )
  switch ($Cmd) {
    'grok'   { & (Join-Path $grokBin 'grok.exe') }
    'kimi'   { & (Join-Path $kimiBin 'kimi.exe') }
    'codex'  { codex }
    'doctor' {
      # Per-agent health check: run whatever each installed CLI offers
      $checked = $false
      $grokExe = Join-Path $grokBin 'grok.exe'
      if (Test-Path $grokExe) { Write-Host '== grok ==' -ForegroundColor Cyan; & $grokExe doctor; $checked = $true }
      $kimiExe = Join-Path $kimiBin 'kimi.exe'
      if (Test-Path $kimiExe) { Write-Host '== kimi ==' -ForegroundColor Cyan; & $kimiExe --version; $checked = $true }
      if (Get-Command codex -ErrorAction SilentlyContinue) { Write-Host '== codex ==' -ForegroundColor Cyan; codex --version; $checked = $true }
      if (-not $checked) { Write-Host 'no agent CLI found (grok/kimi/codex/deepseek)' -ForegroundColor DarkCyan }
    }
    'home'   { Set-Location $env:USERPROFILE }
    'config' { Set-Location (Join-Path $env:USERPROFILE '.config\wezterm') }
    default {
      Write-Host @"
AI STAR CUBE shell helpers
  wb grok     Start Grok
  wb kimi     Start Kimi
  wb codex    Start Codex
  wb doctor   Health check for each installed agent
  wb config   Jump to WezTerm config dir
  wb home     Jump to home

WezTerm (window-local keys only when focused)
  F7 explorer · F9 projects · F4 close pane · F6 desk · F8 help
  Leader = Alt+z then lowercase (e/x/a/p/…); Ctrl+; left for the AI agent
  Pane focus: mouse click
"@ -ForegroundColor Cyan
    }
  }
}

# Friendlier prompt marker so you know you're in a workbench shell
function prompt {
  $cwd = (Get-Location).Path
  $home = $env:USERPROFILE
  if ($cwd.StartsWith($home, [StringComparison]::OrdinalIgnoreCase)) {
    $cwd = '~' + $cwd.Substring($home.Length)
  }
  Write-Host "AI" -NoNewline -ForegroundColor Magenta
  Write-Host " $cwd" -NoNewline -ForegroundColor Blue
  return "> "
}
