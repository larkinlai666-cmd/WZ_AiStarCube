$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$bootstrap = Join-Path $repo 'live-workbench\workbench\bootstrap.ps1'
$src = [System.IO.File]::ReadAllText($bootstrap, [System.Text.Encoding]::UTF8)

$fail = 0
function Check([bool]$Condition, [string]$Message) {
  if ($Condition) { Write-Output "PASS: $Message" }
  else { $script:fail++; Write-Output "FAIL: $Message" }
}

foreach ($name in @('ConvertTo-WzNumericVersion', 'Test-CodexResumeCompatible', 'Get-CodexRuntimeVersion', 'Read-CodexSessionSummaries')) {
  $m = [regex]::Match($src, "(?ms)^function $name \{.*?^\}")
  if (-not $m.Success) { throw "$name not found" }
  . ([ScriptBlock]::Create($m.Value))
}

$script:CodexRuntimeVersions = @{}
Check (-not (Test-CodexResumeCompatible -RuntimeVersion '0.137.0' -SessionVersion '0.145.0-alpha.18')) 'older Codex reader is blocked'
Check (Test-CodexResumeCompatible -RuntimeVersion '0.147.0' -SessionVersion '0.145.0-alpha.18') 'newer Codex reader is allowed'
Check (Test-CodexResumeCompatible -RuntimeVersion '' -SessionVersion '0.145.0-alpha.18') 'unknown runtime version does not false-block'
Check (Test-CodexResumeCompatible -RuntimeVersion '0.147.0' -SessionVersion '') 'unknown session version does not false-block'

$codex = Get-Command codex.cmd -ErrorAction SilentlyContinue
if ($codex) {
  $runtime = Get-CodexRuntimeVersion -Exe $codex.Source
  Check ($runtime -match '^\d+\.\d+\.\d+') 'installed Codex runtime version is readable'
  Check (Test-CodexResumeCompatible -RuntimeVersion $runtime -SessionVersion '0.145.0-alpha.18') 'installed Codex can read the reported failing session generation'
} else {
  Write-Output 'SKIP: codex.cmd is not installed'
}

function Step-LoadingPlan { param([string]$Label) }
function Test-WeakPath { param([string]$Cwd) return $false }
function Resolve-ProjectName { param([string]$Path, [string]$FallbackLeaf = '') return $FallbackLeaf }
function Get-SessionDiskBytes { param([string]$SessionDir) return [long]0 }

$oldProfile = $env:USERPROFILE
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('wz-codex-compat-' + [guid]::NewGuid().ToString('N'))
try {
  $env:USERPROFILE = $tmp
  $sessionDir = Join-Path $tmp '.codex\sessions\2026\07\20'
  [void](New-Item -ItemType Directory -Path $sessionDir -Force)
  $rollout = Join-Path $sessionDir 'rollout-test.jsonl'
  $meta = '{"timestamp":"2026-07-20T00:00:00Z","type":"session_meta","payload":{"id":"compat-test","cwd":"C:\\AIProjects\\compat-test","timestamp":"2026-07-20T00:00:00Z","model_provider":"openai","cli_version":"0.145.0-alpha.18"}}'
  [System.IO.File]::WriteAllText($rollout, $meta + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
  $rows = @(Read-CodexSessionSummaries -Files @((Get-Item -LiteralPath $rollout)))
  Check ($rows.Count -eq 1) 'Codex session metadata row is enumerated'
  Check ($rows[0].SessionCliVersion -eq '0.145.0-alpha.18') 'writer CLI version is retained on the row'
} finally {
  $env:USERPROFILE = $oldProfile
  if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
}

Check ($src -match 'SessionCliVersion = \$best\.SessionCliVersion') 'bound rows preserve writer version'
Check ($src -match 'SessionCliVersion = \$s\.SessionCliVersion') 'recent rows preserve writer version'
Check ($src -match 'Start-CodexTab.+-SessionCliVersion \(\[string\]\$Row\.SessionCliVersion\)') 'resume launch passes writer version to the gate'

if ($fail -gt 0) { Write-Output "RESULT: FAILED ($fail)"; exit 1 }
Write-Output 'RESULT: ALL PASS'
exit 0
