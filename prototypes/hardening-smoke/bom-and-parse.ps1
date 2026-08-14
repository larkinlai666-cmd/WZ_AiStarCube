$ErrorActionPreference = 'Stop'
$wb = Join-Path $env:USERPROFILE '.config\wezterm\workbench'
$bom = [byte[]]@(0xEF, 0xBB, 0xBF)
$overall = 0
foreach ($name in @('bootstrap.ps1', 'sidebar.ps1')) {
  $p = Join-Path $wb $name
  $bytes = [System.IO.File]::ReadAllBytes($p)
  $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
  if (-not $hasBom) {
    [System.IO.File]::WriteAllBytes($p, $bom + $bytes)
    Write-Host "BOM reapplied: $name"
  } else {
    Write-Host "BOM already present: $name"
  }
}
foreach ($name in @('bootstrap.ps1', 'sidebar.ps1')) {
  $p = Join-Path $wb $name
  $errs = $null
  [void][System.Management.Automation.PSParser]::Tokenize(
    [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8), [ref]$errs)
  Write-Host "$name parse errors: $($errs.Count)"
  if ($errs.Count -gt 0) {
    $overall = 1
    foreach ($e in $errs | Select-Object -First 5) {
      Write-Host ("  " + $e.Message + " @line " + $e.Token.StartLine)
    }
  }
}
exit $overall
