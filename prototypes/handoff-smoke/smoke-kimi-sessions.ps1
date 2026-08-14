# Smoke test: Read-KimiSessionSummaries extracted from live bootstrap.ps1
# Run: powershell -NoProfile -File smoke-kimi-sessions.ps1
$ErrorActionPreference = 'Stop'
$live = 'C:\Users\Administrator\.config\wezterm\workbench\bootstrap.ps1'
$src = [System.IO.File]::ReadAllText($live)

$m = [regex]::Match($src, '(?ms)^function Read-KimiSessionSummaries \{.*?^\}')
if (-not $m.Success) { throw 'Read-KimiSessionSummaries not found in live bootstrap.ps1' }

# Minimal stubs for the helpers the function calls
function Test-WeakPath { param([string]$Cwd) return $false }
function Resolve-ProjectName { param([string]$Path, [string]$FallbackLeaf = '') return $FallbackLeaf }
function Get-SessionDiskBytes { param([string]$SessionDir) return [long]0 }

. ([ScriptBlock]::Create($m.Value))

$rows = @(Read-KimiSessionSummaries)
Write-Output ("total rows: " + $rows.Count)
foreach ($r in $rows) {
  Write-Output ("- [{0}] {1} | {2} | {3} | upd={4:yyyy-MM-dd HH:mm:ss}" -f $r.Agent, $r.Id, $r.Cwd, $r.Title, $r.Updated)
}

$fail = 0
function Assert([bool]$cond, [string]$msg) {
  if ($cond) { Write-Output "PASS: $msg" } else { $script:fail++; Write-Output "FAIL: $msg" }
}

$wz = @($rows | Where-Object { $_.Cwd -eq 'G:\GrokProject\WZ_Skill' })
Assert ($wz.Count -eq 1) 'exactly one (latest) session kept for wd_wz_skill'
if ($wz.Count -ge 1) {
  $s = $wz[0]
  Assert ($s.Agent -eq 'kimi') "Agent='kimi'"
  Assert ($s.Model -eq 'Kimi') "Model='Kimi'"
  Assert ($s.Kind -eq 'session') "Kind='session'"
  Assert ($s.Id -eq 'session_99dd4b01-a07c-4442-af73-2490a6882e69') 'latest session id picked'
$expectTitle = (Get-Content -LiteralPath "$env:USERPROFILE\.kimi-code\sessions\wd_wz_skill_d5b3c52ea15d\session_99dd4b01-a07c-4442-af73-2490a6882e69\state.json" -Raw -Encoding UTF8 | ConvertFrom-Json).title
Write-Output ("expectTitle bytes: " + (($expectTitle.ToCharArray() | ForEach-Object { [int]$_ }) -join ','))
Assert ($s.Title -eq $expectTitle) 'title equals state.json title (contains 多个模型接手)'
Assert ($s.Title -like ('*' + [char]0x591A + [char]0x4E2A + [char]0x6A21 + [char]0x578B + [char]0x63A5 + [char]0x624B + '*')) 'title contains 多个模型接手'
  Assert ($s.GitRoot -eq '') "GitRoot=''"
  Assert (@($s.RecentPrompts).Count -eq 0) 'RecentPrompts empty'
  Assert ($s.Updated -is [DateTime]) 'Updated is DateTime'
}
$kb = @($rows | Where-Object { $_.Cwd -like 'G:\KimiData\kimi\Workspaces\Kimi_Base*' })
Assert ($kb.Count -eq 1) 'only newest session kept for wd_kimi_base (2 on disk)'
$find = @($rows | Where-Object { $_.Cwd -eq 'G:\KimiProject\find' })
Assert ($find.Count -eq 1) 'wd_find session listed'

if ($fail -gt 0) { Write-Output ("RESULT: FAILED (" + $fail + ")"); exit 1 }
Write-Output 'RESULT: ALL PASS'
exit 0
