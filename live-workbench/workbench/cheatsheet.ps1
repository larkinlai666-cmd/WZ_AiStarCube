# AI STAR CUBE cheatsheet pane (F8 / Leader+h)
# Keep this file ASCII-safe in structure; body text loads from cheatsheet.txt (UTF-8).

$ErrorActionPreference = "SilentlyContinue"

try {
  $Host.UI.RawUI.WindowTitle = "AI STAR CUBE cheatsheet"
} catch {}

# Mark pane for toggle (WezTerm user var; base64 of "1" is MQ==)
try {
  $esc = [char]27
  $bel = [char]7
  [Console]::Write(($esc + "]1337;SetUserVar=star_cube_help=MQ==" + $bel))
} catch {}

try {
  chcp 65001 | Out-Null
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$sheet = Join-Path $PSScriptRoot "cheatsheet.txt"

Clear-Host
if (Test-Path -LiteralPath $sheet) {
  Get-Content -LiteralPath $sheet -Encoding UTF8 | ForEach-Object { Write-Host $_ }
} else {
  Write-Host ("cheatsheet.txt missing: " + $sheet) -ForegroundColor Red
  Write-Host "Expected next to cheatsheet.ps1 under .config\wezterm\workbench\" -ForegroundColor DarkCyan
}

Write-Host ""
Write-Host "  [q] close panel   [F4] close pane   [F8] or Alt+z h toggle" -ForegroundColor DarkCyan
Write-Host ""

while ($true) {
  if ([Console]::KeyAvailable) {
    $key = [Console]::ReadKey($true)
    $ch = $key.KeyChar
    if ($key.Key -eq "Q" -or $ch -eq "q" -or $key.Key -eq "Escape") {
      exit 0
    }
  }
  Start-Sleep -Milliseconds 80
}
