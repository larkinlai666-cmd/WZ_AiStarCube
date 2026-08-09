# Optional: add to your PowerShell profile for AI STAR CUBE shell panes
#   notepad $PROFILE
#   then:  . "$env:USERPROFILE\.config\wezterm\workbench\profile-snippet.ps1"

# Ensure Grok CLI is always on PATH
$grokBin = Join-Path $env:USERPROFILE ".grok\bin"
if (Test-Path $grokBin) {
  if (-not ($env:Path -split ';' | Where-Object { $_ -ieq $grokBin })) {
    $env:Path = "$grokBin;$env:Path"
  }
}

# Grok completions (if present)
$grokComp = Join-Path $env:USERPROFILE ".grok\completions\powershell\grok.ps1"
if (Test-Path $grokComp) {
  . $grokComp
}

# Quick jumps
function wb {
  <#
    .SYNOPSIS  Open AI workbench helpers from any shell pane
  #>
  param(
    [Parameter(Position = 0)]
    [ValidateSet('grok', 'codex', 'doctor', 'home', 'config', 'help')]
    [string]$Cmd = 'help'
  )
  switch ($Cmd) {
    'grok'   { & (Join-Path $grokBin 'grok.exe') }
    'codex'  { codex }
    'doctor' { & (Join-Path $grokBin 'grok.exe') doctor }
    'home'   { Set-Location $env:USERPROFILE }
    'config' { Set-Location (Join-Path $env:USERPROFILE '.config\wezterm') }
    default {
      Write-Host @"
AI STAR CUBE shell helpers
  wb grok     Start Grok
  wb codex    Start Codex
  wb doctor   grok doctor
  wb config   Jump to WezTerm config dir
  wb home     Jump to home

WezTerm (window-local keys only when focused)
  F7 explorer · F9 projects · F4 close pane · F6 desk · F8 help
  Leader = Alt+z then lowercase (e/x/a/p/…); Ctrl+; left for Grok
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
