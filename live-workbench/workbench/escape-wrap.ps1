#Requires -Version 5.1
# ASCII-only on purpose. This file is the last door when Init explodes.
# Do not add CJK. Do not call agent-discovery.ps1. Do not splat.

$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot
$boot = Join-Path $here 'bootstrap.ps1'

function Get-WzEscapeCwd {
  $repair = Join-Path (Split-Path -Parent $here) 'repair'
  if (Test-Path -LiteralPath $repair -PathType Container) { return $repair }
  if (Test-Path -LiteralPath $here -PathType Container) { return $here }
  if ($env:USERPROFILE -and (Test-Path -LiteralPath $env:USERPROFILE)) { return $env:USERPROFILE }
  return (Get-Location).Path
}

function Show-WzEscapeBanner {
  param([string]$Reason)
  $cwd = Get-WzEscapeCwd
  Write-Host ''
  Write-Host '  WZ ESCAPE SHELL' -ForegroundColor Cyan
  if ($Reason) { Write-Host ('  ' + $Reason) -ForegroundColor Red }
  Write-Host '  Init did not stay up. This tab is a plain PowerShell.' -ForegroundColor DarkGray
  Write-Host ('  cwd hint: ' + $cwd) -ForegroundColor DarkGray
  Write-Host '  Press F8 for the repair pod (install\repair). wz doctor / wz report also work.' -ForegroundColor Yellow
  Write-Host ''
}

if (-not (Test-Path -LiteralPath $boot -PathType Leaf)) {
  Show-WzEscapeBanner -Reason 'bootstrap.ps1 missing'
} else {
  try {
    & $boot
  } catch {
    Show-WzEscapeBanner -Reason ('INIT CRASH: ' + $_.Exception.Message)
  }
}
