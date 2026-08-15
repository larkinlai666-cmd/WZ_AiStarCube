# Optional: add to your PowerShell profile for AI STAR CUBE shell panes
#   notepad $PROFILE
#   then:  . "$env:USERPROFILE\.config\wezterm\workbench\profile-snippet.ps1"

# Quick jumps
function wb {
  <#
    .SYNOPSIS  Open AI workbench helpers from any shell pane
  #>
  param(
    [Parameter(Position = 0)]
    [ValidateSet('doctor', 'home', 'config', 'help')]
    [string]$Cmd = 'help'
  )
  switch ($Cmd) {
    'doctor' {
      $wbDir = Join-Path $env:USERPROFILE '.config\wezterm\workbench'
      $discovery = Join-Path $wbDir 'agent-discovery.ps1'
      $agents = if (Test-Path -LiteralPath $discovery) { @(& $discovery -WorkbenchDir $wbDir) } else { @() }
      if ($agents.Count -eq 0) { Write-Host 'no self-described or locally registered Agent CLI found' -ForegroundColor DarkCyan }
      else { $agents | Format-Table Id, Label, Exe, Source -AutoSize }
    }
    'home'   { Set-Location $env:USERPROFILE }
    'config' { Set-Location (Join-Path $env:USERPROFILE '.config\wezterm') }
    default {
      Write-Host @"
AI STAR CUBE shell helpers
  wb doctor   List every dynamically discovered Agent CLI
  wb config   Jump to WezTerm config dir
  wb home     Jump to home

WezTerm (window-local keys only when focused)
  F1 help · F3 new project · F4 close pane · F5 reload · F6 desk · F7 explorer
  No Leader layer; F2 and Ctrl+; are left for the AI agent
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
