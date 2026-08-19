# Init end-to-end behavioral assertions (2026-08-19 splat incident lesson).
# Unit tests exercise agent-discovery.ps1 directly and BYPASS bootstrap's call
# convention — which is exactly where the 08-19 regression lived. This suite
# asserts what the USER sees: the rendered 2 AGENT zone must list exactly the
# agents discovery reports, before and after an `r` refresh.
# Usage: powershell -NoProfile -File test-init-e2e.ps1
$ErrorActionPreference = 'Stop'
$wb = 'C:\Users\Administrator\.config\wezterm\workbench'
$bootstrap = Join-Path $wb 'bootstrap.ps1'
$discovery = Join-Path $wb 'agent-discovery.ps1'
$fail = 0

function Assert([bool]$Cond, [string]$Name) {
  if ($Cond) { Write-Host "PASS: $Name" }
  else { Write-Host "FAIL: $Name"; $script:fail++ }
}

# expected agent count straight from the inventory source
$expected = @(& $discovery -WorkbenchDir $wb | Where-Object { $_.Id -and $_.Exe })

function Invoke-InitOnce([string]$InputText, [string]$Tag) {
  # PS-to-PS stdin piping swallows the post-discovery repaint (harness
  # artifact, not product behavior); native-style file redirection is exact.
  $inFile = Join-Path $env:TEMP ("wz-init-e2e-in-{0}.txt" -f $Tag)
  $outFile = Join-Path $env:TEMP ("wz-init-e2e-{0}.txt" -f $Tag)
  [System.IO.File]::WriteAllText($inFile, $InputText, (New-Object System.Text.UTF8Encoding $false))
  $p = Start-Process -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
    -ArgumentList @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $bootstrap) `
    -RedirectStandardInput $inFile -RedirectStandardOutput $outFile -RedirectStandardError ($outFile + '.err') `
    -WindowStyle Hidden -Wait -PassThru
  $code = $p.ExitCode
  $lines = Get-Content -LiteralPath $outFile
  return @{ Code = $code; Lines = $lines }
}

function Get-AgentZoneRows($Lines) {
  # The screen renders several times (loading frames → final state); the
  # meaningful assertion targets the LAST rendering of the zone.
  $inZone = $false
  $rows = 0
  $sawEmpty = $false
  $bestRows = 0
  $bestEmpty = $false
  foreach ($ln in $Lines) {
    if ($ln -match '2 AGENT') {
      if ($inZone) { $bestRows = $rows; $bestEmpty = $sawEmpty }
      $inZone = $true; $rows = 0; $sawEmpty = $false
      continue
    }
    if (-not $inZone) { continue }
    if ($ln -match '^\s*\+-+\+\s*$') { continue }
    if ($ln -match '\|\s*\[\d+\]\s') { $rows++; continue }
    if ($ln -match 'no self-described or locally registered|no Agent detected') { $sawEmpty = $true; continue }
    # zone content ended: a non-row, non-border line after rows appeared
    if ($rows -gt 0 -or $sawEmpty) { $bestRows = $rows; $bestEmpty = $sawEmpty; $inZone = $false }
  }
  if ($inZone) { $bestRows = $rows; $bestEmpty = $sawEmpty }
  return @{ Rows = $bestRows; SawEmpty = $bestEmpty }
}

# --- cold start ---
$r1 = Invoke-InitOnce "q`n" 'cold'
Assert ($r1.Code -eq 0) 'cold start exits 0'
Assert (($r1.Lines -match '1 LIST').Count -gt 0) 'zone 1 LIST renders'
Assert (($r1.Lines -match '2 AGENT').Count -gt 0) 'zone 2 AGENT renders'
Assert (($r1.Lines -match '3 COMMAND').Count -gt 0) 'zone 3 COMMAND renders'
$z1 = Get-AgentZoneRows $r1.Lines
if ($expected.Count -gt 0) {
  Assert ($z1.Rows -eq $expected.Count) "AGENT zone row count ($($z1.Rows)) == discovery count ($($expected.Count))"
  Assert (-not $z1.SawEmpty) 'AGENT zone is not the empty-state placeholder'
} else {
  Assert $z1.SawEmpty 'zero-agent device renders the honest empty state'
}
Assert (($r1.Lines -match 'InvalidCast|ParameterBinding|Traceback|ParserError').Count -eq 0) 'no red error boilerplate in cold start'

# --- r refresh path (the 08-19 -Refresh branch) ---
$r2 = Invoke-InitOnce "r`nq`n" 'refresh'
Assert ($r2.Code -eq 0) 'refresh run exits 0'
$z2 = Get-AgentZoneRows $r2.Lines
if ($expected.Count -gt 0) {
  Assert ($z2.Rows -eq $expected.Count) "post-refresh AGENT rows ($($z2.Rows)) == discovery count ($($expected.Count))"
}

if ($fail -eq 0) { Write-Host 'ALL INIT E2E TESTS PASSED' } else { Write-Host "FAILURES: $fail"; exit 1 }
