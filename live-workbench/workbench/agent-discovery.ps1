#Requires -Version 5.1
<#
.SYNOPSIS
  Discover locally installed AI agent CLIs without an agent-name whitelist.

.DESCRIPTION
  Discovery is metadata-driven and never launches a candidate executable.
  Sources are live and persisted PATH, npm/Python package metadata, executable
  version/static capability metadata, *.wz-agent.json manifests, and the
  optional local TSV override. Static binary verdicts use a bounded fingerprint
  cache, so the result is safe and fast to call on every Init cold start.
#>
[CmdletBinding()]
param(
  [switch]$AsJson,
  [switch]$AsTsv,
  [string]$WorkbenchDir = $PSScriptRoot,
  [switch]$ProcessPathOnly,
  [string]$UserPathOverride
)

$ErrorActionPreference = 'SilentlyContinue'
$script:WzCommandCache = @{}
$script:WzMaxJsonBytes = 1MB
$script:WzMaxTextChars = 131072
$script:WzMaxBinaryBytes = 512MB
$script:WzBinaryScanBudget = 768MB
$script:WzBinaryBytesScanned = 0L
$script:WzSearchPathDirectories = @()
$script:WzPersistedUserPathKeys = @{}
$script:WzUserPathOverrideProvided = $PSBoundParameters.ContainsKey('UserPathOverride')
$script:WzEffectiveProcessPathOnly = $ProcessPathOnly -or ([string]$env:WZ_AGENT_DISCOVERY_PROCESS_PATH_ONLY -eq '1')
$script:WzBinaryCacheLoaded = $false
$script:WzBinaryCacheDirty = $false
$script:WzBinaryCache = @{}
$script:WzBinaryCachePath = if ($env:LOCALAPPDATA) {
  Join-Path $env:LOCALAPPDATA 'WZ_AiStarCube\agent-discovery-cache.json'
} else {
  Join-Path $WorkbenchDir 'agent-discovery-cache.json'
}

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
    # The host process can keep an old PATH after an installer updates the
    # persisted User/Machine PATH. Search the freshly read directories without
    # mutating this process environment.
    if (-not [System.IO.Path]::IsPathRooted($name)) {
      $extensions = @('')
      if (-not [System.IO.Path]::GetExtension($name)) {
        $extensions = @('.ps1', '.cmd', '.bat', '.exe', '.com', '')
      }
      foreach ($dir in @($script:WzSearchPathDirectories)) {
        foreach ($extension in $extensions) {
          $candidate = Join-Path $dir ($name + $extension)
          if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            try { $candidate = [System.IO.Path]::GetFullPath($candidate) } catch {}
            $script:WzCommandCache[$cacheKey] = $candidate
            return $candidate
          }
        }
      }
    }
    $script:WzCommandCache[$cacheKey] = ''
  }
  return $null
}

