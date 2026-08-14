# Extract sidebar hyperlink emission and verify OSC-8 well-formedness
# + D-014 launcher-extension guard (.cmd/.exe never hyperlinked).
$ErrorActionPreference = 'Stop'
$src = Get-Content -Raw 'C:\Users\Administrator\.config\wezterm\workbench\sidebar.ps1'

function Get-Func([string]$Name) {
  $m = [regex]::Match($src, "(?ms)^function $Name .*?^\}")
  if (-not $m.Success) { throw "func $Name not found" }
  return $m.Value
}
$body = @(
  Get-Func 'ConvertTo-FileUri'
  Get-Func 'Get-AnsiColorCode'
  Get-Func 'Write-Hyperlink'
  Get-Func 'Write-ClickablePath'
) -join "`n`n"
Invoke-Expression $body

$esc = [char]27
$fail = 0

function Capture-Clickable([string]$Path, [string]$Label) {
  $sw = New-Object System.IO.StringWriter
  $old = [Console]::Out
  [Console]::SetOut($sw)
  try { Write-ClickablePath -PathValue $Path -Label $Label -Color Gray }
  finally { [Console]::SetOut($old) }
  return $sw.ToString()
}

# case 1: normal file -> well-formed OSC-8
$raw = Capture-Clickable 'C:\Users\Administrator\proj\file one.txt' 'file one.txt'
$vis = $raw.Replace("$esc", '<ESC>')
Write-Host "normal RAW: $vis"
if ($raw -match '\x1b\]8;;file:///C:/.+\x1b\\' -and $raw -match '\x1b\]8;;\x1b\\\x1b\[0m') {
  Write-Host 'normal: PASS'
} else { Write-Host 'normal: FAIL'; $fail++ }

# case 2: launcher ext -> NO OSC-8 at all (plain text)
foreach ($p in @('C:\a\tool.cmd', 'C:\a\app.exe', 'C:\a\setup.msi', 'C:\a\run.bat')) {
  $r = Capture-Clickable $p (Split-Path $p -Leaf)
  if ($r -match '\x1b\]8;;') { Write-Host "guard FAIL (linked): $p"; $fail++ }
  else { Write-Host "guard PASS (plain): $p" }
}

# case 3: directory (no ext) stays clickable
$raw3 = Capture-Clickable 'C:\Users\Administrator\proj' 'proj/'
if ($raw3 -match '\x1b\]8;;file:///') { Write-Host 'dir: PASS' } else { Write-Host 'dir: FAIL'; $fail++ }

if ($fail -eq 0) { Write-Host 'ALL PASS' } else { Write-Host "FAILURES: $fail"; exit 1 }
