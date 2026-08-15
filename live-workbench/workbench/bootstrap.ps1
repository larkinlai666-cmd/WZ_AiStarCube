# WZ-AiWorkBench Task Init Panel (v4)
# ============================================================================
# HARD GATES (keep in sync with desk.lua)
# ============================================================================
# R1  AI CLIs for real work MUST run with a strong project path as cwd
#     (grok --cwd / codex -C,--cd / kimi process cwd). Never bare home.
# R2  Weak/system paths are NEVER a project root (home/Desktop/Documents root/…).
# R3  「项目名」= desk-roots LEFT column (binding name), NOT session title / cwd leaf.
# R4  「项目路径」= desk-roots RIGHT column; frozen at create/bind; .wz-project reinforces.
# R5  set_root / bind refuse weak paths and reserved names.
# R6  UI Project column = Resolve-ProjectName(path); never show "home" as a task.
#
# UI IRON (wizard / terminal choosers) — user mandate 2026-08:
# R-UI-1  Space blocks: identity / primary list / secondary actions / input.
# R-UI-2  Gray/DarkGray = STATIC only. Never paint [b]/[q]/[0]/[n] choices gray.
# R-UI-3  Actionable chips = White / Yellow / Cyan (high contrast).
#
# List: strong desk-roots TASK + favorites + titled recent (weak demoted).
# New task: F3 / Init c → name → parent (choice-first) → agent/CLI (D-015)
#           → freeze (desk-roots optional 3rd col = the same agent) → open in project cwd.
param(
  [switch]$All,
  # F3 / dedicated entry: run create wizard only, then exit (no Init table loop)
  [switch]$WizardOnly
)

$ErrorActionPreference = 'Continue'
try {
  chcp 65001 | Out-Null
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}
# Navigation-only title — never a filesystem path (prevents tab pollution)
try {
  if ($WizardOnly) { $Host.UI.RawUI.WindowTitle = 'New project' }
  else { $Host.UI.RawUI.WindowTitle = 'Init' }
} catch {}

$script:SessionsRoot  = Join-Path $env:USERPROFILE '.grok\sessions'
$script:RootsFile     = Join-Path $env:USERPROFILE '.config\wezterm\workbench\desk-roots.tsv'
$script:FavoritesFile = Join-Path $env:USERPROFILE '.config\wezterm\workbench\favorites.txt'
$script:RecentParentsFile = Join-Path $env:USERPROFILE '.config\wezterm\workbench\recent-parents.tsv'
$script:AgentRegistryFile = Join-Path $PSScriptRoot 'agent-registry.tsv'
$script:AgentRegistryLocalFile = Join-Path $PSScriptRoot 'agent-registry.local.tsv'
$script:AgentDiscoveryFile = Join-Path $PSScriptRoot 'agent-discovery.ps1'
$script:AgentDefinitions = $null
$script:Grok          = $null  # resolved below
$script:DefaultParent = $null  # resolved below
$script:MaxRows       = 18
$script:RecentDays    = 45
$script:ShowAll       = [bool]$All
$script:Selected      = 0
$script:Rows          = @()
$script:RowsDirty     = $true   # rebuild row data only when dirty
$script:ScreenDirty   = $true   # D-009: repaint ONLY when a command changed state
$script:LoadBarY      = -1     # screen line of the loading bar; -1 = no loading screen
$script:LoadFrame     = 0
$script:LoadLastDraw  = $null
$script:LoadCurrent   = 0
$script:LoadTotal     = 1
$script:Wez           = $null
$script:BufH          = 40
$script:DrawnLines    = 0
$script:DeskRoots     = [ordered]@{}
$script:DeskAgents    = @{}   # D-004: name -> agent (optional desk-roots 3rd column)
$script:StatusHint    = ''
# Two-step launch on ONE screen (user directive 2026-08-13), D-009 line-input:
# the screen is STATIC — redrawn only on state transitions (arm/launch/cancel/
# refresh). NO per-keystroke repaint, NO cursor: two ConPTY renderer attempts
# (blank+repaint, overwrite) both flickered; user ruled stability > cursor.
# Both steps share one grammar: <num>+Enter = pick · Enter alone = default ·
# q = back. Read-Host does the buffering; there is nothing to repaint mid-type.
$script:PendingRow      = $null
$script:PendingForceNew = $false
$script:PendingLaunch   = $null
$script:ReservedNames = @(
  'home', 'desktop', 'documents', 'downloads', 'pictures', 'music', 'videos',
  'administrator', 'users', 'temp', 'tmp', 'appdata', 'windows', 'system32',
  'config', '.grok', '.kimi-code', '.codex', '.config', 'wezterm', 'my documents', 'onedrive'
)

foreach ($c in @(
    $(if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'WezTerm\wezterm.exe' }),
    (Get-Command wezterm -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
  )) {
  if ($c -and (Test-Path -LiteralPath $c)) { $script:Wez = $c; break }
}

