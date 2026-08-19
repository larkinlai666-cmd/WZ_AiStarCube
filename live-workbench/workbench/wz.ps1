#Requires -Version 5.1
# Product CLI: wz doctor | wz report | wz repair
# Does not start Init. ASCII only.

[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('doctor', 'report', 'repair')]
  [string]$Command = 'repair'
)

$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot
$installRoot = Split-Path -Parent $here
$repairRoot = Join-Path $installRoot 'repair'
$pod = Join-Path $here 'escape-pod.ps1'

function Ensure-WzRepairDesk {
  try {
    if (-not (Test-Path -LiteralPath $repairRoot -PathType Container)) {
      New-Item -ItemType Directory -Force -Path $repairRoot | Out-Null
    }
    $installTxt = Join-Path $repairRoot 'INSTALL.txt'
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($installTxt, @(
      ('INSTALL=' + $installRoot),
      'This folder is the WZ repair desk. Do not use it for daily project work.'
    ), $utf8)
    return $true
  } catch {
    Write-Host ('  repair desk unavailable: ' + $_.Exception.Message) -ForegroundColor DarkYellow
    return $false
  }
}

function Get-WzDoctorLines {
  $rows = New-Object System.Collections.Generic.List[string]
  $fail = 0
  [void]$rows.Add('install: ' + $installRoot)
  $checks = @(
    @{ Ok = (Test-Path -LiteralPath (Join-Path $installRoot 'wezterm.lua') -PathType Leaf); Msg = 'wezterm.lua' },
    @{ Ok = (Test-Path -LiteralPath (Join-Path $here 'escape-pod.ps1') -PathType Leaf); Msg = 'escape-pod.ps1' },
    @{ Ok = (Test-Path -LiteralPath (Join-Path $here 'agent-discovery.ps1') -PathType Leaf); Msg = 'agent-discovery.ps1' },
    @{ Ok = (Test-Path -LiteralPath $repairRoot -PathType Container); Msg = 'repair desk' }
  )
  foreach ($c in $checks) {
    if ($c.Ok) { [void]$rows.Add('OK  ' + $c.Msg) } else { [void]$rows.Add('BAD ' + $c.Msg); $fail++ }
  }
  $wezOk = $false
  if ($env:ProgramFiles) {
    $c = Join-Path $env:ProgramFiles 'WezTerm\wezterm.exe'
    if (Test-Path -LiteralPath $c -PathType Leaf) { $wezOk = $true; [void]$rows.Add('OK  WezTerm: ' + $c) }
  }
  if (-not $wezOk) { [void]$rows.Add('BAD WezTerm not found'); $fail++ }
  $disc = Join-Path $here 'agent-discovery.ps1'
  $names = @()
  if (Test-Path -LiteralPath $disc -PathType Leaf) {
    try {
      $agents = @(& $disc -WorkbenchDir $here | Where-Object { $_.Id -and $_.Exe })
      $names = @($agents | ForEach-Object { [string]$_.Label })
    } catch {
      [void]$rows.Add('BAD discovery: ' + $_.Exception.Message)
      $fail++
    }
  }
  if ($names.Count -gt 0) { [void]$rows.Add('OK  agents: ' + ($names -join ', ')) }
  else { [void]$rows.Add('!!  no Agent detected') }
  return @{ Lines = $rows.ToArray(); Fail = $fail }
}

Ensure-WzRepairDesk

if ($Command -eq 'doctor') {
  $d = Get-WzDoctorLines
  Write-Host ''
  Write-Host '  WZ doctor' -ForegroundColor Cyan
  foreach ($l in $d.Lines) {
    if ($l.StartsWith('OK')) { Write-Host ('  ' + $l) -ForegroundColor Green }
    elseif ($l.StartsWith('BAD')) { Write-Host ('  ' + $l) -ForegroundColor Red }
    else { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
  }
  Write-Host ''
  if ($d.Fail -gt 0) { exit 1 }
  exit 0
}

if ($Command -eq 'report') {
  $d = Get-WzDoctorLines
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $outFile = Join-Path $repairRoot ('INCIDENT-' + $stamp + '.md')
  $buf = New-Object System.Collections.Generic.List[string]
  [void]$buf.Add('# WZ incident ' + $stamp)
  [void]$buf.Add('')
  [void]$buf.Add('INSTALL=' + $installRoot)
  [void]$buf.Add('')
  [void]$buf.Add('## doctor')
  [void]$buf.Add('```')
  foreach ($l in $d.Lines) { [void]$buf.Add($l) }
  [void]$buf.Add('```')
  $log = Join-Path $here 'discovery-debug.log'
  if (Test-Path -LiteralPath $log -PathType Leaf) {
    [void]$buf.Add('')
    [void]$buf.Add('## discovery-debug.log (tail)')
    [void]$buf.Add('```')
    foreach ($l in @(Get-Content -LiteralPath $log -Tail 40 -ErrorAction SilentlyContinue)) { [void]$buf.Add([string]$l) }
    [void]$buf.Add('```')
  }
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllLines($outFile, $buf.ToArray(), $utf8)
  Write-Host ('  wrote ' + $outFile) -ForegroundColor Green
  exit 0
}

if (-not (Test-Path -LiteralPath $pod -PathType Leaf)) {
  Write-Host '  escape-pod.ps1 missing' -ForegroundColor Red
  exit 1
}
& $pod
exit $LASTEXITCODE