function Get-WzPathDirectories {
  $seen = @{}
  $out = New-Object System.Collections.Generic.List[string]
  $sources = New-Object System.Collections.Generic.List[object]
  [void]$sources.Add([pscustomobject]@{ Kind = 'process'; Value = [string]$env:PATH })
  if (-not $script:WzEffectiveProcessPathOnly) {
    $userPath = if ($script:WzUserPathOverrideProvided) {
      [string]$UserPathOverride
    } else {
      [string][Environment]::GetEnvironmentVariable('Path', 'User')
    }
    [void]$sources.Add([pscustomobject]@{ Kind = 'user'; Value = $userPath })
    [void]$sources.Add([pscustomobject]@{ Kind = 'machine'; Value = [string][Environment]::GetEnvironmentVariable('Path', 'Machine') })
  }
  foreach ($source in $sources) {
    foreach ($raw in (([string]$source.Value) -split ';')) {
      $dir = [Environment]::ExpandEnvironmentVariables(([string]$raw).Trim().Trim('"')).TrimEnd('\', '/')
      if (-not $dir -or $dir -match '^\\\\' -or -not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
      try { $dir = [System.IO.Path]::GetFullPath($dir) } catch {}
      $key = $dir.ToLowerInvariant()
      if ([string]$source.Kind -eq 'user') { $script:WzPersistedUserPathKeys[$key] = $true }
      if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; [void]$out.Add($dir) }
    }
  }
  return $out.ToArray()
}

function Initialize-WzBinaryCache {
  if ($script:WzBinaryCacheLoaded) { return }
  $script:WzBinaryCacheLoaded = $true
  $cache = Read-WzJsonFile -Path $script:WzBinaryCachePath
  if ($null -eq $cache -or -not $cache.entries) { return }
  foreach ($entry in @($cache.entries)) {
    $path = [string]$entry.path
    if (-not $path) { continue }
    $script:WzBinaryCache[$path.ToLowerInvariant()] = [pscustomobject]@{
      Path = $path
      Length = [long]$entry.length
      LastWriteUtcTicks = [long]$entry.lastWriteUtcTicks
      Detected = [bool]$entry.detected
    }
  }
}

function Save-WzBinaryCache {
  if (-not $script:WzBinaryCacheDirty) { return }
  $temp = $null
  try {
    $parent = Split-Path -Parent $script:WzBinaryCachePath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $entries = @($script:WzBinaryCache.Values | Sort-Object Path | Select-Object -First 128 | ForEach-Object {
      [ordered]@{ path = $_.Path; length = $_.Length; lastWriteUtcTicks = $_.LastWriteUtcTicks; detected = $_.Detected }
    })
    $json = ConvertTo-Json -InputObject ([ordered]@{ version = 1; entries = $entries }) -Depth 4 -Compress
    $temp = $script:WzBinaryCachePath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    [System.IO.File]::WriteAllText($temp, $json, (New-Object System.Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $script:WzBinaryCachePath -PathType Leaf) {
      [System.IO.File]::Replace($temp, $script:WzBinaryCachePath, $null, $true)
    } else {
      [System.IO.File]::Move($temp, $script:WzBinaryCachePath)
    }
    $script:WzBinaryCacheDirty = $false
  } catch {}
  finally {
    if ($temp -and (Test-Path -LiteralPath $temp -PathType Leaf)) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
  }
}

function Test-WzStaticBinaryAgentMetadata {
  param([System.IO.FileInfo]$File)
  if (-not $File -or $File.Length -le 0 -or $File.Length -gt $script:WzMaxBinaryBytes) { return $false }
  Initialize-WzBinaryCache
  $key = $File.FullName.ToLowerInvariant()
  if ($script:WzBinaryCache.ContainsKey($key)) {
    $cached = $script:WzBinaryCache[$key]
    if ([long]$cached.Length -eq [long]$File.Length -and [long]$cached.LastWriteUtcTicks -eq [long]$File.LastWriteTimeUtc.Ticks) {
      return [bool]$cached.Detected
    }
  }
  if (($script:WzBinaryBytesScanned + $File.Length) -gt $script:WzBinaryScanBudget) { return $false }
  $script:WzBinaryBytesScanned += $File.Length
  $patterns = @('coding agent', 'ai agent', 'agentic coding', 'agentic software', 'ai coding', 'code assistant', 'terminal assistant')
  $detected = $false
  $stream = $null
  try {
    $stream = [System.IO.File]::Open($File.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $buffer = New-Object byte[] (4MB)
    $encoding = [System.Text.Encoding]::ASCII
    $carry = ''
    while (($count = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
      $text = $carry + $encoding.GetString($buffer, 0, $count)
      foreach ($pattern in $patterns) {
        if ($text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $detected = $true; break }
      }
      if ($detected) { break }
      $carry = if ($text.Length -gt 32) { $text.Substring($text.Length - 32) } else { $text }
    }
  } catch { $detected = $false }
  finally { if ($stream) { $stream.Dispose() } }
  $script:WzBinaryCache[$key] = [pscustomobject]@{
    Path = $File.FullName
    Length = [long]$File.Length
    LastWriteUtcTicks = [long]$File.LastWriteTimeUtc.Ticks
    Detected = [bool]$detected
  }
  $script:WzBinaryCacheDirty = $true
  return $detected
}

function Get-WzDedicatedBinaryScore {
  param([System.IO.FileInfo]$File)
  if (-not $File -or -not $File.Directory -or $File.Directory.Name -ine 'bin') { return 0 }
  $appName = ([string]$File.Directory.Parent.Name).TrimStart('.').ToLowerInvariant()
  $commandName = ([string]$File.BaseName).ToLowerInvariant()
  if (-not $appName -or -not $commandName) { return 0 }
  if ($appName -eq $commandName) { return 4 }
  if ($appName.StartsWith($commandName + '-') -or $appName.StartsWith($commandName + '_')) { return 3 }
  if ($commandName.StartsWith($appName + '-') -or $commandName.StartsWith($appName + '_')) { return 2 }
  return 0
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
  $script:WzSearchPathDirectories = @($pathDirs)

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

  # Some modern standalone Agent installers place a self-contained EXE in a
  # dedicated user PATH directory but ship no package manifest and either no
  # Windows version resource or only the embedded runtime's generic resource.
  # Inspect only the likely primary binary of such user-owned app/bin roots.
  # This is a static byte scan: candidates are never executed, the vocabulary
  # describes capabilities rather than products, and fingerprints are cached.
  $userRoots = @()
  foreach ($rawRoot in @($env:USERPROFILE, $env:LOCALAPPDATA, $env:APPDATA)) {
    if (-not $rawRoot) { continue }
    try { $userRoots += [System.IO.Path]::GetFullPath([string]$rawRoot).TrimEnd('\') } catch { $userRoots += [string]$rawRoot }
  }
  foreach ($dir in $pathDirs) {
    $dirKey = $dir.ToLowerInvariant()
    if (-not $script:WzPersistedUserPathKeys.ContainsKey($dirKey)) { continue }
    $isUserOwned = $false
    foreach ($userRoot in $userRoots) {
      if ($userRoot -and ($dir.Equals($userRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $dir.StartsWith($userRoot + '\', [System.StringComparison]::OrdinalIgnoreCase))) {
        $isUserOwned = $true
        break
      }
    }
    if (-not $isUserOwned -or (Split-Path -Leaf $dir) -ine 'bin') { continue }
    $eligible = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue | Where-Object {
      $_.Extension -in @('.exe', '.cmd', '.bat', '.ps1')
    } | ForEach-Object {
      $score = Get-WzDedicatedBinaryScore -File $_
      if ($score -gt 0) { [pscustomobject]@{ File = $_; Score = $score } }
    })
    foreach ($group in @($eligible | Group-Object { ([string]$_.File.Length + '|' + [string]$_.File.LastWriteTimeUtc.Ticks) })) {
      $primary = @($group.Group | Sort-Object @{ Expression = 'Score'; Descending = $true }, @{ Expression = { $_.File.Name.Length }; Descending = $false }, @{ Expression = { $_.File.Name }; Descending = $false } | Select-Object -First 1)
      if ($primary.Count -eq 0) { continue }
      $exeFile = [System.IO.FileInfo]$primary[0].File
      $hasCapability = if ($exeFile.Extension -ieq '.exe') {
        Test-WzStaticBinaryAgentMetadata -File $exeFile
      } else {
        $text = Read-WzTextPrefix -Path $exeFile.FullName
        ($null -ne $text -and (Test-WzAgentMetadata $text))
      }
      if ($hasCapability) {
        Add-WzCandidate -Id $exeFile.BaseName -Label (ConvertTo-WzAgentLabel $exeFile.BaseName) -Exe $exeFile.FullName -Source 'user-path:static-capability'
      }
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

  Save-WzBinaryCache
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