function Get-DefaultProjectsParent {
  # Product-neutral default; historical roots are read only for existing users.
  if ($env:WZ_PROJECTS_ROOT -and $env:WZ_PROJECTS_ROOT.Trim()) {
    return $env:WZ_PROJECTS_ROOT.Trim().TrimEnd('\')
  }
  foreach ($c in @('G:\AIProjects', 'D:\AIProjects', 'E:\AIProjects', 'C:\AIProjects')) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  foreach ($c in @('G:\GrokProject', 'D:\GrokProject', 'E:\GrokProject', 'C:\GrokProject')) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  $docs = [Environment]::GetFolderPath('MyDocuments')
  if (-not $docs) { $docs = Join-Path $env:USERPROFILE 'Documents' }
  return (Join-Path $docs 'AIProjects')
}

function Resolve-GrokExe {
  $list = New-Object System.Collections.Generic.List[string]
  try {
    $cmd = Get-Command grok -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { [void]$list.Add([string]$cmd.Source) }
  } catch {}
  foreach ($c in @(
      (Join-Path $env:USERPROFILE '.grok\bin\grok.exe'),
      $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Programs\grok\grok.exe' }),
      $(if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'grok\grok.exe' })
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

function Limit-Display {
  # Hard truncate to MaxWidth display cells; NO '~' marker. Frame safety net:
  # used where overflowing the box border is worse than losing tail content.
  param([string]$Text, [int]$MaxWidth)
  if ($null -eq $Text -or $MaxWidth -le 0) { return '' }
  if ((Get-DisplayWidth $Text) -le $MaxWidth) { return $Text }
  $acc = ''
  foreach ($ch in $Text.ToCharArray()) {
    $try = $acc + $ch
    if ((Get-DisplayWidth $try) -gt $MaxWidth) { return $acc }
    $acc = $try
  }
  return $acc
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
  if (-not $Dt) { return '---- -- --' }  # fits Date col (min 10); old 13-char form overflowed to '---- -- ~'
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
  if ($n.StartsWith('.')) { return $true }
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
    (Join-Path $env:USERPROFILE '.config\wezterm')
  ) | ForEach-Object { Normalize-PathKey $_ }
  if ($exact -contains $c) { return $true }
  if ($c.StartsWith((Normalize-PathKey (Join-Path $env:USERPROFILE 'AppData')) + '\')) { return $true }
  if ($h -and $c.StartsWith($h + '\.')) { return $true }
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

function Commit-WzAtomicFile {
  param([string]$TemporaryPath, [string]$Destination)
  $backup = $Destination + '.swap.' + $PID + '.' + [guid]::NewGuid().ToString('N')
  try {
    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
      [System.IO.File]::Replace($TemporaryPath, $Destination, $backup, $true)
    } else {
      [System.IO.File]::Move($TemporaryPath, $Destination)
    }
  } finally {
    if ((Test-Path -LiteralPath $backup -PathType Leaf) -and -not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
      [System.IO.File]::Move($backup, $Destination)
    }
    if (Test-Path -LiteralPath $backup -PathType Leaf) {
      Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
    }
  }
}

function Write-WzUtf8LinesAtomic {
  param([string]$Path, [string[]]$Lines)
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  $tmp = Join-Path $dir ((Split-Path -Leaf $Path) + '.tmp.' + $PID + '.' + [guid]::NewGuid().ToString('N'))
  $utf8 = New-Object System.Text.UTF8Encoding $false
  try {
    [System.IO.File]::WriteAllLines($tmp, $Lines, $utf8)
    Commit-WzAtomicFile -TemporaryPath $tmp -Destination $Path
  } finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
  }
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
  Write-WzUtf8LinesAtomic -Path $marker -Lines $lines
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
  $script:DeskAgents = @{}
  if (-not (Test-Path -LiteralPath $script:RootsFile)) { return $map }
  try {
    foreach ($line in Get-Content -LiteralPath $script:RootsFile -Encoding UTF8 -ErrorAction SilentlyContinue) {
      $t = $line.Trim()
      if ($t -eq '' -or $t.StartsWith('#')) { continue }
      # D-004: tolerate 2 or 3 TAB columns (name, path, optional agent)
      $parts = $t -split "`t"
      if ($parts.Count -lt 2) { $parts = $t -split '\s+', 2 }
      if ($parts.Count -ge 2 -and $parts[0] -and $parts[1]) {
        $map[$parts[0].Trim()] = $parts[1].Trim().TrimEnd('\')
        if ($parts.Count -ge 3 -and $parts[2].Trim()) {
          $script:DeskAgents[$parts[0].Trim()] = $parts[2].Trim().ToLowerInvariant()
        }
      }
    }
  } catch {}
  return $map
}

function Write-DeskRoots {
  param($Map, [hashtable]$Agents)
  $dir = Split-Path -Parent $script:RootsFile
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $lines = @(
    '# AI STAR CUBE desk roots - project_name<TAB>absolute_path[<TAB>agent]',
    '# 项目名(绑定名) 与 项目路径 写死绑定；Explorer / 状态栏 / F6 / Init 共用',
    '# 弱路径(home/Desktop/…)与保留名不得写入',
    '# 第三列 route id 来自开放式 Agent 探测；shell = 非 AI 逃生项'
  )
  foreach ($k in ($Map.Keys | Sort-Object)) {
    $p = $Map[$k]
    if ((Test-ReservedName -Name $k)) { continue }
    if (-not (Test-StrongProjectPath -Cwd $p)) { continue }
    $a = $null
    if ($Agents -and $Agents.Contains($k)) { $a = ([string]$Agents[$k]).Trim().ToLowerInvariant() }
    # Always write a route explicitly. Legacy 2-column rows bind to the first
    # currently discovered agent, or shell when this machine has no agent CLI.
    if (-not $a) {
      $available = @(Get-InstalledAgentPeers)
      $a = if ($available.Count -gt 0) { [string]$available[0].Id } else { 'shell' }
    }
    $lines += ($k + "`t" + $p + "`t" + $a)
  }
  # Unique temp + File.Replace avoids cross-process .tmp collisions and the
  # truncate/delete window that could lose every binding on interruption.
  Write-WzUtf8LinesAtomic -Path $script:RootsFile -Lines $lines
}

function Set-DeskRootBinding {
  param([string]$Name, [string]$Path, [string]$Agent = '')
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
  # D-004: keep existing agent column for surviving rows
  $agents = @{}
  foreach ($k in $map.Keys) {
    if ($script:DeskAgents -and $script:DeskAgents.Contains($k)) {
      $agents[$k] = [string]$script:DeskAgents[$k]
    }
  }
  $Agent = $Agent.Trim().ToLowerInvariant()
  if ($Agent) { $agents[$Name] = $Agent }
  $map[$Name] = $Path
  Write-DeskRoots -Map $map -Agents $agents
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
  if ($m -match '(?i)grok|gpt|claude|gemini|o1|o3|llm|anthropic|openai|xai|kimi|moonshot') { return $m }
  if ($m -match '[A-Za-z]' -and $m -match '\d') { return $m }
  if ($AgentName -and $AgentName -match '(?i)grok|codex|kimi|agent|build|plan') { return $m }
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

function Read-SessionSummaries {
  param([object[]]$Files)
  $rows = @()
  if (-not (Test-Path -LiteralPath $script:SessionsRoot)) { return $rows }
  if ($null -eq $Files) { $Files = @(Get-ChildItem -LiteralPath $script:SessionsRoot -Recurse -Filter 'summary.json' -File -ErrorAction SilentlyContinue) }
  foreach ($f in @($Files)) {
    Step-LoadingPlan -Label 'reading optional session adapter metadata'
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
    # agent_name is a profile id ('grok-build-plan' etc.) — normalize to the CLI
    # peer id so resume matching / D-005 resolution actually fire.
    if ($agent -match '^(?i)grok') { $agent = 'grok' }

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

function Read-KimiSessionSummaries {
  param([object[]]$WdDirs)
  # D-004/F-011: Kimi Code CLI sessions (~/.kimi-code/sessions/wd_*/session_*/state.json).
  # kimi has no --cwd/--resume: process cwd IS task identity; resume = `kimi --continue`,
  # which only continues the LATEST session of that working dir — so keep only the newest
  # session per wd_* directory (listing older ones would be misleading).
  $rows = @()
  $root = Join-Path $env:USERPROFILE '.kimi-code\sessions'
  if (-not (Test-Path -LiteralPath $root)) { return $rows }
  if ($null -eq $WdDirs) { $WdDirs = @(Get-ChildItem -LiteralPath $root -Directory -Filter 'wd_*' -ErrorAction SilentlyContinue) }
  foreach ($wd in @($WdDirs)) {
    Step-LoadingPlan -Label 'reading optional session adapter metadata'
    $best = $null
    $sessDirs = Get-ChildItem -LiteralPath $wd.FullName -Directory -Filter 'session_*' -ErrorAction SilentlyContinue
    foreach ($sd in $sessDirs) {
      $sf = Join-Path $sd.FullName 'state.json'
      if (-not (Test-Path -LiteralPath $sf)) { continue }
      try {
        $j = Get-Content -LiteralPath $sf -Raw -Encoding UTF8 | ConvertFrom-Json
      } catch { continue }
      if ($j.archived -eq $true) { continue }
      $ms = 0
      try { $ms = [int64]$j.updatedAt } catch { $ms = 0 }
      if ($ms -le 0) { try { $ms = [int64]$j.createdAt } catch { $ms = 0 } }
      if ($null -eq $best -or $ms -gt $best.Ms) {
        $best = [pscustomobject]@{ Ms = $ms; J = $j; Dir = $sd.FullName }
      }
    }
    if ($null -eq $best) { continue }
    $j = $best.J

    $id = if ($j.id) { [string]$j.id } else { Split-Path $best.Dir -Leaf }
    $workPath = if ($j.cwd) { ([string]$j.cwd).Trim().Replace('/', '\').TrimEnd('\') } else { '' }

    $updated = $null
    if ($best.Ms -gt 0) {
      try { $updated = [DateTimeOffset]::FromUnixTimeMilliseconds($best.Ms).LocalDateTime } catch { $updated = $null }
    }
    if (-not $updated) { $updated = (Get-Item -LiteralPath $best.Dir).LastWriteTime }

    $lastPrompt = if ($j.lastPrompt) { [string]$j.lastPrompt } else { '' }
    $title = if ($j.title) { [string]$j.title } else { '' }
    if ([string]::IsNullOrWhiteSpace($title)) { $title = $lastPrompt }
    if ([string]::IsNullOrWhiteSpace($title)) { $title = '' }

    $proj = Resolve-ProjectName -Path $workPath -FallbackLeaf $(if ($workPath) { Split-Path -Leaf $workPath } else { '' })
    $diskBytes = Get-SessionDiskBytes -SessionDir $best.Dir

    $rows += [pscustomobject]@{
      Kind = 'session'; Id = [string]$id; Cwd = [string]$workPath; Project = [string]$proj
      Title = [string]$title; Model = 'Kimi'; Agent = 'kimi'
      Msgs = 0; ChatMsgs = 0; TotalMsgs = 0
      Branch = '-'; Effort = '-'; Updated = $updated
      LastTurn = [string]$lastPrompt; Excerpt = [string]$lastPrompt; GitRoot = ''
      DiskBytes = [long]$diskBytes; SessionDir = $best.Dir
      SessionSummary = ''
      RecentPrompts = @()
      SessionCwd = [string]$workPath
      IsWeak = [bool](Test-WeakPath -Cwd $workPath)
    }
  }
  return @($rows | Sort-Object Updated -Descending)
}

function Read-CodexSessionSummaries {
  param([object[]]$Files, [switch]$IndexCounted)
  # Codex CLI parity: sessions live in ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl;
  # first line = session_meta (payload: id/cwd/timestamp/model_provider).
  # ~/.codex/session_index.jsonl ({id,thread_name,updated_at} per line) supplies
  # Title/Updated. `codex resume <id>` can restore ANY session (not just latest),
  # so keep up to 3 newest per cwd (unlike kimi's 1-per-wd rule) to avoid noise.
  $rows = @()
  $root = Join-Path $env:USERPROFILE '.codex\sessions'
  if (-not (Test-Path -LiteralPath $root)) { return $rows }

  # Optional title/time index (id -> {thread_name, updated_at})
  $index = @{}
  $idxFile = Join-Path $env:USERPROFILE '.codex\session_index.jsonl'
  if (Test-Path -LiteralPath $idxFile) {
    foreach ($line in (Get-Content -LiteralPath $idxFile -Encoding UTF8 -ErrorAction SilentlyContinue)) {
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      try { $o = $line | ConvertFrom-Json } catch { continue }
      if ($o.id) { $index[[string]$o.id] = $o }
    }
    if ($IndexCounted) { Step-LoadingPlan -Label 'reading optional session title index' }
  }

  if ($null -eq $Files) {
    $Files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'rollout-*.jsonl' -ErrorAction SilentlyContinue)
    # Bounded work: newest 60 rollouts by file mtime keeps parse cost flat.
    if ($Files.Count -gt 60) { $Files = @($Files | Sort-Object LastWriteTime -Descending | Select-Object -First 60) }
  }
  foreach ($f in @($Files)) {
    Step-LoadingPlan -Label 'reading optional session adapter metadata'
    # Only the first line is needed — never slurp whole rollouts
    $first = Get-Content -LiteralPath $f.FullName -TotalCount 1 -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $first) { continue }
    try { $j = $first | ConvertFrom-Json } catch { continue }
    if ($j.type -ne 'session_meta' -or -not $j.payload) { continue }
    $p = $j.payload

    $id = if ($p.id) { [string]$p.id } else { '' }
    if (-not $id) { continue }
    $workPath = if ($p.cwd) { ([string]$p.cwd).Trim().Replace('/', '\').TrimEnd('\') } else { '' }
    if (-not $workPath) { continue }

    $idx = $null
    if ($index.ContainsKey($id)) { $idx = $index[$id] }

    $updated = $null
    if ($idx -and $idx.updated_at) {
      try { $updated = [DateTimeOffset]::Parse([string]$idx.updated_at).LocalDateTime } catch { $updated = $null }
    }
    if (-not $updated -and $p.timestamp) {
      try { $updated = [DateTimeOffset]::Parse([string]$p.timestamp).LocalDateTime } catch { $updated = $null }
    }
    if (-not $updated) { $updated = $f.LastWriteTime }

    $title = if ($idx -and $idx.thread_name) { [string]$idx.thread_name } else { '' }
    $model = if ($p.model_provider) { [string]$p.model_provider } else { 'Codex' }

    $proj = Resolve-ProjectName -Path $workPath -FallbackLeaf $(if ($workPath) { Split-Path -Leaf $workPath } else { '' })
    $diskBytes = Get-SessionDiskBytes -SessionDir $f.DirectoryName

    $rows += [pscustomobject]@{
      Kind = 'session'; Id = [string]$id; Cwd = [string]$workPath; Project = [string]$proj
      Title = [string]$title; Model = [string]$model; Agent = 'codex'
      Msgs = 0; ChatMsgs = 0; TotalMsgs = 0
      Branch = '-'; Effort = '-'; Updated = $updated
      LastTurn = [string]$title; Excerpt = [string]$title; GitRoot = ''
      DiskBytes = [long]$diskBytes; SessionDir = $f.DirectoryName
      SessionSummary = ''
      RecentPrompts = @()
      SessionCwd = [string]$workPath
      IsWeak = [bool](Test-WeakPath -Cwd $workPath)
    }
  }

  # Cap at 3 newest per cwd
  $kept = @()
  $perCwd = @{}
  foreach ($r in @($rows | Sort-Object Updated -Descending)) {
    $k = ([string]$r.Cwd).ToLowerInvariant()
    if (-not $perCwd.ContainsKey($k)) { $perCwd[$k] = 0 }
    if ($perCwd[$k] -ge 3) { continue }
    $perCwd[$k] = [int]$perCwd[$k] + 1
    $kept += $r
  }
  return $kept
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

function Get-DeepSeekSessionHash {
  # DeepSeek CLI session filename: sha256(path.resolve(cwd)) hex, first 16
  # chars (see dist/session.js). Node path.resolve on Win = absolute path with
  # backslashes; crypto.update(string) hashes UTF-8 bytes.
  param([string]$Path)
  try {
    $p = [System.IO.Path]::GetFullPath([string]$Path)
    # Node path.resolve strips a trailing separator (except drive root) — match it
    if ($p.Length -gt 3) { $p = $p.TrimEnd('\') }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
      $hex = [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($p)))
      $hex = $hex.Replace('-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
    return $hex.Substring(0, 16)
  } catch { return '' }
}

function Read-DeepSeekSessionSummaries {
  # F-014: one JSON per project cwd at ~/.deepseek-cli/sessions/<hash>.json —
  # the hash is NOT invertible, so enumerate by hashing KNOWN candidate paths
  # (desk-roots + favorites) and probing the store. Bound tasks (Layer A) get
  # full resume parity; unbound-recents (Layer C) cannot list deepseek sessions
  # (no path source to hash). Casing caveat: process.cwd() uses filesystem
  # casing — a differently-cased desk-root just misses detection (shows
  # "no session yet"), never a wrong row.
  param([string[]]$Candidates)
  $rows = @()
  $root = Join-Path $env:USERPROFILE '.deepseek-cli\sessions'
  if (-not (Test-Path -LiteralPath $root)) { return $rows }
  if (-not $Candidates -or $Candidates.Count -eq 0) { return $rows }
  $seenHash = @{}
  $ci = 0
  foreach ($cand in $Candidates) {
    Step-LoadingPlan -Label 'probing optional hash-indexed sessions'
    if ([string]::IsNullOrWhiteSpace([string]$cand)) { continue }
    $h = Get-DeepSeekSessionHash -Path ([string]$cand)
    if (-not $h -or $seenHash.ContainsKey($h)) { continue }
    $seenHash[$h] = $true
    $sf = Join-Path $root ($h + '.json')
    if (-not (Test-Path -LiteralPath $sf)) { continue }
    $ci++
    $j = $null
    try { $j = Get-Content -LiteralPath $sf -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    if ($null -eq $j -or $null -eq $j.messages) { continue }
    $workPath = ([string]$cand).Trim().Replace('/', '\').TrimEnd('\')
    $fi = Get-Item -LiteralPath $sf
    $updated = $fi.LastWriteTime
    $msgs = @($j.messages)
    $lastPrompt = ''
    for ($mi = $msgs.Count - 1; $mi -ge 0; $mi--) {
      if (([string]$msgs[$mi].role) -eq 'user') {
        $mc = $msgs[$mi].content
        if ($mc -is [string]) { $lastPrompt = $mc } else { $lastPrompt = [string]($mc | ConvertTo-Json -Compress -Depth 4) }
        break
      }
    }
    if ($lastPrompt.Length -gt 120) { $lastPrompt = $lastPrompt.Substring(0, 120) }
    $proj = Resolve-ProjectName -Path $workPath -FallbackLeaf $(if ($workPath) { Split-Path -Leaf $workPath } else { '' })
    $rows += [pscustomobject]@{
      Kind = 'session'; Id = [string]$h; Cwd = [string]$workPath; Project = [string]$proj
      Title = [string]$lastPrompt; Model = 'DeepSeek'; Agent = 'deepseek'
      Msgs = 0; ChatMsgs = 0; TotalMsgs = [int]$msgs.Count
      Branch = '-'; Effort = '-'; Updated = $updated
      LastTurn = [string]$lastPrompt; Excerpt = [string]$lastPrompt; GitRoot = ''
      DiskBytes = [long]$fi.Length; SessionDir = $root
      SessionSummary = ''
      RecentPrompts = @()
      SessionCwd = [string]$workPath
      IsWeak = [bool](Test-WeakPath -Cwd $workPath)
    }
  }
  return $rows
}

function Build-Rows {
  $script:DeskRoots = Read-DeskRoots
  # Optional session-store adapters exist for a few CLIs. Detection itself is
  # fully open; only scan an adapter when that dynamically discovered id exists.
  # Perf gate (2026-08-13): only scan stores of agents actually installed —
  # an uninstalled CLI's leftover files (e.g. old codex rollouts) taxed every
  # panel open with a full recursive scan whose sessions can never be launched.
  $peers = @{}
  $peerIds = @()
  foreach ($p in @(Get-InstalledAgentPeers)) { $peers[$p.Id] = $true; $peerIds += $p.Id }

  # One global progress axis. Previous readers each reset their own denominator
  # and could show 100% several times while later stores/merge work remained.
  # Enumerate once, pass the same bounded collections to the readers, and
  # reserve two final steps for merge/indexing and row publication.
  $grokFiles = @()
  if ($peers['grok'] -and (Test-Path -LiteralPath $script:SessionsRoot -PathType Container)) {
    $grokFiles = @(Get-ChildItem -LiteralPath $script:SessionsRoot -Recurse -Filter 'summary.json' -File -ErrorAction SilentlyContinue)
  }
  $kimiDirs = @()
  $kimiRoot = Join-Path $env:USERPROFILE '.kimi-code\sessions'
  if ($peers['kimi'] -and (Test-Path -LiteralPath $kimiRoot -PathType Container)) {
    $kimiDirs = @(Get-ChildItem -LiteralPath $kimiRoot -Directory -Filter 'wd_*' -ErrorAction SilentlyContinue)
  }
  $codexFiles = @()
  $codexIndexCount = 0
  $codexRoot = Join-Path $env:USERPROFILE '.codex\sessions'
  $codexIndex = Join-Path $env:USERPROFILE '.codex\session_index.jsonl'
  if ($peers['codex'] -and (Test-Path -LiteralPath $codexRoot -PathType Container)) {
    $codexFiles = @(Get-ChildItem -LiteralPath $codexRoot -Recurse -File -Filter 'rollout-*.jsonl' -ErrorAction SilentlyContinue)
    if ($codexFiles.Count -gt 60) { $codexFiles = @($codexFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 60) }
    if (Test-Path -LiteralPath $codexIndex -PathType Leaf) { $codexIndexCount = 1 }
  }
  $dsCands = @()
  if ($peers['deepseek']) { $dsCands = @($script:DeskRoots.Values) + @(Read-Favorites) }
  $loadUnits = $grokFiles.Count + $kimiDirs.Count + $codexFiles.Count + $codexIndexCount + $dsCands.Count + 2
  Start-LoadingPlan -Total $loadUnits -Label 'inventory ready; reading task metadata'

  $sessions = @()
  if ($peers['grok'])  { $sessions += @(Read-SessionSummaries -Files $grokFiles) }
  if ($peers['kimi'])  { $sessions += @(Read-KimiSessionSummaries -WdDirs $kimiDirs) }
  if ($peers['codex']) { $sessions += @(Read-CodexSessionSummaries -Files $codexFiles -IndexCounted:($codexIndexCount -gt 0)) }
  if ($peers['deepseek']) {
    # Hash-keyed store → probe with known candidate paths (bound + favorites)
    $sessions += @(Read-DeepSeekSessionSummaries -Candidates $dsCands)
  }
  Step-LoadingPlan -Label 'merging task and session identities'
  $sessions = @($sessions | Sort-Object Updated -Descending)
  $layerA = @()
  $layerB = @()
  $layerC = @()
  $usedSessionIds = @{}
  $seenPath = @{}

  # Layer A: bound projects ONLY if strong path + non-reserved name (R2/R5)
  foreach ($name in $script:DeskRoots.Keys) {
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
      $agentA = if ($best.Agent) { ([string]$best.Agent).ToLowerInvariant() } elseif ($script:DeskAgents.Contains($name)) { [string]$script:DeskAgents[$name] } else { '' }
      if (-not $agentA -or -not $peers[$agentA]) { $agentA = if ($peerIds.Count -gt 0) { $peerIds[0] } else { '' } }
      $resumeOk = ($best.Agent) -and (([string]$best.Agent).ToLowerInvariant() -eq $agentA)
      $hintA = if ($resumeOk) { "Enter=resume($agentA)  n=new" } else { "Enter=new($agentA)  (last session was $($best.Agent))" }
      $layerA += [pscustomobject]@{
        Index = 0; Kind = 'session'; Layer = 'bound'
        Id = $best.Id; Cwd = $path; Project = $name
        Title = $best.Title; Model = $best.Model; Agent = $best.Agent
        Msgs = $best.Msgs; ChatMsgs = $best.ChatMsgs; TotalMsgs = $best.TotalMsgs
        Branch = $best.Branch; Effort = $best.Effort
        Updated = $best.Updated; LastTurn = $best.LastTurn; Excerpt = $best.Excerpt
        Badge = 'TASK'; Hint = $hintA
        SessionDir = $best.SessionDir; SessionSummary = $best.SessionSummary
        RecentPrompts = $best.RecentPrompts; DiskBytes = $best.DiskBytes
        GitRoot = $best.GitRoot
        SessionCwd = $best.SessionCwd
        IsWeak = $false
        LaunchAgent = $agentA; ForceNew = (-not $resumeOk)
      }
    } else {
      $seenPath[$pk] = $true
      $title = if ($exists) {
        "[task] $name  - no session yet"
      } else {
        "[task] $name  - path missing - press c to recreate"
      }
      $agentP = if ($script:DeskAgents.Contains($name)) { [string]$script:DeskAgents[$name] } else { '' }
      if (-not $agentP -or -not $peers[$agentP]) { $agentP = if ($peerIds.Count -gt 0) { $peerIds[0] } else { '' } }
      $hintP = if ($agentP) { "Enter=open($agentP)  c=wizard" } else { 'Enter=open  c=wizard' }
      $excerptP = if ($agentP) { "$agentP  (cwd: $path)" } else { $path }
      $modelP = Get-AgentLabel -Id $agentP
      $layerA += [pscustomobject]@{
        Index = 0; Kind = 'project'; Layer = 'bound'
        Id = ''; Cwd = $path; Project = $name
        Title = $title; Model = $modelP; Agent = ''; Msgs = 0
        ChatMsgs = 0; TotalMsgs = 0
        Branch = ''; Effort = ''; Updated = $null
        LastTurn = 'desk-roots binding'; Excerpt = $excerptP
        Badge = 'TASK'; Hint = $hintP
        SessionDir = ''; SessionSummary = ''; RecentPrompts = @(); DiskBytes = 0
        GitRoot = $path
        SessionCwd = ''; IsWeak = $false
        LaunchAgent = $agentP; ForceNew = $true
      }
    }
  }

  # Layer B: favorites (strong only)
  foreach ($fav in (Read-Favorites)) {
    if (-not (Test-StrongProjectPath -Cwd $fav)) { continue }
    $pk = Normalize-PathKey $fav
    if ($seenPath.ContainsKey($pk)) { continue }
    $name = Resolve-ProjectName -Path $fav
    $seenPath[$pk] = $true
    $agentF = if ($peerIds.Count -gt 0) { $peerIds[0] } else { '' }
    $hintF = if ($agentF) { "Enter=open($agentF)" } else { 'Enter=open' }
    $modelF = Get-AgentLabel -Id $agentF
    $layerB += [pscustomobject]@{
      Index = 0; Kind = 'project'; Layer = 'fav'
      Id = ''; Cwd = $fav; Project = $name
      Title = "[fav] $name  - Enter open / c to bind as task"
      Model = $modelF; Agent = ''; Msgs = 0
      Branch = ''; Effort = ''; Updated = $null
      LastTurn = 'favorites.txt'; Excerpt = $fav
      Badge = 'FAV'; Hint = $hintF
      SessionCwd = ''; IsWeak = $false
      LaunchAgent = $agentF; ForceNew = $true
    }
  }

  # Layer C: unbound recent titled sessions (strong paths only unless -All)
  foreach ($s in $sessions) {
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
    $agentC = ([string]$s.Agent).ToLowerInvariant()
    if (-not $agentC -or -not $peers[$agentC]) { $agentC = if ($peerIds.Count -gt 0) { $peerIds[0] } else { '' } }
    $resumeC = ($s.Agent) -and (([string]$s.Agent).ToLowerInvariant() -eq $agentC)
    $hintC = $(if ($isWeak) { 'weak cwd - c to bind real project' } elseif ($resumeC) { "Enter=resume($agentC)  (unbound; use c to bind)" } else { "Enter=new($agentC)  (unbound; session was $($s.Agent))" })
    $layerC += [pscustomobject]@{
      Index = 0; Kind = 'session'; Layer = $(if ($isWeak) { 'system' } else { 'recent' })
      Id = $s.Id; Cwd = $cwdShow; Project = $projName
      Title = $s.Title; Model = $s.Model; Agent = $s.Agent
      Msgs = $s.Msgs; ChatMsgs = $s.ChatMsgs; TotalMsgs = $s.TotalMsgs
      Branch = $s.Branch; Effort = $s.Effort
      Updated = $s.Updated; LastTurn = $s.LastTurn; Excerpt = $s.Excerpt
      Badge = $(if ($isWeak) { 'SYS' } else { 'RECENT' })
      Hint = $hintC
      SessionDir = $s.SessionDir; SessionSummary = $s.SessionSummary
      RecentPrompts = $s.RecentPrompts; DiskBytes = $s.DiskBytes
      GitRoot = $s.GitRoot
      SessionCwd = $s.SessionCwd
      IsWeak = $isWeak
      LaunchAgent = $agentC; ForceNew = (-not $resumeC)
    }
  }

  # Recency-first ordering (Init = 回到最近任务): bound tasks by last activity desc,
  # no-session tasks last (binding order kept); favs keep file order; recents are
  # already Updated desc. Index is assigned after ordering, then capped.
  $sortedA  = @($layerA | Where-Object { $null -ne $_.Updated } | Sort-Object Updated -Descending)
  $sortedA += @($layerA | Where-Object { $null -eq $_.Updated })
  $out = @($sortedA) + @($layerB) + @($layerC)

  # D-010: default view caps at 9 rows so every task number is a single digit
  # and two-digit combo input (<task><agent>, e.g. 13 = task 1 + agent 3) stays
  # unambiguous; `a` (ShowAll) lifts the cap and disables combo.
  $cap = if ($script:ShowAll) { $script:MaxRows } else { [Math]::Min(9, $script:MaxRows) }
  if ($out.Count -gt $cap) { $out = @($out | Select-Object -First $cap) }
  for ($ii = 0; $ii -lt $out.Count; $ii++) { $out[$ii].Index = $ii + 1 }

  # Act* column removed (user call 2026-08-13: never read well) — no per-row
  # metrics are computed at all; the list shows identity/path/model/title only.

  $script:Rows = $out
  if ($script:Rows.Count -eq 0) { $script:Selected = 0 }
  elseif ($script:Selected -ge $script:Rows.Count) { $script:Selected = $script:Rows.Count - 1 }
  Step-LoadingPlan -Label 'ready'
  return $out
}

# =============================================================================
# Color standard (D-013)
#   Yellow    = RESERVED — the ONLY input-affordance color: option index
#               chips / key chips + input-prompt prefixes (wz> / agent N /
#               explorer> / wizard Read-LinePrompt). Nothing else may use it.
#   DarkGray  = unimportant meta + ALL box frames/titles
#   Gray      = normal body / option labels
#   White     = primary content (project/path, input status text)
#   Green     = selection row OR success / (default) marker
#   Red       = error / missing path only
#   Cyan      = informational hints
#   Magenta   = decoration (splash cat) + AGENT zone frame
#   DarkCyan  = secondary attention (DarkYellow family retired)
# Zone border colors (frames/titles are never Yellow):
#   HEADER   = DarkGray
#   1 LIST   = Cyan
#   2 AGENT  = Magenta
#   3 COMMAND = DarkGray (neutral — the Yellow chips inside are the signal)
# Stage highlight (Init two-step): active step's number chips glow Yellow,
# inactive step's chips dim to DarkGray.
# =============================================================================

function Get-UiWidth {
  # Content band = 86% of the full pane/window width (widened 2026-08-13 from
  # 70% — user: 延长右边区间, the right ~30% was wasted while rows overflowed).
  try {
    $full = [Math]::Max(80, $Host.UI.RawUI.WindowSize.Width - 1)
    return [Math]::Max(64, [Math]::Floor($full * 0.86))
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
  $script:LoadBarY = -1
}

function Show-LoadingScreen {
  # Instant frame + lively walking-cat progress block; Build-Rows and the
  # session readers feed Update-LoadingBar so loading is watched, not waited.
  Reset-Screen
  Write-BoxTop -Title 'WZ INIT' -Border ([ConsoleColor]::DarkGray)
  Write-BoxLine -Text ((Get-Date -Format 'yyyy-MM-dd HH:mm') + '   loading tasks...') -Fg Cyan -Border ([ConsoleColor]::DarkGray)
  Write-BoxBottom -Border ([ConsoleColor]::DarkGray)
  Write-FullLine -Text ''
  Write-BoxTop -Title '1 LIST' -Border ([ConsoleColor]::Cyan)
  $script:LoadFrame = 0
  $script:LoadLastDraw = $null
  $script:LoadBarY = $script:DrawnLines
  for ($i = 0; $i -lt 5; $i++) { Write-FullLine -Text '' }  # cat(3) + bar(1) + label(1)
  Write-BoxLine -Text 'discovering installed AI agents + compatible sessions...' -Fg DarkGray -Border ([ConsoleColor]::Cyan)
  Write-BoxBottom -Border ([ConsoleColor]::Cyan)
  Update-LoadingBar -Current 0 -Total 1 -Label 'warming up'
}

function Update-LoadingBar {
  # Walking-cat progress block (5 lines at absolute Y recorded by
  # Show-LoadingScreen): a 3-line ASCII cat walks right as the bar fills.
  # Time-throttled so per-file updates never add meaningful overhead.
  param([int]$Current, [int]$Total, [string]$Label)
  if ($script:LoadBarY -lt 0) { return }
  # Redirected host: no cursor positioning — skip redraws instead of
  # concatenating every frame into one giant line in the captured output.
  try { if ([Console]::IsOutputRedirected) { return } } catch { }
  $finished = ($Total -gt 0 -and $Current -ge $Total)
  if (-not $finished -and $script:LoadLastDraw) {
    if (((Get-Date) - $script:LoadLastDraw).TotalMilliseconds -lt 66) { return }
  }
  $script:LoadLastDraw = Get-Date
  try {
    $raw = $Host.UI.RawUI
    $inner = Get-InnerWidth
    $barW = [Math]::Min(40, [Math]::Max(16, $inner - 24))
    $frac = if ($Total -gt 0) { [Math]::Min(1.0, $Current / $Total) } else { 0 }
    $fill = [int]($barW * $frac)
    $bar = ([string][char]0x2588) * $fill + ([string][char]0x2591) * ($barW - $fill)
    $pose = $script:LoadFrame % 2
    $script:LoadFrame++
    $face = if ($pose -eq 0) { '( o.o )' } else { '( -.- )' }
    $legs = if ($pose -eq 0) { ' > ^ <' } else { ' > ^ <~' }
    $catX = 4 + [int](($barW - 8) * $frac)
    $pad = ' ' * $catX
    $pct = [int]($frac * 100)
    $lines = @(
      ($pad + ' /\_/\'),
      ($pad + $face),
      ($pad + $legs),
      ('  [' + $bar + '] ' + $pct + '%  ' + $Current + '/' + $Total),
      ('  ' + $Label)
    )
    $pos = $raw.CursorPosition
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $t = Pad-Display -Text $lines[$i] -Width $inner -NoTrim
      $raw.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 2, ($script:LoadBarY + $i)
      [Console]::Write($t)
    }
    $raw.CursorPosition = $pos
  } catch {}
}

function Start-LoadingPlan {
  param([int]$Total, [string]$Label = 'reading task metadata')
  $script:LoadCurrent = 0
  $script:LoadTotal = [Math]::Max(1, $Total)
  Update-LoadingBar -Current 0 -Total $script:LoadTotal -Label $Label
}

function Step-LoadingPlan {
  param([string]$Label)
  $script:LoadCurrent = [Math]::Min($script:LoadTotal, $script:LoadCurrent + 1)
  Update-LoadingBar -Current $script:LoadCurrent -Total $script:LoadTotal -Label $Label
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
    [ConsoleColor]$Border = [ConsoleColor]::DarkGray,
    [object[]]$Parts
  )
  # Parts: array of @{ T='text'; C=[ConsoleColor] }
  # Frame guarantee: parts are HARD-truncated (Limit-Display, no '~') so the
  # right border can never be pushed past the box edge (爆格子 regression fix).
  $inner = Get-InnerWidth
  $segs = @()
  $segs += @{ T = '  |'; C = $Border }
  $segs += @{ T = ' '; C = [ConsoleColor]::Gray }
  $used = 1
  foreach ($p in $Parts) {
    $t = [string]$p.T
    $c = $p.C
    if (-not $c) { $c = [ConsoleColor]::Gray }
    $room = $inner - $used
    if ($room -le 0) { break }
    $tw = Get-DisplayWidth $t
    if ($tw -gt $room) {
      $t = Limit-Display -Text $t -MaxWidth $room
      $tw = Get-DisplayWidth $t
    }
    $segs += @{ T = $t; C = $c }
    $used += $tw
  }
  $pad = $inner - $used
  if ($pad -gt 0) { $segs += @{ T = (' ' * $pad); C = [ConsoleColor]::DarkGray } }
  $segs += @{ T = '|'; C = $Border }
  foreach ($s in $segs) {
    if ($s.T -eq '|') { Write-Host $s.T -ForegroundColor $s.C }
    else { Write-Host -NoNewline $s.T -ForegroundColor $s.C }
  }
  $script:DrawnLines++
}

# Fixed-cell multi-color row. Every row that shares $Widths starts each option
# at the same terminal column; label length can no longer push later cells.
function Write-BoxGridRow {
  param(
    [ConsoleColor]$Border = [ConsoleColor]::DarkGray,
    [object[]]$Cells,
    [int[]]$Widths
  )
  $parts = @()
  for ($i = 0; $i -lt $Widths.Count; $i++) {
    $width = [Math]::Max(0, [int]$Widths[$i])
    if ($width -eq 0) { continue }
    $cell = if ($i -lt $Cells.Count) { $Cells[$i] } else { $null }
    $used = 0
    if ($cell) {
      $key = [string]$cell.K
      $label = [string]$cell.L
      $keyColor = if ($cell.KC) { $cell.KC } else { [ConsoleColor]::Yellow }
      $labelColor = if ($cell.LC) { $cell.LC } else { [ConsoleColor]::Gray }
      if ($key) {
        $key = Limit-Display -Text $key -MaxWidth $width
        $kw = Get-DisplayWidth $key
        $parts += @{ T = $key; C = $keyColor }
        $used += $kw
      }
      $room = $width - $used
      if ($label -and $room -gt 0) {
        $label = Limit-Display -Text $label -MaxWidth $room
        $lw = Get-DisplayWidth $label
        $parts += @{ T = $label; C = $labelColor }
        $used += $lw
      }
    }
    $pad = $width - $used
    if ($pad -gt 0) { $parts += @{ T = (' ' * $pad); C = [ConsoleColor]::DarkGray } }
  }
  Write-BoxKeyRow -Border $Border -Parts $parts
}

# Column layout for content band = 86% of full window width (see Get-UiWidth).
# Guarantee: Title ~45%+ of the band; Project compact; gaps wide (3–6 spaces).
function Update-ColLayout {
  $inner = Get-InnerWidth
  $U = [Math]::Max(60, $inner - 1)

  # --- Flexible primary fields (must stay readable) ---
  $title = [Math]::Max(30, [Math]::Floor($U * 0.45) - 27)  # 27 = path col beyond old act col
  $proj  = [Math]::Min(22, [Math]::Max(14, [Math]::Floor($U * 0.14)))  # narrower Project → room for Title (user 23:32)

  # --- Compact meta ---
  # Number column = FULL chip prefix width after the left border: leading ' '
  # (Write-BoxKeyRow) + 2-space indent + bracket chip. Default view chips are
  # compact ('[1]'=3 → 6); ShowAll pads to 2 digits ('[12]'=4 → 7). Must match
  # Show-Screen exactly or the right border drifts off the frame.
  $flagW = 0
  $num = if ($script:ShowAll) { 7 } else { 6 }
  $date = 11
  $badge = 5
  $model = 9
  $path = 32  # project folder path; Pad-Display tail-truncates with '~' when over
  $branch = 0   # hide branch in list by default → more title room
  # parts: chip date badge proj path model title = 7 → 6 gaps
  $gapsN = 6

  $meta = $num + $date + $badge + $model + $path + $branch
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
    if ($need -gt 0 -and $date -gt 10) {
      # floor 10: keeps the '---- -- --' placeholder intact; real dates may
      # still lose a minute digit in ultra-narrow hosts (frame stays intact)
      $cut = [Math]::Min($need, $date - 10)
      $date -= $cut
      $need -= $cut
    }
    if ($need -gt 0) {
      $title = [Math]::Max(28, $title - $need)
    }
    $meta = $num + $date + $badge + $model + $path + $branch
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
      # last resort for narrow hosts: shrink Path then Project, re-fit Title
      $used3 = $flagW + $meta + $title + $proj + ($gapsN * $gapW)
      if ($used3 -gt $U) {
        $path = 24
        $meta = $num + $date + $badge + $model + $path + $branch
        $title = [Math]::Max(20, $U - $flagW - $meta - $proj - ($gapsN * $gapW))
        $used3 = $flagW + $meta + $title + $proj + ($gapsN * $gapW)
        if ($used3 -gt $U) {
          $proj = 14
          $title = [Math]::Max(16, $U - $flagW - $meta - $proj - ($gapsN * $gapW))
        }
      }
    }
  }

  $script:ColGap = ' ' * $gapW
  $script:Col = @{
    Num    = $num
    Date   = $date
    Badge  = $badge
    Proj   = $proj
    Path   = $path
    Model  = $model
    Branch = $branch
    Title  = $title
  }
}

function Format-TableRow {
  # D-009: returns columns from Date onward; the bracket chip is prepended by
  # Show-Screen as its own colored segment (stage highlight).
  param(
    [string]$Date, [string]$Badge,
    [string]$Proj, [string]$Path, [string]$Model, [string]$Branch, [string]$Title
  )
  $br = if ($script:Col.Branch -le 0) { '' } else {
    Pad-Display -Text $(if ([string]::IsNullOrEmpty($Branch) -or $Branch -eq '-') { '' } else { $Branch }) -Width $script:Col.Branch
  }
  $parts = @(
    (Pad-Display -Text $Date -Width $script:Col.Date),
    (Pad-Display -Text $Badge -Width $script:Col.Badge),
    (Pad-Display -Text $Proj -Width $script:Col.Proj),
    (Pad-Display -Text $Path -Width $script:Col.Path),
    (Pad-Display -Text $(if ([string]::IsNullOrEmpty($Model)) { '' } else { $Model }) -Width $script:Col.Model)
  )
  if ($script:Col.Branch -gt 0) { $parts += $br }
  $parts += (Pad-Display -Text $Title -Width $script:Col.Title)
  return ($parts -join $script:ColGap)
}

function Format-HeaderRow {
  # D-009: header from Date onward; the "[#]" chip cell is prepended by Show-Screen.
  $parts = @(
    (Pad-Display -Text 'DateTime' -Width $script:Col.Date),
    (Pad-Display -Text 'Tag' -Width $script:Col.Badge),
    (Pad-Display -Text 'Project' -Width $script:Col.Proj),
    (Pad-Display -Text 'Path' -Width $script:Col.Path),
    (Pad-Display -Text 'Model' -Width $script:Col.Model)
  )
  if ($script:Col.Branch -gt 0) {
    $parts += (Pad-Display -Text 'Branch' -Width $script:Col.Branch)
  }
  $parts += (Pad-Display -Text 'Title' -Width $script:Col.Title)
  return ($parts -join $script:ColGap)
}

function Show-Screen {
  # Static screen (D-009): draw ONLY when something changed. Line input via
  # Read-Host needs zero repaint while typing.
  if (-not $script:ScreenDirty -and -not $script:RowsDirty) { return }
  if ($script:RowsDirty) {
    Show-LoadingScreen
    [void](Build-Rows)  # sets $script:Rows
    $script:RowsDirty = $false
  }
  $script:ScreenDirty = $false
  $rows = $script:Rows
  Reset-Screen
  Update-ColLayout
  $now = Get-Date -Format 'yyyy-MM-dd HH:mm'
  $view = if ($script:ShowAll) { 'ALL non-noise (combo off)' } else { 'top 9 · <t><a> combo on · a = all' }
  $hint = $script:StatusHint
  $script:StatusHint = ''

  # D-013: bright Yellow is RESERVED for input affordances only — option
  # index chips and input-prompt prefixes. Frames/titles NEVER Yellow.
  # Zone borders: LIST=Cyan, AGENT=Magenta, COMMAND=DarkGray (neutral;
  # lets the Yellow key chips inside pop as the sole input signal).
  $bHead = [ConsoleColor]::DarkGray
  $bList = [ConsoleColor]::Cyan
  $bCmd  = [ConsoleColor]::DarkGray

  # ----- HEADER -----
  Write-BoxTop -Title 'WZ INIT' -Border $bHead
  Write-BoxLine -Text ("$now   rows $($rows.Count)   $view") -Fg DarkGray -Border $bHead
  if ($hint) {
    Write-BoxRule -Border $bHead
    Write-BoxLine -Text ("! $hint") -Fg Cyan -Border $bHead
  }
  Write-BoxBottom -Border $bHead

  # ----- 1 LIST (Cyan border) -----
  # D-009 stage highlight: active step's number chips glow Yellow, inactive dim
  # to DarkGray. Chips are bracketed [n] in BOTH zones at the same indent (x=6);
  # width budget lives in Update-ColLayout ($num = 1 space + 2 indent + chip).
  $listActive = (-not $script:PendingRow)
  $listTitle = if ($listActive) { '1 LIST  << step 1 · type task number' } else { '1 LIST' }
  Write-BoxTop -Title $listTitle -Border $bList
  $chipHdr = Pad-Display -Text '[#]' -Width ($script:Col.Num - 3)
  $hdr = '   ' + $chipHdr + $script:ColGap + (Format-HeaderRow)
  $hdr = Pad-Display -Text $hdr -Width (Get-InnerWidth) -NoTrim
  Write-FullLine -Text ('  |' + $hdr + '|') -Fg DarkGray
  Write-BoxRule -Border $bList

  if ($rows.Count -eq 0) {
    Write-BoxLine -Text '(empty)  press  c  in COMMAND to create first task' -Fg Gray -Border $bList
  } else {
    $chipC = if ($listActive) { [ConsoleColor]::Yellow } else { [ConsoleColor]::DarkGray }
    $rowC  = if ($listActive) { [ConsoleColor]::Gray } else { [ConsoleColor]::DarkGray }
    for ($idx = 0; $idx -lt $rows.Count; $idx++) {
      $r = $rows[$idx]
      # Compact chip: '[1]' in the capped default view; '[12]' pad only in ShowAll
      $chip = if ($script:ShowAll) { '[' + ([string]$r.Index).PadLeft(2) + ']' } else { '[' + [string]$r.Index + ']' }
      $rest = Format-TableRow `
        -Date (Format-DateTime $r.Updated) -Badge $(if ($r.Badge) { $r.Badge } else { '' }) `
        -Proj $r.Project -Path $(if ($r.Cwd) { $r.Cwd } else { '' }) `
        -Model $(if ($r.Model) { $r.Model } else { '' }) `
        -Branch $(if ($r.Branch -and $r.Branch -ne '-') { $r.Branch } else { '' }) `
        -Title $r.Title
      Write-BoxKeyRow -Border $bList -Parts @(
        @{ T = ('  ' + $chip); C = $chipC },
        @{ T = ($script:ColGap + $rest); C = $rowC }
      )
    }
  }
  Write-BoxBottom -Border $bList

  Write-FullLine -Text ''

  # ----- 2 AGENT (always visible; step-2 input lands at the prompt below) -----
  $bAgt = [ConsoleColor]::Magenta
  $peerList = @(Get-InstalledAgentPeers)
  $armRow = if ($script:PendingRow) { $script:PendingRow } else { $null }
  $agentActive = [bool]$armRow
  $agTitle = if ($armRow) { '2 AGENT  << step 2 · pick agent for ' + $armRow.Project } else { '2 AGENT' }
  Write-BoxTop -Title $agTitle -Border $bAgt
  if ($peerList.Count -eq 0) {
    Write-BoxLine -Text '(no self-described or locally registered agent CLI detected)' -Fg DarkGray -Border $bAgt
  } else {
    $aChipC = if ($agentActive) { [ConsoleColor]::Yellow } else { [ConsoleColor]::DarkGray }
    $aNameC = if ($agentActive) { [ConsoleColor]::White } else { [ConsoleColor]::Gray }
    $aModeC = if ($agentActive) { [ConsoleColor]::Gray } else { [ConsoleColor]::DarkGray }
    $defAgent = if ($armRow) { [string]$armRow.LaunchAgent } else { '' }
    for ($ai = 0; $ai -lt $peerList.Count; $ai++) {
      $peer = $peerList[$ai]
      $mode = 'new'
      if (-not $script:PendingForceNew -and $armRow -and $armRow.Kind -eq 'session' -and $armRow.Id -and (([string]$armRow.Agent).ToLowerInvariant() -eq $peer.Id)) { $mode = 'resume' }
      $tag = ''
      if ($armRow -and $peer.Id -eq $defAgent) { $tag = '  (default)' }
      Write-BoxKeyRow -Border $bAgt -Parts @(
        @{ T = ('  [' + ($ai + 1) + ']'); C = $aChipC },
        @{ T = (' ' + $peer.Label); C = $aNameC },
        @{ T = ('  ' + $mode); C = $aModeC },
        @{ T = $tag; C = [ConsoleColor]::Green }
      )
    }
  }
  Write-BoxRule -Border $bAgt
  if ($armRow) {
    Write-BoxLine -Text 'type: agent number + Enter = that agent · Enter alone = (default) · q = cancel' -Fg White -Border $bAgt
  } else {
    Write-BoxLine -Text 'idle — step 1 first: type a task number below; agents light up on demand' -Fg DarkGray -Border $bAgt
  }
  Write-BoxBottom -Border $bAgt

  Write-FullLine -Text ''

  # ----- 3 COMMAND (DarkGray frame; Yellow key chips = sole input signal) -----
  Write-BoxTop -Title '3 COMMAND  << type keys here' -Border $bCmd

  # Input line - static hint; real typing happens at the Read-Host prompt below.
  # D-013: ' >_' marker Yellow (input-affordance prefix, same family as
  # wz> / explorer>), status text White; the frame itself stays DarkGray.
  $comboOn = (-not $script:ShowAll) -and ($script:Rows.Count -le 9) -and ($script:Rows.Count -gt 0)
  if ($script:PendingRow) {
    $field = '  step 2 ACTIVE: agent number + Enter  (Enter = default, q = cancel)'
  } elseif ($comboOn) {
    $field = '  step 1 ACTIVE: task # · or one-shot <t><a> = task+agent launch'
  } else {
    $field = '  step 1 ACTIVE: task number + Enter  (n<num> = new session)'
  }
  Write-BoxKeyRow -Border $bCmd -Parts @(
    @{ T = ' >_'; C = [ConsoleColor]::Yellow },
    @{ T = $field; C = [ConsoleColor]::White }
  )

  Write-BoxRule -Border $bCmd

  # D-016: three fixed grid cells. All rows reuse these widths, so the c/s/q
  # options cannot drift with the prose length of the cell before them.
  $gridW = [Math]::Max(30, (Get-InnerWidth) - 1) # Write-BoxKeyRow owns 1 leading space
  $grid1 = [Math]::Floor($gridW * 0.40)
  $grid2 = [Math]::Floor($gridW * 0.34)
  $cmdGridWidths = @($grid1, $grid2, ($gridW - $grid1 - $grid2))
  Write-BoxGridRow -Border $bCmd -Widths $cmdGridWidths -Cells @(
    @{ K = '[ <num> ]'; L = ' open task → pick agent' },
    @{ K = '[ <t><a> ]'; L = ' one-shot launch' },
    $null
  )
  Write-BoxGridRow -Border $bCmd -Widths $cmdGridWidths -Cells @(
    @{ K = '[ n<num> ]'; L = ' new session → pick agent' },
    @{ K = '[ c ]'; L = ' NEW TASK wizard'; LC = [ConsoleColor]::White },
    @{ K = '[ s ]'; L = ' shell' }
  )
  Write-BoxRule -Border $bCmd
  Write-BoxGridRow -Border $bCmd -Widths $cmdGridWidths -Cells @(
    @{ K = '[ a ]'; L = ' looser'; LC = [ConsoleColor]::DarkGray },
    @{ K = '[ r ]'; L = ' refresh'; LC = [ConsoleColor]::DarkGray },
    @{ K = '[ q ]'; L = ' quit'; LC = [ConsoleColor]::DarkGray }
  )
  Write-BoxBottom -Border $bCmd

  End-Screen
}

function Get-RowByIndex {
  param([int]$Num)
  foreach ($r in $script:Rows) { if ($r.Index -eq $Num) { return $r } }
  return $null
}

function Resolve-LaunchCwd {
  # R1: never hand an agent CLI a weak path as session identity
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

function Set-SpawnedTabTitle {
  # D-011: NEVER call `set-tab-title` without a verified pane id — the no-id
  # form targets the CLI's CURRENT tab, which renamed the Init tab to
  # "WZ_Skill | Kimi" on every launch (user report 2026-08-13 晚). Hardened
  # 2026-08-14 after pollution recurred: spawn stdout must be EXACTLY the new
  # pane id (digits only, whole output) — any extra content aborts the rename;
  # self-target guard can never rename our own (Init) pane's tab; every call
  # is appended to tabtitle-debug.log so the next repro shows the raw truth.
  param([string]$SpawnOut, [int]$ExitCode, [string]$TabTitle)
  $paneId = $null
  if ($ExitCode -eq 0 -and $SpawnOut) {
    $m = [regex]::Match($SpawnOut.Trim(), '^(\d+)$')
    if ($m.Success) { $paneId = $m.Groups[1].Value }
  }
  $self = $env:WEZTERM_PANE
  $action = 'rename'
  if ($ExitCode -ne 0) { $action = 'skip-exit' }
  elseif (-not $paneId) { $action = 'skip-parse' }
  elseif ($self -and $paneId -eq $self) { $action = 'skip-self'; $paneId = $null }
  try {
    $log = Join-Path $PSScriptRoot 'tabtitle-debug.log'
    $raw = if ($null -eq $SpawnOut) { '<null>' } else { ($SpawnOut -replace '\r', '<CR>' -replace '\n', '<LF>') }
    $line = '{0:yyyy-MM-dd HH:mm:ss} exit={1} self={2} pane={3} action={4} title="{5}" raw="{6}"' -f `
      (Get-Date), $ExitCode, $(if ($self) { $self } else { '?' }), $(if ($paneId) { $paneId } else { '-' }), $action, $TabTitle, $raw
    if ((Test-Path -LiteralPath $log) -and ((Get-Item -LiteralPath $log).Length -gt 65536)) {
      Set-Content -LiteralPath $log -Value '# tabtitle debug (rotated)' -Encoding UTF8
    }
    Add-Content -LiteralPath $log -Value $line -Encoding UTF8
  } catch {}
  if (-not $paneId) { return }  # status.lua computes a label anyway; never touch current tab
  try { & $script:Wez @('cli', 'set-tab-title', '--pane-id', "$paneId", $TabTitle) 2>$null | Out-Null } catch {}
}

function Get-AgentSplashScript {
  # D-012-era launch UX: Init closes right after a successful spawn, and the
  # agent CLI then boots for seconds over a BLACK void. 2026-08-14 user: give
  # EVERY agent the Init walking cat (那只 loading 猫猫读条), not a static card.
  # Animated 5-frame *indeterminate* splash (~300ms) painted BEFORE the agent
  # starts. A percentage here was false telemetry: the wrapper cannot know an
  # arbitrary interactive CLI's readiness and 100% could appear seconds before
  # its first paint. Counted file/session work uses the real global progress
  # axis; process handoff deliberately shows no percentage.
  # Redirected hosts (smoke tests) get one static frame — no cursor math there.
  # Template is a SINGLE-quoted here-string: only the __WZ_SPLASH_*_7F3A__
  # tokens are substituted (L2-7: unguessable tokens kill chain-replace
  # hazards), so inner $__vars reach the spawned wrapper verbatim.
  param([string]$AgentLabel, [string]$Project)
  $al = $AgentLabel.Replace("'", "''")
  $pj = $Project.Replace("'", "''")
  $tpl = @'
try { [Console]::Clear() } catch {}
$__al = '__WZ_SPLASH_AGENT_7F3A__'
$__pj = '__WZ_SPLASH_PROJ_7F3A__'
$__w = 80
try { $__w = [Console]::WindowWidth } catch {}
$__bw = [Math]::Min(44, [Math]::Max(16, $__w - 26))
$__redir = $false
try { $__redir = [Console]::IsOutputRedirected } catch {}
$__frames = 5
if ($__redir) { $__frames = 1 }
$__y = 0
for ($__f = 0; $__f -lt $__frames; $__f++) {
  $frac = 1.0
  if ($__frames -gt 1) { $frac = $__f / ($__frames - 1) }
  $pulse = [Math]::Max(3, [int]($__bw / 6))
  $start = [int](($__bw - $pulse) * $frac)
  $bar = ([string][char]0x2591) * $start + ([string][char]0x2588) * $pulse + ([string][char]0x2591) * ($__bw - $start - $pulse)
  $face = '( -.- )'
  $legs = ' > ^ <~'
  if ($__f % 2 -eq 0) { $face = '( o.o )'; $legs = ' > ^ <' }
  $pad = ' ' * (2 + [int](($__bw - 8) * $frac))
  try {
    if (-not $__redir) {
      if ($__f -eq 0) { $__y = [Console]::CursorTop } else { [Console]::SetCursorPosition(0, $__y) }
    }
    Write-Host ''
    Write-Host ($pad + ' /\_/\') -ForegroundColor Magenta
    Write-Host ($pad + $face) -ForegroundColor Magenta
    Write-Host ($pad + $legs) -ForegroundColor Magenta
    Write-Host ('  [' + $bar + ']') -ForegroundColor Magenta
    Write-Host ('  ' + $__pj + ' · ' + $__al) -ForegroundColor Gray
    Write-Host '  handing off to agent process...' -ForegroundColor DarkGray
  } catch {}
  if ($__frames -gt 1 -and $__f -lt ($__frames - 1)) { Start-Sleep -Milliseconds 75 }
}
try { [Console]::Clear() } catch {}
'@
  return $tpl.Replace('__WZ_SPLASH_AGENT_7F3A__', $al).Replace('__WZ_SPLASH_PROJ_7F3A__', $pj)
}

function Get-AgentSplashSpawn {
  # Spawn argv for: powershell -NoLogo -Command "<splash>; & '<exe>' <args...>".
  # No -NoExit → when the agent exits, the pane closes (parity with direct
  # spawn today). argv0 is real powershell.exe (no .cmd-shim freeze hazard).
  param([string]$Exe, [string[]]$ExeArgs, [string]$AgentLabel, [string]$Project)
  $exeLit = "'" + ([string]$Exe).Replace("'", "''") + "'"
  $argStr = ''
  if ($ExeArgs) {
    $argStr = ' ' + (($ExeArgs | ForEach-Object { "'" + ([string]$_).Replace("'", "''") + "'" }) -join ' ')
  }
  $psCmd = (Get-AgentSplashScript -AgentLabel $AgentLabel -Project $Project) + "`r`n& $exeLit$argStr"
  return @('powershell.exe', '-NoLogo', '-Command', $psCmd)
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
    return $false
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
    $proj = Split-Path -Leaf $Cwd
    $spawn = @('cli', 'spawn')
    $spawn += @('--cwd', $Cwd)
    $spawn += '--'
    $spawn += Get-AgentSplashSpawn -Exe $script:Grok -ExeArgs $fullArgs -AgentLabel 'Grok' -Project $proj
    try {
      $spawnOut = & $script:Wez @spawn 2>$null | Out-String
      # Tab role suffix is agent-specific (status.lua parses "Project | Role");
      # each Start-*Tab sets its own — this one is Grok only
      $tabTitle = '{0} | Grok' -f $proj
      Set-SpawnedTabTitle -SpawnOut $spawnOut -ExitCode $LASTEXITCODE -TabTitle $tabTitle
      Write-Host ("  OK: {0}" -f $Title) -ForegroundColor Green
      Write-Host ("  --cwd {0}" -f $Cwd) -ForegroundColor DarkGray
      Start-Sleep -Milliseconds 200  # D-012: Init closes right after — settle only, no read time
      return $true
    } catch {}
  }
  Set-Location -LiteralPath $Cwd
  & $script:Grok @fullArgs
}

function Start-KimiTab {
  # F-011: kimi has no --cwd / --resume. Process cwd IS task identity
  # (wezterm cli spawn --cwd <task path>), continue = `kimi --continue`.
  param(
    [string]$Cwd,
    [string[]]$KimiArgs,
    [string]$Title = 'kimi'
  )
  $exe = Find-AgentExe -Id 'kimi'
  if (-not $exe) {
    $script:StatusHint = 'kimi.exe not found — install Kimi Code CLI first'
    return $false
  }
  # R1 hard gate (same as Grok)
  if (-not (Test-StrongProjectPath -Cwd $Cwd)) {
    $script:StatusHint = "GATE: refuse Kimi on weak path ($Cwd) — press c for new task"
    return
  }
  if (-not (Test-Path -LiteralPath $Cwd)) {
    $script:StatusHint = "Path missing: $Cwd"
    return
  }

  $fullArgs = @(); if ($KimiArgs) { $fullArgs += $KimiArgs }
  if ($script:Wez -and (Test-WezAlive)) {
    $proj = Split-Path -Leaf $Cwd
    $spawn = @('cli', 'spawn')
    $spawn += @('--cwd', $Cwd)
    $spawn += '--'
    $spawn += Get-AgentSplashSpawn -Exe $exe -ExeArgs $fullArgs -AgentLabel 'Kimi' -Project $proj
    try {
      $spawnOut = & $script:Wez @spawn 2>$null | Out-String
      $tabTitle = '{0} | Kimi' -f $proj
      Set-SpawnedTabTitle -SpawnOut $spawnOut -ExitCode $LASTEXITCODE -TabTitle $tabTitle
      Write-Host ("  OK: {0}" -f $Title) -ForegroundColor Green
      Write-Host ("  cwd {0}" -f $Cwd) -ForegroundColor DarkGray
      Start-Sleep -Milliseconds 200  # D-012: Init closes right after — settle only
      return $true
    } catch {}
  }
  Set-Location -LiteralPath $Cwd
  & $exe @fullArgs
}

function Start-CodexTab {
  # Codex parity: unlike kimi, codex HAS a work-root flag (-C/--cd <DIR>) and can
  # resume any session by id: `codex resume <id>` / `codex resume --last`.
  # Shim pitfall: WinGet resolves `codex` to codex.cmd, and .cmd MUST NOT be the
  # argv0 of CreateProcess (freeze history — see Start-ProjectWithCli). A shim is
  # therefore launched through a PowerShell host wrap, a real exe directly.
  param(
    [string]$Cwd,
    [string[]]$CodexArgs,
    [string]$Title = 'codex'
  )
  $exe = Find-AgentExe -Id 'codex'
  if (-not $exe) {
    $script:StatusHint = 'codex.exe not found — install Codex CLI first'
    return
  }
  # R1 hard gate (same as Grok/Kimi)
  if (-not (Test-StrongProjectPath -Cwd $Cwd)) {
    $script:StatusHint = "GATE: refuse Codex on weak path ($Cwd) — press c for new task"
    return
  }
  if (-not (Test-Path -LiteralPath $Cwd)) {
    $script:StatusHint = "Path missing: $Cwd"
    return
  }

  # Inject -C <cwd> (root-level flag, must precede subcommands like resume)
  $hasC = $false
  if ($CodexArgs) {
    for ($ci = 0; $ci -lt $CodexArgs.Count; $ci++) {
      if ($CodexArgs[$ci] -eq '-C' -or $CodexArgs[$ci] -eq '--cd') { $hasC = $true; break }
      if ($CodexArgs[$ci] -like '--cd=*') { $hasC = $true; break }
    }
  }
  $fullArgs = @()
  if (-not $hasC) { $fullArgs += @('-C', $Cwd) }
  if ($CodexArgs) { $fullArgs += $CodexArgs }

  $isShim = $exe -match '\.(cmd|bat|ps1)$'
  if ($script:Wez -and (Test-WezAlive)) {
    $proj = Split-Path -Leaf $Cwd
    $tabTitle = '{0} | Codex' -f $proj
    if ($isShim) {
      # Host wrap: keep shell open (-NoExit) so CLI errors stay visible
      $argStr = ($fullArgs | ForEach-Object { "'" + ([string]$_).Replace("'", "''") + "'" }) -join ' '
      $invoke = [System.IO.Path]::GetFileNameWithoutExtension($exe)
      $psCmd = (Get-AgentSplashScript -AgentLabel 'Codex' -Project $proj) + "`r`n& $invoke $argStr"
      $spawn = @('cli', 'spawn', '--cwd', $Cwd, '--', 'powershell.exe', '-NoLogo', '-NoExit', '-Command', $psCmd)
    } else {
      $spawn = @('cli', 'spawn', '--cwd', $Cwd, '--') + (Get-AgentSplashSpawn -Exe $exe -ExeArgs $fullArgs -AgentLabel 'Codex' -Project $proj)
    }
    try {
      $spawnOut = & $script:Wez @spawn 2>$null | Out-String
      Set-SpawnedTabTitle -SpawnOut $spawnOut -ExitCode $LASTEXITCODE -TabTitle $tabTitle
      Write-Host ("  OK: {0}" -f $Title) -ForegroundColor Green
      Write-Host ("  -C {0}" -f $Cwd) -ForegroundColor DarkGray
      Start-Sleep -Milliseconds 200  # D-012: Init closes right after — settle only
      return $true
    } catch {}
  }
  Set-Location -LiteralPath $Cwd
  if ($isShim) {
    $invoke = [System.IO.Path]::GetFileNameWithoutExtension($exe)
    & $invoke @fullArgs
  } else {
    & $exe @fullArgs
  }
}

function Start-DeepSeekTab {
  # F-014: DeepSeek CLI (@kavienw/deepseek-cli, npm shim deepseek.cmd).
  # NO --cwd flag — process cwd IS project identity (kimi pattern);
  # resume = `deepseek --continue` (per-cwd session at
  # ~/.deepseek-cli/sessions/<sha256(cwd)[0:16]>.json; REPL also auto-restores,
  # so ForceNew cannot guarantee a blank context — CLI's own product behavior).
  # npm .cmd shim MUST NOT be argv0 of CreateProcess → PowerShell host wrap
  # (codex shim pattern), walking-cat splash prepended.
  param(
    [string]$Cwd,
    [string[]]$DeepseekArgs,
    [string]$Title = 'deepseek'
  )
  $exe = Find-AgentExe -Id 'deepseek'
  if (-not $exe) {
    $script:StatusHint = 'deepseek.cmd not found — npm i -g @kavienw/deepseek-cli first'
    return
  }
  # R1 hard gate (same as Grok/Kimi/Codex)
  if (-not (Test-StrongProjectPath -Cwd $Cwd)) {
    $script:StatusHint = "GATE: refuse DeepSeek on weak path ($Cwd) — press c for new task"
    return
  }
  if (-not (Test-Path -LiteralPath $Cwd)) {
    $script:StatusHint = "Path missing: $Cwd"
    return
  }

  $fullArgs = @(); if ($DeepseekArgs) { $fullArgs += $DeepseekArgs }
  if ($script:Wez -and (Test-WezAlive)) {
    $proj = Split-Path -Leaf $Cwd
    $argStr = ($fullArgs | ForEach-Object { "'" + ([string]$_).Replace("'", "''") + "'" }) -join ' '
    $invoke = [System.IO.Path]::GetFileNameWithoutExtension($exe)
    $psCmd = (Get-AgentSplashScript -AgentLabel 'DeepSeek' -Project $proj) + "`r`n& $invoke $argStr"
    $spawn = @('cli', 'spawn', '--cwd', $Cwd, '--', 'powershell.exe', '-NoLogo', '-NoExit', '-Command', $psCmd)
    try {
      $spawnOut = & $script:Wez @spawn 2>$null | Out-String
      $tabTitle = '{0} | DeepSeek' -f $proj
      Set-SpawnedTabTitle -SpawnOut $spawnOut -ExitCode $LASTEXITCODE -TabTitle $tabTitle
      Write-Host ("  OK: {0}" -f $Title) -ForegroundColor Green
      Write-Host ("  cwd {0}" -f $Cwd) -ForegroundColor DarkGray
      Start-Sleep -Milliseconds 200  # D-012: Init closes right after — settle only
      return $true
    } catch {}
  }
  Set-Location -LiteralPath $Cwd
  $invoke = [System.IO.Path]::GetFileNameWithoutExtension($exe)
  & $invoke @fullArgs
}

function Get-AgentDefinitions {
  # D-016: one metadata-driven inventory for the Init chooser and F3 wizard.
  # The helper has no product-name whitelist and never executes candidates.
  if ($null -ne $script:AgentDefinitions) { return @($script:AgentDefinitions) }
  $out = @()
  if (Test-Path -LiteralPath $script:AgentDiscoveryFile -PathType Leaf) {
    try { $out = @(& $script:AgentDiscoveryFile -WorkbenchDir $PSScriptRoot) } catch {}
  }
  $script:AgentDefinitions = @($out | Where-Object { $_.Id -and $_.Exe } | Sort-Object Label, Id)
  return @($script:AgentDefinitions)
}

function Get-AgentLabel {
  param([string]$Id)
  foreach ($d in @(Get-AgentDefinitions)) {
    if ([string]$d.Id -eq ([string]$Id).ToLowerInvariant()) { return [string]$d.Label }
  }
  return [string]$Id
}

function Get-InstalledAgentPeers {
  # Cached per Init process; a cold start always re-discovers. `r` clears both
  # caches so a newly installed or locally registered agent appears in place.
  if ($null -ne $script:AgentPeers) { return @($script:AgentPeers) }
  $script:AgentPeers = @(Get-AgentDefinitions | ForEach-Object {
    [pscustomobject]@{ Id = [string]$_.Id; Label = [string]$_.Label; Exe = [string]$_.Exe }
  })
  return @($script:AgentPeers)
}

function Invoke-AgentLaunch {
  # Launches $Agent on the row's project path. Resume only when the row carries a
  # session of that same agent; otherwise a fresh session starts on the path.
  # Returns $true only when the agent tab was actually spawned (D-012: callers
  # close the Init tab on success; cancel/gate/failure paths stay open).
  param($Row, [string]$Agent, [string]$Launch, [switch]$ForceNew)
  $resume = (-not $ForceNew) -and ($Row.Kind -eq 'session') -and $Row.Id -and (([string]$Row.Agent).ToLowerInvariant() -eq $Agent)
  $verb = if ($ForceNew) { 'new' } elseif ($resume) { 'resume' } else { 'open' }
  $title = '{0} {1}' -f $verb, $Row.Project
  if ($Agent -eq 'kimi') {
    if ($resume) { return (Start-KimiTab -Cwd $Launch -KimiArgs @('--continue') -Title $title) }
    return (Start-KimiTab -Cwd $Launch -KimiArgs @() -Title $title)
  }
  if ($Agent -eq 'codex') {
    if ($resume) { return (Start-CodexTab -Cwd $Launch -CodexArgs @('resume', $Row.Id) -Title $title) }
    return (Start-CodexTab -Cwd $Launch -CodexArgs @() -Title $title)
  }
  if ($Agent -eq 'deepseek') {
    # --continue resolves the per-cwd session itself; $Row.Id (hash) is
    # display/matching identity only, never passed to the CLI.
    if ($resume) { return (Start-DeepSeekTab -Cwd $Launch -DeepseekArgs @('--continue') -Title $title) }
    return (Start-DeepSeekTab -Cwd $Launch -DeepseekArgs @() -Title $title)
  }
  if ($Agent -eq 'grok') {
    if ($resume) { return (Start-GrokTab -Cwd $Launch -GrokArgs @('--cwd', $Launch, '--resume', $Row.Id) -Title $title) }
    return (Start-GrokTab -Cwd $Launch -GrokArgs @('--cwd', $Launch) -Title $title)
  }

  # Generic adapter: every newly discovered agent can launch immediately. A
  # product-specific resume adapter is optional; absence never hides the agent.
  $def = @(Get-AgentDefinitions | Where-Object { $_.Id -eq $Agent } | Select-Object -First 1)
  if ($def.Count -eq 0) {
    $script:StatusHint = "agent '$Agent' is no longer installed"
    return $false
  }
  return (Start-ProjectWithCli -Cwd $Launch -Name $Row.Project -Kind $Agent -Exe $def[0].Exe -Label $def[0].Label -Id $Agent)
}

function Invoke-RowPrimary {
  # Step 1 of the two-step launch: gates + arm the AGENT zone (same screen).
  param($Row)
  if (-not $Row) {
    $script:StatusHint = 'No row selected - press c for new task wizard'
    $script:ScreenDirty = $true
    return
  }
  if ($Row.IsWeak -or $Row.Layer -eq 'system') {
    $script:StatusHint = 'GATE: system/home session is not a formal task — press c to create/bind project'
    $script:ScreenDirty = $true
    return
  }
  $launch = Resolve-LaunchCwd -Row $Row
  if (-not $launch) {
    $script:StatusHint = 'GATE: no strong project path — press c wizard'
    $script:ScreenDirty = $true
    return
  }
  $script:PendingRow = $Row
  $script:PendingForceNew = $false
  $script:PendingLaunch = $launch
  $script:ScreenDirty = $true
}

function Invoke-RowNewSession {
  # Step 1 (forced-new variant): gates + arm the AGENT zone.
  param($Row)
  if (-not $Row -or -not $Row.Cwd -or $Row.IsWeak -or $Row.Layer -eq 'system') {
    Invoke-NewTaskWizard
    $script:ScreenDirty = $true
    return
  }
  $launch = Resolve-LaunchCwd -Row $Row
  if (-not $launch) {
    $script:StatusHint = 'Path missing/weak - use c wizard'
    $script:ScreenDirty = $true
    return
  }
  $script:PendingRow = $Row
  $script:PendingForceNew = $true
  $script:PendingLaunch = $launch
  $script:ScreenDirty = $true
}

function Complete-AgentPick {
  # Step 2: launch the armed row with the picked agent (zone is on-screen already).
  param([string]$Agent)
  $row = $script:PendingRow
  if (-not $row) { return }
  $launch = $script:PendingLaunch
  $force = $script:PendingForceNew
  $script:PendingRow = $null
  $script:PendingForceNew = $false
  $script:PendingLaunch = $null
  $ok = if ($force) { Invoke-AgentLaunch -Row $row -Agent $Agent -Launch $launch -ForceNew }
        else { Invoke-AgentLaunch -Row $row -Agent $Agent -Launch $launch }
  if ($ok) {
    # D-012: launch succeeded → close this Init tab. The agent tab was spawned
    # (and focused) moments ago; no long-lived Init tab remains to pollute or
    # mislabel. Gate refusal / spawn failure / cancel all keep Init open.
    # Close-CurrentWezPane kills our own pane and never returns on success;
    # $false only when no wez CLI/pane id (non-wezterm host) → fall through
    # to a normal re-render.
    [void](Close-CurrentWezPane)
  }
  $script:RowsDirty = $true
  $script:ScreenDirty = $true
}


function Read-LinePrompt {
  param([string]$Label, [string]$Default = '')
  try { $Host.UI.RawUI.CursorVisible = $true } catch {}
  # D-013: input-prompt prefix is always bright Yellow (global input affordance).
  if ($Default) {
    Write-Host -NoNewline ("  {0} [{1}]: " -f $Label, $Default) -ForegroundColor Yellow
  } else {
    Write-Host -NoNewline ("  {0}: " -f $Label) -ForegroundColor Yellow
  }
  $v = Read-Host
  if ([string]::IsNullOrWhiteSpace($v)) { return $Default }
  return $v.Trim()
}

function Close-CurrentWezPane {
  # Close the pane running this script (F3 WizardOnly tab; D-012 Init
  # close-on-launch). Kills our own pane — on success the pane dies before
  # control returns. Returns $false WITHOUT exiting when no wez CLI / pane id
  # is available (non-wezterm host, pipe smoke) so callers can degrade.
  $paneId = $env:WEZTERM_PANE
  $wez = $script:Wez
  if (-not $wez) {
    try {
      $c = Get-Command wezterm -ErrorAction SilentlyContinue
      if ($c -and $c.Source) { $wez = [string]$c.Source }
    } catch {}
  }
  if ($wez -and $paneId) {
    try {
      & $wez @('cli', 'kill-pane', '--pane-id', "$paneId") 2>$null | Out-Null
    } catch {}
    exit 0
  }
  return $false
}

function Stop-Wizard {
  # cancel | done — when -WizardOnly, always close the tab (do not leave a PS prompt)
  param([ValidateSet('cancel', 'done')]$How = 'cancel')
  if ($WizardOnly) {
    Write-Host ''
    if ($How -eq 'cancel') {
      Write-Host '  Cancelled. Closing tab...' -ForegroundColor DarkGray
    } else {
      Write-Host '  Done. Closing wizard tab...' -ForegroundColor DarkGray
    }
    Start-Sleep -Milliseconds 400
    Close-CurrentWezPane
  }
  if ($How -eq 'cancel') {
    $script:StatusHint = 'Wizard cancelled'
  }
}

function Format-CliLeaf {
  # Display only filename so users do not click a full .exe/.cmd path (misleading hyperlink)
  param([string]$Exe)
  if ([string]::IsNullOrWhiteSpace($Exe)) { return '' }
  try {
    return [System.IO.Path]::GetFileName($Exe)
  } catch {
    return $Exe
  }
}

# =============================================================================
# UI IRON RULE (wizard / Init panels) — do not violate
# -----------------------------------------------------------------------------
# R-UI-1  Spacing: separate identity / primary choices / secondary actions /
#         input with blank lines. Never glue all blocks into one dense corner.
# R-UI-2  Color roles:
#           White/Yellow/Cyan = selectable actions and primary data
#           Green             = confirmed identity (name/path summary)
#           DarkGray/Gray     = STATIC labels only (section titles, tips)
#                               NEVER use gray for [b] [q] [0] or any choice
# R-UI-3  Every actionable key chip must be high-contrast (Yellow or White).
# =============================================================================

function Write-UiBlank {
  param([int]$N = 1)
  for ($i = 0; $i -lt $N; $i++) { Write-Host '' }
}

function Write-UiRule {
  param([ConsoleColor]$Fg = [ConsoleColor]::DarkCyan)
  Write-Host '  ============================================================' -ForegroundColor $Fg
}

function Write-UiSoftRule {
  Write-Host '  ------------------------------------------------------------' -ForegroundColor DarkGray
}

function Write-UiSection {
  # Static section label only — not a choice
  param([string]$Text)
  Write-Host ("  {0}" -f $Text) -ForegroundColor DarkGray
}

function Write-UiChoice {
  # Actionable option line — NEVER DarkGray.
  # D-013: 亮黄是唯一输入可供性色——选项索引芯片恒为亮黄，标签恒为 Gray，
  # 调用方不再决定芯片颜色（-Fg 仅对无芯片的纯文本行生效）。
  param([string]$Text, [ConsoleColor]$Fg = [ConsoleColor]::White)
  if ($Text -match '^(\s*\[[^\]]*\])(.*)$') {
    Write-Host '  ' -NoNewline
    Write-Host $Matches[1] -NoNewline -ForegroundColor Yellow
    Write-Host $Matches[2] -ForegroundColor Gray
  } else {
    Write-Host ("  {0}" -f $Text) -ForegroundColor $Fg
  }
}

function Write-UiStatic {
  param([string]$Text, [ConsoleColor]$Fg = [ConsoleColor]::DarkGray)
  Write-Host ("  {0}" -f $Text) -ForegroundColor $Fg
}

function Show-WizardHeader {
  param([string]$Title, [string]$Hint = '')
  Clear-Host
  Write-UiBlank 1
  Write-UiRule -Fg Cyan
  Write-Host '   WZ NEW PROJECT' -ForegroundColor White
  Write-UiRule -Fg Cyan
  Write-UiBlank 1
  Write-Host ("  {0}" -f $Title) -ForegroundColor White
  if ($Hint) {
    Write-UiBlank 1
    Write-UiStatic $Hint
  }
  Write-UiBlank 1
  Write-UiSoftRule
  Write-UiBlank 1
}

function Build-LocationOptions {
  # Fills $script:WzLocN / WzLocFull / WzLocTag parallel arrays (max 8).
  # NEVER return nested Object[] — that caused System.Object[] cast crashes.
  param([string]$ProjectName)

  $script:WzLocN = New-Object System.Collections.Generic.List[int]
  $script:WzLocFull = New-Object System.Collections.Generic.List[string]
  $script:WzLocTag = New-Object System.Collections.Generic.List[string]

  $parents = New-Object System.Collections.Generic.List[string]
  $tags = @{}

  function Add-P([string]$p, [string]$tag) {
    if ([string]::IsNullOrWhiteSpace($p)) { return }
    try { $p = [System.IO.Path]::GetFullPath($p.Trim().TrimEnd('\')) } catch {
      $p = $p.Trim().TrimEnd('\')
    }
    if (Test-WeakPath -Cwd $p) { return }
    $k = Normalize-PathKey $p
    foreach ($e in $parents) {
      if ((Normalize-PathKey $e) -eq $k) { return }
    }
    [void]$parents.Add($p)
    $tags[$k] = $tag
  }

  $def = Get-DefaultProjectsParent
  $script:DefaultParent = $def
  if ($def) { Add-P ([string]$def) 'RECOMMENDED' }

  try {
    foreach ($r in (Get-RecentParents)) {
      if ($r) { Add-P ([string]$r) 'RECENT' }
    }
  } catch {}

  try {
    foreach ($n in (Get-NeighborParents)) {
      if ($n -and $n.Path) { Add-P ([string]$n.Path) 'NEAR' }
    }
  } catch {}

  foreach ($c in @('G:\AIProjects', 'D:\AIProjects', 'E:\AIProjects', 'C:\AIProjects')) {
    try {
      if (Test-Path -LiteralPath $c) { Add-P $c 'DISK' }
    } catch {}
  }

  # Historical roots are migration-compatible inputs, never the fresh default.
  foreach ($c in @('G:\GrokProject', 'D:\GrokProject', 'E:\GrokProject', 'C:\GrokProject')) {
    try {
      if (Test-Path -LiteralPath $c) { Add-P $c 'DISK' }
    } catch {}
  }

  try {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    if ($docs) { Add-P (Join-Path $docs 'AIProjects') 'DOCS' }
  } catch {}

  if ($parents.Count -eq 0 -and $def) {
    [void]$parents.Add([string]$def)
    $tags[(Normalize-PathKey $def)] = 'RECOMMENDED'
  }

  $n = 1
  foreach ($p in $parents) {
    if ($n -gt 8) { break }
    $full = Join-Path ([string]$p) ([string]$ProjectName)
    try { $full = [System.IO.Path]::GetFullPath($full) } catch {}
    $k = Normalize-PathKey $p
    $tag = ''
    if ($tags.ContainsKey($k)) { $tag = [string]$tags[$k] }
    [void]$script:WzLocN.Add([int]$n)
    [void]$script:WzLocFull.Add([string]$full)
    [void]$script:WzLocTag.Add([string]$tag)
    $n++
  }
}

function Get-LocationCount {
  if (-not $script:WzLocN) { return 0 }
  return [int]$script:WzLocN.Count
}

function Build-InstalledAiCliOptions {
  # Fills parallel lists: WzCliN/Id/Label/Exe/Kind — no nested Object[] returns.
  $script:WzCliN = New-Object System.Collections.Generic.List[int]
  $script:WzCliId = New-Object System.Collections.Generic.List[string]
  $script:WzCliLabel = New-Object System.Collections.Generic.List[string]
  $script:WzCliExe = New-Object System.Collections.Generic.List[string]
  $script:WzCliKind = New-Object System.Collections.Generic.List[string]
  $seen = @{}
  $script:WzCliBuildN = 1

  function Add-Cli([string]$Id, [string]$Label, [string]$Exe, [string]$Kind) {
    if ([string]::IsNullOrWhiteSpace($Exe)) { return }
    if (-not (Test-Path -LiteralPath $Exe)) { return }
    $k = $Exe.ToLowerInvariant()
    if ($seen.ContainsKey($k)) { return }
    $seen[$k] = $true
    $n = [int]$script:WzCliBuildN
    $script:WzCliBuildN = $n + 1
    [void]$script:WzCliN.Add($n)
    [void]$script:WzCliId.Add([string]$Id)
    [void]$script:WzCliLabel.Add([string]$Label)
    [void]$script:WzCliExe.Add([string]$Exe)
    [void]$script:WzCliKind.Add([string]$Kind)
  }

  foreach ($m in @(Get-AgentDefinitions)) {
    Add-Cli -Id ([string]$m.Id) -Label ([string]$m.Label) -Exe ([string]$m.Exe) -Kind ([string]$m.Id)
  }

  # Always offer shell (do not require Test-Path on bare name)
  $psExe = 'powershell.exe'
  try {
    $psc = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($psc -and $psc.Source) { $psExe = [string]$psc.Source }
  } catch {}
  $hasShell = $false
  foreach ($k in $script:WzCliKind) { if ($k -eq 'shell') { $hasShell = $true; break } }
  if (-not $hasShell) {
    $nShell = [int]$script:WzCliN.Count + 1
    [void]$script:WzCliN.Add($nShell)
    [void]$script:WzCliId.Add('shell')
    [void]$script:WzCliLabel.Add('PowerShell only (no AI CLI)')
    [void]$script:WzCliExe.Add($psExe)
    [void]$script:WzCliKind.Add('shell')
  }
}

function Get-CliCount {
  if (-not $script:WzCliN) { return 0 }
  return [int]$script:WzCliN.Count
}

function Find-AgentExe {
  # Open inventory lookup: no switch statement and no product-name whitelist.
  param([string]$Id)
  $needle = ([string]$Id).ToLowerInvariant()
  foreach ($d in @(Get-AgentDefinitions)) {
    if (([string]$d.Id).ToLowerInvariant() -eq $needle -and (Test-Path -LiteralPath $d.Exe -PathType Leaf)) {
      return [string]$d.Exe
    }
  }
  return $null
}

function Initialize-NewProjectSkeleton {
  # Empty folder + "Explain this codebase" often hangs/crashes AI CLIs.
  param([string]$Path, [string]$Name)
  try {
    $readme = Join-Path $Path 'README.md'
    if (-not (Test-Path -LiteralPath $readme)) {
      $body = @(
        "# $Name"
        ''
        'Created by WZ New Project wizard.'
        ''
        '## Notes'
        '- Project path is frozen in desk-roots and .wz-project'
        '- Add source files here; AI CLIs use this folder as cwd'
        ''
      ) -join "`n"
      $utf8 = New-Object System.Text.UTF8Encoding $false
      [System.IO.File]::WriteAllText($readme, $body, $utf8)
    }
  } catch {}
}

function Start-ProjectWithCli {
  param(
    [string]$Cwd,
    [string]$Name,
    [string]$Kind,
    [string]$Exe,
    [string]$Label,
    [string]$Id
  )
  $title = "new $Name"
  $Kind = [string]$Kind
  $Exe = [string]$Exe
  $Id = [string]$Id
  $Label = [string]$Label

  if (-not (Test-Path -LiteralPath $Cwd)) {
    Write-Host ("  FAIL: project folder missing: {0}" -f $Cwd) -ForegroundColor Red
    Write-Host '  Create/bind may have failed earlier.' -ForegroundColor Cyan
    return
  }

  # L2-3 defense in depth: re-run the R1 gate here too — the wizard enforces
  # strong paths upstream, but never launch an agent identity on a weak path.
  if ($Kind -ne 'shell' -and -not (Test-StrongProjectPath -Cwd $Cwd)) {
    Write-Host ("  GATE: refuse launch on weak path ({0}) — bind a strong project path" -f $Cwd) -ForegroundColor Red
    return
  }

  if ($Kind -eq 'shell') {
    if ($script:Wez -and (Test-WezAlive)) {
      & $script:Wez @('cli', 'spawn', '--cwd', $Cwd, '--', 'powershell.exe', '-NoLogo') 2>$null | Out-Null
      if ($LASTEXITCODE -ne 0) { return $false }
    } else {
      Set-Location -LiteralPath $Cwd
    }
    $script:StatusHint = "Shell @ $Name"
    return $true
  }

  if ($Kind -eq 'grok') {
    if ($Exe -and (Test-Path -LiteralPath $Exe)) { $script:Grok = $Exe }
    return (Start-GrokTab -Cwd $Cwd -GrokArgs @('--cwd', $Cwd) -Title $title)
  }

  # ------------------------------------------------------------------
  # Windows shims (.cmd / .ps1 from winget/npm) MUST NOT be argv0 of
  # CreateProcess. Spawn PowerShell with --cwd, then invoke the command
  # name on PATH. Direct spawn of codex.cmd caused freezes / wrong host.
  # ------------------------------------------------------------------
  $invoke = $Exe
  if (-not $invoke) { $invoke = $Id }
  if ([string]::IsNullOrWhiteSpace($invoke)) { $invoke = $Id }
  # M2-4: prefer the wizard-resolved exe path over a bare PATH name — a CLI
  # found via fallback locations is NOT on PATH inside the spawned shell.
  if ($Exe -and (Test-Path -LiteralPath $Exe)) { $invoke = [string]$Exe }

  $cwdEsc = $Cwd.Replace("'", "''")
  $invEsc = $invoke.Replace("'", "''")
  $nameEsc = $Name.Replace("'", "''")
  # Role for tab bar (status.lua reads title for "Project | Codex")
  $role = if ($Label) { $Label } elseif ($Id) { $Id } else { 'AI' }
  $roleEsc = $role.Replace("'", "''")
  # Keep shell open if CLI exits/crashes so user sees the error instead of a dead tab
  # Walking-cat splash first (same wrapper animation as Start-*Tab), then WZ launch lines.
  $psCommand = (Get-AgentSplashScript -AgentLabel $role -Project $Name) + "`r`n" + @"
`$ErrorActionPreference = 'Continue'
try { `$Host.UI.RawUI.WindowTitle = '$nameEsc | $roleEsc' } catch {}
Set-Location -LiteralPath '$cwdEsc'
Write-Host ''
Write-Host ('  WZ launch: {0}' -f '$invEsc') -ForegroundColor Cyan
Write-Host ('  cwd:      {0}' -f (Get-Location).Path) -ForegroundColor DarkGray
Write-Host ''
try {
  `$cmdName = '$invEsc'
  & `$cmdName
} catch {
  Write-Host `$_.Exception.Message -ForegroundColor Red
}
Write-Host ''
Write-Host '  CLI ended. Window kept open - close tab when done.' -ForegroundColor DarkGray
"@

  if ($script:Wez -and (Test-WezAlive)) {
    try {
      $spawnOut = & $script:Wez @(
        'cli', 'spawn',
        '--cwd', $Cwd,
        '--',
        'powershell.exe',
        '-NoLogo',
        '-NoExit',
        '-ExecutionPolicy', 'Bypass',
        '-Command', $psCommand
      ) 2>$null | Out-String
      # Prefer explicit tab title so bar never falls back to literal "Tab"
      $tabTitle = '{0} | {1}' -f $Name, $role
      Set-SpawnedTabTitle -SpawnOut $spawnOut -ExitCode $LASTEXITCODE -TabTitle $tabTitle
      Write-Host ("  OK: started {0} via PowerShell host" -f $Label) -ForegroundColor Green
      Write-Host ("  cwd {0}" -f $Cwd) -ForegroundColor DarkGray
      Write-Host ("  cmd {0}" -f $invoke) -ForegroundColor DarkGray
      Write-Host ("  tab {0}" -f $tabTitle) -ForegroundColor DarkGray
      $script:StatusHint = "$Id @ $Name"
      return $true
    } catch {
      Write-Host ("  FAIL spawn: {0}" -f $_.Exception.Message) -ForegroundColor Red
      return $false
    }
  } else {
    Write-Host '  Start manually in this folder:' -ForegroundColor Cyan
    Write-Host ("    cd /d {0}" -f $Cwd) -ForegroundColor White
    Write-Host ("    {0}" -f $invoke) -ForegroundColor White
    return $false
  }
}

function Write-WzProjectMarkerEx {
  param(
    [string]$Name,
    [string]$Path,
    [string]$CliId = '',
    [string]$CliExe = ''
  )
  $Path = $Path.Trim().TrimEnd('\')
  $marker = Join-Path $Path '.wz-project'
  $lines = New-Object System.Collections.Generic.List[string]
  [void]$lines.Add('# WZ project identity - frozen at create/bind')
  [void]$lines.Add(('name={0}' -f $Name))
  [void]$lines.Add(('path={0}' -f $Path))
  if ($CliId) { [void]$lines.Add(('cli={0}' -f $CliId)) }
  if ($CliExe) { [void]$lines.Add(('cli_exe={0}' -f $CliExe)) }
  [void]$lines.Add(('created={0:yyyy-MM-ddTHH:mm:ssK}' -f (Get-Date)))
  Write-WzUtf8LinesAtomic -Path $marker -Lines @($lines.ToArray())
}

function Invoke-NewTaskWizard {
  # 4 steps / 4 prompts. Agent identity and its CLI are one choice (D-015).
  # UI iron rules: R-UI-1 spacing, R-UI-2 gray=static only.
  try { $Host.UI.RawUI.CursorVisible = $true } catch {}
  if (-not $script:Grok) {
    try { $script:Grok = Resolve-GrokExe } catch {}
  }

  $step = 1
  $name = ''
  $fullPath = ''
  $cliIdx = -1
  $agentChoice = ''

  while ($step -ge 1 -and $step -le 4) {
    try {
      # ========== STEP 1: NAME ==========
      if ($step -eq 1) {
        Show-WizardHeader -Title 'Step 1 / 4   Project name' -Hint 'Binding name = default folder name'
        Write-UiSection 'RULES (static - not choices)'
        Write-UiBlank 1
        Write-UiStatic 'Allowed : A-Z a-z 0-9 . _ -     e.g. WZ_Skill  my-game'
        Write-UiStatic 'Forbidden: home Desktop Documents Downloads Administrator'
        Write-UiBlank 2
        Write-UiSoftRule
        Write-UiBlank 1
        Write-UiSection 'ACTIONS'
        Write-UiBlank 1
        Write-UiChoice '[q]  cancel wizard' -Fg White
        Write-UiBlank 2
        $name = Read-LinePrompt -Label 'Name'
        if ($name -eq 'q' -or $name -eq 'Q') {
          Stop-Wizard -How cancel
          return
        }
        if (-not (Test-ValidProjectName -Name $name)) {
          if (Test-ReservedName -Name $name) {
            Write-Host '  ERROR: reserved system name' -ForegroundColor Red
          } else {
            Write-Host '  ERROR: invalid name' -ForegroundColor Red
          }
          Start-Sleep -Milliseconds 900
          continue
        }
        $step = 2
        continue
      }

      # ========== STEP 2: LOCATION ==========
      if ($step -eq 2) {
        Build-LocationOptions -ProjectName $name
        $cnt = Get-LocationCount
        Show-WizardHeader -Title 'Step 2 / 4   Create location' -Hint 'Pick one path. Final = parent\name'

        Write-UiSection 'PROJECT'
        Write-UiBlank 1
        Write-Host ("  NAME     {0}" -f $name) -ForegroundColor Green
        Write-UiBlank 2

        Write-UiSoftRule
        Write-UiBlank 1
        Write-UiSection 'LOCATIONS  (enter a number)'
        Write-UiBlank 1
        if ($cnt -lt 1) {
          Write-Host '  (no auto options - use 0)' -ForegroundColor DarkCyan
        } else {
          for ($i = 0; $i -lt $cnt; $i++) {
            $nn = [int]$script:WzLocN[$i]
            $full = [string]$script:WzLocFull[$i]
            $tag = [string]$script:WzLocTag[$i]
            Write-UiBlank 1
            if ($tag) {
              Write-UiChoice ('[{0}]  {1}' -f $nn, $tag) -Fg White
            } else {
              Write-UiChoice ('[{0}]' -f $nn) -Fg White
            }
            Write-Host ('       {0}' -f $full) -ForegroundColor White
          }
        }

        Write-UiBlank 2
        Write-UiSoftRule
        Write-UiBlank 1
        Write-UiSection 'OTHER ACTIONS'
        Write-UiBlank 1
        Write-UiChoice '[0]  type PARENT folder only' -Fg Cyan
        Write-UiChoice '[b]  back to project name' -Fg White
        Write-UiChoice '[q]  cancel wizard' -Fg White
        Write-UiBlank 2

        $def = if ($cnt -gt 0) { '1' } else { '0' }
        $ch = Read-LinePrompt -Label 'Location' -Default $def
        if ($ch -eq 'q' -or $ch -eq 'Q') {
          Stop-Wizard -How cancel
          return
        }
        if ($ch -eq 'b' -or $ch -eq 'B') {
          $step = 1
          continue
        }

        if ($ch -eq '0') {
          Write-UiBlank 1
          Write-UiSoftRule
          Write-UiBlank 1
          Write-Host ("  Will create:  <parent>\{0}" -f $name) -ForegroundColor White
          Write-UiBlank 1
          Write-UiStatic ('Example parent: {0}' -f (Get-DefaultProjectsParent))
          Write-UiBlank 1
          Write-UiChoice '[b]  back to list' -Fg White
          Write-UiChoice '[q]  cancel' -Fg White
          Write-UiBlank 1
          $parent = Read-LinePrompt -Label 'Parent'
          if ($parent -eq 'q' -or $parent -eq 'Q') {
            Stop-Wizard -How cancel
            return
          }
          if ($parent -eq 'b' -or $parent -eq 'B') { continue }
          if ([string]::IsNullOrWhiteSpace($parent)) {
            Write-Host '  ERROR: empty parent' -ForegroundColor Red
            Start-Sleep -Milliseconds 800
            continue
          }
          $parent = $parent.Trim().TrimEnd('\')
          try { $parent = [System.IO.Path]::GetFullPath($parent) } catch {}
          if (Test-WeakPath -Cwd $parent) {
            Write-Host '  ERROR: parent is weak/system path' -ForegroundColor Red
            Start-Sleep -Milliseconds 1000
            continue
          }
          $cand = Join-Path $parent $name
          try { $cand = [System.IO.Path]::GetFullPath($cand) } catch {}
          if (-not (Test-StrongProjectPath -Cwd $cand)) {
            Write-Host '  ERROR: result path not allowed' -ForegroundColor Red
            Start-Sleep -Milliseconds 1000
            continue
          }
          $fullPath = [string]$cand
          $step = 3
          continue
        }

        if ($ch -match '^\d+$') {
          $num = [int]$ch
          $found = $false
          for ($i = 0; $i -lt $cnt; $i++) {
            if ([int]$script:WzLocN[$i] -eq $num) {
              $cand = [string]$script:WzLocFull[$i]
              if (-not (Test-StrongProjectPath -Cwd $cand)) {
                Write-Host '  ERROR: that path is not allowed' -ForegroundColor Red
                Start-Sleep -Milliseconds 1000
                $found = $true
                break
              }
              $fullPath = $cand
              $found = $true
              $step = 3
              break
            }
          }
          if ($step -eq 3) { continue }
          if (-not $found) {
            Write-Host '  ERROR: number not in list' -ForegroundColor Red
            Start-Sleep -Milliseconds 800
          }
          continue
        }

        Write-Host '  ERROR: enter 1-8, or 0, or b/q' -ForegroundColor Red
        Start-Sleep -Milliseconds 800
        continue
      }

      # ========== STEP 3: AGENT / CLI ==========
      if ($step -eq 3) {
        Build-InstalledAiCliOptions
        $cc = Get-CliCount
        Show-WizardHeader -Title 'Step 3 / 4   Agent / CLI' -Hint 'One choice sets both the launcher and task default'

        Write-UiSection 'PROJECT'
        Write-UiBlank 1
        Write-Host ("  NAME     {0}" -f $name) -ForegroundColor Green
        Write-UiBlank 1
        Write-Host ("  PATH     {0}" -f $fullPath) -ForegroundColor White
        Write-UiBlank 2

        Write-UiSoftRule
        Write-UiBlank 1
        Write-UiSection 'INSTALLED AGENT / CLI  (enter number)'
        Write-UiBlank 1
        if ($cc -lt 1) {
          Write-Host '  ERROR: no CLI rows. Press b or q.' -ForegroundColor Red
        } else {
          for ($i = 0; $i -lt $cc; $i++) {
            $nn = [int]$script:WzCliN[$i]
            $label = [string]$script:WzCliLabel[$i]
            $exe = [string]$script:WzCliExe[$i]
            $kind = [string]$script:WzCliKind[$i]
            Write-UiBlank 1
            if ($kind -eq 'shell') {
              Write-UiChoice ('[{0}]  {1}' -f $nn, $label) -Fg Cyan
            } else {
              Write-UiChoice ('[{0}]  {1}' -f $nn, $label) -Fg White
              # Leaf only — full .exe/.cmd paths are NOT useful to click (hyperlink trap)
              Write-UiStatic ('      binary: {0}' -f (Format-CliLeaf $exe))
            }
          }
        }
        Write-UiBlank 2
        Write-UiSoftRule
        Write-UiBlank 1
        Write-UiSection 'OTHER ACTIONS'
        Write-UiBlank 1
        Write-UiChoice '[b]  back to location' -Fg White
        Write-UiChoice '[q]  cancel wizard' -Fg White
        Write-UiBlank 2

        $ch = Read-LinePrompt -Label 'Agent / CLI' -Default '1'
        if ($ch -eq 'q' -or $ch -eq 'Q') {
          Stop-Wizard -How cancel
          return
        }
        if ($ch -eq 'b' -or $ch -eq 'B') {
          $step = 2
          continue
        }
        if ($ch -match '^\d+$') {
          $num = [int]$ch
          $cliIdx = -1
          for ($i = 0; $i -lt $cc; $i++) {
            if ([int]$script:WzCliN[$i] -eq $num) { $cliIdx = $i; break }
          }
          if ($cliIdx -ge 0) {
            $cliId = ([string]$script:WzCliId[$cliIdx]).Trim().ToLowerInvariant()
            $cliKind = [string]$script:WzCliKind[$cliIdx]
            # Every choice writes the same identity it launches. PowerShell-only
            # uses the explicit `shell` route id instead of silently becoming grok;
            # combinations such as "Codex CLI + grok agent" are impossible.
            $agentChoice = $cliId
            $step = 4
            continue
          }
        }
        Write-Host '  ERROR: pick a number from the list' -ForegroundColor Red
        Start-Sleep -Milliseconds 800
        continue
      }

      # ========== STEP 4: CONFIRM ==========
      if ($step -eq 4) {
        if ($cliIdx -lt 0) { $step = 3; continue }
        $cliLabel = [string]$script:WzCliLabel[$cliIdx]
        $cliExe = [string]$script:WzCliExe[$cliIdx]
        $cliKind = [string]$script:WzCliKind[$cliIdx]
        $cliId = ([string]$script:WzCliId[$cliIdx]).Trim().ToLowerInvariant()
        $agentChoice = $cliId

        Show-WizardHeader -Title 'Step 4 / 4   Confirm create' -Hint 'Review summary, then Y to freeze and open'

        Write-UiSection 'SUMMARY'
        Write-UiBlank 1
        Write-Host ("  NAME     {0}" -f $name) -ForegroundColor Green
        Write-UiBlank 1
        Write-Host ("  PATH     {0}" -f $fullPath) -ForegroundColor White
        Write-UiBlank 1
        Write-Host ("  AGENT/CLI {0}" -f $cliLabel) -ForegroundColor Cyan
        Write-UiBlank 1
        Write-UiStatic ('ID        {0}' -f $agentChoice)
        Write-UiBlank 1
        Write-UiStatic ('BINARY    {0}' -f (Format-CliLeaf $cliExe))
        Write-UiBlank 1
        $exists = Test-Path -LiteralPath $fullPath
        if ($exists) {
          Write-Host '  DIR      exists (bind only, no wipe)' -ForegroundColor Green
        } else {
          Write-Host '  DIR      will create new folder' -ForegroundColor DarkCyan
        }

        Write-UiBlank 2
        Write-UiSoftRule
        Write-UiBlank 1
        Write-UiSection 'ACTIONS'
        Write-UiBlank 1
        Write-UiChoice '[Y]  create + bind + open' -Fg White
        Write-UiChoice '[b]  back to agent / CLI pick' -Fg White
        Write-UiChoice '[q]  cancel (nothing written)' -Fg White
        Write-UiBlank 2

        $ok = Read-LinePrompt -Label 'Create now (Y/n)' -Default 'Y'
        if ($ok -eq 'q' -or $ok -eq 'Q') {
          Stop-Wizard -How cancel
          return
        }
        if ($ok -eq 'b' -or $ok -eq 'B' -or $ok -match '^(n|N)') {
          $step = 3
          continue
        }

        try {
          if (-not $exists) {
            New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
            Write-Host ("  + created {0}" -f $fullPath) -ForegroundColor Green
          }
          if (-not (Test-Path -LiteralPath $fullPath)) {
            throw "Folder still missing after create: $fullPath"
          }
          Initialize-NewProjectSkeleton -Path $fullPath -Name $name
          Set-DeskRootBinding -Name $name -Path $fullPath -Agent $agentChoice
          Write-WzProjectMarkerEx -Name $name -Path $fullPath -CliId $cliId -CliExe $cliExe
          Write-Host ("  + FROZEN {0} -> {1}" -f $name, $fullPath) -ForegroundColor Green
          Write-Host ("  + README.md skeleton (empty projects crash some CLIs)" ) -ForegroundColor DarkGray
          try {
            $par = Split-Path -Parent $fullPath
            if ($par) { Add-RecentParent -ParentPath $par }
          } catch {}
        } catch {
          Write-Host ("  FAIL: {0}" -f $_.Exception.Message) -ForegroundColor Red
          Write-Host '  Press Enter to stay on confirm...' -ForegroundColor White
          try { [void](Read-Host) } catch {}
          continue
        }

        Write-UiBlank 1
        Write-Host '  Opening AI CLI in project folder...' -ForegroundColor Cyan
        Write-Host ("  Expect cwd: {0}" -f $fullPath) -ForegroundColor DarkGray
        try {
          Start-ProjectWithCli -Cwd $fullPath -Name $name -Kind $cliKind -Exe $cliExe -Label $cliLabel -Id $cliId
        } catch {
          Write-Host ("  Open failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
          Write-Host '  Project is still created and bound.' -ForegroundColor Cyan
        }

        try {
          Build-Rows | Out-Null
          for ($ii = 0; $ii -lt $script:Rows.Count; $ii++) {
            if ($script:Rows[$ii].Project -eq $name) { $script:Selected = $ii; break }
          }
        } catch {}

        # F3 dedicated tab: close after success (project already opened in new tab)
        Stop-Wizard -How done
        return
      }
    } catch {
      Write-Host ''
      Write-Host ("  ERROR: {0}" -f $_.Exception.Message) -ForegroundColor Red
      Write-Host '  Staying on this step. q=cancel' -ForegroundColor Cyan
      Start-Sleep -Milliseconds 1500
    }
  }
}

# ---- main ----
if ($WizardOnly) {
  # F3 / dedicated new-project entry — no Init table loop
  try {
    if (-not $script:Grok) { $script:Grok = Resolve-GrokExe }
  } catch {}
  $script:DefaultParent = Get-DefaultProjectsParent
  try { $script:DeskRoots = Read-DeskRoots } catch { $script:DeskRoots = [ordered]@{} }
  Invoke-NewTaskWizard
  # If wizard returned without Stop-Wizard (edge), still close the tab
  try { $Host.UI.RawUI.CursorVisible = $true } catch {}
  Stop-Wizard -How done
}

$running = $true
while ($running) {
  Show-Screen

  # ---- step 2 (armed): pick agent — SAME grammar as step 1 (D-008 kept, D-009:
  # line input instead of per-key repaint; the screen above stays static) ----
  if ($script:PendingRow) {
    $peerIds = @()
    foreach ($p in @(Get-InstalledAgentPeers)) { $peerIds += $p.Id }
    if ($peerIds.Count -eq 0) {
      $script:PendingRow = $null
      $script:PendingForceNew = $false
      $script:StatusHint = 'no installed agent detected — install one or add agent-registry.local.tsv'
      $script:ScreenDirty = $true
      continue
    }
    $defIdx = 1
    $dflt = ([string]$script:PendingRow.LaunchAgent).ToLowerInvariant()
    for ($ii = 0; $ii -lt $peerIds.Count; $ii++) {
      if ($peerIds[$ii] -eq $dflt) { $defIdx = $ii + 1; break }
    }
    Write-Host -NoNewline ("  agent 1-{0} (Enter = {1} {2}, q = cancel) " -f $peerIds.Count, $defIdx, $peerIds[$defIdx - 1]) -ForegroundColor Yellow
    $line = Read-Host
    # L2-2: stdin EOF (redirected host, input exhausted) — leave the panel
    # cleanly instead of spinning on empty reads forever.
    if ($null -eq $line) { break }
    $line = ([string]$line).Trim()
    if ($line -eq '') { Complete-AgentPick -Agent $peerIds[$defIdx - 1]; continue }
    if ($line -eq 'q' -or $line -eq 'Q') {
      $script:PendingRow = $null
      $script:PendingForceNew = $false
      $script:PendingLaunch = $null
      $script:StatusHint = 'launch cancelled'
      $script:ScreenDirty = $true
      continue
    }
    $pick = 0
    if ([int]::TryParse($line, [ref]$pick) -and $pick -ge 1 -and $pick -le $peerIds.Count) {
      Complete-AgentPick -Agent $peerIds[$pick - 1]
      continue
    }
    $script:StatusHint = ('no such agent — Enter = default, 1-' + $peerIds.Count + ', q = cancel')
    $script:ScreenDirty = $true
    continue
  }

  # ---- step 1: pick task / panel commands ----
  Write-Host -NoNewline '  wz> ' -ForegroundColor Yellow
  $line = Read-Host
  # L2-2: stdin EOF — exit cleanly (see step-2 note above)
  if ($null -eq $line) { break }
  $line = ([string]$line).Trim()
  if ($line -eq '') { continue }  # empty Enter: no state change → no repaint
  if ($line -eq 'q' -or $line -eq 'Q') {
    try { $Host.UI.RawUI.CursorVisible = $true } catch {}
    Write-Host '  left panel.' -ForegroundColor DarkGray
    break
  }
  if ($line -eq 'c' -or $line -eq 'C') { Invoke-NewTaskWizard; $script:ScreenDirty = $true; continue }
  if ($line -eq 'r' -or $line -eq 'R') {
    $script:AgentDefinitions = $null
    $script:AgentPeers = $null
    $script:RowsDirty = $true
    continue
  }  # D-016: re-read metadata + local registration in the same Init process
  if ($line -eq 'a' -or $line -eq 'A') { $script:ShowAll = -not $script:ShowAll; $script:RowsDirty = $true; continue }
  if ($line -eq 's' -or $line -eq 'S') {
    if ($script:Wez -and (Test-WezAlive)) {
      & $script:Wez @('cli', 'spawn', '--', 'powershell.exe', '-NoLogo') 2>$null | Out-Null
      $script:StatusHint = 'shell tab opened'
    } else {
      $script:StatusHint = 'wezterm not alive — cannot spawn shell tab'
    }
    $script:ScreenDirty = $true
    continue
  }
  if ($line -match '^\d+$') {
    # M2-1: cap digit length — 11+ digits overflow [int] and dump a red error
    # record that no repaint covers. Row numbers never exceed 2 digits (MaxRows
    # 18), so >4 digits is always a mistake.
    if ($line.Length -gt 4) {
      $script:StatusHint = 'number too long — <num>=task · <t><a>=one-shot · q=quit'
      $script:ScreenDirty = $true
      continue
    }
    # D-010 combo fast path: in the 9-row default view a two-digit input is
    # <task><agent> — gates still run (Invoke-RowPrimary), launch is immediate.
    if ($line.Length -eq 2 -and -not $script:ShowAll -and $script:Rows.Count -le 9) {
      $tIdx = [int]$line.Substring(0, 1)
      $aIdx = [int]$line.Substring(1, 1)
      $peerIdsC = @()
      foreach ($p in @(Get-InstalledAgentPeers)) { $peerIdsC += $p.Id }
      $r = Get-RowByIndex $tIdx
      if (-not $r) { $script:StatusHint = ('no task #' + $tIdx); $script:ScreenDirty = $true; continue }
      if ($aIdx -lt 1 -or $aIdx -gt $peerIdsC.Count) {
        $script:StatusHint = ('combo agent digit must be 1-' + $peerIdsC.Count + ' (your pick: ' + $aIdx + ')')
        $script:ScreenDirty = $true
        continue
      }
      Invoke-RowPrimary $r
      if ($script:PendingRow) { Complete-AgentPick -Agent $peerIdsC[$aIdx - 1] }
      continue
    }
    $r = Get-RowByIndex ([int]$line)
    if ($r) { Invoke-RowPrimary $r } else { $script:StatusHint = ('no row #' + $line); $script:ScreenDirty = $true }
    continue
  }
  if ($line -match '^[nN]\s*(\d+)$') {
    $digits = $Matches[1]
    # M2-1: same length cap on the forced-new variant
    if ($digits.Length -gt 4) {
      $script:StatusHint = 'number too long — n<num>=new session · q=quit'
      $script:ScreenDirty = $true
      continue
    }
    # D-010 combo, forced-new variant: n13 = task 1, agent 3, new session
    if ($digits.Length -eq 2 -and -not $script:ShowAll -and $script:Rows.Count -le 9) {
      $tIdx = [int]$digits.Substring(0, 1)
      $aIdx = [int]$digits.Substring(1, 1)
      $peerIdsC = @()
      foreach ($p in @(Get-InstalledAgentPeers)) { $peerIdsC += $p.Id }
      $r = Get-RowByIndex $tIdx
      if (-not $r) { $script:StatusHint = ('no task #' + $tIdx); $script:ScreenDirty = $true; continue }
      if ($aIdx -lt 1 -or $aIdx -gt $peerIdsC.Count) {
        $script:StatusHint = ('combo agent digit must be 1-' + $peerIdsC.Count)
        $script:ScreenDirty = $true
        continue
      }
      Invoke-RowNewSession $r
      if ($script:PendingRow) { Complete-AgentPick -Agent $peerIdsC[$aIdx - 1] }
      continue
    }
    $r = Get-RowByIndex ([int]$digits)
    if ($r) { Invoke-RowNewSession $r } else { $script:StatusHint = ('no row #' + $digits); $script:ScreenDirty = $true }
    continue
  }
  $script:StatusHint = 'unknown — <num>=task · n<num>=new session · c=create · r=refresh · a=all · s=shell · q=quit'
  $script:ScreenDirty = $true
}

try { $Host.UI.RawUI.CursorVisible = $true } catch {}
Write-Host '  WZ bootstrap ended.' -ForegroundColor DarkGray
