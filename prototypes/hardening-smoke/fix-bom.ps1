$files = @(
  'G:\GrokProject\WZ_Skill\Install-WZ.ps1',
  'G:\GrokProject\WZ_Skill\open-project.ps1',
  'G:\GrokProject\WZ_Skill\live-workbench\workbench\profile-snippet.ps1',
  'G:\GrokProject\WZ_Skill\live-workbench\workbench\cheatsheet.ps1',
  'C:\Users\Administrator\.config\wezterm\workbench\profile-snippet.ps1',
  'C:\Users\Administrator\.config\wezterm\workbench\cheatsheet.ps1'
)
foreach ($f in $files) {
  if (-not (Test-Path $f)) { Write-Host "MISS $f"; continue }
  $b = [System.IO.File]::ReadAllBytes($f)
  $hasBom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
  if ($hasBom) { Write-Host "BOM ok: $f" }
  else {
    $bom = [byte[]](0xEF, 0xBB, 0xBF)
    [System.IO.File]::WriteAllBytes($f, $bom + $b)
    Write-Host "BOM added: $f"
  }
}
