# WZ-AiWorkBench Task Init Panel (v4)
# ============================================================================
# HARD GATES (keep in sync with desk.lua)
# ============================================================================
# R1  Grok for real work MUST use --cwd <strong project path>. Never bare home.
# R2  Weak/system paths are NEVER a project root (home/Desktop/Documents root/…).
# R3  「项目名」= desk-roots LEFT column (binding name), NOT session title / cwd leaf.
# R4  「项目路径」= desk-roots RIGHT column; frozen at create/bind; .wz-project reinforces.
# R5  set_root / bind refuse weak paths and reserved names.
# R6  UI Project column = Resolve-ProjectName(path); never show "home" as a task.
#
# List: strong desk-roots TASK + favorites + titled recent (weak demoted).
# New task: press c → name → path freeze → bind → open Grok with --cwd only.
param([switch]$All)

$ErrorActionPreference = 'Continue'
try {
  chcp 65001 | Out-Null
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}
# Navigation-only title — never a filesystem path (prevents tab pollution)
try { $Host.UI.RawUI.WindowTitle = 'Init' } catch {}

$script:SessionsRoot  = Join-Path $env:USERPROFILE '.grok\sessions'
$script:RootsFile     = Join-Path $env:USERPROFILE '.config\wezterm\workbench\desk-roots.tsv'
$script:FavoritesFile = Join-Path $env:USERPROFILE '.config\wezterm\workbench\favorites.txt'
$script:Grok          = $null  # resolved below
$script:DefaultParent = $null  # resolved below
$script:MaxRows       = 18
$script:RecentDays    = 45
$script:ShowAll       = [bool]$All
$script:Selected      = 0
$script:Rows          = @()
$script:Wez           = $null
$script:BufH          = 40
$script:DrawnLines    = 0
$script:DeskRoots     = [ordered]@{}
$script:StatusHint    = ''
$script:ReservedNames = @(
  'home', 'desktop', 'documents', 'downloads', 'pictures', 'music', 'videos',
  'administrator', 'users', 'temp', 'tmp', 'appdata', 'windows', 'system32',
  'config', '.grok', '.config', 'wezterm', 'my documents', 'onedrive'
)

