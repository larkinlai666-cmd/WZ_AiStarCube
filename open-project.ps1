# Open WZ_Skill inside the EXISTING WezTerm window as a NEW TAB.
# Never Start-Process an agent CLI alone — that creates a separate OS window
# that stacks on top of WezTerm (looks like "tabs never appear side by side").
#
# Usage (from any clone path):
#   powershell -ExecutionPolicy Bypass -File .\open-project.ps1
#   powershell -ExecutionPolicy Bypass -File .\open-project.ps1 -Prompt "continue WZ"
#   powershell -ExecutionPolicy Bypass -File .\open-project.ps1 -Continue
#   powershell -ExecutionPolicy Bypass -File .\open-project.ps1 -Agent kimi [-Continue]

[CmdletBinding()]
param(
    [string]$Prompt = "",
    [switch]$NewWindow,
    # Resume most recent session for this project
    # (grok -c / kimi --continue / codex resume --last / deepseek --continue)
    [switch]$Continue,
    # Open Grok Agent Dashboard instead of a chat (grok only)
    [switch]$Dashboard,
    # D-004: which agent CLI to launch. Empty (default) = desk-roots 3rd column
    # for this project, else first installed of grok/kimi/codex/deepseek.
    # grok = --cwd flag; kimi/codex/deepseek = process cwd via wezterm spawn
    # (kimi/deepseek have no --cwd; codex has -C but the workbench uses process
    # cwd uniformly).
    [ValidateSet('', 'grok', 'kimi', 'codex', 'deepseek')]
    [string]$Agent = ''
)

