# AI STAR CUBE Explorer — bound to task workspace (WS) + desk root (DESK)
# Open: F7  or  Leader Alt+z then e  (window-local; not system-global)


param(
  [string]$StartPath = $env:USERPROFILE,
  [string]$DeskRoot = "",
  [string]$Workspace = "home"
)

$ErrorActionPreference = 'Continue'
try { $Host.UI.RawUI.WindowTitle = "AI Explorer · $Workspace" } catch {}
try {
  chcp 65001 | Out-Null
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$script:RootsFile = Join-Path $env:USERPROFILE '.config\wezterm\workbench\desk-roots.tsv'
$script:Workspace = if ([string]::IsNullOrWhiteSpace($Workspace)) { 'home' } else { $Workspace }

function Resolve-SafePath {
  param([string]$PathValue)
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return $null }
  try {
    return (Resolve-Path -LiteralPath $PathValue -ErrorAction Stop).Path
  } catch {
    return $null
  }
}

function Get-WeztermExe {
  $list = @()
  if ($env:ProgramFiles) {
    $list += (Join-Path $env:ProgramFiles 'WezTerm\wezterm.exe')
  }
  $pf86 = ${env:ProgramFiles(x86)}
  if ($pf86) {
    $list += (Join-Path $pf86 'WezTerm\wezterm.exe')
  }
  $cmd = Get-Command wezterm -ErrorAction SilentlyContinue
  if ($cmd) { $list += $cmd.Source }
  foreach ($c in $list) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  return $null
}

function Read-DeskRootFromFile {
  param([string]$Ws)
  if (-not (Test-Path -LiteralPath $script:RootsFile)) { return $null }
  foreach ($line in Get-Content -LiteralPath $script:RootsFile -ErrorAction SilentlyContinue) {
    $t = $line.Trim()
    if ($t -eq '' -or $t.StartsWith('#')) { continue }
    $parts = $t -split "`t", 2
    if ($parts.Count -lt 2) {
      $parts = $t -split '\s+', 2
    }
    if ($parts.Count -ge 2 -and $parts[0] -eq $Ws) {
      return (Resolve-SafePath -PathValue $parts[1])
    }
  }
  return $null
}

function Write-DeskRootToFile {
  param([string]$Ws, [string]$PathValue)
  $dir = Split-Path $script:RootsFile -Parent
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  $map = @{}
  if (Test-Path -LiteralPath $script:RootsFile) {
    foreach ($line in Get-Content -LiteralPath $script:RootsFile -ErrorAction SilentlyContinue) {
      $t = $line.Trim()
      if ($t -eq '' -or $t.StartsWith('#')) { continue }
      $parts = $t -split "`t", 2
      if ($parts.Count -lt 2) { $parts = $t -split '\s+', 2 }
      if ($parts.Count -ge 2) { $map[$parts[0]] = $parts[1] }
    }
  }
  $map[$Ws] = $PathValue
  $out = @(
    '# AI STAR CUBE desk roots — workspace_name<TAB>absolute_path',
    '# 任务工作区名 与 任务根目录 的绑定；Explorer / 状态栏 / F6 共用'
  )
  foreach ($k in ($map.Keys | Sort-Object)) {
    $out += ($k + "`t" + $map[$k])
  }
  Set-Content -LiteralPath $script:RootsFile -Value $out -Encoding UTF8
}

$script:Wez = Get-WeztermExe
$script:Cwd = Resolve-SafePath -PathValue $StartPath
if (-not $script:Cwd) { $script:Cwd = $env:USERPROFILE }

$script:Desk = Resolve-SafePath -PathValue $DeskRoot
if (-not $script:Desk) {
  $script:Desk = Read-DeskRootFromFile -Ws $script:Workspace
}
if (-not $script:Desk) {
  $script:Desk = $script:Cwd
  Write-DeskRootToFile -Ws $script:Workspace -PathValue $script:Desk
}

$script:Entries = @()