foreach ($c in @(
    (Join-Path $env:ProgramFiles 'WezTerm\wezterm.exe'),
    (Get-Command wezterm -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
  )) {
  if ($c -and (Test-Path -LiteralPath $c)) { $script:Wez = $c; break }
}

function Get-DefaultProjectsParent {
  # Portable: env override → existing *:\GrokProject → Documents\GrokProjects
  if ($env:WZ_PROJECTS_ROOT -and $env:WZ_PROJECTS_ROOT.Trim()) {
    return $env:WZ_PROJECTS_ROOT.Trim().TrimEnd('\')
  }
  foreach ($c in @('G:\GrokProject', 'D:\GrokProject', 'E:\GrokProject', 'C:\GrokProject')) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  $docs = [Environment]::GetFolderPath('MyDocuments')
  if (-not $docs) { $docs = Join-Path $env:USERPROFILE 'Documents' }
  return (Join-Path $docs 'GrokProjects')
}

function Resolve-GrokExe {
  $list = New-Object System.Collections.Generic.List[string]
  try {
    $cmd = Get-Command grok -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { [void]$list.Add([string]$cmd.Source) }
  } catch {}
  foreach ($c in @(
      (Join-Path $env:USERPROFILE '.grok\bin\grok.exe'),
      (Join-Path $env:LOCALAPPDATA 'Programs\grok\grok.exe'),
      (Join-Path $env:ProgramFiles 'grok\grok.exe')
    )) {
    if ($c) { [void]$list.Add($c) }
  }
  foreach ($c in $list) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  return $null
}

$script:DefaultParent = Get-DefaultProjectsParent
$script:Grok = Resolve-GrokExe
if (-not $script:Grok) {
  $script:Grok = Join-Path $env:USERPROFILE '.grok\bin\grok.exe'  # path used in error messages
}

function Get-DisplayWidth {
  param([string]$s)
  if ($null -eq $s) { return 0 }
  $w = 0
  foreach ($ch in $s.ToCharArray()) {
    $code = [int]$ch
    if ($code -le 0x1F) { continue }
    $wide = $false
    if ($code -ge 0x1100) {
      if ($code -le 0x115F -or $code -eq 0x2329 -or $code -eq 0x232A) { $wide = $true }
      elseif ($code -ge 0x2E80 -and $code -le 0xA4CF) { $wide = $true }
      elseif ($code -ge 0xAC00 -and $code -le 0xD7A3) { $wide = $true }
      elseif ($code -ge 0xF900 -and $code -le 0xFAFF) { $wide = $true }
      elseif ($code -ge 0xFE10 -and $code -le 0xFE6F) { $wide = $true }
      elseif ($code -ge 0xFF00 -and $code -le 0xFF60) { $wide = $true }
      elseif ($code -ge 0xFFE0 -and $code -le 0xFFE6) { $wide = $true }
      elseif ($code -ge 0x20000) { $wide = $true }
    }
    if ($wide) { $w += 2 } else { $w += 1 }
  }
  return $w
}

function Pad-Display {
  param(
    [string]$Text,
    [int]$Width,
    [ValidateSet('Left', 'Right')]$Align = 'Left',
    [switch]$NoTrim
  )
  if ($null -eq $Text) { $Text = '' }
  if ($NoTrim) { $Text = $Text -replace '[\r\n]+', ' ' }
  else { $Text = ($Text -replace '[\r\n\t]+', ' ').Trim() }
  $w = Get-DisplayWidth $Text
  if ($w -gt $Width) {
    $acc = ''
    foreach ($ch in $Text.ToCharArray()) {
      $try = $acc + $ch
      if ((Get-DisplayWidth ($try + '~')) -gt $Width) { return ($acc + '~') }
      $acc = $try
    }
    return $acc
  }
  $pad = $Width - $w
  if ($pad -lt 0) { $pad = 0 }
  $spaces = ' ' * $pad
  if ($Align -eq 'Right') { return $spaces + $Text }
  return $Text + $spaces
}

function Test-WezAlive {
  return $null -ne (Get-Process -Name 'wezterm-gui' -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function ConvertFrom-IsoTime {
  param([string]$Iso)
  if ([string]::IsNullOrWhiteSpace($Iso)) { return $null }
  try { return [DateTimeOffset]::Parse($Iso).ToLocalTime().DateTime }
  catch {
    try { return [DateTime]::Parse($Iso).ToLocalTime() } catch { return $null }
  }
}

function Format-DateTime {
  param($Dt)
  if (-not $Dt) { return '---- -- --:--' }
  $now = Get-Date
  if ($Dt.Year -eq $now.Year) { return $Dt.ToString('MM-dd HH:mm') }
  return $Dt.ToString('yy-MM-dd HH:mm')
}

function Normalize-PathKey {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
  return $Path.Trim().Replace('/', '\').TrimEnd('\').ToLowerInvariant()
}

function Test-NoiseCwd {
  param([string]$Cwd)
  if ([string]::IsNullOrWhiteSpace($Cwd)) { return $true }
  $l = $Cwd.ToLowerInvariant()
  if ($l -match '\\windows\\(system32|syswow64)') { return $true }
  if ($l -match '\\appdata\\local\\temp') { return $true }
  if ($l -match '\\windows\\temp') { return $true }
  return $false
}

function Test-ReservedName {
  param([string]$Name)
  if ([string]::IsNullOrWhiteSpace($Name)) { return $true }
  $n = $Name.Trim().ToLowerInvariant()
  return ($script:ReservedNames -contains $n)
}

function Test-WeakPath {
  # R2: never a project root (exact profile shortcuts + noise trees)
  param([string]$Cwd)
  if ([string]::IsNullOrWhiteSpace($Cwd)) { return $true }
  if (Test-NoiseCwd -Cwd $Cwd) { return $true }
  $c = Normalize-PathKey $Cwd
  $h = Normalize-PathKey $env:USERPROFILE
  if ($c -eq $h) { return $true }
  $exact = @(
    (Join-Path $env:USERPROFILE 'Desktop'),
    (Join-Path $env:USERPROFILE 'Documents'),
    (Join-Path $env:USERPROFILE 'Downloads'),
    (Join-Path $env:USERPROFILE 'Pictures'),
    (Join-Path $env:USERPROFILE 'Music'),
    (Join-Path $env:USERPROFILE 'Videos'),
    (Join-Path $env:USERPROFILE 'OneDrive'),
    (Join-Path $env:USERPROFILE '.config'),
    (Join-Path $env:USERPROFILE '.grok'),
    (Join-Path $env:USERPROFILE '.config\wezterm'),
    (Join-Path $env:USERPROFILE '.grok\bin'),
    (Join-Path $env:USERPROFILE '.grok\sessions')
  ) | ForEach-Object { Normalize-PathKey $_ }
  if ($exact -contains $c) { return $true }
  if ($c.StartsWith((Normalize-PathKey (Join-Path $env:USERPROFILE 'AppData')) + '\')) { return $true }
  if ($c -match '^[a-z]:$') { return $true }
  return $false
}

function Test-WeakHomeCwd {
  # alias kept for older call sites
  param([string]$Cwd)
  return (Test-WeakPath -Cwd $Cwd)
}

function Test-StrongProjectPath {
  param([string]$Cwd)
  if ([string]::IsNullOrWhiteSpace($Cwd)) { return $false }
  if (Test-WeakPath -Cwd $Cwd) { return $false }
  return $true
}

function Test-BadTitle {
  param([string]$Title)
  if ([string]::IsNullOrWhiteSpace($Title)) { return $true }
  $t = $Title.Trim()
  if ($t -eq '(no title)' -or $t -match '^\(no title' -or $t -eq '-' -or $t.Length -lt 2) { return $true }
  return $false
}

function Test-ValidProjectName {
  param([string]$Name)
  if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
  if ($Name.Length -lt 1 -or $Name.Length -gt 100) { return $false }
  if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { return $false }
  if ($Name -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') { return $false }
  if ($Name.EndsWith('.')) { return $false }
  if (Test-ReservedName -Name $Name) { return $false }
  return $true
}

function Read-WzProjectMarker {
  param([string]$ProjectPath)
  if (-not $ProjectPath -or -not (Test-Path -LiteralPath $ProjectPath)) { return $null }
  $marker = Join-Path $ProjectPath '.wz-project'
  if (-not (Test-Path -LiteralPath $marker)) { return $null }
  try {
    $name = $null; $path = $null
    foreach ($ln in Get-Content -LiteralPath $marker -Encoding UTF8 -ErrorAction SilentlyContinue) {
      if ($ln -match '^\s*name\s*=\s*(.+)\s*$') { $name = $Matches[1].Trim() }
      if ($ln -match '^\s*path\s*=\s*(.+)\s*$') { $path = $Matches[1].Trim().TrimEnd('\') }
    }
    if ($name -and -not (Test-ReservedName -Name $name)) {
      return [pscustomobject]@{ Name = $name; Path = $path }
    }
  } catch {}
  return $null
}

function Write-WzProjectMarker {
  param([string]$Name, [string]$Path)
  $Path = $Path.Trim().TrimEnd('\')
  $marker = Join-Path $Path '.wz-project'
  $lines = @(
    "# WZ project identity — frozen at create/bind; do not hand-edit casually",
    "name=$Name",
    "path=$Path",
    ("created={0:yyyy-MM-ddTHH:mm:ssK}" -f (Get-Date))
  )
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllLines($marker, $lines, $utf8)
}

function Resolve-ProjectName {
  # R3/R6: project name = desk-roots binding, else .wz-project, else strong leaf
  param([string]$Path, [string]$FallbackLeaf = '')
  if ([string]::IsNullOrWhiteSpace($Path)) {
    if ($FallbackLeaf -and -not (Test-ReservedName -Name $FallbackLeaf)) { return $FallbackLeaf }
    return '(system)'
  }
  $bound = Get-BoundNameForPath -Path $Path
  if ($bound -and -not (Test-ReservedName -Name $bound)) { return $bound }
  $mark = Read-WzProjectMarker -ProjectPath $Path
  if ($mark -and $mark.Name) { return $mark.Name }
  if (Test-StrongProjectPath -Cwd $Path) {
    $leaf = Split-Path -Leaf $Path
    if ($leaf -and -not (Test-ReservedName -Name $leaf)) { return $leaf }
  }
  if ($FallbackLeaf -and -not (Test-ReservedName -Name $FallbackLeaf)) { return $FallbackLeaf }
  return '(system)'
}

function Read-DeskRoots {
  $map = [ordered]@{}
  if (-not (Test-Path -LiteralPath $script:RootsFile)) { return $map }
  try {
    foreach ($line in Get-Content -LiteralPath $script:RootsFile -Encoding UTF8 -ErrorAction SilentlyContinue) {
      $t = $line.Trim()
      if ($t -eq '' -or $t.StartsWith('#')) { continue }
      $parts = $t -split "`t", 2
      if ($parts.Count -lt 2) { $parts = $t -split '\s+', 2 }
      if ($parts.Count -ge 2 -and $parts[0] -and $parts[1]) {
        $map[$parts[0].Trim()] = $parts[1].Trim().TrimEnd('\')
      }
    }
  } catch {}
  return $map
}

function Write-DeskRoots {
  param($Map)
  $dir = Split-Path -Parent $script:RootsFile
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $lines = @(
    '# AI STAR CUBE desk roots - project_name<TAB>absolute_path',
    '# 项目名(绑定名) 与 项目路径 写死绑定；Explorer / 状态栏 / F6 / Init 共用',
    '# 弱路径(home/Desktop/…)与保留名不得写入'
  )
  foreach ($k in ($Map.Keys | Sort-Object)) {
    $p = $Map[$k]
    if ((Test-ReservedName -Name $k)) { continue }
    if (-not (Test-StrongProjectPath -Cwd $p)) { continue }
    $lines += ($k + "`t" + $p)
  }
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllLines($script:RootsFile, $lines, $utf8)
}

function Set-DeskRootBinding {
  param([string]$Name, [string]$Path)
  $Name = $Name.Trim()
  $Path = $Path.Trim().TrimEnd('\')
  if (Test-ReservedName -Name $Name) {
    throw "Reserved project name refused: $Name"
  }
  if (-not (Test-StrongProjectPath -Cwd $Path)) {
    throw "Weak/system path cannot be a project root: $Path"
  }
  $map = @{}
  foreach ($k in $script:DeskRoots.Keys) {
    if (-not (Test-ReservedName -Name $k) -and (Test-StrongProjectPath -Cwd $script:DeskRoots[$k])) {
      $map[$k] = $script:DeskRoots[$k]
    }
  }
  $pk = Normalize-PathKey $Path
  foreach ($k in @($map.Keys)) {
    if ((Normalize-PathKey $map[$k]) -eq $pk -and $k -ne $Name) { $map.Remove($k) }
  }
  $map[$Name] = $Path
  Write-DeskRoots -Map $map
  $script:DeskRoots = Read-DeskRoots
  # freeze identity on disk so reopen never invents another name
  try { Write-WzProjectMarker -Name $Name -Path $Path } catch {}
}

function Read-Favorites {
  $list = @()
  if (-not (Test-Path -LiteralPath $script:FavoritesFile)) { return $list }
  try {
    foreach ($line in Get-Content -LiteralPath $script:FavoritesFile -Encoding UTF8 -ErrorAction SilentlyContinue) {
      $t = $line.Trim()
      if ($t -eq '' -or $t.StartsWith('#')) { continue }
      $p = $t.TrimEnd('\')
      if (Test-Path -LiteralPath $p) { $list += $p }
    }
  } catch {}
  return $list
}

function Get-BoundNameForPath {
  param([string]$Path)
  $pk = Normalize-PathKey $Path
  foreach ($k in $script:DeskRoots.Keys) {
    if ((Normalize-PathKey $script:DeskRoots[$k]) -eq $pk) { return $k }
  }
  foreach ($k in $script:DeskRoots.Keys) {
    $root = Normalize-PathKey $script:DeskRoots[$k]
    if ($pk.StartsWith($root + '\')) { return $k }
  }
  return $null
}

function Get-ModelDisplay {
  param([string]$ModelId, [string]$AgentName)
  if ([string]::IsNullOrWhiteSpace($ModelId)) { return '' }
  $m = $ModelId.Trim()
  if ($m -eq '-' -or $m -eq 'n/a' -or $m -eq 'none') { return '' }
  if ($m -match '(?i)grok|gpt|claude|gemini|o1|o3|llm|anthropic|openai|xai') { return $m }
  if ($m -match '[A-Za-z]' -and $m -match '\d') { return $m }
  if ($AgentName -and $AgentName -match '(?i)grok|codex|agent|build|plan') { return $m }
  if ($m -match '^(cmd|shell|powershell|bash|pwsh)$') { return '' }
  return $m
}

function Get-SessionDiskBytes {
  param([string]$SessionDir)
  if (-not $SessionDir -or -not (Test-Path -LiteralPath $SessionDir)) { return 0 }
  $n = [long]0
  foreach ($name in @('chat_history.jsonl', 'updates.jsonl')) {
    $fp = Join-Path $SessionDir $name
    if (Test-Path -LiteralPath $fp) {
      try { $n += (Get-Item -LiteralPath $fp).Length } catch {}
    }
  }
  return $n
}

function Get-PromptExcerpt {
  param([string]$SessionId, [string]$SessionDir, [string]$Fallback)
  $list = Get-RecentPrompts -SessionId $SessionId -SessionDir $SessionDir -Count 1
  if ($list -and $list.Count -gt 0) { return $list[0] }
  return $Fallback
}

function Get-RecentPrompts {
  param([string]$SessionId, [string]$SessionDir, [int]$Count = 3)
  $out = New-Object System.Collections.Generic.List[string]
  if (-not $SessionDir) { return @() }
  $file = Join-Path $SessionDir 'prompt_history.jsonl'
  if (-not (Test-Path -LiteralPath $file)) { return @() }
  try {
    $lines = Get-Content -LiteralPath $file -Tail 80 -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { return @() }
    for ($i = $lines.Count - 1; $i -ge 0 -and $out.Count -lt $Count; $i--) {
      $line = $lines[$i]
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      try { $o = $line | ConvertFrom-Json } catch { continue }
      if ($SessionId -and $o.session_id -and ($o.session_id -ne $SessionId)) { continue }
      $t = $null
      if ($o.prompt) { $t = [string]$o.prompt }
      elseif ($o.text) { $t = [string]$o.text }
      elseif ($o.content) { $t = [string]$o.content }
      if ($t -and $t.Trim().Length -gt 4) {
        $one = ($t -replace '[\r\n]+', ' ').Trim()
        if ($one.Length -gt 220) { $one = $one.Substring(0, 217) + '...' }
        $out.Add($one) | Out-Null
      }
    }
  } catch {}
  return @($out)
}

function Get-ProjectStateHint {
  param([string]$ProjectPath)
  if (-not $ProjectPath -or -not (Test-Path -LiteralPath $ProjectPath)) { return $null }
  $state = Join-Path $ProjectPath 'PROJECT_STATE.md'
  if (-not (Test-Path -LiteralPath $state)) { return $null }
  try {
    $lines = Get-Content -LiteralPath $state -Encoding UTF8 -ErrorAction SilentlyContinue
    $next = $null
    $obj = $null
    $pkg = $null
    foreach ($ln in $lines) {
      if ($ln -match '^\s*-\s*Next:\s*(.+)\s*$') { $next = $Matches[1].Trim() }
      if ($ln -match '^\s*-\s*Package:\s*(.+)\s*$') { $pkg = $Matches[1].Trim() }
      if (-not $obj -and $ln -match '^##\s+Objective') { $obj = 'see' }
      elseif ($obj -eq 'see' -and $ln.Trim() -ne '' -and $ln -notmatch '^#') {
        $obj = $ln.Trim()
        if ($obj.Length -gt 160) { $obj = $obj.Substring(0, 157) + '...' }
      }
    }
    return [pscustomobject]@{ Next = $next; Objective = $obj; Package = $pkg }
  } catch { return $null }
}

function Format-RelativeTime {
  param($Dt)
  if (-not $Dt) { return '-' }
  try {
    $span = (Get-Date) - [DateTime]$Dt
    if ($span.TotalMinutes -lt 1) { return 'just now' }
    if ($span.TotalMinutes -lt 60) { return ('{0:N0}m ago' -f $span.TotalMinutes) }
    if ($span.TotalHours -lt 24) { return ('{0:N0}h ago' -f $span.TotalHours) }
    if ($span.TotalDays -lt 14) { return ('{0:N0}d ago' -f $span.TotalDays) }
    return Format-DateTime $Dt
  } catch { return Format-DateTime $Dt }
}

function Write-BoxWrapped {
  param(
    [string]$Label,
    [string]$Text,
    [ConsoleColor]$Fg = [ConsoleColor]::Gray,
    [int]$MaxLines = 4
  )
  if ([string]::IsNullOrWhiteSpace($Text)) { return }
  $inner = Get-InnerWidth
  $labW = 11
  $textW = $inner - $labW - 3
  if ($textW -lt 20) { $textW = 20 }
  $Text = ($Text -replace '[\r\n]+', ' ').Trim()
  $chunks = New-Object System.Collections.Generic.List[string]
  $rest = $Text
  while ($rest.Length -gt 0 -and $chunks.Count -lt $MaxLines) {
    if ((Get-DisplayWidth $rest) -le $textW) {
      $chunks.Add($rest) | Out-Null
      $rest = ''
      break
    }
    # take by display width approx via char walk
    $acc = ''
    foreach ($ch in $rest.ToCharArray()) {
      $try = $acc + $ch
      if ((Get-DisplayWidth $try) -gt $textW) { break }
      $acc = $try
    }
    if ($acc.Length -lt 1) { $acc = $rest.Substring(0, [Math]::Min(20, $rest.Length)) }
    $chunks.Add($acc) | Out-Null
    $rest = $rest.Substring($acc.Length).TrimStart()
  }
  if ($rest.Length -gt 0 -and $chunks.Count -ge $MaxLines) {
    $last = $chunks[$chunks.Count - 1]
    $chunks[$chunks.Count - 1] = (Pad-Display -Text ($last.TrimEnd() + '...') -Width $textW)
  }
  for ($i = 0; $i -lt $chunks.Count; $i++) {
    $lab = if ($i -eq 0) { Pad-Display -Text $Label -Width $labW } else { Pad-Display -Text '' -Width $labW }
    $body = ' ' + $lab + ' ' + (Pad-Display -Text $chunks[$i] -Width $textW -NoTrim)
    $body = Pad-Display -Text $body -Width $inner -NoTrim
    Write-FullLine -Text ('  |' + $body + '|') -Fg $Fg
  }
}

function Read-SessionSummaries {
  $rows = @()
  if (-not (Test-Path -LiteralPath $script:SessionsRoot)) { return $rows }
  $files = Get-ChildItem -LiteralPath $script:SessionsRoot -Recurse -Filter 'summary.json' -File -ErrorAction SilentlyContinue
  foreach ($f in $files) {
    try {
      $j = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch { continue }

    $id = $null; $cwd = $null
    if ($j.info) { $id = $j.info.id; $cwd = $j.info.cwd }
    if (-not $id) { $id = $j.id }
    if (-not $cwd) { $cwd = $j.cwd }
    if (-not $id) { $id = Split-Path $f.DirectoryName -Leaf }

    $updated = ConvertFrom-IsoTime ($j.last_active_at)
    if (-not $updated) { $updated = ConvertFrom-IsoTime ($j.updated_at) }
    if (-not $updated) { $updated = $f.LastWriteTime }

    $title = $j.generated_title
    if ([string]::IsNullOrWhiteSpace($title)) { $title = $j.session_summary }
    if ([string]::IsNullOrWhiteSpace($title)) { $title = '' }

    $sessionCwd = if ($cwd) { ([string]$cwd).Trim().Replace('/', '\').TrimEnd('\') } else { '' }
    $gitRoot = $null
    if ($j.git_root_dir) {
      $gitRoot = ([string]$j.git_root_dir).Trim().Replace('/', '\').TrimEnd('\')
      if ($gitRoot -and ((Test-NoiseCwd -Cwd $sessionCwd) -or (Test-WeakPath -Cwd $sessionCwd))) {
        if (-not (Test-NoiseCwd -Cwd $gitRoot) -and (Test-StrongProjectPath -Cwd $gitRoot)) {
          $cwd = $gitRoot
        }
      }
    }
    # Prefer bound project path when session was started under weak home
    $workPath = if ($cwd) { ([string]$cwd).Trim().Replace('/', '\').TrimEnd('\') } else { $sessionCwd }
    if (Test-WeakPath -Cwd $workPath) {
      # keep raw for identity flag; Project will be (system) unless remapped later
    }
    $proj = Resolve-ProjectName -Path $workPath -FallbackLeaf $(if ($workPath) { Split-Path -Leaf $workPath } else { '' })

    $modelRaw = if ($j.current_model_id) { [string]$j.current_model_id } else { '' }
    $agent = if ($j.agent_name) { [string]$j.agent_name } else { '' }
    $model = Get-ModelDisplay -ModelId $modelRaw -AgentName $agent

    $chatMsgs = 0
    if ($null -ne $j.num_chat_messages) { $chatMsgs = [int]$j.num_chat_messages }
    $totalMsgs = 0
    if ($null -ne $j.num_messages) { $totalMsgs = [int]$j.num_messages }
    $msgsShow = if ($totalMsgs -gt 0) { $totalMsgs } else { $chatMsgs }

    $branch = if ($j.head_branch) { [string]$j.head_branch } else { '-' }
    $effort = if ($j.reasoning_effort) { [string]$j.reasoning_effort } else { '-' }
    $last = if ($j.last_turn_summary) { [string]$j.last_turn_summary } else { '' }

    $diskBytes = Get-SessionDiskBytes -SessionDir $f.DirectoryName
    $prompts = @(Get-RecentPrompts -SessionId ([string]$id) -SessionDir $f.DirectoryName -Count 3)
    $excerpt = if ($prompts.Count -gt 0) { $prompts[0] } else { $last }
    if ([string]::IsNullOrWhiteSpace($excerpt)) { $excerpt = $last }
    $sessSummary = if ($j.session_summary) { [string]$j.session_summary } else { '' }

    $rows += [pscustomobject]@{
      Kind = 'session'; Id = [string]$id; Cwd = [string]$workPath; Project = [string]$proj
      Title = [string]$title; Model = [string]$model; Agent = [string]$agent
      Msgs = [int]$msgsShow; ChatMsgs = [int]$chatMsgs; TotalMsgs = [int]$totalMsgs
      Branch = [string]$branch; Effort = [string]$effort; Updated = $updated
      LastTurn = [string]$last; Excerpt = [string]$excerpt; GitRoot = [string]$gitRoot
      DiskBytes = [long]$diskBytes; SessionDir = $f.DirectoryName
      SessionSummary = $sessSummary
      RecentPrompts = $prompts
      SessionCwd = [string]$sessionCwd
      IsWeak = [bool](Test-WeakPath -Cwd $workPath)
    }
  }
  return @($rows | Sort-Object Updated -Descending)
}

function Test-KeepUnboundSession {
  param($S, [bool]$ShowAll)
  if (Test-NoiseCwd -Cwd $S.Cwd) { return $false }
  if ($ShowAll) { return -not [string]::IsNullOrWhiteSpace($S.Cwd) }
  if (Test-BadTitle -Title $S.Title) { return $false }
  if (Test-WeakHomeCwd -Cwd $S.Cwd -and -not $S.GitRoot) {
    if ($S.Updated -and $S.Updated -lt (Get-Date).AddDays(-7)) { return $false }
    if ($S.DiskBytes -lt 2048) { return $false }
  }
  if ($S.Updated -and $S.Updated -lt (Get-Date).AddDays(-$script:RecentDays)) { return $false }
  return $true
}

function Build-Rows {
  $script:DeskRoots = Read-DeskRoots
  $sessions = Read-SessionSummaries
  $out = @()
  $i = 1
  $usedSessionIds = @{}
  $seenPath = @{}

  # Layer A: bound projects ONLY if strong path + non-reserved name (R2/R5)
  foreach ($name in $script:DeskRoots.Keys) {
    if ($i -gt $script:MaxRows) { break }
    $path = $script:DeskRoots[$name]
    if (-not $path) { continue }
    if (Test-ReservedName -Name $name) { continue }
    if (-not (Test-StrongProjectPath -Cwd $path)) { continue }
    $pk = Normalize-PathKey $path
    $exists = Test-Path -LiteralPath $path

    $best = $null
    foreach ($s in $sessions) {
      $sc = Normalize-PathKey $(if ($s.GitRoot -and (Test-StrongProjectPath -Cwd $s.GitRoot)) { $s.GitRoot } else { $s.Cwd })
      if (-not $sc) { continue }
      if ($sc -eq $pk -or $sc.StartsWith($pk + '\')) {
        if (-not $best -or $s.Updated -gt $best.Updated) { $best = $s }
      }
    }

    if ($best) {
      $usedSessionIds[$best.Id] = $true
      $seenPath[$pk] = $true
      $out += [pscustomobject]@{
        Index = $i; Kind = 'session'; Layer = 'bound'
        Id = $best.Id; Cwd = $path; Project = $name
        Title = $best.Title; Model = $best.Model; Agent = $best.Agent
        Msgs = $best.Msgs; ChatMsgs = $best.ChatMsgs; TotalMsgs = $best.TotalMsgs
        Branch = $best.Branch; Effort = $best.Effort
        Updated = $best.Updated; LastTurn = $best.LastTurn; Excerpt = $best.Excerpt
        Badge = 'TASK'; Hint = 'Enter=resume  n=new session'
        SessionDir = $best.SessionDir; SessionSummary = $best.SessionSummary
        RecentPrompts = $best.RecentPrompts; DiskBytes = $best.DiskBytes
        GitRoot = $best.GitRoot
        SessionCwd = $best.SessionCwd
        IsWeak = $false
      }
    } else {
      $seenPath[$pk] = $true
      $title = if ($exists) {
        "[task] $name  - no session yet - Enter to open"
      } else {
        "[task] $name  - path missing - press c to recreate"
      }
      $out += [pscustomobject]@{
        Index = $i; Kind = 'project'; Layer = 'bound'
        Id = ''; Cwd = $path; Project = $name
        Title = $title; Model = ''; Agent = ''; Msgs = 0
        ChatMsgs = 0; TotalMsgs = 0
        Branch = ''; Effort = ''; Updated = (Get-Date)
        LastTurn = 'desk-roots binding'; Excerpt = "grok --cwd $path"
        Badge = 'TASK'; Hint = 'Enter=open  c=wizard'
        SessionDir = ''; SessionSummary = ''; RecentPrompts = @(); DiskBytes = 0
        GitRoot = $path
        SessionCwd = ''; IsWeak = $false
      }
    }
    $i++
  }

  # Layer B: favorites (strong only)
  foreach ($fav in (Read-Favorites)) {
    if ($i -gt $script:MaxRows) { break }
    if (-not (Test-StrongProjectPath -Cwd $fav)) { continue }
    $pk = Normalize-PathKey $fav
    if ($seenPath.ContainsKey($pk)) { continue }
    $name = Resolve-ProjectName -Path $fav
    $seenPath[$pk] = $true
    $out += [pscustomobject]@{
      Index = $i; Kind = 'project'; Layer = 'fav'
      Id = ''; Cwd = $fav; Project = $name
      Title = "[fav] $name  - Enter open / c to bind as task"
      Model = ''; Agent = ''; Msgs = 0
      Branch = ''; Effort = ''; Updated = (Get-Date)
      LastTurn = 'favorites.txt'; Excerpt = $fav
      Badge = 'FAV'; Hint = 'Enter=open'
      SessionCwd = ''; IsWeak = $false
    }
    $i++
  }

  # Layer C: unbound recent titled sessions (strong paths only unless -All)
  foreach ($s in $sessions) {
    if ($i -gt $script:MaxRows) { break }
    if ($usedSessionIds.ContainsKey($s.Id)) { continue }
    if (-not (Test-KeepUnboundSession -S $s -ShowAll $script:ShowAll)) { continue }
    $cwdShow = if ($s.GitRoot -and (Test-StrongProjectPath -Cwd $s.GitRoot)) { $s.GitRoot } else { $s.Cwd }
    $isWeak = Test-WeakPath -Cwd $cwdShow
    # R2 demote: weak sessions hidden by default; only with a (Show All)
    if ($isWeak -and -not $script:ShowAll) { continue }
    $pathKey = Normalize-PathKey $cwdShow
    if ($pathKey -and $seenPath.ContainsKey($pathKey) -and -not $isWeak) { continue }
    if ($pathKey -and -not $isWeak) { $seenPath[$pathKey] = $true }
    $usedSessionIds[$s.Id] = $true
    $projName = if ($isWeak) { '(system)' } else { Resolve-ProjectName -Path $cwdShow -FallbackLeaf $s.Project }
    $out += [pscustomobject]@{
      Index = $i; Kind = 'session'; Layer = $(if ($isWeak) { 'system' } else { 'recent' })
      Id = $s.Id; Cwd = $cwdShow; Project = $projName
      Title = $s.Title; Model = $s.Model; Agent = $s.Agent
      Msgs = $s.Msgs; ChatMsgs = $s.ChatMsgs; TotalMsgs = $s.TotalMsgs
      Branch = $s.Branch; Effort = $s.Effort
      Updated = $s.Updated; LastTurn = $s.LastTurn; Excerpt = $s.Excerpt
      Badge = $(if ($isWeak) { 'SYS' } else { 'RECENT' })
      Hint = $(if ($isWeak) { 'weak cwd - c to bind real project' } else { 'Enter=resume  (unbound; use c to bind)' })
      SessionDir = $s.SessionDir; SessionSummary = $s.SessionSummary
      RecentPrompts = $s.RecentPrompts; DiskBytes = $s.DiskBytes
      GitRoot = $s.GitRoot
      SessionCwd = $s.SessionCwd
      IsWeak = $isWeak
    }
    $i++
  }

  $script:Rows = $out
  if ($script:Rows.Count -eq 0) { $script:Selected = 0 }
  elseif ($script:Selected -ge $script:Rows.Count) { $script:Selected = $script:Rows.Count - 1 }
  return $out
}

# =============================================================================
# Color standard
#   DarkGray  = unimportant meta (act*, sid, secondary help)
#   Gray      = normal body
#   White     = primary content (project/path, input focus line)
#   Green     = selection row OR success
#   Red       = error / missing path only
#   Yellow    = temporary note OR high-priority key chips in COMMAND
# Zone border colors (different per section, not rainbow body text):
#   HEADER   = DarkGray
#   1 LIST   = Cyan
#   2 SELECTED = Green
#   3 COMMAND  = Yellow  (hottest — this is where you type)
# =============================================================================

function Get-UiWidth {
  # Content band = 70% of the full pane/window width (NOT "narrow to 30%").
  # Left-aligned; right ~30% stays empty for stretch adaptability.
  try {
    $full = [Math]::Max(80, $Host.UI.RawUI.WindowSize.Width - 1)
    return [Math]::Max(64, [Math]::Floor($full * 0.70))
  } catch {
    return 90
  }
}

function Write-FullLine {
  param([string]$Text, [ConsoleColor]$Fg = [ConsoleColor]::Gray)
  $width = Get-UiWidth
  if ($null -eq $Text) { $Text = '' }
  $line = Pad-Display -Text $Text -Width $width -NoTrim
  Write-Host $line -ForegroundColor $Fg
  $script:DrawnLines++
}

function Reset-Screen {
  try {
    $raw = $Host.UI.RawUI
    $script:BufH = [Math]::Max(24, $raw.WindowSize.Height)
    $width = Get-UiWidth
    $blank = ' ' * $width
    $raw.CursorVisible = $false
    $raw.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 0, 0
    for ($i = 0; $i -lt $script:BufH; $i++) { [Console]::WriteLine($blank) }
    $raw.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 0, 0
  } catch { Clear-Host }
  $script:DrawnLines = 0
}

function End-Screen {
  # No blank padding — keeps cursor next to COMMAND bar
  try { $Host.UI.RawUI.CursorVisible = $true } catch {}
}

function Get-InnerWidth {
  return [Math]::Max(48, (Get-UiWidth) - 6)
}

function Write-BoxTop {
  param([string]$Title, [ConsoleColor]$Border = [ConsoleColor]::DarkGray)
  $inner = Get-InnerWidth
  $t = " $Title "
  $tw = Get-DisplayWidth $t
  if ($tw -gt ($inner - 4)) {
    $t = Pad-Display -Text $Title -Width ($inner - 4)
    $t = " $t "
    $tw = Get-DisplayWidth $t
  }
  $fill = $inner - $tw
  if ($fill -lt 0) { $fill = 0 }
  $left = [Math]::Floor($fill / 2)
  $right = $fill - $left
  $line = '  +' + ('-' * $left) + $t + ('-' * $right) + '+'
  Write-FullLine -Text $line -Fg $Border
}

function Write-BoxBottom {
  param([ConsoleColor]$Border = [ConsoleColor]::DarkGray)
  $inner = Get-InnerWidth
  Write-FullLine -Text ('  +' + ('-' * $inner) + '+') -Fg $Border
}

function Write-BoxRule {
  param([ConsoleColor]$Border = [ConsoleColor]::DarkGray)
  $inner = Get-InnerWidth
  Write-FullLine -Text ('  |' + ('-' * $inner) + '|') -Fg $Border
}

function Write-BoxLine {
  param(
    [string]$Text,
    [ConsoleColor]$Fg = [ConsoleColor]::Gray,
    [ConsoleColor]$Border = [ConsoleColor]::DarkGray
  )
  $inner = Get-InnerWidth
  if ($null -eq $Text) { $Text = '' }
  $body = Pad-Display -Text (' ' + $Text) -Width $inner -NoTrim
  # Single color per line (console limitation); body color carries meaning
  Write-FullLine -Text ('  |' + $body + '|') -Fg $Fg
}

function Write-BoxKeyValue {
  param(
    [string]$Label,
    [string]$Value,
    [ConsoleColor]$ValueFg = [ConsoleColor]::Gray
  )
  if ([string]::IsNullOrWhiteSpace($Value)) { $Value = '-' }
  $inner = Get-InnerWidth
  $lab = Pad-Display -Text $Label -Width 11
  $rest = $inner - 14
  if ($rest -lt 10) { $rest = 10 }
  $val = Pad-Display -Text $Value -Width $rest
  $body = ' ' + $lab + ' ' + $val
  $body = Pad-Display -Text $body -Width $inner -NoTrim
  Write-FullLine -Text ('  |' + $body + '|') -Fg $ValueFg
}

# Multi-color key row: border + segments (keys HIGHLIGHT, labels gray)
function Write-BoxKeyRow {
  param(
    [ConsoleColor]$Border = [ConsoleColor]::Yellow,
    [object[]]$Parts
  )
  # Parts: array of @{ T='text'; C=[ConsoleColor] }
  $inner = Get-InnerWidth
  $raw = $Host.UI.RawUI
  try {
    $x0 = 0
    $y0 = $raw.CursorPosition.Y
  } catch {}

  Write-Host -NoNewline '  |' -ForegroundColor $Border
  $used = 0
  Write-Host -NoNewline ' ' -ForegroundColor Gray
  $used = 1
  foreach ($p in $Parts) {
    $t = [string]$p.T
    $c = $p.C
    if (-not $c) { $c = [ConsoleColor]::Gray }
    Write-Host -NoNewline $t -ForegroundColor $c
    $used += (Get-DisplayWidth $t)
  }
  $pad = $inner - $used
  if ($pad -gt 0) { Write-Host -NoNewline (' ' * $pad) -ForegroundColor DarkGray }
  Write-Host '|' -ForegroundColor $Border
  $script:DrawnLines++
}

# Column layout for content band = 70% of full window width.
# Guarantee: Title ~45%+, Project ~20%+ of the band; gaps wide (3–6 spaces).
function Update-ColLayout {
  $inner = Get-InnerWidth
  $U = [Math]::Max(60, $inner - 1)

  # --- Flexible primary fields (must stay readable) ---
  $title = [Math]::Max(34, [Math]::Floor($U * 0.45))
  $proj  = [Math]::Max(18, [Math]::Floor($U * 0.20))

  # --- Compact meta ---
  $flagW = 2
  $num = 3
  $date = 11
  $badge = 5
  $model = 9
  $act = 5
  $branch = 0   # hide branch in list by default → more title room
  # parts: flag num date badge proj model act title = 8 → 7 gaps
  $gapsN = 7

  $meta = $num + $date + $badge + $model + $act + $branch
  $core = $flagW + $meta + $title + $proj

  # Gaps: use leftover; prefer 4–6 spaces when band is wide
  $gapPool = $U - $core
  if ($gapPool -lt ($gapsN * 3)) {
    # shrink model first, then date, then slightly title
    $need = ($gapsN * 3) - $gapPool
    if ($model -gt 7) {
      $cut = [Math]::Min($need, $model - 7)
      $model -= $cut
      $need -= $cut
    }
    if ($need -gt 0 -and $date -gt 9) {
      $cut = [Math]::Min($need, $date - 9)
      $date -= $cut
      $need -= $cut
    }
    if ($need -gt 0) {
      $title = [Math]::Max(28, $title - $need)
    }
    $meta = $num + $date + $badge + $model + $act + $branch
    $core = $flagW + $meta + $title + $proj
    $gapPool = $U - $core
  }

  # Gap width from leftover only — never force a gap that overflows the band
  # (overflow made Pad-Display chop Title from the right → "DingT~")
  $gapPool = $U - $flagW - $meta - $title - $proj
  if ($gapPool -lt 0) {
    $title = [Math]::Max(24, $title + $gapPool)
    $gapPool = $U - $flagW - $meta - $title - $proj
  }
  $gapW = if ($gapsN -gt 0) { [Math]::Floor($gapPool / $gapsN) } else { 2 }
  if ($gapW -lt 2) { $gapW = 2 }
  if ($gapW -gt 6) { $gapW = 6 }

  # Fit exactly to U: leftover → Title; still over → shrink Title
  $used = $flagW + $meta + $title + $proj + ($gapsN * $gapW)
  $leftover = $U - $used
  if ($leftover -gt 0) {
    $title += $leftover
  } elseif ($leftover -lt 0) {
    $title = [Math]::Max(20, $title + $leftover)
    # if still over, drop gap to 2 and re-fit
    $used2 = $flagW + $meta + $title + $proj + ($gapsN * $gapW)
    if ($used2 -gt $U) {
      $gapW = 2
      $title = [Math]::Max(20, $U - $flagW - $meta - $proj - ($gapsN * $gapW))
    }
  }

  $script:ColGap = ' ' * $gapW
  $script:Col = @{
    Num    = $num
    Date   = $date
    Badge  = $badge
    Proj   = $proj
    Model  = $model
    Act    = $act
    Branch = $branch
    Title  = $title
  }
}

function Format-TableRow {
  param(
    [bool]$Selected, [string]$Num, [string]$Date, [string]$Badge,
    [string]$Proj, [string]$Model, [string]$Act, [string]$Branch, [string]$Title
  )
  $flag = if ($Selected) { '> ' } else { '  ' }
  $br = if ($script:Col.Branch -le 0) { '' } else {
    Pad-Display -Text $(if ([string]::IsNullOrEmpty($Branch) -or $Branch -eq '-') { '' } else { $Branch }) -Width $script:Col.Branch
  }
  $parts = @(
    $flag,
    (Pad-Display -Text $Num -Width $script:Col.Num -Align Right),
    (Pad-Display -Text $Date -Width $script:Col.Date),
    (Pad-Display -Text $Badge -Width $script:Col.Badge),
    (Pad-Display -Text $Proj -Width $script:Col.Proj),
    (Pad-Display -Text $(if ([string]::IsNullOrEmpty($Model)) { '' } else { $Model }) -Width $script:Col.Model),
    (Pad-Display -Text $Act -Width $script:Col.Act -Align Right)
  )
  if ($script:Col.Branch -gt 0) { $parts += $br }
  $parts += (Pad-Display -Text $Title -Width $script:Col.Title)
  return ($parts -join $script:ColGap)
}

function Format-HeaderRow {
  $flag = '  '
  $parts = @(
    $flag,
    (Pad-Display -Text '#' -Width $script:Col.Num -Align Right),
    (Pad-Display -Text 'DateTime' -Width $script:Col.Date),
    (Pad-Display -Text 'Tag' -Width $script:Col.Badge),
    (Pad-Display -Text 'Project' -Width $script:Col.Proj),
    (Pad-Display -Text 'Model' -Width $script:Col.Model),
    (Pad-Display -Text 'Act*' -Width $script:Col.Act -Align Right)
  )
  if ($script:Col.Branch -gt 0) {
    $parts += (Pad-Display -Text 'Branch' -Width $script:Col.Branch)
  }
  $parts += (Pad-Display -Text 'Title' -Width $script:Col.Title)
  return ($parts -join $script:ColGap)
}

function Show-Screen {
  $rows = Build-Rows
  Reset-Screen
  Update-ColLayout
  $now = Get-Date -Format 'yyyy-MM-dd HH:mm'
  $view = if ($script:ShowAll) { 'ALL non-noise' } else { 'bound + fav + titled-recent' }
  $hint = $script:StatusHint
  $script:StatusHint = ''

  # Zone borders
  $bHead = [ConsoleColor]::DarkGray
  $bList = [ConsoleColor]::Cyan
  $bSel  = [ConsoleColor]::Green
  $bCmd  = [ConsoleColor]::Yellow

  # ----- HEADER -----
  Write-BoxTop -Title 'WZ INIT' -Border $bHead
  Write-BoxLine -Text ("$now   rows $($rows.Count)   $view") -Fg DarkGray -Border $bHead
  if ($hint) {
    Write-BoxRule -Border $bHead
    Write-BoxLine -Text ("! $hint") -Fg Yellow -Border $bHead
  }
  Write-BoxBottom -Border $bHead

  # ----- 1 LIST (Cyan border) -----
  Write-BoxTop -Title '1 LIST' -Border $bList
  $hdr = Pad-Display -Text (Format-HeaderRow) -Width (Get-InnerWidth) -NoTrim
  Write-FullLine -Text ('  |' + $hdr + '|') -Fg DarkGray
  Write-BoxRule -Border $bList

  if ($rows.Count -eq 0) {
    Write-BoxLine -Text '(empty)  press  c  in COMMAND to create first task' -Fg Gray -Border $bList
  } else {
    $innerList = Get-InnerWidth
    for ($idx = 0; $idx -lt $rows.Count; $idx++) {
      $r = $rows[$idx]
      $sel = ($idx -eq $script:Selected)
      $act = if ($r.Msgs -gt 0) { [string]$r.Msgs } else { '' }
      $line = Format-TableRow -Selected $sel -Num ([string]$r.Index) `
        -Date (Format-DateTime $r.Updated) -Badge $(if ($r.Badge) { $r.Badge } else { '' }) `
        -Proj $r.Project -Model $(if ($r.Model) { $r.Model } else { '' }) `
        -Act $act -Branch $(if ($r.Branch -and $r.Branch -ne '-') { $r.Branch } else { '' }) `
        -Title $r.Title
      # Pad to exact inner width (no extra leading space — row already has flag gutter)
      $body = Pad-Display -Text $line -Width $innerList -NoTrim
      $fg = if ($sel) { [ConsoleColor]::Green } else { [ConsoleColor]::Gray }
      Write-FullLine -Text ('  |' + $body + '|') -Fg $fg
    }
  }
  Write-BoxBottom -Border $bList

  # Double vertical gap between major modules (2x previous zero-gap)
  Write-FullLine -Text ''
  Write-FullLine -Text ''

  # ----- 2 DETAIL (Green) - recall aid for the task -----
  Write-BoxTop -Title '2 DETAIL - recall this task' -Border $bSel
  if ($rows.Count -gt 0) {
    $cur = $rows[$script:Selected]
    $pathMissing = ($cur.Cwd -and -not (Test-Path -LiteralPath $cur.Cwd))

    # --- identity (high contrast): PROJECT name ≠ session title ≠ session cwd leaf ---
    Write-BoxKeyValue -Label 'PROJECT' -Value $cur.Project -ValueFg White
    if ($pathMissing) {
      Write-BoxKeyValue -Label 'PATH' -Value ("MISSING  $($cur.Cwd)") -ValueFg Red
    } else {
      Write-BoxKeyValue -Label 'PATH' -Value $cur.Cwd -ValueFg White
    }
    if ($cur.SessionCwd -and (Normalize-PathKey $cur.SessionCwd) -ne (Normalize-PathKey $cur.Cwd)) {
      Write-BoxKeyValue -Label 'sess-cwd' -Value $cur.SessionCwd -ValueFg DarkYellow
    }
    if ($cur.IsWeak) {
      Write-BoxKeyValue -Label 'GATE' -Value 'weak/system cwd — not a formal task (use c wizard)' -ValueFg Red
    }
    Write-BoxKeyValue -Label 'layer' -Value ("{0} | {1}" -f $cur.Layer, $cur.Badge) -ValueFg Gray
    Write-BoxKeyValue -Label 'active' -Value (Format-RelativeTime $cur.Updated) -ValueFg White
    Write-BoxKeyValue -Label 'when' -Value (Format-DateTime $cur.Updated) -ValueFg DarkGray

    Write-BoxRule -Border $bSel

    # --- conversation identity (title is NOT project name) ---
    Write-BoxKeyValue -Label 'title' -Value $(if ($cur.Title) { $cur.Title } else { '(no title)' }) -ValueFg Cyan
    if ($cur.SessionSummary -and $cur.SessionSummary -ne $cur.Title) {
      Write-BoxWrapped -Label 'about' -Text $cur.SessionSummary -Fg Gray -MaxLines 2
    }

    # --- last AI turn (primary recall) ---
    $turn = $cur.LastTurn
    if ([string]::IsNullOrWhiteSpace($turn)) { $turn = $cur.Excerpt }
    if (-not [string]::IsNullOrWhiteSpace($turn)) {
      Write-BoxRule -Border $bSel
      Write-BoxWrapped -Label 'LAST TURN' -Text $turn -Fg White -MaxLines 4
    }

    # --- recent user prompts ---
    $prompts = @()
    if ($cur.RecentPrompts) { $prompts = @($cur.RecentPrompts) }
    if ($prompts.Count -eq 0 -and $cur.SessionDir) {
      $prompts = @(Get-RecentPrompts -SessionId $cur.Id -SessionDir $cur.SessionDir -Count 3)
    }
    if ($prompts.Count -gt 0) {
      Write-BoxRule -Border $bSel
      Write-BoxLine -Text ' recent prompts (newest first)' -Fg DarkGray -Border $bSel
      $n = 1
      foreach ($p in $prompts) {
        Write-BoxWrapped -Label ("  Q$n") -Text $p -Fg Gray -MaxLines 2
        $n++
      }
    }

    # --- project state (PPS) if present ---
    $hint = Get-ProjectStateHint -ProjectPath $cur.Cwd
    if ($hint -and ($hint.Next -or $hint.Objective -or $hint.Package)) {
      Write-BoxRule -Border $bSel
      if ($hint.Package) {
        Write-BoxKeyValue -Label 'package' -Value $hint.Package -ValueFg Gray
      }
      if ($hint.Objective) {
        Write-BoxWrapped -Label 'objective' -Text $hint.Objective -Fg White -MaxLines 3
      }
      if ($hint.Next) {
        Write-BoxWrapped -Label 'NEXT' -Text $hint.Next -Fg Yellow -MaxLines 3
      }
    }

    Write-BoxRule -Border $bSel

    # --- meta strip ---
    $meta = @(
      $(if ($cur.Model) { $cur.Model } else { 'no-model' }),
      $(if ($cur.Branch -and $cur.Branch -ne '-') { 'br:' + $cur.Branch } else { $null }),
      $(if ($cur.Effort -and $cur.Effort -ne '-') { 'effort:' + $cur.Effort } else { $null }),
      ('msgs:' + $cur.Msgs),
      $(if ($cur.ChatMsgs) { 'chat:' + $cur.ChatMsgs } else { $null })
    ) | Where-Object { $_ }
    Write-BoxKeyValue -Label 'meta' -Value ($meta -join ' | ') -ValueFg DarkGray
    if ($cur.Id) {
      $sidShort = $cur.Id
      if ($sidShort.Length -gt 36) { $sidShort = $sidShort.Substring(0, 34) + '..' }
      Write-BoxKeyValue -Label 'sid' -Value $sidShort -ValueFg DarkGray
    } else {
      Write-BoxKeyValue -Label 'sid' -Value '(no session yet - Enter opens new)' -ValueFg DarkGray
    }
    Write-BoxKeyValue -Label 'action' -Value $(if ($cur.Hint) { $cur.Hint } else { 'Enter open' }) -ValueFg Green
  } else {
    Write-BoxLine -Text 'No selection. Press c in COMMAND to create a task.' -Fg Gray -Border $bSel
  }
  Write-BoxBottom -Border $bSel

  # Double vertical gap between DETAIL and COMMAND
  Write-FullLine -Text ''
  Write-FullLine -Text ''

  # ----- 3 COMMAND (Yellow border + loud key chips) -----
  Write-BoxTop -Title '3 COMMAND  << type keys here' -Border $bCmd

  # Input focus line - White, tight under title
  $inner = Get-InnerWidth
  $field = ' >_  waiting for key...'
  $field = Pad-Display -Text $field -Width $inner -NoTrim
  Write-FullLine -Text ('  |' + $field + '|') -Fg $bCmd

  Write-BoxRule -Border $bCmd

  # PRIMARY keys — each key token Yellow/White, labels Gray
  Write-BoxKeyRow -Border $bCmd -Parts @(
    @{ T = '[ Enter ]'; C = [ConsoleColor]::Yellow },
    @{ T = ' open/resume selected'; C = [ConsoleColor]::Gray },
    @{ T = '    '; C = [ConsoleColor]::DarkGray },
    @{ T = '[ c ]'; C = [ConsoleColor]::Yellow },
    @{ T = ' NEW TASK wizard'; C = [ConsoleColor]::White }
  )
  Write-BoxKeyRow -Border $bCmd -Parts @(
    @{ T = '[  n  ]'; C = [ConsoleColor]::Yellow },
    @{ T = ' new session in project'; C = [ConsoleColor]::Gray },
    @{ T = '    '; C = [ConsoleColor]::DarkGray },
    @{ T = '[ j/k ]'; C = [ConsoleColor]::Yellow },
    @{ T = ' move'; C = [ConsoleColor]::Gray }
  )
  Write-BoxRule -Border $bCmd
  # Secondary — quieter, but keys still Yellow
  Write-BoxKeyRow -Border $bCmd -Parts @(
    @{ T = '[a]'; C = [ConsoleColor]::Yellow },
    @{ T = ' looser  '; C = [ConsoleColor]::DarkGray },
    @{ T = '[r]'; C = [ConsoleColor]::Yellow },
    @{ T = ' refresh  '; C = [ConsoleColor]::DarkGray },
    @{ T = '[i]'; C = [ConsoleColor]::Yellow },
    @{ T = ' detail  '; C = [ConsoleColor]::DarkGray },
    @{ T = '[d]'; C = [ConsoleColor]::Yellow },
    @{ T = ' dash  '; C = [ConsoleColor]::DarkGray },
    @{ T = '[0-9]'; C = [ConsoleColor]::Yellow },
    @{ T = ' jump  '; C = [ConsoleColor]::DarkGray },
    @{ T = '[q]'; C = [ConsoleColor]::Yellow },
    @{ T = ' quit'; C = [ConsoleColor]::DarkGray }
  )
  Write-BoxBottom -Border $bCmd

  End-Screen
}

function Get-RowByIndex {
  param([int]$Num)
  foreach ($r in $script:Rows) { if ($r.Index -eq $Num) { return $r } }
  return $null
}

function Get-SelectedRow {
  if ($script:Rows.Count -eq 0) { return $null }
  return $script:Rows[$script:Selected]
}

function Resolve-LaunchCwd {
  # R1: never hand Grok a weak path as session identity
  param($Row)
  if (-not $Row) { return $null }
  $path = $Row.Cwd
  if ($path -and (Test-StrongProjectPath -Cwd $path) -and (Test-Path -LiteralPath $path)) {
    return $path
  }
  # try bound name
  if ($Row.Project -and -not (Test-ReservedName -Name $Row.Project)) {
    $bound = $script:DeskRoots[$Row.Project]
    if ($bound -and (Test-StrongProjectPath -Cwd $bound) -and (Test-Path -LiteralPath $bound)) {
      return $bound
    }
  }
  return $null
}

function Start-GrokTab {
  param(
    [string]$Cwd,
    [string[]]$GrokArgs,
    [string]$Title = 'grok'
  )
  if (-not (Test-Path -LiteralPath $script:Grok)) {
    $script:StatusHint = 'grok.exe not found'
    return
  }
  # R1 hard gate
  if (-not (Test-StrongProjectPath -Cwd $Cwd)) {
    $script:StatusHint = "GATE: refuse Grok on weak path ($Cwd) — press c for new task"
    return
  }
  if (-not (Test-Path -LiteralPath $Cwd)) {
    $script:StatusHint = "Path missing: $Cwd"
    return
  }
  # Always inject --cwd if caller forgot (R1)
  $hasCwd = $false
  if ($GrokArgs) {
    for ($gi = 0; $gi -lt $GrokArgs.Count; $gi++) {
      if ($GrokArgs[$gi] -eq '--cwd' -or $GrokArgs[$gi] -eq '-C') { $hasCwd = $true; break }
      if ($GrokArgs[$gi] -like '--cwd=*') { $hasCwd = $true; break }
    }
  }
  if (-not $hasCwd) {
    $GrokArgs = @('--cwd', $Cwd) + @($GrokArgs | Where-Object { $_ })
  }

  $fullArgs = @(); if ($GrokArgs) { $fullArgs += $GrokArgs }
  if ($script:Wez -and (Test-WezAlive)) {
    $spawn = @('cli', 'spawn')
    $spawn += @('--cwd', $Cwd)
    $spawn += '--'
    $spawn += @($script:Grok) + $fullArgs
    try {
      & $script:Wez @spawn 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) {
        Write-Host ("  OK: {0}" -f $Title) -ForegroundColor Green
        Write-Host ("  --cwd {0}" -f $Cwd) -ForegroundColor DarkGray
        Start-Sleep -Seconds 0.6
        return
      }
    } catch {}
  }
  Set-Location -LiteralPath $Cwd
  & $script:Grok @fullArgs
}

function Invoke-RowPrimary {
  param($Row)
  if (-not $Row) {
    $script:StatusHint = 'No row selected - press c for new task wizard'
    return
  }
  if ($Row.IsWeak -or $Row.Layer -eq 'system') {
    $script:StatusHint = 'GATE: system/home session is not a formal task — press c to create/bind project'
    return
  }
  $launch = Resolve-LaunchCwd -Row $Row
  if (-not $launch) {
    $script:StatusHint = 'GATE: no strong project path — press c wizard'
    return
  }
  if ($Row.Kind -eq 'session' -and $Row.Id) {
    $a = @('--cwd', $launch, '--resume', $Row.Id)
    Start-GrokTab -Cwd $launch -GrokArgs $a -Title ("resume {0}" -f $Row.Project)
    return
  }
  Start-GrokTab -Cwd $launch -GrokArgs @('--cwd', $launch) -Title ("open {0}" -f $Row.Project)
}

function Invoke-RowNewSession {
  param($Row)
  if (-not $Row -or -not $Row.Cwd -or $Row.IsWeak -or $Row.Layer -eq 'system') {
    Invoke-NewTaskWizard
    return
  }
  $launch = Resolve-LaunchCwd -Row $Row
  if (-not $launch) {
    $script:StatusHint = 'Path missing/weak - use c wizard'
    return
  }
  Start-GrokTab -Cwd $launch -GrokArgs @('--cwd', $launch) -Title ("new {0}" -f $Row.Project)
}

function Show-RowDetail {
  param($Row)
  if (-not $Row) { return }
  try { $Host.UI.RawUI.CursorVisible = $true } catch {}
  Clear-Host
  Write-Host ''
  Write-Host '  DETAIL' -ForegroundColor Cyan
  Write-Host ("  PROJECT : {0}   (desk-roots name / .wz-project)" -f $Row.Project) -ForegroundColor White
  Write-Host ("  PATH    : {0}" -f $Row.Cwd) -ForegroundColor Yellow
  if ($Row.SessionCwd) {
    Write-Host ("  sess-cwd: {0}" -f $Row.SessionCwd) -ForegroundColor DarkYellow
  }
  Write-Host ("  layer   : {0} | {1}" -f $Row.Layer, $Row.Badge)
  Write-Host ("  time    : {0}" -f (Format-DateTime $Row.Updated))
  Write-Host ("  model   : {0}" -f $(if ($Row.Model) { $Row.Model } else { '(empty)' }))
  Write-Host ("  act*    : {0} (not a filter)" -f $Row.Msgs)
  Write-Host ("  sid     : {0}" -f $Row.Id)
  Write-Host ("  title   : {0}   (Grok chat title — NOT project name)" -f $Row.Title)
  Write-Host ("  summary : {0}" -f $Row.LastTurn) -ForegroundColor Gray
  if ($Row.IsWeak) {
    Write-Host '  GATE    : weak/system — refuse formal open; use c wizard' -ForegroundColor Red
  }
  Write-Host ''
  Write-Host '  any key...' -ForegroundColor DarkGray
  [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Move-Selection {
  param([int]$Delta)
  if ($script:Rows.Count -eq 0) { return }
  $script:Selected = $script:Selected + $Delta
  if ($script:Selected -lt 0) { $script:Selected = $script:Rows.Count - 1 }
  if ($script:Selected -ge $script:Rows.Count) { $script:Selected = 0 }
}

function Read-LinePrompt {
  param([string]$Label, [string]$Default = '')
  try { $Host.UI.RawUI.CursorVisible = $true } catch {}
  if ($Default) {
    Write-Host -NoNewline ("  {0} [{1}]: " -f $Label, $Default) -ForegroundColor Cyan
  } else {
    Write-Host -NoNewline ("  {0}: " -f $Label) -ForegroundColor Cyan
  }
  $v = Read-Host
  if ([string]::IsNullOrWhiteSpace($v)) { return $Default }
  return $v.Trim()
}

function Show-WizardHeader {
  param([string]$Step)
  Clear-Host
  Write-Host ''
  Write-Host '  ========================================================' -ForegroundColor DarkGray
  Write-Host '   WZ NEW TASK WIZARD' -ForegroundColor White
  Write-Host '  ========================================================' -ForegroundColor DarkGray
  Write-Host ("  Step: {0}" -f $Step) -ForegroundColor Gray
  Write-Host '  Tip: Enter accepts default; type q to cancel' -ForegroundColor DarkGray
  Write-Host ''
}

function Get-ParentPresets {
  # Preferred parents for NEW projects — portable, never USERPROFILE / Desktop as default
  $list = @()
  $n = 1
  $def = Get-DefaultProjectsParent
  $script:DefaultParent = $def
  $candidates = @(
    $def,
    'G:\GrokProject',
    'D:\GrokProject',
    'E:\GrokProject',
    'C:\GrokProject',
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'GrokProjects'),
    [Environment]::GetFolderPath('MyDocuments')
  )
  $seen = @{}
  foreach ($path in $candidates) {
    if (-not $path) { continue }
    $pk = Normalize-PathKey $path
    if ($seen.ContainsKey($pk)) { continue }
    # Offer default even if missing (wizard will create); others only if exist
    $isDefault = ((Normalize-PathKey $path) -eq (Normalize-PathKey $def))
    if ($isDefault -or (Test-Path -LiteralPath $path)) {
      $seen[$pk] = $true
      $list += [pscustomobject]@{ Num = $n; Path = $path }
      $n++
    }
  }
  return $list
}

function Invoke-NewTaskWizard {
  # Step 2 of product plan: freeze project path at create time so session identity
  # and project content cannot separate.
  try { $Host.UI.RawUI.CursorVisible = $true } catch {}

  Show-WizardHeader '1/4  Project name (binding name)'
  Write-Host "  Project name = desk-roots binding name (list / F9 / status)." -ForegroundColor Gray
  Write-Host "  Also used as default folder name. Grok chat title is NOT project name." -ForegroundColor DarkGray
  Write-Host "  Allowed: A-Z a-z 0-9 . _ -   examples: WZ_Skill  my-game  app01" -ForegroundColor DarkGray
  Write-Host "  Forbidden: home Desktop Documents Downloads Administrator ..." -ForegroundColor DarkRed
  Write-Host ''
  $name = ''
  while ($true) {
    $name = Read-LinePrompt -Label 'Project name'
    if ($name -eq 'q' -or $name -eq 'Q') {
      $script:StatusHint = 'Wizard cancelled'
      return
    }
    if (Test-ValidProjectName -Name $name) { break }
    if (Test-ReservedName -Name $name) {
      Write-Host '  Reserved name (system) — pick a real project name' -ForegroundColor Red
    } else {
      Write-Host '  Invalid name, try again' -ForegroundColor Red
    }
  }

  Show-WizardHeader '2/4  Project path (FROZEN)'
  Write-Host ("  Name: {0}" -f $name) -ForegroundColor Green
  Write-Host ("  Default parent: {0}" -f (Get-DefaultProjectsParent)) -ForegroundColor DarkGray
  Write-Host '  (override with env WZ_PROJECTS_ROOT)' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host '  Path will be WRITTEN DEAD into desk-roots + .wz-project.' -ForegroundColor Yellow
  Write-Host '  All future Grok sessions for this task use --cwd = this path only.' -ForegroundColor Gray
  Write-Host ''
  $presets = Get-ParentPresets
  if ($presets.Count -eq 0) {
    $script:DefaultParent = Get-DefaultProjectsParent
    if (-not (Test-Path -LiteralPath $script:DefaultParent)) {
      try { New-Item -ItemType Directory -Force -Path $script:DefaultParent | Out-Null } catch {}
    }
    $presets = Get-ParentPresets
  }
  foreach ($p in $presets) {
    $mark = if ($p.Num -eq 1) { '  [recommended]' } else { '' }
    Write-Host ("    [{0}]  {1}\{2}{3}" -f $p.Num, $p.Path, $name, $mark) -ForegroundColor Yellow
  }
  Write-Host '    [0]  type full project path yourself' -ForegroundColor Yellow
  Write-Host '    [f]  sibling of currently selected strong project' -ForegroundColor Yellow
  Write-Host ''

  $fullPath = $null
  while (-not $fullPath) {
    $choice = Read-LinePrompt -Label 'Choice or path' -Default '1'
    if ($choice -eq 'q' -or $choice -eq 'Q') {
      $script:StatusHint = 'Wizard cancelled'
      return
    }
    if ($choice -eq '0') {
      $manual = Read-LinePrompt -Label ('Full path (e.g. {0}\MyApp)' -f (Get-DefaultProjectsParent))
      if ($manual -eq 'q') { $script:StatusHint = 'Wizard cancelled'; return }
      if (-not [string]::IsNullOrWhiteSpace($manual)) {
        $candidate = $manual.Trim().TrimEnd('\')
        try { $candidate = [System.IO.Path]::GetFullPath($candidate) } catch {}
        if (-not (Test-StrongProjectPath -Cwd $candidate)) {
          Write-Host '  GATE: path is weak/system — refuse' -ForegroundColor Red
          continue
        }
        $fullPath = $candidate
      }
      continue
    }
    if ($choice -eq 'f' -or $choice -eq 'F') {
      $sel = Get-SelectedRow
      if ($sel -and $sel.Cwd -and (Test-StrongProjectPath -Cwd $sel.Cwd) -and (Test-Path -LiteralPath $sel.Cwd)) {
        $parent = Split-Path -Parent $sel.Cwd
        $candidate = Join-Path $parent $name
        if (-not (Test-StrongProjectPath -Cwd $candidate)) {
          Write-Host '  GATE: resulting path is weak — refuse' -ForegroundColor Red
        } else {
          $fullPath = $candidate
        }
      } else {
        Write-Host '  No usable strong selected path' -ForegroundColor Red
      }
      continue
    }
    if ($choice -match '^\d+$') {
      $num = [int]$choice
      $hit = $presets | Where-Object { $_.Num -eq $num } | Select-Object -First 1
      if ($hit) {
        $candidate = Join-Path $hit.Path $name
        try { $candidate = [System.IO.Path]::GetFullPath($candidate) } catch {}
        if (-not (Test-StrongProjectPath -Cwd $candidate)) {
          Write-Host '  GATE: resulting path is weak/system — refuse' -ForegroundColor Red
          continue
        }
        $fullPath = $candidate
        continue
      }
    }
    if ($choice -match '^[A-Za-z]:\\' -or $choice.StartsWith('\\')) {
      $p = $choice.Trim().TrimEnd('\')
      if ((Split-Path -Leaf $p) -ieq $name) { $candidate = $p }
      elseif (Test-Path -LiteralPath $p) { $candidate = Join-Path $p $name }
      else { $candidate = $p }
      try { $candidate = [System.IO.Path]::GetFullPath($candidate) } catch {}
      if (-not (Test-StrongProjectPath -Cwd $candidate)) {
        Write-Host '  GATE: path is weak/system — refuse' -ForegroundColor Red
        continue
      }
      $fullPath = $candidate
      continue
    }
    Write-Host '  Unrecognized. Use number 0-N or a full path.' -ForegroundColor Red
  }

  $fullPath = [System.IO.Path]::GetFullPath($fullPath)
  # Leaf should match name when using parent\name convention (warn if not)
  $leaf = Split-Path -Leaf $fullPath
  if ($leaf -ine $name) {
    Write-Host ("  Note: folder leaf '{0}' differs from project name '{1}' (allowed; binding uses name)" -f $leaf, $name) -ForegroundColor DarkYellow
  }

  Show-WizardHeader '3/4  Confirm FREEZE name + path'
  Write-Host ("  PROJECT : {0}" -f $name) -ForegroundColor White
  Write-Host ("  PATH    : {0}" -f $fullPath) -ForegroundColor Yellow
  Write-Host '  These two values are written dead. Session identity = PATH via --cwd.' -ForegroundColor Gray
  $exists = Test-Path -LiteralPath $fullPath
  if ($exists) {
    Write-Host '  Dir exists - will bind only (no wipe)' -ForegroundColor Green
  } else {
    Write-Host '  Dir missing - will create empty folder + .wz-project' -ForegroundColor DarkYellow
  }
  Write-Host ''
  Write-Host "  Writes: desk-roots.tsv + PATH\.wz-project" -ForegroundColor DarkGray
  Write-Host ''
  $ok = Read-LinePrompt -Label 'Confirm freeze create/bind? (Y/n)' -Default 'Y'
  if ($ok -match '^(n|N|q|Q)') {
    $script:StatusHint = 'Wizard cancelled'
    return
  }

  try {
    if (-not $exists) {
      New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
      Write-Host ("  + created {0}" -f $fullPath) -ForegroundColor Green
    }
    Set-DeskRootBinding -Name $name -Path $fullPath
    Write-Host ("  + FROZEN: {0} -> {1}" -f $name, $fullPath) -ForegroundColor Green
    Write-Host ("  + marker: {0}\.wz-project" -f $fullPath) -ForegroundColor Green
  } catch {
    Write-Host ("  FAIL: {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host '  any key...' -ForegroundColor DarkGray
    [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    return
  }

  Show-WizardHeader '4/4  Open (always --cwd = frozen path)'
  Write-Host ("  Task {0} is ready" -f $name) -ForegroundColor Green
  Write-Host ("  {0}" -f $fullPath) -ForegroundColor Yellow
  Write-Host ''
  Write-Host "    [1]  Open Grok now (new session, --cwd=PATH)  [recommended]" -ForegroundColor Cyan
  Write-Host '    [2]  Open Grok with a first prompt' -ForegroundColor Cyan
  Write-Host '    [3]  Bind only, return to list' -ForegroundColor Gray
  Write-Host '    [4]  Open PowerShell in project (no Grok)' -ForegroundColor Gray
  Write-Host ''
  $mode = Read-LinePrompt -Label 'Choice' -Default '1'
  if ($mode -eq 'q' -or $mode -eq 'Q') {
    $script:StatusHint = "Bound $name - Enter later from list"
    return
  }

  switch ($mode) {
    '2' {
      $prompt = Read-LinePrompt -Label 'First prompt for Grok'
      if ($prompt -eq 'q') { break }
      $gargs = @('--cwd', $fullPath)
      if (-not [string]::IsNullOrWhiteSpace($prompt)) { $gargs += $prompt }
      Start-GrokTab -Cwd $fullPath -GrokArgs $gargs -Title ("new task {0}" -f $name)
    }
    '3' {
      $script:StatusHint = "Frozen task $name @ $fullPath"
    }
    '4' {
      if ($script:Wez -and (Test-WezAlive)) {
        & $script:Wez @('cli', 'spawn', '--cwd', $fullPath, '--', 'powershell.exe', '-NoLogo') 2>$null | Out-Null
      } else {
        Set-Location -LiteralPath $fullPath
      }
      $script:StatusHint = "Shell @ $name"
    }
    default {
      Start-GrokTab -Cwd $fullPath -GrokArgs @('--cwd', $fullPath) -Title ("new task {0}" -f $name)
    }
  }

  Build-Rows | Out-Null
  for ($ii = 0; $ii -lt $script:Rows.Count; $ii++) {
    if ($script:Rows[$ii].Project -eq $name) { $script:Selected = $ii; break }
  }
}

# ---- main ----
$running = $true
while ($running) {
  Show-Screen
  try {
    $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
  } catch {
    Write-Host -NoNewline '  wz> '
    $line = Read-Host
    if ($line -eq 'q') { break }
    if ($line -eq 'c') { Invoke-NewTaskWizard; continue }
    if ($line -match '^\d+$') {
      $r = Get-RowByIndex ([int]$line)
      if ($r) {
        for ($ii = 0; $ii -lt $script:Rows.Count; $ii++) {
          if ($script:Rows[$ii].Index -eq $r.Index) { $script:Selected = $ii; break }
        }
        Invoke-RowPrimary $r
      }
    }
    continue
  }

  $vk = [int]$key.VirtualKeyCode
  $ch = $key.Character

  if ($vk -eq 38 -or $ch -eq 'k' -or $ch -eq 'K') { Move-Selection -1; continue }
  if ($vk -eq 40 -or $ch -eq 'j' -or $ch -eq 'J') { Move-Selection 1; continue }
  if ($vk -eq 13) { Invoke-RowPrimary (Get-SelectedRow); continue }
  if ($vk -eq 27 -or $ch -eq 'q' -or $ch -eq 'Q') {
    try { $Host.UI.RawUI.CursorVisible = $true } catch {}
    Write-Host '  left panel.' -ForegroundColor DarkGray
    break
  }
  if ($ch -eq 'r' -or $ch -eq 'R') { continue }
  if ($ch -eq 'a' -or $ch -eq 'A') { $script:ShowAll = -not $script:ShowAll; $script:Selected = 0; continue }
  if ($ch -eq 'd' -or $ch -eq 'D') {
    # Dashboard is global UI — not a project session (skip R1 project gate)
    if ($script:Wez -and (Test-WezAlive)) {
      & $script:Wez @('cli', 'spawn', '--', $script:Grok, 'dashboard') 2>$null | Out-Null
      $script:StatusHint = 'Dashboard opened (not a project session)'
    } else {
      & $script:Grok dashboard
    }
    continue
  }
  if ($ch -eq 'c' -or $ch -eq 'C') { Invoke-NewTaskWizard; continue }
  if ($ch -eq 'n' -or $ch -eq 'N') { Invoke-RowNewSession (Get-SelectedRow); continue }
  if ($ch -eq 'i' -or $ch -eq 'I') { Show-RowDetail (Get-SelectedRow); continue }
  if ($ch -eq 's' -or $ch -eq 'S') {
    if ($script:Wez -and (Test-WezAlive)) {
      & $script:Wez @('cli', 'spawn', '--', 'powershell.exe', '-NoLogo') 2>$null | Out-Null
    }
    continue
  }
  if ($ch -ge '0' -and $ch -le '9') {
    try { $Host.UI.RawUI.CursorVisible = $true } catch {}
    Write-Host -NoNewline ("  wz> {0}" -f $ch) -ForegroundColor Magenta
    $rest = Read-Host
    $line = ($ch + $rest).Trim()
    if ($line -match '^\d+$') {
      $r = Get-RowByIndex ([int]$line)
      if ($r) {
        for ($ii = 0; $ii -lt $script:Rows.Count; $ii++) {
          if ($script:Rows[$ii].Index -eq $r.Index) { $script:Selected = $ii; break }
        }
        Invoke-RowPrimary $r
      }
    }
    continue
  }
}

try { $Host.UI.RawUI.CursorVisible = $true } catch {}
Write-Host '  WZ bootstrap ended.' -ForegroundColor DarkGray
