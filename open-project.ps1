# Open WZ_Skill inside the EXISTING WezTerm window as a NEW TAB.
# Never Start-Process grok.exe alone — that creates a separate OS window
# that stacks on top of WezTerm (looks like "tabs never appear side by side").
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File G:\GrokProject\WZ_Skill\open-project.ps1
#   powershell -ExecutionPolicy Bypass -File ...\open-project.ps1 -Prompt "continue WZ"

[CmdletBinding()]
param(
    [string]$Prompt = "",
    [switch]$NewWindow,
    # Resume most recent Grok session for this project (grok -c)
    [switch]$Continue,
    # Open Grok Agent Dashboard instead of a chat
    [switch]$Dashboard
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = "G:\GrokProject\WZ_Skill"
}

# Freeze project identity: name + path (desk-roots + .wz-project)
# 「项目名」= binding name (not session title). Path is absolute and fixed.
function Update-DeskRootBinding {
    param(
        [string]$RootPath,
        [string]$ProjectName = ""
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
    if (Test-Path -LiteralPath $rootsFile) {
        foreach ($line in Get-Content -LiteralPath $rootsFile -ErrorAction SilentlyContinue) {
            $t = $line.Trim()
            if ($t -eq "" -or $t.StartsWith("#")) { continue }
            $parts = $t -split "`t", 2
            if ($parts.Count -lt 2) { $parts = $t -split "\s+", 2 }
            if ($parts.Count -ge 2) {
                $k = $parts[0]; $p = $parts[1]
                if ($reserved -contains $k.ToLowerInvariant()) { continue }
                $map[$k] = $p
            }
        }
    }
    # one path → one name
    $pk = $RootPath.TrimEnd('\').ToLowerInvariant()
    foreach ($k in @($map.Keys)) {
        if ($map[$k].TrimEnd('\').ToLowerInvariant() -eq $pk -and $k -ne $ProjectName) {
            $map.Remove($k)
        }
    }
    $map[$ProjectName] = $RootPath
    $out = @(
        "# AI STAR CUBE desk roots — project_name<TAB>absolute_path",
        "# 项目名(绑定名) 与 项目路径 写死绑定；Explorer / 状态栏 / F6 / Init 共用",
        "# 弱路径(home/Desktop/…)与保留名不得写入"
    )
    foreach ($k in ($map.Keys | Sort-Object)) {
        $out += ($k + "`t" + $map[$k])
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
Update-DeskRootBinding -RootPath $ProjectRoot -ProjectName "WZ_Skill"

$grok = Join-Path $env:USERPROFILE ".grok\bin\grok.exe"
if (-not (Test-Path -LiteralPath $grok)) {
    $cmd = Get-Command grok -ErrorAction SilentlyContinue
    if ($cmd) { $grok = $cmd.Source }
}
if (-not (Test-Path -LiteralPath $grok)) {
    throw "grok.exe not found under ~/.grok/bin or PATH"
}

$wez = $null
foreach ($c in @(
    "C:\Program Files\WezTerm\wezterm.exe",
    (Get-Command wezterm -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
)) {
    if ($c -and (Test-Path -LiteralPath $c)) { $wez = $c; break }
}

Write-Host "Project : $ProjectRoot"
Write-Host "Grok    : $grok"
Write-Host "WezTerm : $wez"

$prog = @($grok)
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
Write-Host "WARNING: WezTerm not found; starting grok in a bare console (not a WezTerm tab)."
Start-Process -FilePath $grok -ArgumentList (@("--cwd", $ProjectRoot) + @($Prompt | Where-Object { $_ })) -WorkingDirectory $ProjectRoot | Out-Null