function Test-UnderDesk {
  param([string]$PathValue)
  if ([string]::IsNullOrWhiteSpace($PathValue) -or [string]::IsNullOrWhiteSpace($script:Desk)) {
    return $false
  }
  $a = $PathValue.TrimEnd('\').ToLowerInvariant()
  $b = $script:Desk.TrimEnd('\').ToLowerInvariant()
  return ($a -eq $b) -or $a.StartsWith($b + '\')
}

function ConvertTo-FileUri {
  param([string]$PathValue)
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return $null }
  $full = $PathValue
  try {
    $full = [System.IO.Path]::GetFullPath($PathValue)
  } catch {}
  # WezTerm OpenLink on Windows: file:///C:/dir/file
  $slash = ($full -replace '\\', '/')
  # encode only unsafe chars; keep : / 
  $slash = [uri]::EscapeUriString($slash)
  if ($slash -match '^[A-Za-z]:') {
    return ('file:///{0}' -f $slash)
  }
  return ('file://{0}' -f $slash)
}

function Get-AnsiColorCode {
  param([ConsoleColor]$Color)
  switch ($Color) {
    'Black'       { return '30' }
    'DarkBlue'    { return '34' }
    'DarkGreen'   { return '32' }
    'DarkCyan'    { return '36' }
    'DarkRed'     { return '31' }
    'DarkMagenta' { return '35' }
    'DarkYellow'  { return '33' }
    'Gray'        { return '37' }
    'DarkGray'    { return '90' }
    'Blue'        { return '94' }
    'Green'       { return '92' }
    'Cyan'        { return '96' }
    'Red'         { return '91' }
    'Magenta'     { return '95' }
    'Yellow'      { return '93' }
    'White'       { return '97' }
    default       { return '37' }
  }
}

function Write-Hyperlink {
  param(
    [string]$Uri,
    [string]$Text,
    [ConsoleColor]$Color = [ConsoleColor]::Gray
  )
  if ([string]::IsNullOrWhiteSpace($Text)) { return }
  if ([string]::IsNullOrWhiteSpace($Uri)) {
    Write-Host $Text -ForegroundColor $Color -NoNewline
    return
  }
  # IMPORTANT: do NOT use Write-Host -ForegroundColor around OSC-8.
  # Write-Host wraps SGR color around the whole string and breaks hyperlink parsing.
  # Emit raw: ESC[colorm + OSC8 open + text + OSC8 close + ESC[0m  (ST = ESC\)
  $esc = [char]27
  $st = $esc + '\'
  $col = Get-AnsiColorCode -Color $Color
  $seq = (
    $esc + '[' + $col + 'm' +
    $esc + ']8;;' + $Uri + $st +
    $Text +
    $esc + ']8;;' + $st +
    $esc + '[0m'
  )
  [Console]::Write($seq)
}

function Write-ClickablePath {
  param(
    [string]$PathValue,
    [string]$Label,
    [ConsoleColor]$Color = [ConsoleColor]::Gray,
    # Full path next to every row is noise (VIEW already shows location).
    # Only use -ShowFullPath for DESK/VIEW header lines.
    [switch]$ShowFullPath
  )
  $uri = ConvertTo-FileUri -PathValue $PathValue
  $text = if ([string]::IsNullOrWhiteSpace($Label)) { $PathValue } else { $Label }
  Write-Hyperlink -Uri $uri -Text $text -Color $Color
  if ($ShowFullPath -and $PathValue -and $PathValue -ne $text) {
    Write-Host '  ' -NoNewline
    Write-Host $PathValue -ForegroundColor DarkGray -NoNewline
  }
}

function Open-DefaultApp {
  param([string]$PathValue, [string]$Kind = 'file')
  if ([string]::IsNullOrWhiteSpace($PathValue) -or -not (Test-Path -LiteralPath $PathValue)) {
    Write-Host '  path missing' -ForegroundColor Red
    return $false
  }
  try {
    if ($Kind -eq 'dir') {
      Start-Process -FilePath 'explorer.exe' -ArgumentList @($PathValue) | Out-Null
    } else {
      # OS default association (documents, images, links, …)
      Start-Process -FilePath $PathValue | Out-Null
    }
    Write-Host ("  默认打开: {0}" -f $PathValue) -ForegroundColor Green
    return $true
  } catch {
    try {
      Invoke-Item -LiteralPath $PathValue
      Write-Host ("  默认打开: {0}" -f $PathValue) -ForegroundColor Green
      return $true
    } catch {
      Write-Host ("  open failed: {0}" -f $_) -ForegroundColor Red
      return $false
    }
  }
}

function Normalize-PathKey {
  param([string]$PathValue)
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return '' }
  try {
    $full = [System.IO.Path]::GetFullPath($PathValue)
    return $full.TrimEnd('\').ToLowerInvariant()
  } catch {
    return $PathValue.Trim().TrimEnd('\').ToLowerInvariant()
  }
}

function Get-ParentPath {
  param([string]$PathValue)
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return $null }
  try {
    $full = $PathValue
    try { $full = [System.IO.Path]::GetFullPath($PathValue) } catch {}
    $parentInfo = [System.IO.Directory]::GetParent($full)
    if (-not $parentInfo) { return $null }
    $parent = $parentInfo.FullName
    if ([string]::IsNullOrWhiteSpace($parent)) { return $null }
    # Drive root has no further parent worth listing
    if ((Normalize-PathKey $parent) -eq (Normalize-PathKey $full)) { return $null }
    $resolved = Resolve-SafePath -PathValue $parent
    if ($resolved) { return $resolved }
    return $parent
  } catch {
    try {
      $parent = Split-Path -LiteralPath $PathValue -Parent -ErrorAction SilentlyContinue
      if ([string]::IsNullOrWhiteSpace($parent)) { return $null }
      if ((Normalize-PathKey $parent) -eq (Normalize-PathKey $PathValue)) { return $null }
      return $parent
    } catch {
      return $null
    }
  }
}

function Move-ToParent {
  $from = $script:Cwd
  $parent = Get-ParentPath -PathValue $script:Cwd
  if (-not $parent) {
    Write-Host '  已在盘符根目录，没有更上一级' -ForegroundColor DarkYellow
    Start-Sleep -Seconds 0.7
    return $false
  }
  if ((Normalize-PathKey $parent) -eq (Normalize-PathKey $from)) {
    Write-Host '  无法再向上' -ForegroundColor DarkYellow
    Start-Sleep -Seconds 0.7
    return $false
  }
  $script:Cwd = $parent
  $leftDesk = -not (Test-UnderDesk -PathValue $script:Cwd)
  Write-Host ("  ↑ VIEW  {0}" -f $from) -ForegroundColor DarkGray
  Write-Host ("  →      {0}" -f $script:Cwd) -ForegroundColor Green
  if ($leftDesk) {
    Write-Host '  (已离开任务根 DESK 树；按 s 回到 DESK)' -ForegroundColor DarkYellow
  }
  Start-Sleep -Milliseconds 350
  return $true
}

function ConvertFrom-FullwidthDigits {
  param([string]$Text)
  if ($null -eq $Text) { return '' }
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $Text.ToCharArray()) {
    $code = [int][char]$ch
    # 全角 ０-９ → 0-9
    if ($code -ge 0xFF10 -and $code -le 0xFF19) {
      [void]$sb.Append([char](0x30 + ($code - 0xFF10)))
    } else {
      [void]$sb.Append($ch)
    }
  }
  return $sb.ToString()
}

# Color / zone standard (aligned with Init panel)
#   HEADER DarkGray | LIST Cyan | LOCATION Green | COMMAND Yellow
#   Keys Yellow highlight | body Gray/White | meta DarkGray | error Red | select Green

function Get-UiWidth {
  # Fill the explorer pane (opened ~21% of window). Cap for long-name safety.
  try {
    $full = [Math]::Max(36, $Host.UI.RawUI.WindowSize.Width - 1)
    return [Math]::Max(36, [Math]::Min($full, 56))
  } catch {
    return 48
  }
}

function Get-InnerWidth {
  return [Math]::Max(32, (Get-UiWidth) - 6)
}

# Display cells (CJK = 2) — never use raw String.Length for layout math
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

function Truncate-Display {
  param([string]$Text, [int]$MaxCells)
  if ($null -eq $Text) { return '' }
  if ($MaxCells -le 0) { return '' }
  if ((Get-DisplayWidth $Text) -le $MaxCells) { return $Text }
  if ($MaxCells -le 1) { return '~' }
  $acc = ''
  foreach ($ch in $Text.ToCharArray()) {
    $try = $acc + $ch
    if ((Get-DisplayWidth ($try + '~')) -gt $MaxCells) {
      return ($acc + '~')
    }
    $acc = $try
  }
  return $acc
}

# Keep extension when possible: head~tail.ext
function Format-NameFit {
  param([string]$Name, [int]$MaxCells, [switch]$IsDir)
  if ($null -eq $Name) { $Name = '' }
  $suffix = ''
  if ($IsDir) { $suffix = '/' }
  $core = $Name
  $budget = $MaxCells - (Get-DisplayWidth $suffix)
  if ($budget -lt 2) { $budget = 2 }
  if ((Get-DisplayWidth $core) -le $budget) {
    return ($core + $suffix)
  }
  # Try keep extension
  $ext = ''
  $dot = $core.LastIndexOf('.')
  if ($dot -gt 0 -and $dot -lt ($core.Length - 1) -and -not $IsDir) {
    $ext = $core.Substring($dot)
    $base = $core.Substring(0, $dot)
  } else {
    $base = $core
  }
  $extW = Get-DisplayWidth $ext
  $ell = '~'
  $ellW = 1
  $room = $budget - $extW - $ellW
  if ($room -lt 2) {
    return ((Truncate-Display -Text $core -MaxCells $budget) + $suffix)
  }
  # Prefer more of the start (identifies batch prefixes like _raw_)
  $headN = [Math]::Max(4, [Math]::Floor($room * 0.55))
  $tailN = $room - $headN
  if ($tailN -lt 2) {
    $tailN = 2
    $headN = $room - $tailN
  }
  $head = Truncate-Display -Text $base -MaxCells $headN
  # strip accidental trailing ~
  if ($head.EndsWith('~')) { $head = $head.Substring(0, $head.Length - 1) }
  # tail from end of base
  $tail = ''
  if ($tailN -gt 0 -and $base.Length -gt 0) {
    $rev = ''
    $chars = $base.ToCharArray()
    for ($i = $chars.Length - 1; $i -ge 0; $i--) {
      $try = $chars[$i] + $rev
      if ((Get-DisplayWidth $try) -gt $tailN) { break }
      $rev = $try
    }
    $tail = $rev
  }
  return ($head + $ell + $tail + $ext + $suffix)
}

function Write-BoxRowClose {
  param(
    [int]$Used,
    [ConsoleColor]$Border = [ConsoleColor]::DarkGray
  )
  $inner = Get-InnerWidth
  $pad = $inner - $Used
  if ($pad -lt 0) { $pad = 0 }
  Write-Host ((' ' * $pad) + '|') -ForegroundColor $Border
}

# Fixed-column file/folder row: never blows the right border
# Layout: |{idx,3} {name padded}{size,6}|
function Write-FileRow {
  param(
    [int]$Index,
    [string]$FullPath,
    [string]$Name,
    [string]$Kind,  # dir | file | parent
    [string]$SizeText = '',
    [ConsoleColor]$Border = [ConsoleColor]::Cyan
  )
  $inner = Get-InnerWidth
  $idxW = 3
  $sizeW = 6
  $gap = 1
  # content after leading space inside box: idx + gap + name + gap + size
  $nameBudget = $inner - 1 - $idxW - $gap - $gap - $sizeW
  if ($nameBudget -lt 6) { $nameBudget = 6 }

  $isDir = ($Kind -eq 'dir' -or $Kind -eq 'parent')
  $display = Format-NameFit -Name $Name -MaxCells $nameBudget -IsDir:$isDir
  $nameW = Get-DisplayWidth $display
  $padName = $nameBudget - $nameW
  if ($padName -lt 0) { $padName = 0 }

  $sizeDisp = if ($isDir -and $Kind -ne 'parent') {
    ''
  } elseif ($Kind -eq 'parent') {
    ''
  } else {
    $SizeText
  }
  if ((Get-DisplayWidth $sizeDisp) -gt $sizeW) {
    $sizeDisp = Truncate-Display -Text $sizeDisp -MaxCells $sizeW
  }
  $sizePad = $sizeW - (Get-DisplayWidth $sizeDisp)
  if ($sizePad -lt 0) { $sizePad = 0 }

  $idxStr = ('{0,' + $idxW + '}') -f $Index
  $nameColor = if ($Kind -eq 'parent') { [ConsoleColor]::Green }
    elseif ($Kind -eq 'dir') { [ConsoleColor]::Cyan }
    else { [ConsoleColor]::Gray }
  $idxColor = if ($Kind -eq 'parent') { [ConsoleColor]::Green } else { [ConsoleColor]::DarkGray }

  Write-Host -NoNewline '  |' -ForegroundColor $Border
  Write-Host -NoNewline ' ' -ForegroundColor Gray
  Write-Host -NoNewline $idxStr -ForegroundColor $idxColor
  Write-Host -NoNewline ' ' -ForegroundColor Gray
  Write-ClickablePath -PathValue $FullPath -Label $display -Color $nameColor
  Write-Host -NoNewline (' ' * $padName) -ForegroundColor DarkGray
  Write-Host -NoNewline ' ' -ForegroundColor Gray
  Write-Host -NoNewline ((' ' * $sizePad) + $sizeDisp) -ForegroundColor DarkGray
  Write-Host '|' -ForegroundColor $Border
}

function Write-BoxTop {
  param([string]$Title, [ConsoleColor]$Border = [ConsoleColor]::DarkGray)
  $inner = Get-InnerWidth
  $t = " $Title "
  $tw = $t.Length
  if ($tw -gt ($inner - 2)) {
    $t = ' ' + $Title.Substring(0, [Math]::Max(1, $inner - 4)) + ' '
    $tw = $t.Length
  }
  $fill = $inner - $tw
  if ($fill -lt 0) { $fill = 0 }
  $left = [Math]::Floor($fill / 2)
  $right = $fill - $left
  Write-Host ('  +' + ('-' * $left) + $t + ('-' * $right) + '+') -ForegroundColor $Border
}

function Write-BoxBottom {
  param([ConsoleColor]$Border = [ConsoleColor]::DarkGray)
  $inner = Get-InnerWidth
  Write-Host ('  +' + ('-' * $inner) + '+') -ForegroundColor $Border
}

function Write-BoxRule {
  param([ConsoleColor]$Border = [ConsoleColor]::DarkGray)
  $inner = Get-InnerWidth
  Write-Host ('  |' + ('-' * $inner) + '|') -ForegroundColor $Border
}

function Write-BoxText {
  param([string]$Text, [ConsoleColor]$Fg = [ConsoleColor]::Gray, [ConsoleColor]$Border = [ConsoleColor]::DarkGray)
  $inner = Get-InnerWidth
  if ($null -eq $Text) { $Text = '' }
  $Text = Truncate-Display -Text $Text -MaxCells ($inner - 1)
  $pad = $inner - 1 - (Get-DisplayWidth $Text)
  if ($pad -lt 0) { $pad = 0 }
  Write-Host ('  | ' + $Text + (' ' * $pad) + '|') -ForegroundColor $Fg
}

function Write-BoxKeyParts {
  param([ConsoleColor]$Border = [ConsoleColor]::Yellow, [object[]]$Parts)
  $inner = Get-InnerWidth
  Write-Host -NoNewline '  |' -ForegroundColor $Border
  Write-Host -NoNewline ' ' -ForegroundColor Gray
  $used = 1
  foreach ($p in $Parts) {
    $t = [string]$p.T
    $c = if ($p.C) { $p.C } else { [ConsoleColor]::Gray }
    Write-Host -NoNewline $t -ForegroundColor $c
    $used += $t.Length
  }
  $pad = $inner - $used
  if ($pad -gt 0) { Write-Host -NoNewline (' ' * $pad) -ForegroundColor DarkGray }
  Write-Host '|' -ForegroundColor $Border
}

$script:AutoRefresh = $true
$script:FsDirty = $false
$script:LastRefreshUtc = [DateTime]::UtcNow
$script:Watcher = $null
$script:WatchHandlers = @()

function Stop-FsWatch {
  if ($script:WatchHandlers) {
    foreach ($h in $script:WatchHandlers) {
      try { Unregister-Event -SourceIdentifier $h -ErrorAction SilentlyContinue } catch {}
    }
  }
  $script:WatchHandlers = @()
  if ($script:Watcher) {
    try {
      $script:Watcher.EnableRaisingEvents = $false
      $script:Watcher.Dispose()
    } catch {}
  }
  $script:Watcher = $null
}

function Start-FsWatch {
  param([string]$PathValue)
  Stop-FsWatch
  if ([string]::IsNullOrWhiteSpace($PathValue) -or -not (Test-Path -LiteralPath $PathValue -PathType Container)) {
    return
  }
  try {
    $w = New-Object System.IO.FileSystemWatcher
    $w.Path = $PathValue
    $w.IncludeSubdirectories = $false
    $w.NotifyFilter = [IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
    $w.EnableRaisingEvents = $true
    $script:Watcher = $w
    $sid = 'wzExplorerFs_' + [guid]::NewGuid().ToString('N')
    foreach ($ev in @('Created', 'Changed', 'Deleted', 'Renamed')) {
      $id = $sid + '_' + $ev
      Register-ObjectEvent -InputObject $w -EventName $ev -SourceIdentifier $id -Action {
        $global:WzExplorerFsDirty = $true
      } | Out-Null
      $script:WatchHandlers += $id
    }
    $global:WzExplorerFsDirty = $false
  } catch {
    $script:Watcher = $null
  }
}

function Test-FsDirty {
  if ($global:WzExplorerFsDirty) {
    $global:WzExplorerFsDirty = $false
    return $true
  }
  return $false
}

function Show-Help {
  Clear-Host
  Write-BoxTop -Title 'EXPLORER HELP' -Border DarkGray
  Write-BoxText -Text 'WS=task name  DESK=task root  VIEW=browse path' -Fg DarkGray
  Write-BoxBottom -Border DarkGray
  Write-BoxTop -Title 'KEYS' -Border Yellow
  Write-BoxKeyParts -Border Yellow -Parts @(
    @{ T = '[ r ]'; C = [ConsoleColor]::Yellow }, @{ T = ' refresh now (no F4/F7)'; C = [ConsoleColor]::White }
  )
  Write-BoxKeyParts -Border Yellow -Parts @(
    @{ T = '[ a ]'; C = [ConsoleColor]::Yellow }, @{ T = ' toggle auto-refresh on/off'; C = [ConsoleColor]::Gray }
  )
  Write-BoxKeyParts -Border Yellow -Parts @(
    @{ T = '[ 0 / .. / u ]'; C = [ConsoleColor]::Yellow }, @{ T = ' parent dir'; C = [ConsoleColor]::Gray }
  )
  Write-BoxKeyParts -Border Yellow -Parts @(
    @{ T = '[ 1..N ]'; C = [ConsoleColor]::Yellow }, @{ T = ' enter folder / open file'; C = [ConsoleColor]::Gray }
  )
  Write-BoxKeyParts -Border Yellow -Parts @(
    @{ T = '[ s ]'; C = [ConsoleColor]::Yellow }, @{ T = ' back to DESK root'; C = [ConsoleColor]::Gray }
  )
  Write-BoxKeyParts -Border Yellow -Parts @(
    @{ T = '[ g ]'; C = [ConsoleColor]::Yellow }, @{ T = ' Grok@VIEW   '; C = [ConsoleColor]::Gray },
    @{ T = '[ gd ]'; C = [ConsoleColor]::Yellow }, @{ T = ' Grok@DESK'; C = [ConsoleColor]::White }
  )
  Write-BoxKeyParts -Border Yellow -Parts @(
    @{ T = '[ b ]'; C = [ConsoleColor]::Yellow }, @{ T = ' bind VIEW as DESK   '; C = [ConsoleColor]::Gray },
    @{ T = '[ w ]'; C = [ConsoleColor]::Yellow }, @{ T = ' shell tab'; C = [ConsoleColor]::Gray }
  )
  Write-BoxKeyParts -Border Yellow -Parts @(
    @{ T = '[ p ]'; C = [ConsoleColor]::Yellow }, @{ T = ' copy path  '; C = [ConsoleColor]::DarkGray },
    @{ T = '[ f ]'; C = [ConsoleColor]::Yellow }, @{ T = ' favorite  '; C = [ConsoleColor]::DarkGray },
    @{ T = '[ q ]'; C = [ConsoleColor]::Yellow }, @{ T = ' quit'; C = [ConsoleColor]::DarkGray }
  )
  Write-BoxBottom -Border Yellow
  Write-Host '  Enter to return...' -ForegroundColor DarkGray
}

function Show-Listing {
  Clear-Host
  $aligned = Test-UnderDesk -PathValue $script:Cwd
  $sameDeskView = (Normalize-PathKey $script:Cwd) -eq (Normalize-PathKey $script:Desk)
  $autoLabel = if ($script:AutoRefresh) { 'AUTO-ON' } else { 'AUTO-OFF' }
  $bHead = [ConsoleColor]::DarkGray
  $bLoc  = [ConsoleColor]::Green
  $bList = [ConsoleColor]::Cyan
  $bCmd  = [ConsoleColor]::Yellow

  # --- HEADER ---
  Write-BoxTop -Title ('EXPLORER  ' + $script:Workspace) -Border $bHead
  Write-BoxText -Text ("refresh  $autoLabel  |  r force  |  a toggle auto") -Fg DarkGray -Border $bHead
  Write-BoxBottom -Border $bHead

  # --- LOCATION (Green border) ---
  Write-BoxTop -Title '1 LOCATION' -Border $bLoc
  $maxPath = (Get-InnerWidth) - 8
  if ($maxPath -lt 12) { $maxPath = 12 }
  $viewLabel = Format-NameFit -Name $script:Cwd -MaxCells $maxPath
  Write-Host -NoNewline '  |' -ForegroundColor $bLoc
  Write-Host -NoNewline ' ' -ForegroundColor Gray
  Write-Host -NoNewline 'VIEW  ' -ForegroundColor DarkGray
  Write-ClickablePath -PathValue $script:Cwd -Label $viewLabel -Color White
  Write-BoxRowClose -Used (1 + 6 + (Get-DisplayWidth $viewLabel)) -Border $bLoc
  if (-not $sameDeskView) {
    $deskLabel = Format-NameFit -Name $script:Desk -MaxCells $maxPath
    Write-Host -NoNewline '  |' -ForegroundColor $bLoc
    Write-Host -NoNewline ' ' -ForegroundColor Gray
    Write-Host -NoNewline 'DESK  ' -ForegroundColor DarkGray
    Write-ClickablePath -PathValue $script:Desk -Label $deskLabel -Color Gray
    Write-BoxRowClose -Used (1 + 6 + (Get-DisplayWidth $deskLabel)) -Border $bLoc
    if (-not $aligned) {
      Write-BoxText -Text '! left DESK tree - press s to return' -Fg Red -Border $bLoc
    }
  }
  Write-BoxBottom -Border $bLoc

  # --- FILE LIST (Cyan border) ---
  # Folders vs files: strong split — section rules + different name colors
  #   folders = Cyan + trailing /
  #   files   = Gray  + size on right
  Write-BoxTop -Title '2 FILES' -Border $bList
  $dirs = @()
  $files = @()
  try {
    $dirs = @(Get-ChildItem -LiteralPath $script:Cwd -Directory -Force -ErrorAction Stop |
      Sort-Object Name | Select-Object -First 40)
    $files = @(Get-ChildItem -LiteralPath $script:Cwd -File -Force -ErrorAction Stop |
      Sort-Object Name | Select-Object -First 40)
  } catch {
    Write-BoxText -Text ("Cannot read: $_") -Fg Red -Border $bList
    Write-BoxBottom -Border $bList
    return
  }

  $script:Entries = @()
  $i = 1
  $parent = Get-ParentPath -PathValue $script:Cwd

  if ($parent -and (Normalize-PathKey $parent) -ne (Normalize-PathKey $script:Cwd)) {
    Write-FileRow -Index 0 -FullPath $parent -Name ('.. ' + (Split-Path -Leaf $parent)) `
      -Kind 'parent' -Border $bList
  }

  # ---- folders block (Cyan names) ----
  Write-BoxText -Text ('-- folders ({0}) --' -f $dirs.Count) -Fg Cyan -Border $bList
  if ($dirs.Count -eq 0) {
    Write-BoxText -Text '(no subfolders)' -Fg DarkGray -Border $bList
  } else {
    foreach ($d in $dirs) {
      $script:Entries += [pscustomobject]@{ Index = $i; Kind = 'dir'; Path = $d.FullName; Name = $d.Name }
      Write-FileRow -Index $i -FullPath $d.FullName -Name $d.Name -Kind 'dir' -Border $bList
      $i++
    }
  }

  # ---- hard separator between folders and files ----
  Write-BoxRule -Border $bList
  Write-BoxText -Text ('-- files ({0}) --' -f $files.Count) -Fg Gray -Border $bList

  if ($files.Count -eq 0) {
    Write-BoxText -Text '(no files)' -Fg DarkGray -Border $bList
  } else {
    foreach ($f in $files) {
      $script:Entries += [pscustomobject]@{ Index = $i; Kind = 'file'; Path = $f.FullName; Name = $f.Name }
      if ($f.Length -lt 1024) { $size = ('{0}B' -f $f.Length) }
      elseif ($f.Length -lt 1048576) { $size = ('{0:N0}K' -f ($f.Length / 1024.0)) }
      else { $size = ('{0:N1}M' -f ($f.Length / 1048576.0)) }
      Write-FileRow -Index $i -FullPath $f.FullName -Name $f.Name -Kind 'file' `
        -SizeText $size -Border $bList
      $i++
    }
  }

  if ($dirs.Count -eq 0 -and $files.Count -eq 0) {
    Write-BoxText -Text '(empty folder)' -Fg DarkGray -Border $bList
  }
  Write-BoxBottom -Border $bList

  # --- COMMAND (Yellow border + loud keys) ---
  Write-BoxTop -Title '3 COMMAND  << type here' -Border $bCmd
  Write-BoxKeyParts -Border $bCmd -Parts @(
    @{ T = ' >_ '; C = [ConsoleColor]::White },
    @{ T = 'waiting...  '; C = [ConsoleColor]::DarkGray },
    @{ T = '[ r ]'; C = [ConsoleColor]::Yellow },
    @{ T = ' refresh  '; C = [ConsoleColor]::White },
    @{ T = '[ a ]'; C = [ConsoleColor]::Yellow },
    @{ T = ' auto'; C = [ConsoleColor]::Gray }
  )
  Write-BoxKeyParts -Border $bCmd -Parts @(
    @{ T = '[ 0 ]'; C = [ConsoleColor]::Yellow },
    @{ T = ' parent  '; C = [ConsoleColor]::Gray },
    @{ T = '[ s ]'; C = [ConsoleColor]::Yellow },
    @{ T = ' DESK  '; C = [ConsoleColor]::Gray },
    @{ T = '[ gd ]'; C = [ConsoleColor]::Yellow },
    @{ T = ' Grok  '; C = [ConsoleColor]::White },
    @{ T = '[ ? ]'; C = [ConsoleColor]::Yellow },
    @{ T = ' help'; C = [ConsoleColor]::DarkGray }
  )
  Write-BoxBottom -Border $bCmd

  $script:LastRefreshUtc = [DateTime]::UtcNow
  # ensure watcher tracks current VIEW
  if ($script:AutoRefresh) {
    $watchPath = if ($script:Watcher) { $script:Watcher.Path } else { '' }
    if ((Normalize-PathKey $watchPath) -ne (Normalize-PathKey $script:Cwd)) {
      Start-FsWatch -PathValue $script:Cwd
    }
  }
}

function Invoke-WezSpawn {
  param(
    [string]$WorkDir,
    [string[]]$ProgArgs
  )
  if (-not $script:Wez) {
    Write-Host '  wezterm.exe not found' -ForegroundColor Red
    return $false
  }
  $spawnArgs = @('cli', 'spawn', '--cwd', $WorkDir)
  if ($ProgArgs -and $ProgArgs.Count -gt 0) {
    $spawnArgs += '--'
    $spawnArgs += $ProgArgs
  }
  try {
    & $script:Wez @spawnArgs 2>$null | Out-Null
    return $true
  } catch {
    Write-Host ("  wezterm cli failed: {0}" -f $_) -ForegroundColor Red
    return $false
  }
}

function Add-Favorite {
  $fav = Join-Path $env:USERPROFILE '.config\wezterm\workbench\favorites.txt'
  $dir = Split-Path $fav -Parent
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  if (-not (Test-Path $fav)) {
    $header = @(
      '# AI STAR CUBE favorites - one full path per line',
      '# Lines starting with # are ignored'
    )
    Set-Content -Path $fav -Value $header -Encoding UTF8
  }
  $existing = @(Get-Content -LiteralPath $fav -ErrorAction SilentlyContinue)
  if ($existing -contains $script:Cwd) {
    Write-Host ("  already favorited: {0}" -f $script:Cwd) -ForegroundColor DarkYellow
  } else {
    Add-Content -LiteralPath $fav -Value $script:Cwd -Encoding UTF8
    Write-Host '  saved to favorites.txt' -ForegroundColor Magenta
    Write-Host ("  {0}" -f $script:Cwd) -ForegroundColor Gray
  }
  Start-Sleep -Seconds 1
}

function Get-EntryByIndex {
  param([int]$Num)
  foreach ($ent in $script:Entries) {
    if ($ent.Index -eq $Num) { return $ent }
  }
  return $null
}

function Start-GrokHere {
  param([string]$WorkDir, [string]$Label)
  $grok = Join-Path $env:USERPROFILE '.grok\bin\grok.exe'
  if (-not (Test-Path -LiteralPath $grok)) {
    Write-Host '  grok.exe not found' -ForegroundColor Red
    Start-Sleep -Seconds 1
    return
  }
  # Always pass --cwd so TUI top bar == DESK/VIEW (F-005)
  $ok = Invoke-WezSpawn -WorkDir $WorkDir -ProgArgs @($grok, '--cwd', $WorkDir)
  if ($ok) {
    Write-Host ("  OK: Grok @ {0}" -f $Label) -ForegroundColor Green
    Write-Host ("  --cwd {0}" -f $WorkDir) -ForegroundColor DarkGray
    Write-Host '  (对话顶栏应与本侧栏 DESK/VIEW 一致；再 F7 会跟对话同根)' -ForegroundColor DarkCyan
    # Keep desk-roots aligned for this task name
    Write-DeskRootToFile -Ws $script:Workspace -PathValue $script:Desk
  } else {
    Set-Location -LiteralPath $WorkDir
    & $grok --cwd $WorkDir
  }
  Start-Sleep -Seconds 1.0
}

function Read-ExplorerLine {
  # Non-blocking-ish input: poll keys with timeout so auto-refresh can redraw
  # without F4/F7. Enter submits; Esc clears buffer.
  $buf = ''
  $pollMs = 200
  Write-Host -NoNewline '  explorer> ' -ForegroundColor Yellow
  while ($true) {
    # Only redraw when filesystem actually changed (not on a timer)
    if ($script:AutoRefresh -and (Test-FsDirty)) {
      Write-Host ''
      return '__AUTO_REFRESH__'
    }
    if ($Host.UI.RawUI.KeyAvailable) {
      $k = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
      $vk = [int]$k.VirtualKeyCode
      $ch = $k.Character
      if ($vk -eq 13) {
        Write-Host ''
        return $buf
      }
      if ($vk -eq 27) {
        $buf = ''
        Write-Host ''
        Write-Host -NoNewline '  explorer> ' -ForegroundColor Yellow
        continue
      }
      if ($vk -eq 8) {
        if ($buf.Length -gt 0) {
          $buf = $buf.Substring(0, $buf.Length - 1)
          Write-Host -NoNewline "`b `b"
        }
        continue
      }
      if ($ch -and [int][char]$ch -ge 32) {
        $buf += $ch
        Write-Host -NoNewline $ch -ForegroundColor White
      }
      continue
    }
    Start-Sleep -Milliseconds $pollMs
  }
}

Start-FsWatch -PathValue $script:Cwd
$running = $true
while ($running) {
  Show-Listing
  $line = Read-ExplorerLine
  if ($null -eq $line) { continue }
  if ($line -eq '__AUTO_REFRESH__') {
    # In-place refresh: re-read folder / watcher events — no F4/F7
    if ($script:AutoRefresh) {
      $fromFile = Read-DeskRootFromFile -Ws $script:Workspace
      if ($fromFile) { $script:Desk = $fromFile }
    }
    continue
  }
  $line = ConvertFrom-FullwidthDigits -Text $line.Trim()
  if ($line -eq '') { continue }

  $low = $line.ToLowerInvariant()
  # normalize "cd .." / "cd.." / ".."
  if ($low -match '^cd\s*\.\.\s*$' -or $low -eq 'cd..') { $low = '..' }

  if ($low -eq '?' -or $low -eq 'help') {
    Show-Help
    [void](Read-Host '  (press Enter)')
    continue
  }

  if ($low -eq 'a' -or $low -eq 'auto') {
    $script:AutoRefresh = -not $script:AutoRefresh
    if ($script:AutoRefresh) {
      Start-FsWatch -PathValue $script:Cwd
      Write-Host '  auto-refresh ON (folder changes redraw here; no F4/F7)' -ForegroundColor Green
    } else {
      Stop-FsWatch
      Write-Host '  auto-refresh OFF (press r to refresh manually)' -ForegroundColor DarkGray
    }
    Start-Sleep -Milliseconds 600
    continue
  }

  if ($low -eq 'q' -or $low -eq 'quit' -or $low -eq 'exit') {
    Stop-FsWatch
    Write-Host '  Quit. Close pane: F4  (or Alt+z then x)' -ForegroundColor DarkGray
    $running = $false
    break
  }

  # Snap back to task desk root
  if ($low -eq 's' -or $low -eq 'root' -or $low -eq 'desk' -or $low -eq 'home-desk') {
    $resolved = Resolve-SafePath -PathValue $script:Desk
    if ($resolved) {
      $script:Cwd = $resolved
      Start-FsWatch -PathValue $script:Cwd
      Write-Host '  VIEW -> DESK (aligned)' -ForegroundColor Green
      Start-Sleep -Milliseconds 400
    } else {
      Write-Host '  DESK path missing' -ForegroundColor Red
      Start-Sleep -Seconds 0.8
    }
    continue
  }

  # Bind current VIEW as new DESK for this workspace
  if ($low -eq 'b' -or $low -eq 'bind') {
    $script:Desk = $script:Cwd
    Write-DeskRootToFile -Ws $script:Workspace -PathValue $script:Desk
    Write-Host '  已绑定任务根 DESK = 当前 VIEW' -ForegroundColor Magenta
    Write-Host ("  WS:{0}" -f $script:Workspace) -ForegroundColor Cyan
    Write-Host ("  DESK:{0}" -f $script:Desk) -ForegroundColor White
    Write-Host '  状态栏下次刷新会显示新 DESK；F6/Grok 将默认用此根' -ForegroundColor DarkGray
    Start-Sleep -Seconds 1.2
    continue
  }

  if ($low -eq '0' -or $low -eq '..' -or $low -eq 'u' -or $low -eq 'up' -or $low -eq '-') {
    if (Move-ToParent) { Start-FsWatch -PathValue $script:Cwd }
    continue
  }

  if ($low -eq '~' -or $low -eq 'home') {
    $script:Cwd = $env:USERPROFILE
    Start-FsWatch -PathValue $script:Cwd
    continue
  }

  if ($low -eq 'r' -or $low -eq 'refresh') {
    # Force in-place refresh (no F4/F7)
    $fromFile = Read-DeskRootFromFile -Ws $script:Workspace
    if ($fromFile) { $script:Desk = $fromFile }
    Start-FsWatch -PathValue $script:Cwd
    $global:WzExplorerFsDirty = $false
    Write-Host '  refreshed' -ForegroundColor Green
    Start-Sleep -Milliseconds 250
    continue
  }

  if ($low -eq 'p' -or $low -eq 'pwd') {
    try {
      Set-Clipboard -Value $script:Cwd
      Write-Host ("  copied VIEW: {0}" -f $script:Cwd) -ForegroundColor Green
    } catch {
      Write-Host ("  VIEW: {0}" -f $script:Cwd) -ForegroundColor Green
    }
    Start-Sleep -Seconds 0.7
    continue
  }

  if ($low -eq 'f' -or $low -eq 'fav') {
    Add-Favorite
    continue
  }

  if ($low -eq 'w') {
    $ok = Invoke-WezSpawn -WorkDir $script:Cwd -ProgArgs @('powershell.exe', '-NoLogo')
    if ($ok) {
      Write-Host '  OK: new shell tab @ VIEW' -ForegroundColor Green
    } else {
      Set-Location -LiteralPath $script:Cwd
      Write-Host '  cd in this pane only' -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 0.8
    continue
  }

  # Grok at desk root (preferred for "this task's AI chat")
  if ($low -eq 'gd' -or $low -eq 'gg') {
    Start-GrokHere -WorkDir $script:Desk -Label 'DESK (任务根)'
    continue
  }

  # Grok at current browse path
  if ($low -eq 'g') {
    Start-GrokHere -WorkDir $script:Cwd -Label 'VIEW (浏览位置)'
    continue
  }

  if ($low -match '^o\s*(\d+)$') {
    $n = [int]$Matches[1]
    if ($n -eq 0) {
      [void](Move-ToParent)
      continue
    }
    $ent = Get-EntryByIndex -Num $n
    if (-not $ent) {
      Write-Host '  bad number' -ForegroundColor Red
      Start-Sleep -Seconds 0.6
      continue
    }
    # o N always system-default open (folders → Explorer)
    [void](Open-DefaultApp -PathValue $ent.Path -Kind $ent.Kind)
    Start-Sleep -Seconds 0.7
    continue
  }

  if ($low -match '^c\s*(\d+)$') {
    $n = [int]$Matches[1]
    $ent = Get-EntryByIndex -Num $n
    if (-not $ent) {
      Write-Host '  bad number' -ForegroundColor Red
      Start-Sleep -Seconds 0.6
      continue
    }
    $code = Get-Command code -ErrorAction SilentlyContinue
    if ($code) {
      & $code.Source $ent.Path
      Write-Host ("  VS Code: {0}" -f $ent.Name) -ForegroundColor Green
    } else {
      [void](Open-DefaultApp -PathValue $ent.Path -Kind $ent.Kind)
      Write-Host '  code not found; used default app' -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 0.7
    continue
  }

  if ($low -match '^\d+$') {
    $n = [int]$low
    if ($n -eq 0) {
      [void](Move-ToParent)
      continue
    }
    $ent = Get-EntryByIndex -Num $n
    if (-not $ent) {
      Write-Host '  bad number' -ForegroundColor Red
      Start-Sleep -Seconds 0.6
      continue
    }
    if ($ent.Kind -eq 'dir') {
      $script:Cwd = $ent.Path
      Start-FsWatch -PathValue $script:Cwd
    } else {
      [void](Open-DefaultApp -PathValue $ent.Path -Kind 'file')
      Start-Sleep -Seconds 0.5
    }
    continue
  }

  $candidate = $line
  if (-not [System.IO.Path]::IsPathRooted($candidate)) {
    $candidate = Join-Path $script:Cwd $line
  }
  $resolved = Resolve-SafePath -PathValue $candidate
  if ($resolved -and (Test-Path -LiteralPath $resolved -PathType Container)) {
    $script:Cwd = $resolved
    Start-FsWatch -PathValue $script:Cwd
  } elseif ($resolved -and (Test-Path -LiteralPath $resolved -PathType Leaf)) {
    [void](Open-DefaultApp -PathValue $resolved -Kind 'file')
    Start-Sleep -Seconds 0.5
  } else {
    Write-Host ("  unknown: {0}  (type ? for help)" -f $line) -ForegroundColor Red
    Start-Sleep -Seconds 0.8
  }
}

Stop-FsWatch
Write-Host '  Explorer ended. Close pane: F4' -ForegroundColor DarkGray
