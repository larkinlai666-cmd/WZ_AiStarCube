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
  $json = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $discoveryPath -WorkbenchDir $workbench -AsJson
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

  # A truly empty environment must stay empty; no historical product is injected.
  $emptyRoot = Join-Path $testRoot 'empty'
  $emptyBin = Join-Path $emptyRoot 'bin'
  $emptyWorkbench = Join-Path $emptyRoot 'workbench'
  New-Item -ItemType Directory -Force -Path $emptyBin, $emptyWorkbench | Out-Null
  [System.IO.File]::WriteAllText((Join-Path $emptyWorkbench 'agent-registry.tsv'), '# none', $utf8)
  $env:PATH = $emptyBin
  $env:APPDATA = Join-Path $emptyRoot 'appdata'
  $emptyJson = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $discoveryPath -WorkbenchDir $emptyWorkbench -AsJson
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
  $resolved = [System.IO.Path]::GetFullPath($testRoot)
  if ($resolved.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) {
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
