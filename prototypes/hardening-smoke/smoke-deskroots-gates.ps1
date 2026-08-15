# H-2/H-3/L-2/L-3 smoke: extract the REAL gate functions from the live
# sidebar.ps1 and exercise Write-DeskRootToFile against a temp RootsFile.
# Run under PS 5.1. Exit 0 = all pass.
param([string]$SidebarPath = (Join-Path $env:USERPROFILE '.config\wezterm\workbench\sidebar.ps1'))

$ErrorActionPreference = 'Stop'

$fails = New-Object System.Collections.Generic.List[string]
function Check([bool]$Cond, [string]$Name) {
  if ($Cond) { Write-Host ("PASS  " + $Name) -ForegroundColor Green }
  else { $script:fails.Add($Name); Write-Host ("FAIL  " + $Name) -ForegroundColor Red }
}

# --- extract top-level blocks (function X { ... } closing at column 0) ----
$lines = [System.IO.File]::ReadAllLines($SidebarPath, [System.Text.Encoding]::UTF8)
function Get-Block([string]$HeadPattern) {
  $start = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $HeadPattern) { $start = $i; break }
  }
  if ($start -lt 0) { throw "block not found: $HeadPattern" }
  $buf = @($lines[$start])
  for ($j = $start + 1; $j -lt $lines.Count; $j++) {
    $buf += $lines[$j]
    if ($lines[$j] -match '^\}\s*$' -or $lines[$j] -match '^\)\s*$') { break }
  }
  return ($buf -join "`r`n")
}

$harness = @(
  (Get-Block '^\$script:ReservedNames\s*=\s*@\('),
  (Get-Block '^function Normalize-PathKey'),
  (Get-Block '^function Test-ReservedName'),
  (Get-Block '^function Test-WeakPath'),
  (Get-Block '^function Commit-WzAtomicFile'),
  (Get-Block '^function Write-WzUtf8LinesAtomic'),
  (Get-Block '^function Write-DeskRootToFile')
) -join "`r`n`r`n"

$scratch = Join-Path $env:TEMP ('wzgates_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$harnessFile = Join-Path $scratch 'harness.ps1'
[System.IO.File]::WriteAllText($harnessFile, $harness, (New-Object System.Text.UTF8Encoding $true))
. $harnessFile
$script:RootsFile = Join-Path $scratch 'desk-roots.tsv'
$script:TestAgents = @()
function Get-DetectedAgents { return @($script:TestAgents) }

$strongA = 'G:\GrokProject\WZ_Skill'
$strongB = 'G:\GrokProject\WZ_Skill\docs'
$strongC = 'G:\GrokProject\WZ_Skill\scripts'

# --- H-2: gates -----------------------------------------------------------
$r = Write-DeskRootToFile -Ws 'home' -PathValue $strongA
Check ($r -eq $false -and -not (Test-Path -LiteralPath $script:RootsFile)) 'H2: reserved name refused'
$r = Write-DeskRootToFile -Ws 't1' -PathValue $env:USERPROFILE
Check ($r -eq $false -and -not (Test-Path -LiteralPath $script:RootsFile)) 'H2: weak path (home) refused'
$r = Write-DeskRootToFile -Ws 't1' -PathValue (Join-Path $env:USERPROFILE '.codex\sessions')
Check ($r -eq $false) 'L2: agent sessions dir is weak'
Check (Test-WeakPath -Cwd (Join-Path $env:USERPROFILE 'AppData')) 'L2: AppData itself is weak (desk.lua prefix parity)'
Check (-not (Test-WeakPath -Cwd $strongA)) 'L2: real project path is strong'
Check (Test-WeakPath -Cwd '\\C:\bad') 'L2: malformed leading-backslash drive is weak'
Check (Test-ReservedName -Name '.kimi') 'L2: .kimi is reserved'
Check (-not (Test-ReservedName -Name 'WZ_Skill')) 'L2: WZ_Skill not reserved'

# --- H-3: no branded default; dynamic route only when detected ------------
$r = Write-DeskRootToFile -Ws 'alpha' -PathValue $strongA
$row = (Get-Content -LiteralPath $script:RootsFile | Where-Object { $_ -match '^alpha\t' })
Check ($r -eq $true -and $row -eq ("alpha`t" + $strongA)) 'H3: zero-Agent row stays unbound without a branded fallback'

# seed: arbitrary route + legacy 2-col row + weak row, then bind dynamically
$seed = @(
  '# seeded',
  ("routed`t" + $strongB + "`tquasar-route"),
  ("legacy`t" + $strongC),
  ("weakrow`t" + $env:USERPROFILE)
)
Set-Content -LiteralPath $script:RootsFile -Value $seed -Encoding UTF8
$script:TestAgents = @([pscustomobject]@{ Id = 'nova-route' })
$r = Write-DeskRootToFile -Ws 'beta' -PathValue $strongA
$text = [System.IO.File]::ReadAllText($script:RootsFile, [System.Text.Encoding]::UTF8)
Check ($text -match ("routed\t" + [regex]::Escape($strongB) + "\tquasar-route")) 'H3: arbitrary existing route preserved on rewrite'
Check ($text -match ("legacy\t" + [regex]::Escape($strongC) + '(\r?\n|$)')) 'H3: legacy 2-col row remains valid and unbranded'
Check ($text -notmatch 'weakrow') 'R5: pre-existing weak row dropped on rewrite (desk.lua parity)'
Check ($text -match ("beta\t" + [regex]::Escape($strongA) + "\tnova-route")) 'H3: new binding uses an arbitrary detected route'

# --- L-3: atomic write leaves no temp --------------------------------------
Check (@(Get-ChildItem -LiteralPath $scratch -Filter '*.tmp.*' -File -ErrorAction SilentlyContinue).Count -eq 0) 'L3: no unique temp file left behind'

Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
if ($fails.Count -gt 0) {
  Write-Host ("SMOKE FAILED: " + ($fails -join '; ')) -ForegroundColor Red
  exit 1
}
Write-Host 'SMOKE ALL PASS' -ForegroundColor Green
exit 0
