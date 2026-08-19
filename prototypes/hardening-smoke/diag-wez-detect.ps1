Write-Host "PF=[$env:ProgramFiles]"
Write-Host "PF86=[${env:ProgramFiles(x86)}]"
$p = Join-Path $env:ProgramFiles 'WezTerm\wezterm.exe'
Write-Host "candidate: $p"
Write-Host ("exists: " + (Test-Path -LiteralPath $p))
$cmd = Get-Command wezterm -ErrorAction SilentlyContinue
if ($cmd) { Write-Host "PATH hit: $($cmd.Source)" } else { Write-Host "PATH hit: none" }
