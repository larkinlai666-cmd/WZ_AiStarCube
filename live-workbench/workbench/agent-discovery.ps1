#Requires -Version 5.1
<#
.SYNOPSIS
  Discover locally installed AI agent CLIs without an agent-name whitelist.

.DESCRIPTION
  Discovery is metadata-driven and side-effect free: no candidate executable is
  launched. Sources are PATH-visible npm/Python package metadata, executable
  version metadata, *.wz-agent.json manifests, and the optional local TSV
  override. The result is safe to call on every Init cold start.
#>
[CmdletBinding()]
param(
  [switch]$AsJson,
  [switch]$AsTsv,
  [string]$WorkbenchDir = $PSScriptRoot
)

$ErrorActionPreference = 'SilentlyContinue'
$script:WzCommandCache = @{}
$script:WzMaxJsonBytes = 1MB
$script:WzMaxTextChars = 131072

function ConvertTo-WzSafeField {
  param(
    [string]$Value,
    [int]$MaxLength = 96,
    [string]$Default = ''
  )
  $text = [string]$Value
  # Metadata is untrusted input. Keep terminal/TSV control characters out of
  # labels, source fields, generated PowerShell commands and WezTerm titles.
  $text = $text -replace '[\x00-\x1F\x7F]+', ' '
  $text = ($text -replace '\s+', ' ').Trim()
  if (-not $text) { $text = $Default }
  if ($text.Length -gt $MaxLength) { $text = $text.Substring(0, $MaxLength).TrimEnd() }
  return $text
}

function Read-WzTextPrefix {
  param([string]$Path, [int]$MaxChars = $script:WzMaxTextChars)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  $reader = $null
  try {
    $reader = New-Object System.IO.StreamReader($Path, [System.Text.Encoding]::UTF8, $true)
    $buffer = New-Object char[] $MaxChars
    $count = $reader.Read($buffer, 0, $buffer.Length)
    if ($count -le 0) { return '' }
    return (New-Object string($buffer, 0, $count))
  } catch { return $null }
  finally { if ($reader) { $reader.Dispose() } }
}

function Read-WzJsonFile {
  param([string]$Path)
  try {
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.Length -gt $script:WzMaxJsonBytes) { return $null }
    return ([System.IO.File]::ReadAllText($item.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
  } catch { return $null }
}

function ConvertTo-WzAgentId {
  param([string]$Value)
  $id = ConvertTo-WzSafeField -Value $Value -MaxLength 80
  $id = [System.IO.Path]::GetFileNameWithoutExtension($id).ToLowerInvariant()
  $id = $id -replace '[^a-z0-9_-]+', '-'
  $id = $id.Trim('-')
  if (-not $id) { return $null }
  if ($id.Length -gt 64) { $id = $id.Substring(0, 64).TrimEnd('-') }
  return $id
}

function ConvertTo-WzAgentLabel {
  param([string]$Value)
  $text = ConvertTo-WzSafeField -Value $Value -MaxLength 80
  if (-not $text) { return 'AI Agent' }
  $text = $text -replace '^@[^/]+/', ''
  $text = $text -replace '[-_]+', ' '
  $text = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($text.ToLowerInvariant())
  return (ConvertTo-WzSafeField -Value $text -MaxLength 80 -Default 'AI Agent')
}

function Test-WzAgentMetadata {
  param([string]$Text)
  $s = (ConvertTo-WzSafeField -Value $Text -MaxLength 4096).ToLowerInvariant()
  if (-not $s) { return $false }
  # Capability vocabulary, never product names. Require explicit evidence that
  # this is an interactive AI/coding agent, not an arbitrary executable.
  return (
    $s -match '\b(coding|code|developer|terminal|command[- ]line|cli)\s+(ai\s+)?(agent|assistant|copilot)\b' -or
    $s -match '\b(ai|artificial intelligence|llm|large language model|generative ai)\s+(coding\s+|developer\s+|terminal\s+)?(agent|assistant|copilot|cli)\b' -or
    $s -match '\b(agentic coding|agentic software|ai coding|coding agent|code assistant)\b'
  )
}

function Resolve-WzAgentCommand {
  param([string[]]$Names)
  foreach ($raw in @($Names)) {
    $name = ([string]$raw).Trim().Trim('"')
    if (-not $name) { continue }
    if (Test-Path -LiteralPath $name -PathType Leaf) {
      try { return [System.IO.Path]::GetFullPath($name) } catch { return $name }
    }
    $cacheKey = $name.ToLowerInvariant()
    if ($script:WzCommandCache.ContainsKey($cacheKey)) {
      $cached = [string]$script:WzCommandCache[$cacheKey]
      if ($cached) { return $cached }
      continue
    }
    try {
      $cmd = Get-Command -Name $name -CommandType Application,ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source -PathType Leaf)) {
        $resolved = [string]$cmd.Source
        $script:WzCommandCache[$cacheKey] = $resolved
        return $resolved
      }
    } catch {}
    $script:WzCommandCache[$cacheKey] = ''
  }
  return $null
}

