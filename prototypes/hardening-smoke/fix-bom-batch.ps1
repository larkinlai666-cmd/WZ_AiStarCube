$ErrorActionPreference = 'Stop'
$wb = Join-Path $env:USERPROFILE '.config\wezterm\workbench'
$bom = [byte[]]@(0xEF, 0xBB, 0xBF)
$targets = @(
  (Join-Path $wb 'cheatsheet.txt'),
  (Join-Path $wb 'profile-snippet.ps1'),
  'G:\GrokProject\WZ_Skill\Install-WZ.ps1',
  'G:\GrokProject\WZ_Skill\open-project.ps1'
)
foreach ($p in $targets) {
  $bytes = [System.IO.File]::ReadAllBytes($p)
  $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
  if (-not $hasBom) {
    [System.IO.File]::WriteAllBytes($p, $bom + $bytes)
    Write-Host "BOM added: $p"
  } else {
    Write-Host "BOM already present: $p"
  }
}
foreach ($p in @((Join-Path $wb 'profile-snippet.ps1'), 'G:\GrokProject\WZ_Skill\Install-WZ.ps1', 'G:\GrokProject\WZ_Skill\open-project.ps1')) {
  $errs = $null
  [void][System.Management.Automation.PSParser]::Tokenize(
    [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8), [ref]$errs)
  Write-Host "$([System.IO.Path]::GetFileName($p)) parse errors: $($errs.Count)"
  if ($errs.Count -gt 0) { exit 1 }
}
exit 0
