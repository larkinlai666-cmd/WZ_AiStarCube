# Zero-agent cold-start simulation: strip PATH to bare system, point profile
# env vars at an empty fake home — Get-Command and every well-known fallback
# then miss, exactly like a brand-new device with no agent CLI installed.
# Usage: printf 'q\n' | powershell -NoProfile -File test-zero-agent.ps1
$fake = Join-Path $PSScriptRoot 'fakehome'
New-Item -ItemType Directory -Force -Path $fake | Out-Null
$env:PATH = 'C:\Windows\System32;C:\Windows\System32\WindowsPowerShell\v1.0'
$env:USERPROFILE = $fake
$env:APPDATA = Join-Path $fake 'AppData\Roaming'
$env:LOCALAPPDATA = Join-Path $fake 'AppData\Local'
# Simulate Install-WZ having bound one project on the fresh device
$wb = Join-Path $fake '.config\wezterm\workbench'
New-Item -ItemType Directory -Force -Path $wb | Out-Null
Set-Content -LiteralPath (Join-Path $wb 'desk-roots.tsv') -Value "WZ_Skill`tG:\GrokProject\WZ_Skill`tdeepseek" -Encoding UTF8
& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Administrator\.config\wezterm\workbench\bootstrap.ps1"
Write-Host ("WRAPPER-EXIT: {0}" -f $LASTEXITCODE)