function Get-WzPathDirectories {
  $seen = @{}
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($raw in (([string]$env:PATH) -split ';')) {
    $dir = ([string]$raw).Trim().Trim('"').TrimEnd('\', '/')
    if (-not $dir -or $dir -match '^\\\\' -or -not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
    try { $dir = [System.IO.Path]::GetFullPath($dir) } catch {}
    $key = $dir.ToLowerInvariant()
    if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; [void]$out.Add($dir) }
  }
  return $out.ToArray()
}

function Get-WzNpmPackageFiles {
  param([string[]]$PathDirs)
  $roots = New-Object System.Collections.Generic.List[string]
  $seen = @{}
  foreach ($dir in @($PathDirs)) {
    foreach ($root in @((Join-Path $dir 'node_modules'), (Join-Path (Split-Path -Parent $dir) 'node_modules'))) {
      if (-not $root -or -not (Test-Path -LiteralPath $root -PathType Container)) { continue }
      $key = $root.ToLowerInvariant()
      if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; [void]$roots.Add($root) }
    }
  }
  if ($env:APPDATA) {
    $root = Join-Path $env:APPDATA 'npm\node_modules'
    if ((Test-Path -LiteralPath $root -PathType Container) -and -not $seen.ContainsKey($root.ToLowerInvariant())) {
      $seen[$root.ToLowerInvariant()] = $true
      [void]$roots.Add($root)
    }
  }
  $files = New-Object System.Collections.Generic.List[string]
  $seenFiles = @{}
  foreach ($root in $roots) {
    foreach ($entry in @(Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue)) {
      if ($entry.Name.StartsWith('@')) {
        foreach ($pkg in @(Get-ChildItem -LiteralPath $entry.FullName -Directory -Force -ErrorAction SilentlyContinue)) {
          $json = Join-Path $pkg.FullName 'package.json'
          if (Test-Path -LiteralPath $json -PathType Leaf) {
            $key = $json.ToLowerInvariant()
            if (-not $seenFiles.ContainsKey($key)) { $seenFiles[$key] = $true; [void]$files.Add($json) }
          }
        }
      } else {
        $json = Join-Path $entry.FullName 'package.json'
        if (Test-Path -LiteralPath $json -PathType Leaf) {
          $key = $json.ToLowerInvariant()
          if (-not $seenFiles.ContainsKey($key)) { $seenFiles[$key] = $true; [void]$files.Add($json) }
        }
      }
    }
  }
  return $files.ToArray()
}

function Get-WzPythonMetadataFiles {
  param([string[]]$PathDirs)
  $roots = New-Object System.Collections.Generic.List[string]
  $seen = @{}
  foreach ($dir in @($PathDirs)) {
    $candidates = @()
    if ((Split-Path -Leaf $dir) -ieq 'Scripts') {
      $parent = Split-Path -Parent $dir
      $candidates += (Join-Path $parent 'Lib\site-packages')
      $candidates += (Join-Path (Split-Path -Parent $parent) 'Lib\site-packages')
    }
    foreach ($root in $candidates) {
      if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
      $key = $root.ToLowerInvariant()
      if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; [void]$roots.Add($root) }
    }
  }
  $files = New-Object System.Collections.Generic.List[string]
  foreach ($root in $roots) {
    foreach ($meta in @(Get-ChildItem -LiteralPath $root -Directory -Filter '*.dist-info' -ErrorAction SilentlyContinue)) {
      $p = Join-Path $meta.FullName 'METADATA'
      if (Test-Path -LiteralPath $p -PathType Leaf) { [void]$files.Add($p) }
    }
  }
  return $files.ToArray()
}

