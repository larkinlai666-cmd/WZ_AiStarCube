#Requires -Version 5.1
param(
  [string]$Discovery = (Join-Path $PSScriptRoot '..\..\live-workbench\workbench\agent-discovery.ps1')
)

$ErrorActionPreference = 'Stop'
$discoveryPath = (Resolve-Path -LiteralPath $Discovery).Path
$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$testRoot = Join-Path $tempBase ('wz-agent-discovery-' + [guid]::NewGuid().ToString('N'))
$oldPath = $env:PATH
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
$utf8 = New-Object System.Text.UTF8Encoding($false)
$powershellExe = Join-Path $PSHOME 'powershell.exe'

function Assert-Wz {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "FAIL: $Message" }
  Write-Host "PASS: $Message"
}

try {
  $bin = Join-Path $testRoot 'bin'
  $workbench = Join-Path $testRoot 'workbench'
  $packageRoot = Join-Path $bin 'node_modules\@fixture\dynamic-agent'
  New-Item -ItemType Directory -Force -Path $bin, $workbench, $packageRoot | Out-Null

  $suffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
  $command = 'quasar-' + $suffix
  $commandFile = Join-Path $bin ($command + '.cmd')
  [System.IO.File]::WriteAllText($commandFile, "@echo off`r`nexit /b 0`r`n", $utf8)
  $package = [ordered]@{
    name = '@fixture/dynamic-agent'
    displayName = "Quasar`tAgent $suffix"
    description = 'A terminal AI coding agent for local projects'
    keywords = @('agentic coding', 'cli')
    bin = [ordered]@{ $command = '.\index.js' }
  } | ConvertTo-Json -Depth 5
  [System.IO.File]::WriteAllText((Join-Path $packageRoot 'package.json'), $package, $utf8)
  [System.IO.File]::WriteAllText((Join-Path $workbench 'agent-registry.tsv'), '# empty product-neutral registry', $utf8)

  $manifestExe = Join-Path $bin 'manifest-probe.exe'
  [System.IO.File]::WriteAllBytes($manifestExe, [byte[]](0x4D, 0x5A))
  $manifest = [ordered]@{
    id = 'Nova Agent!!!'
    label = "Nova`tAgent$([char]27)]2;unsafe$([char]7)"
    command = 'manifest-probe.exe'
  } | ConvertTo-Json -Compress
  [System.IO.File]::WriteAllText((Join-Path $bin 'nova.wz-agent.json'), $manifest, $utf8)

  # Oversized metadata must be ignored without preventing other discoveries.
  $oversized = Join-Path $bin 'oversized.wz-agent.json'
  [System.IO.File]::WriteAllText($oversized, (' ' * (1MB + 1)), $utf8)

  $env:PATH = $bin
  $env:APPDATA = Join-Path $testRoot 'isolated-appdata'
  $env:LOCALAPPDATA = Join-Path $testRoot 'isolated-localappdata'
  $json = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $discoveryPath -WorkbenchDir $workbench -AsJson -ProcessPathOnly
  Assert-Wz ($LASTEXITCODE -eq 0) 'open discovery exits cleanly'
  $rows = @()
  foreach ($item in (ConvertFrom-Json -InputObject ($json -join [Environment]::NewLine))) { $rows += $item }
  $dynamic = @($rows | Where-Object { $_.Id -eq $command })
  Assert-Wz ($dynamic.Count -eq 1) 'an arbitrary npm-described Agent is discovered without a product list'
  Assert-Wz ([System.IO.Path]::GetFullPath(([string]($dynamic[0].Exe))) -eq [System.IO.Path]::GetFullPath($commandFile)) 'discovery freezes the exact executable path'
  Assert-Wz (-not ([string]$dynamic[0].Label).Contains("`t")) 'package labels cannot inject TSV columns'

  $nova = @($rows | Where-Object { $_.Id -eq 'nova-agent' })
  Assert-Wz ($nova.Count -eq 1) 'manifest IDs are normalized without a product whitelist'
  Assert-Wz (([string]$nova[0].Label) -notmatch '[\x00-\x1F\x7F]') 'manifest labels cannot inject terminal control characters'
  Assert-Wz (@($rows | Where-Object { $_.Source -like '*oversized*' }).Count -eq 0) 'oversized JSON metadata is ignored'

  # A stale host process must still see newly persisted user-PATH installs.
  # The fixture deliberately has no package/manifest/version metadata and is
  # not a runnable PE; discovery must use static capability evidence only.
  $persistedApp = Join-Path $testRoot 'nebula-code'
  $persistedBin = Join-Path $persistedApp 'bin'
  New-Item -ItemType Directory -Force -Path $persistedBin | Out-Null
  $primaryExe = Join-Path $persistedBin 'nebula.exe'
  $aliasExe = Join-Path $persistedBin 'agent.exe'
  $binaryFixture = [System.Text.Encoding]::ASCII.GetBytes("MZ`0fixture payload: an interactive coding agent for local projects`0")
  [System.IO.File]::WriteAllBytes($primaryExe, $binaryFixture)
  [System.IO.File]::WriteAllBytes($aliasExe, $binaryFixture)
  $sameStamp = [datetime]::UtcNow.AddMinutes(-1)
  (Get-Item -LiteralPath $primaryExe).LastWriteTimeUtc = $sameStamp
  (Get-Item -LiteralPath $aliasExe).LastWriteTimeUtc = $sameStamp

  $staleBin = Join-Path $testRoot 'stale-process-bin'
  New-Item -ItemType Directory -Force -Path $staleBin | Out-Null
  $env:PATH = $staleBin
  $persistedJson = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $discoveryPath -WorkbenchDir $workbench -AsJson -UserPathOverride $persistedBin
  Assert-Wz ($LASTEXITCODE -eq 0) 'persisted user-PATH discovery exits cleanly with a stale process PATH'
  $persistedRows = @()
  foreach ($item in (ConvertFrom-Json -InputObject ($persistedJson -join [Environment]::NewLine))) { $persistedRows += $item }
  $nebula = @($persistedRows | Where-Object { $_.Id -eq 'nebula' })
  Assert-Wz ($nebula.Count -eq 1) 'an arbitrary standalone Agent is discovered from persisted user PATH without a product list'
  Assert-Wz ([string]$nebula[0].Source -eq 'user-path:static-capability') 'standalone discovery reports its generic static-capability source'
  Assert-Wz (@($persistedRows | Where-Object { $_.Id -eq 'agent' }).Count -eq 0) 'same-payload aliases collapse to the app-matching primary command'
  $cachePath = Join-Path $env:LOCALAPPDATA 'WZ_AiStarCube\agent-discovery-cache.json'
  Assert-Wz (Test-Path -LiteralPath $cachePath) 'standalone scan writes a bounded fingerprint cache'

  # Updating a CLI invalidates the stat fingerprint and atomically replaces the
  # cache without leaving a torn temporary file behind.
  $updatedFixture = [System.Text.Encoding]::ASCII.GetBytes("MZ`0updated fixture payload: an interactive coding agent for local projects`0")
  [System.IO.File]::WriteAllBytes($primaryExe, $updatedFixture)
  [System.IO.File]::WriteAllBytes($aliasExe, $updatedFixture)
  $newStamp = $sameStamp.AddSeconds(10)
  (Get-Item -LiteralPath $primaryExe).LastWriteTimeUtc = $newStamp
  (Get-Item -LiteralPath $aliasExe).LastWriteTimeUtc = $newStamp
  $updatedJson = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $discoveryPath -WorkbenchDir $workbench -AsJson -UserPathOverride $persistedBin
  Assert-Wz ($LASTEXITCODE -eq 0 -and (($updatedJson -join '') -match 'nebula')) 'updated standalone CLI invalidates and refreshes its cached verdict'
  Assert-Wz (@(Get-ChildItem -LiteralPath (Split-Path -Parent $cachePath) -Filter '*.tmp' -File -ErrorAction SilentlyContinue).Count -eq 0) 'atomic cache replacement leaves no temporary file'

  # A truly empty environment must stay empty; no historical product is injected.
  $emptyRoot = Join-Path $testRoot 'empty'
  $emptyBin = Join-Path $emptyRoot 'bin'
  $emptyWorkbench = Join-Path $emptyRoot 'workbench'
  New-Item -ItemType Directory -Force -Path $emptyBin, $emptyWorkbench | Out-Null
  [System.IO.File]::WriteAllText((Join-Path $emptyWorkbench 'agent-registry.tsv'), '# none', $utf8)
  $env:PATH = $emptyBin
  $env:APPDATA = Join-Path $emptyRoot 'appdata'
  $emptyJson = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $discoveryPath -WorkbenchDir $emptyWorkbench -AsJson -ProcessPathOnly
  Assert-Wz ($LASTEXITCODE -eq 0) 'zero-Agent discovery exits cleanly'
  $emptyRows = @()
  if (-not [string]::IsNullOrWhiteSpace(($emptyJson -join ''))) {
    foreach ($item in (ConvertFrom-Json -InputObject ($emptyJson -join [Environment]::NewLine))) { $emptyRows += $item }
  }
  Assert-Wz ($emptyRows.Count -eq 0) 'zero-Agent state remains zero and injects no branded fallback'

  Write-Host 'ALL OPEN-DISCOVERY TESTS PASSED'
}
finally {
  $env:PATH = $oldPath
  $env:APPDATA = $oldAppData
  $env:LOCALAPPDATA = $oldLocalAppData
  $resolved = [System.IO.Path]::GetFullPath($testRoot)
  if ($resolved.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) {
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