$ErrorActionPreference = "Stop"
# Always this clone's root — never a machine-specific hardcoded path
$ProjectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($ProjectRoot) -or -not (Test-Path -LiteralPath $ProjectRoot)) {
    throw "open-project.ps1: cannot resolve project root from PSScriptRoot=$PSScriptRoot"
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
    $reserved = @('home','desktop','documents','downloads','administrator','users','temp','appdata','windows')
    if ($reserved -contains $ProjectName.ToLowerInvariant()) {
        Write-Host "REFUSE: reserved project name '$ProjectName'" -ForegroundColor Red
        return
    }
    $weakExact = @(
        $env:USERPROFILE,
        (Join-Path $env:USERPROFILE 'Desktop'),
        (Join-Path $env:USERPROFILE 'Documents'),
        (Join-Path $env:USERPROFILE 'Downloads')
    ) | ForEach-Object { $_.TrimEnd('\').ToLowerInvariant() }
    if ($weakExact -contains $RootPath.TrimEnd('\').ToLowerInvariant()) {
        Write-Host "REFUSE: weak/system path cannot be project root: $RootPath" -ForegroundColor Red
        return
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
        "# 可选第三列 agent: grok / kimi / codex / deepseek (D-004，四者平权；绑定时显式写入)"
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
    Set-Content -LiteralPath $rootsFile -Value $out -Encoding UTF8
    # freeze on disk
    $marker = Join-Path $RootPath ".wz-project"
    $markerLines = @(
        "# WZ project identity — frozen at create/bind",
        "name=$ProjectName",
        "path=$RootPath",
        ("created={0:yyyy-MM-ddTHH:mm:ssK}" -f (Get-Date))
    )
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($marker, $markerLines, $utf8)
    Write-Host "PROJECT bind: $ProjectName -> $RootPath"
    Write-Host "marker: $marker"
}
# Resolve an agent CLI executable: PATH first, then well-known install dirs.
# codex is usually a WinGet .cmd shim — spawning a shim as argv0 can freeze,
# so the launcher below routes non-.exe shims through a PowerShell host.
function Resolve-AgentExe([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source)) { return $cmd.Source }
    $candidates = @()
    switch ($Name) {
        'grok' { $candidates = @(
            (Join-Path $env:USERPROFILE ".grok\bin\grok.exe"),
            (Join-Path $env:LOCALAPPDATA "Programs\grok\grok.exe")) }
        'kimi' { $candidates = @(
            (Join-Path $env:USERPROFILE ".kimi-code\bin\kimi.exe"),
            (Join-Path $env:USERPROFILE ".kimi-code\bin\kimi.cmd")) }
        'codex' { $candidates = @(
            (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\codex.exe"),
            (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\codex.cmd")) }
        'deepseek' { $candidates = @(
            (Join-Path $env:APPDATA "npm\deepseek.cmd"),
            (Join-Path $env:APPDATA "npm\deepseek.exe")) }
    }
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    return $null
}

$bindName = Split-Path -Leaf $ProjectRoot
if ([string]::IsNullOrWhiteSpace($bindName)) { $bindName = "WZ_AiStarCube" }

# Resolve the effective agent (D-004 — grok/kimi/codex are peers):
#   1. explicit -Agent
#   2. desk-roots.tsv 3rd column for this project
#   3. first installed of grok / kimi / codex (grok NOT required)
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
    foreach ($a in @('grok', 'kimi', 'codex', 'deepseek')) {
        if (Resolve-AgentExe $a) { $Agent = $a; break }
    }
}
if (-not $Agent) {
    throw "open-project.ps1: no agent CLI found. Install at least one of grok / kimi / codex / deepseek."
}
if ($Agent -notin @('grok', 'kimi', 'codex', 'deepseek')) {
    throw "open-project.ps1: unknown agent '$Agent' (expected grok/kimi/codex/deepseek) — fix the 3rd column in $rootsFile"
}
$agentExe = Resolve-AgentExe $Agent
if (-not $agentExe) {
    throw "$Agent CLI not found. Install it, pass -Agent with an installed agent (grok/kimi/codex/deepseek), or fix the 3rd column in $rootsFile."
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

$prog = @()
if ($Agent -eq 'grok') {
    $prog = @($agentExe)
    if ($Dashboard) {
        $prog += "dashboard"
    } else {
        $prog += @("--cwd", $ProjectRoot)
        if ($Continue) {
            $prog += "--continue"
        }
        if (-not [string]::IsNullOrWhiteSpace($Prompt)) {
            $prog += $Prompt
        }
    }
} else {
    # D-004: kimi has no --cwd; codex has -C but the workbench uniformly uses
    # process cwd — identity = process cwd set by
    # `wezterm cli spawn --cwd <path> --` (and -WorkingDirectory fallbacks).
    if ($Dashboard) {
        Write-Host "WARNING: -Dashboard is grok-only; ignored for -Agent $Agent" -ForegroundColor DarkCyan
    }
    $cliArgs = @()
    switch ($Agent) {
        'kimi' {
            if ($Continue) {
                # Same-model handover: resume most recent session in this cwd
                $cliArgs += "--continue"
            }
            if (-not [string]::IsNullOrWhiteSpace($Prompt)) {
                # Verified via `kimi --help`: -p/--prompt runs ONE prompt
                # non-interactively, prints the response, then exits.
                $cliArgs += @("-p", $Prompt)
                Write-Host "NOTE: kimi -p is one-shot non-interactive; the pane content ends when it finishes." -ForegroundColor Cyan
            }
        }
        'codex' {
            if ($Continue) {
                # Verified via `codex resume --help`: resume --last [PROMPT]
                # continues the most recent session (cwd-filtered).
                $cliArgs += @("resume", "--last")
                if (-not [string]::IsNullOrWhiteSpace($Prompt)) {
                    $cliArgs += $Prompt
                }
            } elseif (-not [string]::IsNullOrWhiteSpace($Prompt)) {
                # Verified via `codex --help`: positional [PROMPT] starts the
                # session with that prompt.
                $cliArgs += $Prompt
            }
        }
        'deepseek' {
            if ($Continue) {
                # Verified via `deepseek --help` (0.5.0): --continue/--resume
                # loads the saved session for process.cwd() before running.
                $cliArgs += "--continue"
            }
            if (-not [string]::IsNullOrWhiteSpace($Prompt)) {
                # Positional [prompt...] = one-shot (prints, exits).
                $cliArgs += $Prompt
                Write-Host "NOTE: deepseek positional prompt is one-shot; the pane content ends when it finishes." -ForegroundColor Cyan
            }
        }
        default {
            if ($Continue -or -not [string]::IsNullOrWhiteSpace($Prompt)) {
                Write-Host "WARNING: -Continue/-Prompt not mapped for agent '$Agent'; ignored." -ForegroundColor DarkCyan
            }
        }
    }
    if ($agentExe -match '\.exe$') {
        $prog = @($agentExe) + $cliArgs
    } else {
        # .cmd / extensionless shim cannot be argv0 of CreateProcess — go
        # through a PowerShell host (same pattern as bootstrap.ps1 codex).
        $cmdLine = "& '$($agentExe -replace "'", "''")'"
        foreach ($a in $cliArgs) { $cmdLine += " '$($a -replace "'", "''")'" }
        $prog = @("powershell.exe", "-NoLogo", "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $cmdLine)
    }
}

function Test-WeztermGuiAlive {
    return $null -ne (Get-Process -Name "wezterm-gui" -ErrorAction SilentlyContinue | Select-Object -First 1)
}

if ($wez -and -not $NewWindow) {
    if (Test-WeztermGuiAlive) {
        # Inject a tab into the running GUI (window 0 if WEZTERM_PANE is unset)
        $spawnArgs = @("cli", "spawn", "--cwd", $ProjectRoot)
        $winLine = & $wez cli list 2>$null | Select-Object -Skip 1 -First 1
        if ($winLine -match '^\s*(\d+)\s+') {
            $spawnArgs += @("--window-id", $Matches[1])
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