function Get-WzInstalledAgents {
  param([string]$Root = $WorkbenchDir)
  $found = [ordered]@{}

  function Add-WzCandidate {
    param([string]$Id, [string]$Label, [string]$Exe, [string]$Source, [switch]$Replace)
    $id2 = ConvertTo-WzAgentId $Id
    if (-not $id2 -or -not $Exe -or -not (Test-Path -LiteralPath $Exe -PathType Leaf)) { return }
    $key = $id2.ToLowerInvariant()
    if ($found.Contains($key) -and -not $Replace) { return }
    $found[$key] = [pscustomobject]@{
      Id = $id2
      Label = if ($Label) { ConvertTo-WzSafeField -Value $Label -MaxLength 80 -Default (ConvertTo-WzAgentLabel $id2) } else { ConvertTo-WzAgentLabel $id2 }
      Exe = [System.IO.Path]::GetFullPath($Exe)
      Source = ConvertTo-WzSafeField -Value $Source -MaxLength 192
    }
  }

  $pathDirs = @(Get-WzPathDirectories)

  # npm: package metadata supplies both capability evidence and exported bin(s).
  foreach ($packageFile in @(Get-WzNpmPackageFiles -PathDirs $pathDirs)) {
    try {
      $pkg = Read-WzJsonFile -Path $packageFile
      if ($null -eq $pkg) { continue }
      $meta = @($pkg.name, $pkg.displayName, $pkg.description, ($pkg.keywords -join ' ')) -join ' '
      if (-not (Test-WzAgentMetadata $meta) -or -not $pkg.bin) { continue }
      $bins = [ordered]@{}
      if ($pkg.bin -is [string]) {
        $leaf = ([string]$pkg.name -split '/')[-1]
        $bins[$leaf] = [string]$pkg.bin
      } else {
        foreach ($prop in $pkg.bin.PSObject.Properties) { $bins[$prop.Name] = [string]$prop.Value }
      }
      foreach ($binName in $bins.Keys) {
        $exe = Resolve-WzAgentCommand @([string]$binName)
        if ($exe) {
          $label = if ($pkg.displayName) { [string]$pkg.displayName } else { ConvertTo-WzAgentLabel ([string]$binName) }
          Add-WzCandidate -Id ([string]$binName) -Label $label -Exe $exe -Source ('npm:' + [string]$pkg.name)
        }
      }
    } catch {}
  }

  # Python: package METADATA + console_scripts entry points, with no package-name list.
  foreach ($metadataFile in @(Get-WzPythonMetadataFiles -PathDirs $pathDirs)) {
    try {
      $raw = Read-WzTextPrefix -Path $metadataFile
      if ($null -eq $raw) { continue }
      $name = if ($raw -match '(?m)^Name:\s*(.+)$') { $Matches[1].Trim() } else { '' }
      $summary = if ($raw -match '(?m)^Summary:\s*(.+)$') { $Matches[1].Trim() } else { '' }
      $keywords = if ($raw -match '(?m)^Keywords:\s*(.+)$') { $Matches[1].Trim() } else { '' }
      if (-not (Test-WzAgentMetadata "$name $summary $keywords")) { continue }
      $entryFile = Join-Path (Split-Path -Parent $metadataFile) 'entry_points.txt'
      if (-not (Test-Path -LiteralPath $entryFile -PathType Leaf)) { continue }
      if ((Get-Item -LiteralPath $entryFile).Length -gt $script:WzMaxJsonBytes) { continue }
      $inside = $false
      foreach ($line in Get-Content -LiteralPath $entryFile -Encoding UTF8) {
        $t = ([string]$line).Trim()
        if ($t -match '^\[(.+)\]$') { $inside = ($Matches[1] -eq 'console_scripts'); continue }
        if (-not $inside -or $t -notmatch '^([^=\s]+)\s*=') { continue }
        $binName = $Matches[1]
        $exe = Resolve-WzAgentCommand @($binName)
        if ($exe) { Add-WzCandidate -Id $binName -Label (ConvertTo-WzAgentLabel $binName) -Exe $exe -Source ('python:' + $name) }
      }
    } catch {}
  }

  # PATH manifests and executable version resources support standalone tools.
  $winDir = if ($env:WINDIR) { [System.IO.Path]::GetFullPath($env:WINDIR).TrimEnd('\') } else { '' }
  foreach ($dir in $pathDirs) {
    $isWindowsSystem = $winDir -and $dir.StartsWith($winDir, [System.StringComparison]::OrdinalIgnoreCase)
    foreach ($manifest in @(Get-ChildItem -LiteralPath $dir -File -Filter '*.wz-agent.json' -ErrorAction SilentlyContinue)) {
      try {
        $m = Read-WzJsonFile -Path $manifest.FullName
        if ($null -eq $m) { continue }
        $rawNames = @()
        if ($m.command) { $rawNames += [string]$m.command }
        if ($m.exe) { $rawNames += [string]$m.exe }
        if ($m.commands) { $rawNames += @($m.commands | ForEach-Object { [string]$_ }) }
        $names = New-Object System.Collections.Generic.List[string]
        foreach ($rawName in @($rawNames | Where-Object { $_ })) {
          $name = [string]$rawName
          if (-not [System.IO.Path]::IsPathRooted($name)) { [void]$names.Add((Join-Path $manifest.DirectoryName $name)) }
          [void]$names.Add($name)
        }
        $exe = Resolve-WzAgentCommand $names
        if ($exe) { Add-WzCandidate -Id ([string]$m.id) -Label ([string]$m.label) -Exe $exe -Source ('manifest:' + $manifest.FullName) -Replace }
      } catch {}
    }
    if ($isWindowsSystem) { continue }
    foreach ($exeFile in @(Get-ChildItem -LiteralPath $dir -File -Filter '*.exe' -ErrorAction SilentlyContinue)) {
      try {
        $v = $exeFile.VersionInfo
        $meta = @($v.ProductName, $v.FileDescription, $v.Comments, $v.CompanyName) -join ' '
        if (Test-WzAgentMetadata $meta) {
          Add-WzCandidate -Id $exeFile.BaseName -Label (if ($v.ProductName) { $v.ProductName } else { ConvertTo-WzAgentLabel $exeFile.BaseName }) -Exe $exeFile.FullName -Source 'version-metadata'
        }
      } catch {}
    }
  }

  # Explicit registry is the escape hatch for a silent standalone binary. The
  # shipped file contains no products; local rows may use any id/command.
  foreach ($registry in @((Join-Path $Root 'agent-registry.tsv'), (Join-Path $Root 'agent-registry.local.tsv'))) {
    if (-not (Test-Path -LiteralPath $registry -PathType Leaf)) { continue }
    if ((Get-Item -LiteralPath $registry).Length -gt $script:WzMaxJsonBytes) { continue }
    foreach ($line in Get-Content -LiteralPath $registry -Encoding UTF8) {
      $t = ([string]$line).Trim()
      if (-not $t -or $t.StartsWith('#')) { continue }
      $parts = $t -split "`t", 3
      if ($parts.Count -lt 3) { continue }
      $names = @($parts[2] -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
      $exe = Resolve-WzAgentCommand $names
      if ($exe) { Add-WzCandidate -Id $parts[0] -Label $parts[1] -Exe $exe -Source ('registry:' + (Split-Path -Leaf $registry)) -Replace }
    }
  }

  return @($found.Values | Sort-Object Label, Id)
}

$agents = @(Get-WzInstalledAgents -Root $WorkbenchDir)
if ($AsTsv) {
  try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}
  foreach ($agent in $agents) {
    [Console]::Out.WriteLine(([string]$agent.Id + "`t" + [string]$agent.Label + "`t" + [string]$agent.Exe + "`t" + [string]$agent.Source))
  }
} elseif ($AsJson) {
  ConvertTo-Json -InputObject @($agents) -Depth 4 -Compress
} else {
  $agents
}
