# Open WZ_Skill inside the EXISTING WezTerm window as a NEW TAB.
# Never Start-Process an agent CLI alone — that creates a separate OS window
# that stacks on top of WezTerm (looks like "tabs never appear side by side").
#
# Usage (from any clone path):
#   powershell -ExecutionPolicy Bypass -File .\open-project.ps1
#   powershell -ExecutionPolicy Bypass -File .\open-project.ps1 -Prompt "continue WZ"
#   powershell -ExecutionPolicy Bypass -File .\open-project.ps1 -Continue
#   powershell -ExecutionPolicy Bypass -File .\open-project.ps1 -Agent any-route-id

[CmdletBinding()]
param(
    [string]$Prompt = "",
    [switch]$NewWindow,
    # Resume is only applied by launch adapters that explicitly support it.
    [switch]$Continue,
    # Any id returned by the open Agent discovery helper.
    [string]$Agent = ''
)

$ErrorActionPreference = "Stop"
if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw 'open-project.ps1 supports Windows only.'
}
# Always this clone's root — never a machine-specific hardcoded path
$ProjectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($ProjectRoot) -or -not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    throw "open-project.ps1: cannot resolve project root from PSScriptRoot=$PSScriptRoot"
}

function Normalize-WzPathKey([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    return $Path.Trim().Replace('/', '\').TrimEnd('\').ToLowerInvariant()
}

function Test-WzWeakPath([string]$Path) {
    $key = Normalize-WzPathKey $Path
    $homeKey = Normalize-WzPathKey $env:USERPROFILE
    if (-not $key -or $key -eq $homeKey -or $key -match '^[a-z]:$') { return $true }
    $weakExact = @('Desktop','Documents','Downloads','Pictures','Music','Videos','OneDrive','.config') |
        ForEach-Object { Normalize-WzPathKey (Join-Path $env:USERPROFILE $_) }
    if ($weakExact -contains $key) { return $true }
    $appDataKey = Normalize-WzPathKey (Join-Path $env:USERPROFILE 'AppData')
    if ($key -eq $appDataKey -or $key.StartsWith($appDataKey + '\')) { return $true }
    if ($homeKey -and $key.StartsWith($homeKey + '\.')) { return $true }
    if ($key -match '\\windows\\(system32|syswow64|temp)(\\|$)') { return $true }
    return $false
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

# Freeze project identity: name + path (desk-roots + .wz-project)
# 「项目名」= binding name (not session title). Path is absolute and fixed.
function Update-DeskRootBinding {
    param(
        [string]$RootPath,
        [string]$ProjectName = "",
        # D-004 optional 3rd column; "" = leave this row as-is
        [string]$Agent = ""
    )
    $rootsFile = Join-Path $env:USERPROFILE ".config\wezterm\workbench\desk-roots.tsv"
    if ([string]::IsNullOrWhiteSpace($ProjectName)) {
        $ProjectName = Split-Path -Leaf $RootPath
    }
    $reserved = @('home','desktop','documents','downloads','pictures','music','videos','administrator','users','temp','tmp','appdata','windows','system32','config','.config','wezterm','onedrive')
    if ($ProjectName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$' -or
        $ProjectName -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$' -or
        $reserved -contains $ProjectName.ToLowerInvariant()) {
        throw "REFUSE: invalid or reserved project name '$ProjectName'"
    }
    if (Test-WzWeakPath $RootPath) {
        throw "REFUSE: weak/system path cannot be project root: $RootPath"
    }
    $dir = Split-Path $rootsFile -Parent
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $map = [ordered]@{}
    $agentMap = @{}
    if (Test-Path -LiteralPath $rootsFile) {
        foreach ($line in Get-Content -LiteralPath $rootsFile -ErrorAction SilentlyContinue) {
            $t = $line.Trim()
            if ($t -eq "" -or $t.StartsWith("#")) { continue }
            # D-004: tolerate 2 or 3 TAB columns (name, path, optional agent)
            $parts = $t -split "`t"
            if ($parts.Count -lt 2) { $parts = $t -split "\s+", 2 }
            if ($parts.Count -ge 2) {
                $k = $parts[0]; $p = $parts[1]
                if ($reserved -contains $k.ToLowerInvariant()) { continue }
                $map[$k] = $p
                if ($parts.Count -ge 3 -and $parts[2].Trim()) {
                    $agentMap[$k] = $parts[2].Trim().ToLowerInvariant()
                }
            }
        }
    }
    # one path → one name
    $pk = $RootPath.TrimEnd('\').ToLowerInvariant()
    foreach ($k in @($map.Keys)) {
        if ($map[$k].TrimEnd('\').ToLowerInvariant() -eq $pk -and $k -ne $ProjectName) {
            $map.Remove($k)
            $agentMap.Remove($k)
        }
    }
    $map[$ProjectName] = $RootPath
    $Agent = $Agent.Trim().ToLowerInvariant()
    if ($Agent) { $agentMap[$ProjectName] = $Agent }
    $out = @(
        "# AI STAR CUBE desk roots — project_name<TAB>absolute_path[<TAB>agent]",
        "# 项目名(绑定名) 与 项目路径 写死绑定；Explorer / 状态栏 / F6 / Init 共用",
        "# 弱路径(home/Desktop/…)与保留名不得写入",
        "# 可选第三列 agent: 任意开放探测得到的 route id（绑定时显式写入）"
    )
    foreach ($k in ($map.Keys | Sort-Object)) {
        # Unified semantics with Install-WZ.ps1: rows with a recorded agent get
        # an EXPLICIT 3rd column (including grok); untouched legacy rows keep
        # their original 2-column form.
        if ($agentMap.Contains($k)) {
            $out += ($k + "`t" + $map[$k] + "`t" + [string]$agentMap[$k])
        } else {
            $out += ($k + "`t" + $map[$k])
        }
    }
    Write-WzUtf8LinesAtomic -Path $rootsFile -Lines $out
    # freeze on disk
    $marker = Join-Path $RootPath ".wz-project"
    $markerLines = @(
        "# WZ project identity — frozen at create/bind",
        "name=$ProjectName",
        "path=$RootPath",
        ("created={0:yyyy-MM-ddTHH:mm:ssK}" -f (Get-Date))
    )
    $markerMatches = $false
    if (Test-Path -LiteralPath $marker -PathType Leaf) {
        $existing = @(Get-Content -LiteralPath $marker -Encoding UTF8 -ErrorAction SilentlyContinue)
        $markerMatches = ($existing -contains ('name=' + $ProjectName)) -and ($existing -contains ('path=' + $RootPath))
    }
    if (-not $markerMatches) { Write-WzUtf8LinesAtomic -Path $marker -Lines $markerLines }
    Write-Host "PROJECT bind: $ProjectName -> $RootPath"
    Write-Host "marker: $marker"
}
function Get-DetectedAgents {
    $root = Join-Path $env:USERPROFILE '.config\wezterm\workbench'
    $helper = Join-Path $root 'agent-discovery.ps1'
    if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
        $root = Join-Path $PSScriptRoot 'live-workbench\workbench'
        $helper = Join-Path $root 'agent-discovery.ps1'
    }
    if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) { return @() }
    return @(& $helper -WorkbenchDir $root)
}

$bindName = Split-Path -Leaf $ProjectRoot
if ([string]::IsNullOrWhiteSpace($bindName)) { $bindName = "WZ_AiStarCube_win" }

# Resolve the effective agent from the open inventory:
#   1. explicit -Agent
#   2. desk-roots.tsv 3rd column for this project
#   3. first dynamically discovered Agent
$detectedAgents = @(Get-DetectedAgents)
$rootsFile = Join-Path $env:USERPROFILE ".config\wezterm\workbench\desk-roots.tsv"
if (-not $Agent) {
    if (Test-Path -LiteralPath $rootsFile) {
        foreach ($line in Get-Content -LiteralPath $rootsFile -ErrorAction SilentlyContinue) {
            $t = $line.Trim()
            if ($t -eq "" -or $t.StartsWith("#")) { continue }
            $parts = $t -split "`t"
            if ($parts.Count -ge 3 -and $parts[0] -eq $bindName -and $parts[2].Trim()) {
                $Agent = $parts[2].Trim().ToLowerInvariant()
                break
            }
        }
    }
}
if (-not $Agent) {
    if ($detectedAgents.Count -gt 0) { $Agent = [string]$detectedAgents[0].Id }
}
if (-not $Agent) {
    throw "open-project.ps1: no self-described or locally registered Agent CLI found."
}
$Agent = $Agent.Trim().ToLowerInvariant()
if ($Agent -notmatch '^[a-z0-9][a-z0-9_-]{0,63}$') {
    throw "open-project.ps1: invalid Agent route id '$Agent'."
}
$agentDef = @($detectedAgents | Where-Object { $_.Id -eq $Agent } | Select-Object -First 1)
$agentExe = if ($agentDef.Count -gt 0) { [string]$agentDef[0].Exe } else { $null }
if (-not $agentExe) {
    throw "$Agent CLI not found in the open inventory. Reinstall it, add metadata/local registration, or fix the 3rd column in $rootsFile."
}

# Unified semantics with Install-WZ.ps1: the bound row gets an EXPLICIT 3rd
# agent column recording the effective agent of this run.
Update-DeskRootBinding -RootPath $ProjectRoot -ProjectName $bindName -Agent $Agent

$wez = $null
foreach ($c in @(
    "C:\Program Files\WezTerm\wezterm.exe",
    (Get-Command wezterm -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
)) {
    if ($c -and (Test-Path -LiteralPath $c)) { $wez = $c; break }
}

Write-Host "Project : $ProjectRoot"
Write-Host ("Agent   : {0} ({1})" -f $Agent, $agentExe)
Write-Host "WezTerm : $wez"

$cliArgs = @()
if (-not [string]::IsNullOrWhiteSpace($Prompt)) { $cliArgs += $Prompt }
if ($Continue) {
    Write-Host "WARNING: generic open discovery cannot infer resume flags for '$Agent'; starting normally." -ForegroundColor DarkCyan
}
if ($agentExe -match '\.exe$') {
    $prog = @($agentExe) + $cliArgs
} else {
    # .cmd / extensionless shim cannot be argv0 of CreateProcess.
    $cmdLine = "& '$($agentExe -replace "'", "''")'"
    foreach ($a in $cliArgs) { $cmdLine += " '$($a -replace "'", "''")'" }
    $prog = @("powershell.exe", "-NoLogo", "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $cmdLine)
}

function Test-WeztermGuiAlive {
    return $null -ne (Get-Process -Name "wezterm-gui" -ErrorAction SilentlyContinue | Select-Object -First 1)
}

if ($wez -and -not $NewWindow) {
    if (Test-WeztermGuiAlive) {
        # Inject a tab into the running GUI (window 0 if WEZTERM_PANE is unset)
        $spawnArgs = @("cli", "spawn", "--cwd", $ProjectRoot)
        $windowId = $null
        try {
            $listJson = (& $wez cli list --format json 2>$null | Out-String).Trim()
            if ($listJson) {
                $first = @($listJson | ConvertFrom-Json | Select-Object -First 1)
                if ($first.Count -gt 0 -and $null -ne $first[0].window_id) { $windowId = [string]$first[0].window_id }
            }
        } catch {}
        if (-not $windowId) {
            $winLine = & $wez cli list 2>$null | Select-Object -Skip 1 -First 1
            if ($winLine -match '^\s*(\d+)\s+') { $windowId = $Matches[1] }
        }
        if ($windowId -match '^\d+$') {
            $spawnArgs += @("--window-id", $windowId)
        }
        $spawnArgs += @("--")
        $spawnArgs += $prog
        Write-Host "Spawning TAB in existing WezTerm: wezterm $($spawnArgs -join ' ')"
        & $wez @spawnArgs
        if ($LASTEXITCODE -eq 0) {
            Write-Host "OK: new tab opened. Check the top tab bar (side-by-side)."
            exit 0
        }
        Write-Host "cli spawn failed (exit $LASTEXITCODE); falling back to wezterm start --new-tab"
    }

    # Ask existing GUI for a tab; if none running, starts GUI once
    $startArgs = @("start", "--new-tab", "--cwd", $ProjectRoot, "--") + $prog
    Write-Host "wezterm $($startArgs -join ' ')"
    Start-Process -FilePath $wez -ArgumentList $startArgs -WorkingDirectory $ProjectRoot | Out-Null
    Write-Host "OK: requested tab via wezterm start --new-tab"
    exit 0
}

if ($NewWindow -and $wez) {
    Write-Host "WARNING: -NewWindow creates a separate OS window (not a tab)."
    $startArgs = @("start", "--always-new-process", "--cwd", $ProjectRoot, "--") + $prog
    Start-Process -FilePath $wez -ArgumentList $startArgs -WorkingDirectory $ProjectRoot | Out-Null
    exit 0
}

# Last resort (no wezterm): still avoid silent double-console if possible
Write-Host "WARNING: WezTerm not found; starting $Agent in a bare console (not a WezTerm tab)."
$restArgs = @()
if ($prog.Count -gt 1) { $restArgs = $prog[1..($prog.Count - 1)] }
Start-Process -FilePath $prog[0] -ArgumentList $restArgs -WorkingDirectory $ProjectRoot | Out-Null
