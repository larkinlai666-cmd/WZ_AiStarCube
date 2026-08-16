# Smoke test: Read-CodexSessionSummaries extracted from live bootstrap.ps1
# Run: powershell -NoProfile -File smoke-codex-sessions.ps1
# NOTE: PS 5.1 reads BOM-less .ps1 as ANSI — never use non-ASCII literals in
# assertions below; expected values are derived from the data itself.
$ErrorActionPreference = 'Stop'
$live = 'C:\Users\Administrator\.config\wezterm\workbench\bootstrap.ps1'
$src = [System.IO.File]::ReadAllText($live)

$m = [regex]::Match($src, '(?ms)^function Read-CodexSessionSummaries \{.*?^\}')
if (-not $m.Success) { throw 'Read-CodexSessionSummaries not found in live bootstrap.ps1' }

# Minimal stubs for the helpers the function calls
function Test-WeakPath { param([string]$Cwd) return $false }
function Resolve-ProjectName { param([string]$Path, [string]$FallbackLeaf = '') return $FallbackLeaf }
function Get-SessionDiskBytes { param([string]$SessionDir) return [long]0 }
function Step-LoadingPlan { param([string]$Label) }

. ([ScriptBlock]::Create($m.Value))

$rows = @(Read-CodexSessionSummaries)
Write-Output ("total rows: " + $rows.Count)
foreach ($r in $rows) {
  Write-Output ("- [{0}] {1} | {2} | {3} | upd={4:yyyy-MM-dd HH:mm:ss}" -f $r.Agent, $r.Id, $r.Cwd, $r.Title, $r.Updated)
}

$fail = 0
function Assert([bool]$cond, [string]$msg) {
  if ($cond) { Write-Output "PASS: $msg" } else { $script:fail++; Write-Output "FAIL: $msg" }
}

# Ground truth: parse first line of every rollout file ourselves
$root = Join-Path $env:USERPROFILE '.codex\sessions'
$truth = @{}
$truthVersion = @{}
foreach ($f in (Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'rollout-*.jsonl')) {
  $first = Get-Content -LiteralPath $f.FullName -TotalCount 1 -Encoding UTF8
  if (-not $first) { continue }
  try { $j = $first | ConvertFrom-Json } catch { continue }
  if ($j.type -ne 'session_meta' -or -not $j.payload) { continue }
  if (-not $j.payload.id -or -not $j.payload.cwd) { continue }
  $truth[[string]$j.payload.id] = ([string]$j.payload.cwd).Trim().Replace('/', '\').TrimEnd('\')
  $truthVersion[[string]$j.payload.id] = $(if ($j.payload.cli_version) { [string]$j.payload.cli_version } else { '' })
}
Write-Output ("rollout files with session_meta+cwd: " + $truth.Count)

Assert ($rows.Count -gt 0) 'at least one codex session listed'
Assert ($rows.Count -le $truth.Count) 'rows never exceed sessions on disk'

# Every row: shape + cwd normalization + id/cwd match ground truth
$allShape = $true; $allCwd = $true; $allMatch = $true; $allTime = $true; $allVersion = $true
foreach ($r in $rows) {
  if ($r.Agent -ne 'codex' -or $r.Kind -ne 'session') { $allShape = $false }
  if ($r.Cwd -match '/' -or $r.Cwd.EndsWith('\')) { $allCwd = $false }
  if (-not $truth.ContainsKey($r.Id) -or $truth[$r.Id] -ne $r.Cwd) { $allMatch = $false }
  if (-not ($r.Updated -is [DateTime])) { $allTime = $false }
  if (-not $truthVersion.ContainsKey($r.Id) -or $truthVersion[$r.Id] -ne $r.SessionCliVersion) { $allVersion = $false }
}
Assert $allShape "every row has Agent='codex' and Kind='session'"
Assert $allCwd 'every Cwd backslash-normalized, no trailing backslash'
Assert $allMatch 'every row Id/Cwd matches rollout session_meta'
Assert $allTime 'every Updated parsed as DateTime'
Assert $allVersion 'every row preserves session_meta cli_version'

# Cap: at most 3 rows per cwd
$perCwd = @{}
foreach ($r in $rows) {
  $k = ([string]$r.Cwd).ToLowerInvariant()
  if (-not $perCwd.ContainsKey($k)) { $perCwd[$k] = 0 }
  $perCwd[$k] = [int]$perCwd[$k] + 1
}
$maxPer = 0
foreach ($k in $perCwd.Keys) { if ([int]$perCwd[$k] -gt $maxPer) { $maxPer = [int]$perCwd[$k] } }
Assert ($maxPer -le 3) "at most 3 rows kept per cwd (max seen: $maxPer)"

# Title index: if session_index.jsonl names a listed session, row must carry it
$idxFile = Join-Path $env:USERPROFILE '.codex\session_index.jsonl'
if (Test-Path -LiteralPath $idxFile) {
  $named = @{}
  foreach ($line in (Get-Content -LiteralPath $idxFile -Encoding UTF8)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try { $o = $line | ConvertFrom-Json } catch { continue }
    if ($o.id -and $o.thread_name) { $named[[string]$o.id] = [string]$o.thread_name }
  }
  $titleOk = $true
  foreach ($r in $rows) {
    if ($named.ContainsKey($r.Id) -and $r.Title -ne $named[$r.Id]) { $titleOk = $false }
  }
  Assert $titleOk 'Title matches session_index thread_name when indexed'
}

if ($fail -gt 0) { Write-Output ("RESULT: FAILED (" + $fail + ")"); exit 1 }
Write-Output 'RESULT: ALL PASS'
exit 0
